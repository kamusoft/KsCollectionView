"""リリースを始めてよいかの確かめ (scripts/release/check-release-state.py) のテスト。

本リポジトリと配信用リポジトリの代わりに、一時のディレクトリに作った使い捨ての git リポジトリ
(bare の remote) を使う。Maven Central の取得先の代わりに、偽の HTTP サーバを使う。
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

SCRIPT = release_fakes.load("check-release-state.py")

VERSION = "0.1.0-beta.1"
SNAPSHOT_FILES = {"Package.swift": "// swift-tools-version: 6.4\n", "Sources/A.swift": "let a = 1\n", "README.md": "# mirror\n"}


def write_snapshot(files: dict[str, str]):
    """写しを作る代わりに、決まった中身を書く関数を返す。"""

    def build(repository_root: str, destination: str) -> None:
        for relative, text in files.items():
            support.write(os.path.join(destination, relative), text)

    return build


def outputs_of(path: str) -> dict[str, str]:
    with open(path, encoding="utf-8") as f:
        return dict(line.split("=", 1) for line in f.read().splitlines())


class InputsTest(unittest.TestCase):
    def run_inputs(self, version, dry_run, ref):
        with tempfile.TemporaryDirectory() as directory:
            output = os.path.join(directory, "output")
            code, stdout, _ = support.run_main(
                SCRIPT, ["inputs", "--version", version, "--dry-run", dry_run, "--ref", ref], {"GITHUB_OUTPUT": output}
            )
            return code, stdout, outputs_of(output) if os.path.exists(output) else {}

    def test_accepts_production_from_main(self):
        code, _, outputs = self.run_inputs(VERSION, "false", "refs/heads/main")
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"version": VERSION, "production": "true", "on-main": "true"})

    def test_rejects_wrong_version_forms_first(self):
        for version in ("v0.1.0", "0.1", "0.1.0-pre.1"):
            with self.subTest(version=version):
                code, stdout, outputs = self.run_inputs(version, "true", "refs/heads/main")
                self.assertEqual(code, 1)
                self.assertIn("版の形が違う", stdout)
                self.assertEqual(outputs, {})

    def test_rejects_production_from_other_branches(self):
        code, stdout, outputs = self.run_inputs(VERSION, "false", "refs/heads/develop")
        self.assertEqual(code, 1)
        self.assertIn("main からだけ受け付ける", stdout)
        self.assertEqual(outputs, {})

    def test_accepts_dry_run_from_other_branches(self):
        code, _, outputs = self.run_inputs(VERSION, "true", "refs/heads/develop")
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"version": VERSION, "production": "false", "on-main": "false"})

    def test_rejects_unknown_dry_run_values(self):
        code, stdout, _ = self.run_inputs(VERSION, "yes", "refs/heads/main")
        self.assertEqual(code, 1)
        self.assertIn("dry-run は true か false", stdout)


class TagsTest(unittest.TestCase):
    """本リポジトリの作業コピーと、両リポジトリの bare の remote を一時のディレクトリに作る。"""

    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="release-tags-test-")
        self.addCleanup(shutil.rmtree, self.directory)
        self.main_remote = os.path.join(self.directory, "main.git")
        self.spm_remote = os.path.join(self.directory, "spm.git")
        self.work = os.path.join(self.directory, "work")
        git(self.directory, "init", "--quiet", "--bare", self.main_remote)
        git(self.directory, "init", "--quiet", "--bare", self.spm_remote)
        git(self.directory, "clone", "--quiet", self.main_remote, self.work)
        support.write(os.path.join(self.work, "file.txt"), "1\n")
        git(self.work, "add", "--all")
        git(self.work, "commit", "--quiet", "-m", "first")
        self.first = git(self.work, "rev-parse", "HEAD")
        support.write(os.path.join(self.work, "file.txt"), "2\n")
        git(self.work, "commit", "--quiet", "-am", "second")
        self.commit = git(self.work, "rev-parse", "HEAD")
        git(self.work, "push", "--quiet", "origin", "HEAD:refs/heads/main")
        self.build_patch = mock.patch.object(SCRIPT, "build_snapshot", write_snapshot(SNAPSHOT_FILES))
        self.build_patch.start()
        self.addCleanup(self.build_patch.stop)

    def push_spm_tag(self, files: dict[str, str], tag: str = VERSION) -> str:
        """配信用リポジトリに、files を中身とする commit を作って tag を付ける。"""
        spm_work = os.path.join(self.directory, f"spm-work-{len(os.listdir(self.directory))}")
        git(self.directory, "clone", "--quiet", self.spm_remote, spm_work)
        for relative, text in files.items():
            support.write(os.path.join(spm_work, relative), text)
        git(spm_work, "add", "--all")
        git(spm_work, "commit", "--quiet", "-m", "snapshot")
        git(spm_work, "tag", tag)
        git(spm_work, "push", "--quiet", "origin", "HEAD:refs/heads/main", f"refs/tags/{tag}")
        return git(spm_work, "rev-parse", "HEAD")

    def run_tags(self, commit: str | None = None, spm_url: str | None = None):
        output = os.path.join(self.directory, "output")
        if os.path.exists(output):
            os.remove(output)
        code, stdout, _ = support.run_main(
            SCRIPT,
            [
                "tags", "--version", VERSION, "--commit", commit or self.commit,
                "--remote", self.main_remote, "--spm-url", spm_url or self.spm_remote,
                "--repository-root", self.work,
            ],
            {"GITHUB_OUTPUT": output},
        )
        return code, stdout, outputs_of(output) if os.path.exists(output) else {}

    def test_continues_when_neither_repository_has_the_tag(self):
        code, _, outputs = self.run_tags()
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"main-tag": "absent", "spm-tag": "absent"})

    def test_continues_as_a_rerun_when_the_main_tag_points_at_the_commit(self):
        for annotated in (False, True):
            with self.subTest(annotated=annotated):
                arguments = ["-a", "-m", "release"] if annotated else []
                git(self.work, "tag", "-f", *arguments, VERSION, self.commit)
                git(self.work, "push", "--quiet", "--force", "origin", f"refs/tags/{VERSION}")
                code, stdout, outputs = self.run_tags()
                self.assertEqual(code, 0, stdout)
                self.assertEqual(outputs["main-tag"], "matches")

    def test_stops_when_the_main_tag_points_at_another_commit(self):
        git(self.work, "tag", VERSION, self.first)
        git(self.work, "push", "--quiet", "origin", f"refs/tags/{VERSION}")
        code, stdout, outputs = self.run_tags()
        self.assertEqual(code, 1)
        self.assertIn(f"本リポジトリの tag {VERSION} が、起動した commit", stdout)
        self.assertEqual(outputs, {})

    def test_continues_when_the_spm_tag_has_the_same_snapshot(self):
        self.push_spm_tag(SNAPSHOT_FILES)
        code, stdout, outputs = self.run_tags()
        self.assertEqual(code, 0, stdout)
        self.assertEqual(outputs, {"main-tag": "absent", "spm-tag": "matches"})

    def test_stops_when_the_spm_tag_has_another_snapshot(self):
        self.push_spm_tag({**SNAPSHOT_FILES, "Sources/A.swift": "let a = 2\n"})
        code, stdout, outputs = self.run_tags()
        self.assertEqual(code, 1)
        self.assertIn(f"配信用リポジトリの tag {VERSION} が指す commit", stdout)
        self.assertEqual(outputs, {})

    def test_stops_when_only_the_spm_tag_differs_while_the_main_tag_matches(self):
        git(self.work, "tag", VERSION, self.commit)
        git(self.work, "push", "--quiet", "origin", f"refs/tags/{VERSION}")
        self.push_spm_tag({"Package.swift": "// 別の写し\n"})
        code, stdout, _ = self.run_tags()
        self.assertEqual(code, 1)
        self.assertIn("配信用リポジトリの tag", stdout)
        self.assertNotIn("本リポジトリの tag 0.1.0-beta.1 が、起動した commit", stdout)

    def test_stops_when_the_working_tree_is_not_the_commit(self):
        self.push_spm_tag(SNAPSHOT_FILES)
        code, stdout, _ = self.run_tags(commit=self.first)
        self.assertEqual(code, 1)
        self.assertIn("HEAD", stdout)

    def test_stops_when_a_remote_cannot_be_read(self):
        code, stdout, _ = self.run_tags(spm_url=os.path.join(self.directory, "missing.git"))
        self.assertEqual(code, 1)
        self.assertIn("tag を読めない", stdout)

    def test_rejects_a_malformed_commit(self):
        code, stdout, _ = self.run_tags(commit="abc")
        self.assertEqual(code, 1)
        self.assertIn("commit の ID の形が違う", stdout)


class TagsWithRealSnapshotTest(unittest.TestCase):
    """このリポジトリの作業ツリーから本物の写しを作り、同じ写しに付いた tag を受け付けることを確かめる。"""

    def test_accepts_a_tag_on_the_snapshot_built_from_this_repository(self):
        head = subprocess.run(
            ["git", "-C", support.REPOSITORY_ROOT, "rev-parse", "HEAD"], capture_output=True, text=True, check=True
        ).stdout.strip()
        with tempfile.TemporaryDirectory(prefix="release-real-snapshot-") as directory:
            main_remote = os.path.join(directory, "main.git")
            spm_remote = os.path.join(directory, "spm.git")
            git(directory, "init", "--quiet", "--bare", main_remote)
            git(directory, "init", "--quiet", "--bare", spm_remote)
            snapshot = os.path.join(directory, "snapshot")
            SCRIPT.build_snapshot(support.REPOSITORY_ROOT, snapshot)
            git(snapshot, "init", "--quiet")
            git(snapshot, "add", "--all")
            git(snapshot, "commit", "--quiet", "-m", "snapshot")
            git(snapshot, "tag", VERSION)
            git(snapshot, "push", "--quiet", spm_remote, "HEAD:refs/heads/main", f"refs/tags/{VERSION}")
            output = os.path.join(directory, "output")
            code, stdout, _ = support.run_main(
                SCRIPT,
                [
                    "tags", "--version", VERSION, "--commit", head, "--remote", main_remote,
                    "--spm-url", spm_remote, "--repository-root", support.REPOSITORY_ROOT,
                ],
                {"GITHUB_OUTPUT": output},
            )
            self.assertEqual(code, 0, stdout)
            self.assertEqual(outputs_of(output), {"main-tag": "absent", "spm-tag": "matches"})


class PublishedTest(unittest.TestCase):
    COMMIT = "c" * 40

    def run_published(self, handler):
        with release_fakes.FakeServer(handler) as server, tempfile.TemporaryDirectory() as directory:
            output = os.path.join(directory, "output")
            code, stdout, _ = support.run_main(
                SCRIPT,
                ["published", "--version", VERSION, "--commit", self.COMMIT, "--maven-url", server.url + "/maven2"],
                {"GITHUB_OUTPUT": output},
            )
            requests = list(server.requests)
            return code, stdout, outputs_of(output) if os.path.exists(output) else {}, requests

    def test_unpublished_version_continues(self):
        code, _, outputs, requests = self.run_published(lambda request: (404, "not found"))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"published": "false"})
        self.assertEqual(
            requests[0].path, f"/maven2/jp/kamusoft/kscollectionview/{VERSION}/kscollectionview-{VERSION}.pom"
        )

    def test_version_published_from_the_same_commit_continues(self):
        code, _, outputs, _ = self.run_published(lambda request: (200, release_fakes.pom_text(VERSION, self.COMMIT)))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"published": "true"})

    def test_version_published_from_another_commit_stops(self):
        code, stdout, outputs, _ = self.run_published(lambda request: (200, release_fakes.pom_text(VERSION, "d" * 40)))
        self.assertEqual(code, 1)
        self.assertIn("別の commit", stdout)
        self.assertEqual(outputs, {})

    def test_published_pom_without_commit_stops(self):
        code, stdout, _, _ = self.run_published(lambda request: (200, release_fakes.pom_text(VERSION, None)))
        self.assertEqual(code, 1)
        self.assertIn("scm の tag", stdout)

    def test_unexpected_status_stops(self):
        code, stdout, _, _ = self.run_published(lambda request: (503, "busy"))
        self.assertEqual(code, 1)
        self.assertIn("503", stdout)

    def test_unreachable_registry_stops(self):
        with tempfile.TemporaryDirectory() as directory:
            with release_fakes.FakeServer(lambda request: (404, "")) as server:
                url = server.url
            code, stdout, _ = support.run_main(
                SCRIPT,
                ["published", "--version", VERSION, "--commit", self.COMMIT, "--maven-url", url],
                {"GITHUB_OUTPUT": os.path.join(directory, "output"), **release_fakes.NO_PROXY},
            )
        self.assertEqual(code, 1)
        self.assertIn("届かない", stdout)


if __name__ == "__main__":
    unittest.main()
