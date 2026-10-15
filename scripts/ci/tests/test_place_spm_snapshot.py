"""確かめた SwiftPM の写しを作業コピーに置く道具 (scripts/release/place-spm-snapshot.py) のテスト。

本リポジトリの作業コピーと配信用リポジトリの作業コピーの代わりに、一時のディレクトリに作った
使い捨ての git リポジトリを使う。配信用リポジトリの作業コピーは、origin の設定だけを配信用
リポジトリの URL にする (道具はネットワークを使わない)。
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

import release_fakes
import support
from release_fakes import git

SCRIPT = release_fakes.load("place-spm-snapshot.py")

SPM_ORIGIN = "git@github.com:kamusoft/KsCollectionView-SPM.git"
SNAPSHOT_FILES = {
    "Package.swift": "// swift-tools-version: 6.4\n",
    "Sources/A.swift": "let a = 2\n",
    "README.md": "# mirror\n",
}


def write_files(directory: str, files: dict[str, str]) -> None:
    for relative, text in files.items():
        support.write(os.path.join(directory, relative), text)


def write_snapshot(files: dict[str, str]):
    """写しを作る代わりに、決まった中身を書く関数を返す。"""

    def build(repository_root: str, destination: str) -> None:
        write_files(destination, files)

    return build


def tree_of(files: dict[str, str]) -> str:
    with tempfile.TemporaryDirectory() as directory:
        write_files(directory, files)
        git(directory, "init", "--quiet")
        git(directory, "add", "--all")
        return git(directory, "write-tree")


class PlaceTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="release-place-test-")
        self.addCleanup(shutil.rmtree, self.directory)
        # 本リポジトリの作業コピー (写しを作り直す元)。
        self.work = os.path.join(self.directory, "work")
        os.makedirs(self.work)
        git(self.work, "init", "--quiet")
        support.write(os.path.join(self.work, "file.txt"), "1\n")
        git(self.work, "add", "--all")
        git(self.work, "commit", "--quiet", "-m", "first")
        self.commit = git(self.work, "rev-parse", "HEAD")
        # 配信用リポジトリの作業コピー。前の版の写しが入っている。
        self.spm = os.path.join(self.directory, "spm")
        os.makedirs(self.spm)
        git(self.spm, "init", "--quiet")
        git(self.spm, "config", "remote.origin.url", SPM_ORIGIN)
        write_files(self.spm, {"Package.swift": "// old\n", "Sources/A.swift": "let a = 1\n", "Sources/Old.swift": "old\n"})
        git(self.spm, "add", "--all")
        git(self.spm, "commit", "--quiet", "-m", "previous")
        self.previous = git(self.spm, "rev-parse", "HEAD")
        # 利用者役で確かめた写し (artifact を取り込んだディレクトリ)。
        self.snapshot = os.path.join(self.directory, "spm-snapshot")
        write_files(self.snapshot, SNAPSHOT_FILES)
        patcher = mock.patch.object(SCRIPT, "build_snapshot", write_snapshot(SNAPSHOT_FILES))
        patcher.start()
        self.addCleanup(patcher.stop)

    def run_place(self, commit: str | None = None, destination: str | None = None):
        return support.run_main(
            SCRIPT,
            [
                "--snapshot", self.snapshot, "--destination", destination or self.spm,
                "--commit", commit or self.commit, "--repository-root", self.work,
            ],
        )

    def spm_files(self) -> dict[str, str]:
        found = {}
        for current, directories, files in os.walk(self.spm):
            directories[:] = [name for name in directories if name != ".git"]
            for name in files:
                path = os.path.join(current, name)
                with open(path, encoding="utf-8") as f:
                    found[os.path.relpath(path, self.spm)] = f.read()
        return found

    def test_places_the_verified_snapshot_and_stages_it(self):
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 0, stdout)
        self.assertEqual(self.spm_files(), SNAPSHOT_FILES)
        # index の中身が確かめた写しと同じで、履歴 (.git) は残っている。
        self.assertEqual(git(self.spm, "write-tree"), tree_of(SNAPSHOT_FILES))
        self.assertEqual(git(self.spm, "rev-parse", "HEAD"), self.previous)
        staged = git(self.spm, "diff", "--cached", "--name-status")
        self.assertIn("D\tSources/Old.swift", staged)
        self.assertIn("M\tSources/A.swift", staged)
        self.assertIn("A\tREADME.md", staged)
        # 確かめた写しには、比べるための git の管理情報を作らない。
        self.assertFalse(os.path.exists(os.path.join(self.snapshot, ".git")))

    def test_stages_nothing_when_the_snapshot_is_already_there(self):
        self.assertEqual(self.run_place()[0], 0)
        git(self.spm, "commit", "--quiet", "-m", "snapshot")
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 0, stdout)
        self.assertEqual(git(self.spm, "status", "--porcelain"), "")

    def test_stops_without_touching_the_working_copy_when_the_snapshot_differs_from_the_commit(self):
        write_files(self.snapshot, {"Sources/A.swift": "let a = 3\n"})
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("起動した commit", stdout)
        self.assertIn("作業コピーは変えていない", stdout)
        self.assertEqual(git(self.spm, "status", "--porcelain"), "")

    def test_stops_when_the_snapshot_has_an_extra_file(self):
        write_files(self.snapshot, {"Sources/Leftover.swift": "x\n"})
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("から作った写し", stdout)
        self.assertEqual(git(self.spm, "status", "--porcelain"), "")

    def test_stops_when_the_working_tree_is_not_the_commit(self):
        code, stdout, _ = self.run_place(commit="f" * 40)
        self.assertEqual(code, 1)
        self.assertIn("HEAD", stdout)
        self.assertEqual(git(self.spm, "status", "--porcelain"), "")

    def test_rejects_a_malformed_commit(self):
        code, stdout, _ = self.run_place(commit="abc")
        self.assertEqual(code, 1)
        self.assertIn("commit の ID の形が違う", stdout)

    def test_stops_when_the_snapshot_is_missing_or_empty(self):
        shutil.rmtree(self.snapshot)
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("確かめた写しのディレクトリが無い", stdout)
        os.makedirs(self.snapshot)
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("Package.swift が無い", stdout)

    def test_stops_when_the_snapshot_contains_git_metadata(self):
        support.write(os.path.join(self.snapshot, "Sources", ".git"), "gitdir: elsewhere\n")
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("git の管理情報 (.git) がある", stdout)

    def test_stops_without_touching_a_working_copy_of_another_repository(self):
        git(self.spm, "config", "remote.origin.url", "git@github.com:someone/KsCollectionView-SPM.git")
        code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("作業コピーとして受け付けられない", stdout)
        self.assertEqual(git(self.spm, "status", "--porcelain"), "")

    def test_stops_when_the_destination_is_not_a_working_copy(self):
        empty = os.path.join(self.directory, "empty")
        os.makedirs(empty)
        code, stdout, _ = self.run_place(destination=empty)
        self.assertEqual(code, 1)
        self.assertIn(".git が無い", stdout)
        self.assertEqual(os.listdir(empty), [])

    def test_stops_when_the_staged_tree_differs_from_the_verified_snapshot(self):
        original = SCRIPT.copy_contents

        def copy_and_add(source, destination):
            original(source, destination)
            support.write(os.path.join(destination, "Sources", "Stray.swift"), "stray\n")

        with mock.patch.object(SCRIPT, "copy_contents", copy_and_add):
            code, stdout, _ = self.run_place()
        self.assertEqual(code, 1)
        self.assertIn("push しない", stdout)


class PlaceWithRealSnapshotTest(unittest.TestCase):
    """このリポジトリの作業ツリーから本物の写しを作り、それを確かめた写しとして置けることを確かめる。"""

    def test_places_a_snapshot_built_from_this_repository(self):
        head = subprocess.run(
            ["git", "-C", support.REPOSITORY_ROOT, "rev-parse", "HEAD"], capture_output=True, text=True, check=True
        ).stdout.strip()
        with tempfile.TemporaryDirectory(prefix="release-place-real-") as directory:
            snapshot = os.path.join(directory, "spm-snapshot")
            SCRIPT.build_snapshot(support.REPOSITORY_ROOT, snapshot)
            spm = os.path.join(directory, "spm")
            os.makedirs(spm)
            git(spm, "init", "--quiet")
            git(spm, "config", "remote.origin.url", SPM_ORIGIN)
            code, stdout, _ = support.run_main(
                SCRIPT,
                [
                    "--snapshot", snapshot, "--destination", spm, "--commit", head,
                    "--repository-root", support.REPOSITORY_ROOT,
                ],
            )
            self.assertEqual(code, 0, stdout)
            self.assertTrue(os.path.isfile(os.path.join(spm, "Package.swift")))
            self.assertNotEqual(git(spm, "diff", "--cached", "--name-only"), "")


if __name__ == "__main__":
    unittest.main()
