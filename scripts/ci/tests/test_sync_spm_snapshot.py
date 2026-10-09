"""SwiftPM の写しを作る道具のテスト。

写しの元は、一時のディレクトリに作った使い捨ての git リポジトリにする (元を欠いたり、
リポジトリの中を行き先にしたりする異常系を、このリポジトリを壊さずに確かめるため)。
このリポジトリの実物を元にするのは、行き先が一時のディレクトリの正常系だけである。
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

import support

DISTRIBUTION_DIR = os.path.join(support.REPOSITORY_ROOT, "scripts", "distribution")
SCRIPT = support.load_script("sync-spm-snapshot.py", DISTRIBUTION_DIR)

MAIN_REPOSITORY_URL = "https://github.com/kamusoft/KsCollectionView"
DISTRIBUTION_ORIGIN = "https://github.com/kamusoft/KsCollectionView-SPM.git"
SNAPSHOT_ENTRIES = ["LICENSE", "Package.swift", "README.md", "Sources", "Tests"]

MANIFEST_TEXT = "// swift-tools-version: 6.4\n// 写しの元のマニフェスト\n"
LICENSE_TEXT = "MIT License\n"
README_TEXT = f"# distribution mirror\n\n{MAIN_REPOSITORY_URL}\n"


def git(directory: str, *arguments: str) -> str:
    """使い捨てのリポジトリで git を呼ぶ。利用者の設定 (署名・hook の雛形など) を読ませない。"""
    environment = {key: value for key, value in os.environ.items() if key not in SCRIPT.GIT_LOCATION_VARIABLES}
    environment.update({"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull})
    result = subprocess.run(
        ["git", "-C", directory, "-c", "user.name=test", "-c", "user.email=test@example.com", *arguments],
        capture_output=True,
        text=True,
        env=environment,
        check=True,
    )
    return result.stdout


def commit_all(directory: str, message: str) -> None:
    git(directory, "add", "--all")
    git(directory, "commit", "--quiet", "--message", message)


def tree(directory: str) -> dict[str, str | bytes]:
    """.git を除く中身を、相対パス → 内容 の対応で返す。ディレクトリとシンボリックリンクも載せる。"""
    entries: dict[str, str | bytes] = {}
    for current, directories, files in os.walk(directory):
        if current == directory and ".git" in directories:
            directories.remove(".git")
        for name in directories + files:
            path = os.path.join(current, name)
            relative = os.path.relpath(path, directory)
            if os.path.islink(path):
                entries[relative] = "link:" + os.readlink(path)
            elif os.path.isdir(path):
                entries[relative] = "directory"
            else:
                with open(path, "rb") as f:
                    entries[relative] = f.read()
    return entries


def git_state(directory: str) -> dict[str, str]:
    return {
        "head": git(directory, "rev-parse", "HEAD"),
        "commits": git(directory, "rev-list", "--all", "--count"),
        "tags": git(directory, "tag", "--list"),
        "branches": git(directory, "branch", "--list"),
        "origin": git(directory, "config", "--get", "remote.origin.url"),
    }


def read_bytes(*parts: str) -> bytes:
    with open(os.path.join(*parts), "rb") as f:
        return f.read()


class SnapshotTestCase(unittest.TestCase):
    """写しの元の使い捨てのリポジトリと、行き先を置く場所を用意する。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        # macOS の一時のディレクトリはシンボリックリンクの下にあるので、実体のパスに直しておく。
        self.work = os.path.realpath(directory.name)
        # 写しの元のリポジトリは 1 段下に置く (「このリポジトリを含むディレクトリ」を一時の場所の中に作るため)。
        self.container = os.path.join(self.work, "container")
        self.source = os.path.join(self.container, "KsCollectionView")
        self.make_source_repository()
        patcher = mock.patch.object(SCRIPT, "REPOSITORY_ROOT", self.source)
        patcher.start()
        self.addCleanup(patcher.stop)

    def make_source_repository(self) -> None:
        support.write(os.path.join(self.source, "ios", "Package.swift"), MANIFEST_TEXT)
        support.write(os.path.join(self.source, "ios", "Sources", "Library", "List.swift"), "// 一覧\n")
        support.write(os.path.join(self.source, "ios", "Sources", "Library", "Cells", "Cell.swift"), "// セル\n")
        support.write(os.path.join(self.source, "ios", "Tests", "LibraryTests", "ListTests.swift"), "// テスト\n")
        support.write(os.path.join(self.source, "LICENSE"), LICENSE_TEXT)
        support.write(os.path.join(self.source, "scripts", "distribution", "spm-readme.template.md"), README_TEXT)
        support.write(os.path.join(self.source, "android", "build.gradle.kts"), "// 写しに入らないもの\n")
        git(self.source, "init", "--quiet")
        commit_all(self.source, "source")

    def make_working_copy(
        self,
        name: str = "KsCollectionView-SPM",
        origin: str | None = DISTRIBUTION_ORIGIN,
        git_directory: str | None = None,
    ) -> str:
        """前の写しを commit してある、配信用リポジトリの作業コピーを作る。

        git_directory を渡すと、git の管理情報をそこに置き、.git はそこを指すファイルになる。
        """
        path = os.path.join(self.work, name)
        support.write(os.path.join(path, "Package.swift"), "// 前の写しのマニフェスト\n")
        support.write(os.path.join(path, "Sources", "Library", "Removed.swift"), "// 本体から消えたファイル\n")
        support.write(os.path.join(path, "Tests", "LibraryTests", "RemovedTests.swift"), "// 消えたテスト\n")
        support.write(os.path.join(path, "LICENSE"), "previous\n")
        support.write(os.path.join(path, "README.md"), "previous\n")
        support.write(os.path.join(path, ".hidden"), "前の写しに無いはずのファイル\n")
        if git_directory is None:
            git(path, "init", "--quiet")
        else:
            git(path, "init", "--quiet", "--separate-git-dir", git_directory)
        if origin is not None:
            git(path, "remote", "add", "origin", origin)
        commit_all(path, "previous snapshot")
        git(path, "tag", "0.0.1")
        return path

    def run_tool(self, destination: str, env: dict[str, str] | None = None) -> tuple[int, str, str]:
        return support.run_main(SCRIPT, [destination], env=env)

    def assert_refused(self, destination: str, watched: str, reason: str) -> None:
        """失敗で終わり、watched の下が何も変わっていないことを確かめる。"""
        before = tree(watched) if os.path.exists(watched) else None
        code, stdout, stderr = self.run_tool(destination)
        self.assertEqual(code, 1, stdout + stderr)
        self.assertIn(reason, stderr)
        self.assertNotIn("写しを作った", stdout)
        after = tree(watched) if os.path.exists(watched) else None
        self.assertEqual(before, after)


class SyncSnapshotTest(SnapshotTestCase):
    def test_空の行き先に5点だけが置かれる(self) -> None:
        destination = os.path.join(self.work, "empty")
        os.makedirs(destination)
        code, stdout, stderr = self.run_tool(destination)
        self.assertEqual(code, 0, stderr)
        self.assertEqual(sorted(os.listdir(destination)), SNAPSHOT_ENTRIES)
        self.assertIn(f"写しを作った: {destination} (Sources 2 ファイル / Tests 1 ファイル)", stdout)

    def test_無い行き先は作られる(self) -> None:
        destination = os.path.join(self.work, "not", "yet", "KsCollectionView-SPM")
        code, _, stderr = self.run_tool(destination)
        self.assertEqual(code, 0, stderr)
        self.assertEqual(sorted(os.listdir(destination)), SNAPSHOT_ENTRIES)

    def test_マニフェストとライセンスとREADMEは元と同じ内容である(self) -> None:
        destination = os.path.join(self.work, "snapshot")
        self.assertEqual(self.run_tool(destination)[0], 0)
        self.assertEqual(read_bytes(destination, "Package.swift"), read_bytes(self.source, "ios", "Package.swift"))
        self.assertEqual(read_bytes(destination, "LICENSE"), read_bytes(self.source, "LICENSE"))
        self.assertEqual(
            read_bytes(destination, "README.md"),
            read_bytes(self.source, "scripts", "distribution", "spm-readme.template.md"),
        )

    def test_追跡しているソースとテストが同じ配置で写される(self) -> None:
        destination = os.path.join(self.work, "snapshot")
        self.assertEqual(self.run_tool(destination)[0], 0)
        self.assertEqual(
            tree(destination),
            {
                "Package.swift": MANIFEST_TEXT.encode(),
                "LICENSE": LICENSE_TEXT.encode(),
                "README.md": README_TEXT.encode(),
                "Sources": "directory",
                os.path.join("Sources", "Library"): "directory",
                os.path.join("Sources", "Library", "List.swift"): "// 一覧\n".encode(),
                os.path.join("Sources", "Library", "Cells"): "directory",
                os.path.join("Sources", "Library", "Cells", "Cell.swift"): "// セル\n".encode(),
                "Tests": "directory",
                os.path.join("Tests", "LibraryTests"): "directory",
                os.path.join("Tests", "LibraryTests", "ListTests.swift"): "// テスト\n".encode(),
            },
        )

    def test_追跡していないファイルは写されない(self) -> None:
        support.write(os.path.join(self.source, "ios", "Sources", "Library", "Untracked.swift"), "// 未追跡\n")
        support.write(os.path.join(self.source, "ios", "Sources", ".build", "output.o"), "ビルドの出力\n")
        support.write(os.path.join(self.source, "ios", "Tests", "LibraryTests", "Scratch.swift"), "// 未追跡\n")
        destination = os.path.join(self.work, "snapshot")
        self.assertEqual(self.run_tool(destination)[0], 0)
        copied = tree(destination)
        self.assertNotIn(os.path.join("Sources", "Library", "Untracked.swift"), copied)
        self.assertNotIn(os.path.join("Sources", ".build"), copied)
        self.assertNotIn(os.path.join("Tests", "LibraryTests", "Scratch.swift"), copied)
        # 追跡しているファイルは、消えずに写っている。
        self.assertIn(os.path.join("Sources", "Library", "List.swift"), copied)

    def test_追跡しているファイルは作業ツリーの今の内容で写される(self) -> None:
        support.write(os.path.join(self.source, "ios", "Package.swift"), "// commit していない変更\n")
        destination = os.path.join(self.work, "snapshot")
        self.assertEqual(self.run_tool(destination)[0], 0)
        self.assertEqual(read_bytes(destination, "Package.swift"), "// commit していない変更\n".encode())

    def test_本体から消えたファイルは作業コピーに残らない(self) -> None:
        destination = self.make_working_copy()
        code, _, stderr = self.run_tool(destination)
        self.assertEqual(code, 0, stderr)
        self.assertEqual(sorted(os.listdir(destination)), [".git"] + SNAPSHOT_ENTRIES)
        copied = tree(destination)
        self.assertNotIn(os.path.join("Sources", "Library", "Removed.swift"), copied)
        self.assertNotIn(os.path.join("Tests", "LibraryTests", "RemovedTests.swift"), copied)
        self.assertEqual(copied["Package.swift"], MANIFEST_TEXT.encode())
        self.assertEqual(copied["LICENSE"], LICENSE_TEXT.encode())

    def test_行き先のgitの状態を進めない(self) -> None:
        destination = self.make_working_copy()
        before = git_state(destination)
        self.assertEqual(self.run_tool(destination)[0], 0)
        self.assertTrue(os.path.isdir(os.path.join(destination, ".git")))
        self.assertEqual(git_state(destination), before)
        # 写した結果は、commit されずに作業ツリーの変更として残る。
        self.assertIn("Package.swift", git(destination, "status", "--porcelain"))

    def test_作業コピーに2回流しても同じ結果になる(self) -> None:
        destination = self.make_working_copy()
        self.assertEqual(self.run_tool(destination)[0], 0)
        first = tree(destination)
        self.assertEqual(self.run_tool(destination)[0], 0)
        self.assertEqual(tree(destination), first)

    def test_originの書き方の違いを受け付ける(self) -> None:
        origins = (
            "https://github.com/kamusoft/KsCollectionView-SPM",
            "https://github.com/kamusoft/KsCollectionView-SPM.git",
            "https://github.com/kamusoft/KsCollectionView-SPM/",
            "ssh://git@github.com/kamusoft/KsCollectionView-SPM.git",
            "git@github.com:kamusoft/KsCollectionView-SPM.git",
        )
        for index, origin in enumerate(origins):
            with self.subTest(origin=origin):
                destination = self.make_working_copy(f"working-copy-{index}", origin)
                code, _, stderr = self.run_tool(destination)
                self.assertEqual(code, 0, stderr)
                self.assertEqual(sorted(os.listdir(destination)), [".git"] + SNAPSHOT_ENTRIES)

    def test_行き先の中のシンボリックリンクは指す先を消さない(self) -> None:
        outside = os.path.join(self.work, "outside")
        kept = support.write(os.path.join(outside, "kept.txt"), "消してはいけない\n")
        destination = self.make_working_copy()
        os.symlink(outside, os.path.join(destination, "link"))
        self.assertEqual(self.run_tool(destination)[0], 0)
        self.assertFalse(os.path.lexists(os.path.join(destination, "link")))
        self.assertTrue(os.path.isfile(kept))


class RefusalTest(SnapshotTestCase):
    def test_元が欠けていると何も消さない(self) -> None:
        def remove_file(*parts: str):
            return lambda: os.unlink(os.path.join(self.source, *parts))

        def remove_directory(*parts: str):
            return lambda: shutil.rmtree(os.path.join(self.source, *parts))

        def untrack_sources() -> None:
            # ディレクトリは残っているが、追跡しているファイルが 1 つも無い。
            git(self.source, "rm", "--quiet", "--cached", "-r", os.path.join("ios", "Sources"))

        cases = {
            "マニフェスト": (remove_file("ios", "Package.swift"), os.path.join("ios", "Package.swift")),
            "ソース": (remove_directory("ios", "Sources"), os.path.join("ios", "Sources")),
            "テスト": (remove_directory("ios", "Tests"), os.path.join("ios", "Tests")),
            "ライセンス": (remove_file("LICENSE"), "LICENSE"),
            "固定文": (
                remove_file("scripts", "distribution", "spm-readme.template.md"),
                os.path.join("scripts", "distribution", "spm-readme.template.md"),
            ),
            "追跡しているファイルが作業ツリーに無い": (
                remove_file("ios", "Sources", "Library", "List.swift"),
                os.path.join("ios", "Sources", "Library", "List.swift"),
            ),
            "追跡しているファイルが1つも無い": (untrack_sources, os.path.join("ios", "Sources")),
        }
        destination = self.make_working_copy()
        pristine = os.path.join(self.work, "pristine-source")
        shutil.copytree(self.source, pristine, symlinks=True)
        for name, (damage, expected) in cases.items():
            with self.subTest(欠けた元=name):
                shutil.rmtree(self.source)
                shutil.copytree(pristine, self.source, symlinks=True)
                damage()
                before = git_state(destination)
                self.assert_refused(destination, destination, "写しの元が欠けている")
                self.assertIn(expected, self.run_tool(destination)[2])
                self.assertEqual(git_state(destination), before)

    def test_元が欠けていると無い行き先を作らない(self) -> None:
        os.unlink(os.path.join(self.source, "LICENSE"))
        destination = os.path.join(self.work, "not-yet")
        self.assert_refused(destination, self.work, "写しの元が欠けている")
        self.assertFalse(os.path.exists(destination))

    def test_このリポジトリの中を行き先にすると拒否する(self) -> None:
        os.makedirs(os.path.join(self.source, "empty"))
        destinations = {
            "リポジトリのルート": self.source,
            "中身のあるディレクトリ": os.path.join(self.source, "ios"),
            "ソースのディレクトリ": os.path.join(self.source, "ios", "Sources"),
            "空のディレクトリ": os.path.join(self.source, "empty"),
            "まだ無いパス": os.path.join(self.source, "build", "KsCollectionView-SPM"),
        }
        for name, destination in destinations.items():
            with self.subTest(行き先=name):
                self.assert_refused(destination, self.source, "行き先がこのリポジトリの中にある")
        self.assertFalse(os.path.exists(os.path.join(self.source, "build")))

    def test_シンボリックリンクでこのリポジトリの中を指す行き先を拒否する(self) -> None:
        link = os.path.join(self.work, "link-into-repository")
        os.symlink(os.path.join(self.source, "ios"), link)
        self.assert_refused(link, self.source, "行き先がこのリポジトリの中にある")

    def test_このリポジトリを含むディレクトリを行き先にすると拒否する(self) -> None:
        support.write(os.path.join(self.container, "neighbor.txt"), "隣のファイル\n")
        for name, destination in {"親": self.container, "親の親": self.work}.items():
            with self.subTest(行き先=name):
                self.assert_refused(destination, self.work, "行き先がこのリポジトリを含むディレクトリである")

    def test_ファイルシステムのルートは何でも含むと判定する(self) -> None:
        # ルートを行き先にして道具を流すことはできないので、判定だけを確かめる。
        self.assertTrue(SCRIPT.is_within(self.source, os.path.abspath(os.sep)))
        self.assertTrue(SCRIPT.is_within(os.path.join(self.source, "not", "yet"), self.source))
        # 名前が前方一致するだけの隣のディレクトリは、中ではない。
        self.assertFalse(SCRIPT.is_within(self.source + "-SPM", self.source))

    def test_中身があって作業コピーでない行き先を拒否する(self) -> None:
        plain = os.path.join(self.work, "plain")
        support.write(os.path.join(plain, "notes.txt"), "消してはいけない\n")
        self.assert_refused(plain, plain, "配信用リポジトリ (kamusoft/KsCollectionView-SPM) の作業コピーでもない")
        self.assert_refused(plain, plain, "git のリポジトリではない")

    def test_originが配信用リポジトリでない作業コピーを拒否する(self) -> None:
        origins = (
            "https://github.com/kamusoft/KsCollectionView.git",
            "https://github.com/someone/KsCollectionView-SPM.git",
            "https://example.com/mirror/kamusoft/KsCollectionView-SPM.git",
            "https://github.com/kamusoft/KsCollectionView-SPM-fork.git",
            "git@github.com:kamusoft/KsSettingsView-SPM.git",
        )
        for index, origin in enumerate(origins):
            with self.subTest(origin=origin):
                destination = self.make_working_copy(f"other-{index}", origin)
                before = git_state(destination)
                self.assert_refused(destination, destination, f"origin: {origin}")
                self.assertEqual(git_state(destination), before)

    def test_originの無いリポジトリを拒否する(self) -> None:
        destination = self.make_working_copy("no-origin", origin=None)
        self.assert_refused(destination, destination, "origin が無い")

    def test_作業コピーの最上位でないディレクトリを拒否する(self) -> None:
        working_copy = self.make_working_copy()
        self.assert_refused(os.path.join(working_copy, "Sources"), working_copy, "git の最上位ではない")

    def test_gitの管理情報が行き先の中の別のディレクトリにある作業コピーを拒否する(self) -> None:
        # .git が、行き先の中の別のディレクトリを指すファイルになっている。.git だけを残して消すと、
        # commit と tag を持つ実体が消える。
        destination = os.path.join(self.work, "KsCollectionView-SPM")
        git_directory = os.path.join(destination, ".git-data")
        self.make_working_copy(git_directory=git_directory)
        self.assertTrue(os.path.isfile(os.path.join(destination, ".git")))
        before = git_state(destination)
        # 見ている中身には、管理情報の実体 (.git-data の下) も入っている。
        self.assert_refused(destination, destination, "行き先の git の管理情報が、消す対象の中にある")
        self.assertIn(git_directory, self.run_tool(destination)[2])
        self.assertEqual(git_state(destination), before)
        # commit した内容を、まだ取り出せる。
        self.assertEqual(git(destination, "show", "0.0.1:Package.swift"), "// 前の写しのマニフェスト\n")

    def test_gitの管理情報の場所が行き先そのものである作業コピーを拒否する(self) -> None:
        # HEAD・config・objects・refs が行き先の直下に並び、.git は行き先自身を指すファイルになっている。
        # 管理情報の場所は行き先そのもので、どの子ディレクトリの中にも当たらない。
        destination = self.make_working_copy()
        git_directory = os.path.join(destination, ".git")
        names = sorted(os.listdir(git_directory))
        for name in names:
            os.rename(os.path.join(git_directory, name), os.path.join(destination, name))
        os.rmdir(git_directory)
        support.write(git_directory, "gitdir: .\n")
        git(destination, "config", "core.bare", "false")
        git(destination, "config", "core.worktree", ".")
        # git から見て、行き先が最上位で、管理情報の場所も行き先である。
        self.assertTrue(os.path.samefile(git(destination, "rev-parse", "--show-toplevel").strip(), destination))
        self.assertTrue(os.path.samefile(git(destination, "rev-parse", "--absolute-git-dir").strip(), destination))
        before = git_state(destination)
        # 見ている中身には、行き先の直下に並ぶ管理情報の実体も入っている。
        self.assert_refused(destination, destination, "行き先の git の管理情報の場所が、行き先そのものである")
        for name in ("HEAD", "config", "objects", "refs"):
            self.assertIn(name, names)
            self.assertTrue(os.path.lexists(os.path.join(destination, name)), name)
        self.assertEqual(git_state(destination), before)
        # commit した内容を、まだ取り出せる。
        self.assertEqual(git(destination, "show", "0.0.1:Package.swift"), "// 前の写しのマニフェスト\n")

    def test_gitの管理情報が行き先の外にある作業コピーは受け付ける(self) -> None:
        # 行き先の外にある管理情報は、消す対象に入らない。
        git_directory = os.path.join(self.work, "outside-git-data")
        destination = self.make_working_copy(git_directory=git_directory)
        before = git_state(destination)
        code, _, stderr = self.run_tool(destination)
        self.assertEqual(code, 0, stderr)
        self.assertEqual(sorted(os.listdir(destination)), [".git"] + SNAPSHOT_ENTRIES)
        self.assertEqual(git_state(destination), before)

    def test_行き先がファイルなら拒否する(self) -> None:
        path = support.write(os.path.join(self.work, "file"), "ファイル\n")
        self.assert_refused(path, self.work, "行き先がディレクトリではない")

    def test_gitの場所を固定する環境変数があっても行き先そのものを確かめる(self) -> None:
        # hook の中から呼ばれると、git が別のリポジトリを読むように環境変数が設定されている。
        # それに従うと、作業コピーでない行き先を、作業コピーとして受け付けてしまう。
        working_copy = self.make_working_copy()
        plain = os.path.join(self.work, "plain")
        support.write(os.path.join(plain, "notes.txt"), "消してはいけない\n")
        before = tree(plain)
        code, _, stderr = self.run_tool(plain, env={"GIT_DIR": os.path.join(working_copy, ".git")})
        self.assertEqual(code, 1)
        self.assertIn("git のリポジトリではない", stderr)
        self.assertEqual(tree(plain), before)

    def test_行き先を渡さなければ引数の誤りで終わる(self) -> None:
        code, _, stderr = support.run_main(SCRIPT, [])
        self.assertEqual(code, 2)
        self.assertIn("destination", stderr)


class ManifestTest(unittest.TestCase):
    """写しにそのまま入るマニフェストが、確かめている版のツールを要求していることを確かめる。"""

    def test_マニフェストはSwift_6_4のツールを要求する(self) -> None:
        with open(os.path.join(support.REPOSITORY_ROOT, "ios", "Package.swift"), encoding="utf-8") as f:
            first_line = f.readline().rstrip("\n")
        # SwiftPM は、先頭の行のこの宣言だけを、要求するツールの版として読む。
        self.assertEqual(first_line, "// swift-tools-version: 6.4")


class RepositorySourcesTest(unittest.TestCase):
    """このリポジトリの実物を元にして、写しを作れることを確かめる。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.destination = os.path.join(os.path.realpath(directory.name), "KsCollectionView-SPM")
        code, self.stdout, stderr = support.run_main(SCRIPT, [self.destination])
        self.assertEqual(code, 0, stderr)

    def test_実物の元から5点だけの写しができる(self) -> None:
        self.assertEqual(sorted(os.listdir(self.destination)), SNAPSHOT_ENTRIES)
        self.assertEqual(
            read_bytes(self.destination, "Package.swift"),
            read_bytes(support.REPOSITORY_ROOT, "ios", "Package.swift"),
        )
        self.assertEqual(read_bytes(self.destination, "LICENSE"), read_bytes(support.REPOSITORY_ROOT, "LICENSE"))

    def test_READMEは固定文と同じでこのリポジトリへ案内する(self) -> None:
        readme = read_bytes(self.destination, "README.md")
        self.assertEqual(readme, read_bytes(DISTRIBUTION_DIR, "spm-readme.template.md"))
        text = readme.decode("utf-8")
        self.assertIn(f"**{MAIN_REPOSITORY_URL}**", text)
        # Issue は、配信用リポジトリではなく、このリポジトリで受ける。
        self.assertIn(f"{MAIN_REPOSITORY_URL}/issues", text)
        self.assertNotIn("KsCollectionView-SPM/issues", text)

    def test_写したソースとテストは追跡しているファイルと一致する(self) -> None:
        tracked = git(support.REPOSITORY_ROOT, "ls-files", "-z", "--", "ios/Sources", "ios/Tests").split("\0")
        expected = sorted(os.path.relpath(path, "ios") for path in tracked if path)
        copied = sorted(
            os.path.relpath(os.path.join(current, name), self.destination)
            for top in ("Sources", "Tests")
            for current, _, files in os.walk(os.path.join(self.destination, top))
            for name in files
        )
        self.assertEqual(copied, expected)
        self.assertGreater(len(expected), 0)


if __name__ == "__main__":
    unittest.main()
