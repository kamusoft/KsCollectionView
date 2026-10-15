"""利用者向け Skill の追従の道具 (変わった源泉の一覧・追従の記録の更新) と、記録の読み方のテスト。

道具は、一時のディレクトリに作った使い捨ての git リポジトリに対して流す (履歴に無い commit や、
commit していない変更を、このリポジトリを変えずに確かめるため)。今のリポジトリには流さない
(検証 CI は、Skill が源泉からずれていることを検査しない)。
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest

import support

DOCS_DIR = os.path.join(support.REPOSITORY_ROOT, "scripts", "docs")
SCRIPT = support.load_script("skills-refresh.py", DOCS_DIR)
MANIFEST = support.load_script("skills_manifest.py", DOCS_DIR)

PAGING = "kasane/concepts/core/core-model/collection-paging.md"
ITEMS = "kasane/concepts/core/core-model/collection-items.md"
ENGINE = "kasane/concepts/ios/architecture/paging-engine.md"
HISTORY = "kasane/concepts/log.md"
IOS_SOURCE = "ios/Sources/KsCollectionView/KsSample.swift"
ANDROID_SOURCE = "android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsSample.kt"
SAMPLE_SOURCE = "samples/ios/Sources/SampleScreen.swift"
MANIFEST_PATH = "skills/.manifest.json"

PAGING_TEXT = "".join(f"ページングの決まり {number}\n" for number in range(1, 21))
ITEMS_TEXT = "".join(f"項目の決まり {number}\n" for number in range(1, 21))
ENGINE_TEXT = "".join(f"iOS のページングの仕組み {number}\n" for number in range(1, 21))
SWIFT_TEXT = """\
public struct KsSample {
    public func scrollTo(_ id: Int, animated: Bool = true) {
        let offset = 0
    }

    public func reload() {}
}
"""
KOTLIN_TEXT = """\
package jp.kamusoft.kscollectionview

public class KsSample(
    public val threshold: Float = 1f,
) {
    internal fun helper() {}
}
"""
SOURCES = [
    {"path": PAGING, "pages": ["references/paging.md"]},
    {"path": ITEMS, "pages": ["references/basics.md", "references/layout.md"]},
    {"path": ENGINE, "pages": ["references/paging.md"], "platforms": ["ios"]},
    {"path": HISTORY, "excluded": "概念の文書の更新の履歴で、利用者に伝える内容を持たない"},
]

NO_SOURCE_CHANGES = "変わった源泉は無い"
NO_DECLARATION_CHANGES = "公開の宣言の増減は無い"


def git(directory: str, *arguments: str) -> str:
    """使い捨てのリポジトリで git を呼ぶ。利用者の設定 (署名・hook の雛形など) を読ませない。"""
    environment = {key: value for key, value in os.environ.items() if key not in SCRIPT.GIT_LOCATION_VARIABLES}
    # GIT_OPTIONAL_LOCKS: 状態を読むだけの呼び出しが、index を書き直さないようにする。
    environment.update({"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull, "GIT_OPTIONAL_LOCKS": "0"})
    result = subprocess.run(
        ["git", "-C", directory, "-c", "user.name=test", "-c", "user.email=test@example.com", *arguments],
        capture_output=True,
        text=True,
        env=environment,
        check=True,
    )
    return result.stdout


def manifest_text(commit: str, sources: list[dict] | None = None) -> str:
    manifest = {
        "version": 1,
        "syncedCommit": commit,
        "sources": SOURCES if sources is None else sources,
        "apiExclusions": {"ios": [{"name": "body", "reason": "利用者が呼ばない"}], "android": []},
    }
    return json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"


class RefreshTestCase(unittest.TestCase):
    """源泉と本体のソースを commit し、その commit を指す記録を置いた、使い捨てのリポジトリを用意する。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        # macOS の一時のディレクトリはシンボリックリンクの下にあるので、実体のパスに直しておく。
        self.root = os.path.realpath(directory.name)
        git(self.root, "init", "--quiet")
        self.write(PAGING, PAGING_TEXT)
        self.write(ITEMS, ITEMS_TEXT)
        self.write(ENGINE, ENGINE_TEXT)
        self.write(HISTORY, "履歴\n")
        self.write("kasane/concepts/index.md", "目次\n")
        self.write(IOS_SOURCE, SWIFT_TEXT)
        self.write(ANDROID_SOURCE, KOTLIN_TEXT)
        self.write(SAMPLE_SOURCE, "public struct SampleScreen {}\n")
        self.synced = self.commit("源泉")
        self.write(MANIFEST_PATH, manifest_text(self.synced))
        self.commit("記録")

    def path(self, relative: str) -> str:
        return os.path.join(self.root, *relative.split("/"))

    def write(self, relative: str, text: str) -> None:
        support.write(self.path(relative), text)

    def read(self, relative: str) -> str:
        with open(self.path(relative), encoding="utf-8") as f:
            return f.read()

    def commit(self, message: str) -> str:
        git(self.root, "add", "--all")
        git(self.root, "commit", "--quiet", "--message", message)
        return git(self.root, "rev-parse", "HEAD").strip()

    def status(self, *arguments: str) -> tuple[int, str, str]:
        return support.run_main(SCRIPT, ["status", "--root", self.root, *arguments])

    def record(self, *arguments: str) -> tuple[int, str, str]:
        return support.run_main(SCRIPT, ["record", "--root", self.root, *arguments])

    def repository_state(self) -> dict[str, object]:
        """作業ツリーの中身と、git の履歴・index の状態。"""
        files: dict[str, bytes] = {}
        for current, directories, names in os.walk(self.root):
            if current == self.root:
                directories.remove(".git")
            for name in names:
                full = os.path.join(current, name)
                with open(full, "rb") as f:
                    files[os.path.relpath(full, self.root)] = f.read()
        with open(os.path.join(self.root, ".git", "index"), "rb") as f:
            index = f.read()
        return {
            "files": files,
            "index": index,
            "head": git(self.root, "rev-parse", "HEAD"),
            "commits": git(self.root, "rev-list", "--all", "--count"),
            "branches": git(self.root, "branch", "--list"),
            "tags": git(self.root, "tag", "--list"),
            "status": git(self.root, "status", "--porcelain", "--untracked-files=all"),
        }


class StatusTest(RefreshTestCase):
    def test_変わっていなければ変わった源泉は無いと出て成功する(self) -> None:
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn(f"追従の記録の commit: {self.synced}", out)
        self.assertIn(NO_SOURCE_CHANGES, out)
        self.assertIn(NO_DECLARATION_CHANGES, out)

    def test_変わった源泉と見直す1枚が出る(self) -> None:
        self.write(PAGING, PAGING_TEXT + "しきい値の決まりを足した\n")
        self.commit("ページングの決まりを変えた")
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn("変わった源泉: 1 件", out)
        self.assertIn(f"  {PAGING} (変わった)\n    見直す 1 枚: references/paging.md\n", out)
        self.assertNotIn(ITEMS, out)
        self.assertNotIn(NO_SOURCE_CHANGES, out)

    def test_複数の1枚に掛かる源泉はそのすべてが出る(self) -> None:
        self.write(ITEMS, ITEMS_TEXT + "グループの決まりを足した\n")
        self.commit("項目の決まりを変えた")
        _, out, _ = self.status()
        self.assertIn(f"  {ITEMS} (変わった)\n    見直す 1 枚: references/basics.md・references/layout.md\n", out)

    def test_片方のプラットフォームにだけ掛かる源泉はそう出る(self) -> None:
        self.write(ENGINE, ENGINE_TEXT + "罠を足した\n")
        _, out, _ = self.status()
        self.assertIn(f"  {ENGINE} (変わった)\n    見直す 1 枚: references/paging.md (ios の Skill だけ)\n", out)

    def test_Skillに掛からないと決めた源泉は理由を添えて出る(self) -> None:
        self.write(HISTORY, "履歴\n1 行を足した\n")
        _, out, _ = self.status()
        self.assertIn(f"  {HISTORY} (変わった)\n    見直す 1 枚: Skill に掛からない (理由: 概念の文書の更新の履歴", out)

    def test_公開の宣言を消すと消えた宣言として出る(self) -> None:
        self.write(IOS_SOURCE, SWIFT_TEXT.replace("    public func reload() {}\n", ""))
        self.commit("公開の宣言を消した")
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn(NO_SOURCE_CHANGES, out)
        self.assertIn("公開の宣言の増減: 足された行 0 行・消えた行 1 行", out)
        self.assertIn(f"  - {IOS_SOURCE}: public func reload() {{}}\n", out)

    def test_公開の宣言の引数を変えると前の行と今の行が出る(self) -> None:
        self.write(IOS_SOURCE, SWIFT_TEXT.replace("animated: Bool = true", "animated: Bool = false"))
        self.write(ANDROID_SOURCE, KOTLIN_TEXT.replace("threshold: Float = 1f", "threshold: Float = 2f"))
        self.commit("公開の宣言の引数を変えた")
        _, out, _ = self.status()
        self.assertIn("公開の宣言の増減: 足された行 2 行・消えた行 2 行", out)
        self.assertIn(f"  - {IOS_SOURCE}: public func scrollTo(_ id: Int, animated: Bool = true) {{\n", out)
        self.assertIn(f"  + {IOS_SOURCE}: public func scrollTo(_ id: Int, animated: Bool = false) {{\n", out)
        self.assertIn(f"  - {ANDROID_SOURCE}: public val threshold: Float = 1f,\n", out)
        self.assertIn(f"  + {ANDROID_SOURCE}: public val threshold: Float = 2f,\n", out)

    def test_公開の宣言を足すと足された宣言として出る(self) -> None:
        self.write(ANDROID_SOURCE, KOTLIN_TEXT.replace("    internal fun helper() {}\n", "    public fun refresh() {}\n"))
        _, out, _ = self.status()
        self.assertIn("公開の宣言の増減: 足された行 1 行・消えた行 0 行", out)
        self.assertIn(f"  + {ANDROID_SOURCE}: public fun refresh() {{}}\n", out)

    def test_公開の宣言でない変更は増減に出ない(self) -> None:
        self.write(IOS_SOURCE, SWIFT_TEXT.replace("let offset = 0", "let offset = 1"))
        self.write(ANDROID_SOURCE, KOTLIN_TEXT.replace("internal fun helper() {}", "internal fun helper() { check(true) }"))
        self.commit("公開の宣言でない行を変えた")
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn(NO_DECLARATION_CHANGES, out)
        self.assertIn(NO_SOURCE_CHANGES, out)

    def test_公開の宣言の場所が動いただけなら増減に出ない(self) -> None:
        moved = "ios/Sources/KsCollectionView/Moved/KsRenamed.swift"
        self.write(moved, "// 先頭にコメントを足した\n" + SWIFT_TEXT)
        os.remove(self.path(IOS_SOURCE))
        self.commit("ソースのファイルを動かした")
        _, out, _ = self.status()
        self.assertIn(NO_DECLARATION_CHANGES, out)

    def test_commitしていない変更も出る(self) -> None:
        self.write(PAGING, PAGING_TEXT + "まだ commit していない 1 行\n")
        self.write(IOS_SOURCE, SWIFT_TEXT.replace("    public func reload() {}\n", ""))
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn(f"  {PAGING} (変わった)", out)
        self.assertIn(f"  - {IOS_SOURCE}: public func reload() {{}}\n", out)

    def test_追跡していない新しいソースの公開の宣言も出る(self) -> None:
        added = "ios/Sources/KsCollectionView/KsAdded.swift"
        self.write(added, "public struct KsAdded {}\n")
        _, out, _ = self.status()
        self.assertIn(f"  + {added}: public struct KsAdded {{}}\n", out)

    def test_対象の外の変更は出ない(self) -> None:
        self.write(SAMPLE_SOURCE, "public struct SampleScreen {\n    public func added() {}\n}\n")
        self.write("kasane/concepts/index.md", "目次\n1 行を足した\n")
        self.commit("対象でないファイルを変えた")
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn(NO_SOURCE_CHANGES, out)
        self.assertIn(NO_DECLARATION_CHANGES, out)
        self.assertNotIn("対応の決まっていない源泉", out)

    def test_新しい概念の文書は対応が決まっていないと出る(self) -> None:
        committed = "kasane/concepts/core/core-model/collection-selection.md"
        untracked = "kasane/concepts/android/architecture/selection-wrapper.md"
        self.write(committed, "選択の決まり\n")
        self.commit("新しい概念の文書を足した")
        self.write(untracked, "選択の仕組み\n")
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn("対応の決まっていない源泉: 2 件", out)
        self.assertIn(f"  {committed}\n", out)
        self.assertIn(f"  {untracked}\n", out)
        # 対応の決まっていない源泉は、変わった源泉とは分けて出る。
        self.assertIn(NO_SOURCE_CHANGES, out)

    def test_名前の変わった源泉は前の名前と今の名前が出る(self) -> None:
        renamed = "kasane/concepts/core/core-model/collection-load-more.md"
        git(self.root, "mv", self.path(PAGING), self.path(renamed))
        self.write(renamed, PAGING_TEXT + "名前と一緒に 1 行を足した\n")
        self.commit("概念の文書の名前を変えた")
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn("名前の変わった源泉: 1 件", out)
        self.assertIn(f"  {PAGING} → {renamed}\n    見直す 1 枚: references/paging.md\n", out)
        self.assertNotIn("対応の決まっていない源泉", out)
        self.assertNotIn("無くなった源泉", out)

    def test_commitしていない名前の変更も分かる(self) -> None:
        renamed = "kasane/concepts/core/core-model/collection-load-more.md"
        os.replace(self.path(PAGING), self.path(renamed))
        _, out, _ = self.status()
        self.assertIn(f"  {PAGING} → {renamed}\n", out)

    def test_消えた源泉は無くなった源泉として出る(self) -> None:
        os.remove(self.path(ITEMS))
        self.write("kasane/concepts/core/core-model/unrelated.md", "まったく別の内容\n")
        _, out, _ = self.status()
        self.assertIn("無くなった源泉: 1 件", out)
        self.assertIn(f"  {ITEMS}\n    掛かっていた 1 枚: references/basics.md・references/layout.md\n", out)
        self.assertIn("対応の決まっていない源泉: 1 件", out)

    def test_記録より後に足された源泉は足されたと出る(self) -> None:
        screen = "verification/ios/Sources/VerificationApp/ItemListScreen.swift"
        self.write(MANIFEST_PATH, manifest_text(self.synced, SOURCES + [{"path": screen, "pages": ["SKILL.md"]}]))
        self.write(screen, "struct ItemListScreen {}\n")
        _, out, _ = self.status()
        self.assertIn(f"  {screen} (足された)\n    見直す 1 枚: SKILL.md\n", out)

    def test_差分の本文を出せる(self) -> None:
        self.write(PAGING, PAGING_TEXT.replace("ページングの決まり 3\n", "しきい値は残りの件数で決める\n"))
        self.commit("ページングの決まりを変えた")
        _, plain, _ = self.status()
        self.assertNotIn("しきい値は残りの件数で決める", plain)
        code, out, _ = self.status("--diff")
        self.assertEqual(code, 0)
        self.assertIn(f"--- {PAGING}\n+++ {PAGING}\n", out)
        self.assertIn("-ページングの決まり 3\n+しきい値は残りの件数で決める\n", out)

    def test_無くなった源泉の差分の本文も出せる(self) -> None:
        os.remove(self.path(ITEMS))
        _, plain, _ = self.status()
        self.assertIn("無くなった源泉: 1 件", plain)
        self.assertNotIn("項目の決まり 1\n", plain)
        code, out, _ = self.status("--diff")
        self.assertEqual(code, 0)
        self.assertIn(f"--- {ITEMS}\n+++ /dev/null\n", out)
        # 記録の commit の時点の内容の全行が、消えた行として出る。
        self.assertIn("".join(f"-{line}\n" for line in ITEMS_TEXT.splitlines()), out)

    def test_commitして消した源泉の差分の本文も出せる(self) -> None:
        os.remove(self.path(PAGING))
        self.commit("ページングの文書を消した")
        _, out, _ = self.status("--diff")
        self.assertIn(f"--- {PAGING}\n+++ /dev/null\n", out)
        self.assertIn("".join(f"-{line}\n" for line in PAGING_TEXT.splitlines()), out)

    def test_記録のcommitが履歴に無いと失敗する(self) -> None:
        self.write(MANIFEST_PATH, manifest_text("1" * 40))
        code, out, error = self.status()
        self.assertEqual(code, 1)
        self.assertIn("追従の記録の commit が、手元の履歴に無い: " + "1" * 40, error)
        self.assertNotIn(NO_SOURCE_CHANGES, out)
        self.assertEqual(out, "")

    def test_記録のファイルが無いと失敗する(self) -> None:
        os.remove(self.path(MANIFEST_PATH))
        code, out, error = self.status()
        self.assertEqual(code, 1)
        self.assertIn("追従の記録を読めない: skills/.manifest.json", error)
        self.assertEqual(out, "")

    def test_記録が決めた項目を欠いていると失敗する(self) -> None:
        for field in ("version", "syncedCommit", "sources", "apiExclusions"):
            with self.subTest(field=field):
                data = json.loads(manifest_text(self.synced))
                del data[field]
                self.write(MANIFEST_PATH, json.dumps(data))
                code, out, error = self.status()
                self.assertEqual(code, 1)
                self.assertIn(f"追従の記録に、項目 {field} が無い", error)
                self.assertEqual(out, "")

    def test_gitのリポジトリでないと失敗する(self) -> None:
        with tempfile.TemporaryDirectory() as plain:
            support.write(os.path.join(plain, "skills", ".manifest.json"), manifest_text(self.synced))
            code, out, error = support.run_main(SCRIPT, ["status", "--root", plain])
        self.assertEqual(code, 1)
        self.assertIn("git のリポジトリではない", error)
        self.assertEqual(out, "")

    def test_無いルートは引数の誤りで終わる(self) -> None:
        code, _, error = support.run_main(SCRIPT, ["status", "--root", os.path.join(self.root, "nowhere")])
        self.assertEqual(code, 2)
        self.assertIn("実在するディレクトリではない", error)

    def test_何も書き換えない(self) -> None:
        self.write(PAGING, PAGING_TEXT + "commit していない 1 行\n")
        self.write(IOS_SOURCE, SWIFT_TEXT.replace("    public func reload() {}\n", ""))
        self.write("kasane/concepts/core/core-model/new.md", "新しい文書\n")
        before = self.repository_state()
        code, _, _ = self.status("--diff")
        self.assertEqual(code, 0)
        self.assertEqual(self.repository_state(), before)


class RecordTest(RefreshTestCase):
    def test_今の先頭のcommitを記録する(self) -> None:
        self.write(PAGING, PAGING_TEXT + "しきい値の決まりを足した\n")
        head = self.commit("ページングの決まりを変えた")
        code, out, _ = self.record()
        self.assertEqual(code, 0)
        self.assertIn(f"{self.synced} → {head}", out)
        self.assertEqual(MANIFEST.load_manifest(self.root).synced_commit, head)
        code, out, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn(NO_SOURCE_CHANGES, out)
        self.assertIn(NO_DECLARATION_CHANGES, out)

    def test_渡したcommitを記録する(self) -> None:
        self.write(PAGING, PAGING_TEXT + "1 回目\n")
        first = self.commit("1 回目")
        self.write(PAGING, PAGING_TEXT + "2 回目\n")
        self.commit("2 回目")
        # 省略した ID を渡しても、記録には 40 桁の ID が入る。
        code, _, _ = self.record(first[:10])
        self.assertEqual(code, 0)
        self.assertEqual(MANIFEST.load_manifest(self.root).synced_commit, first)
        _, out, _ = self.status()
        self.assertIn(f"  {PAGING} (変わった)", out)

    def test_ほかの項目を変えない(self) -> None:
        self.write(PAGING, PAGING_TEXT + "しきい値の決まりを足した\n")
        head = self.commit("ページングの決まりを変えた")
        before = self.read(MANIFEST_PATH)
        self.record()
        after = self.read(MANIFEST_PATH)
        self.assertNotEqual(after, before)
        # ID を元に戻すと、1 文字も違わない。
        self.assertEqual(after.replace(head, self.synced), before)

    def test_記録のファイルの書き方を保つ(self) -> None:
        compact = json.dumps(json.loads(manifest_text(self.synced)), ensure_ascii=False)
        self.write(MANIFEST_PATH, compact)
        head = self.commit("記録を 1 行で書いた")
        self.record()
        self.assertEqual(self.read(MANIFEST_PATH), compact.replace(self.synced, head))

    def test_commitしていない変更があると書き換えない(self) -> None:
        self.write(PAGING, PAGING_TEXT + "commit していない 1 行\n")
        before = self.read(MANIFEST_PATH)
        code, out, error = self.record()
        self.assertEqual(code, 1)
        self.assertIn("commit していない変更がある", error)
        self.assertIn(PAGING, error)
        self.assertEqual(out, "")
        self.assertEqual(self.read(MANIFEST_PATH), before)

    def test_indexにだけ残っている変更があると書き換えない(self) -> None:
        # 変更を index に載せた後で、作業ツリーだけを commit の内容に戻す。
        self.write(PAGING, PAGING_TEXT + "commit していない 1 行\n")
        git(self.root, "add", "--", PAGING)
        self.write(PAGING, PAGING_TEXT)
        self.assertEqual(git(self.root, "diff", "--name-only", "HEAD"), "")
        self.assertEqual(git(self.root, "diff", "--cached", "--name-only", "HEAD").strip(), PAGING)
        before = self.read(MANIFEST_PATH)
        code, out, error = self.record()
        self.assertEqual(code, 1)
        self.assertIn("commit していない変更がある", error)
        self.assertIn(PAGING, error)
        self.assertEqual(out, "")
        self.assertEqual(self.read(MANIFEST_PATH), before)

    def test_indexにだけ残っている新しい概念の文書があると書き換えない(self) -> None:
        # 新しい文書を index に載せた後で、作業ツリーから消す。追跡していないファイルとしても出ない。
        added = "kasane/concepts/core/core-model/collection-selection.md"
        self.write(added, "選択の決まり\n")
        git(self.root, "add", "--", added)
        os.remove(self.path(added))
        before = self.read(MANIFEST_PATH)
        code, _, error = self.record()
        self.assertEqual(code, 1)
        self.assertIn(added, error)
        self.assertEqual(self.read(MANIFEST_PATH), before)

    def test_対象の外のindexにだけ残っている変更は妨げない(self) -> None:
        self.write(SAMPLE_SOURCE, "public struct SampleScreen {\n    public func added() {}\n}\n")
        git(self.root, "add", "--", SAMPLE_SOURCE)
        self.write(SAMPLE_SOURCE, "public struct SampleScreen {}\n")
        code, _, _ = self.record()
        self.assertEqual(code, 0)

    def test_追跡していない新しい概念の文書があると書き換えない(self) -> None:
        added = "kasane/concepts/core/core-model/collection-selection.md"
        self.write(added, "選択の決まり\n")
        before = self.read(MANIFEST_PATH)
        code, _, error = self.record()
        self.assertEqual(code, 1)
        self.assertIn(added, error)
        self.assertEqual(self.read(MANIFEST_PATH), before)

    def test_対象の外のcommitしていない変更は妨げない(self) -> None:
        self.write(SAMPLE_SOURCE, "public struct SampleScreen {\n    public func added() {}\n}\n")
        self.write("kasane/concepts/index.md", "目次\n1 行を足した\n")
        code, _, _ = self.record()
        self.assertEqual(code, 0)

    def test_履歴に無いcommitは記録しない(self) -> None:
        before = self.read(MANIFEST_PATH)
        for revision in ("1" * 40, "no-such-branch", "--help-me"):
            with self.subTest(revision=revision):
                code, out, error = support.run_main(SCRIPT, ["record", "--root", self.root, "--", revision])
                self.assertEqual(code, 1)
                self.assertIn("記録する commit が、手元の履歴に無い", error)
                self.assertEqual(out, "")
                self.assertEqual(self.read(MANIFEST_PATH), before)

    def test_commitでないものは記録しない(self) -> None:
        blob = git(self.root, "rev-parse", f"HEAD:{PAGING}").strip()
        before = self.read(MANIFEST_PATH)
        code, _, error = self.record(blob)
        self.assertEqual(code, 1)
        self.assertIn("手元の履歴に無い", error)
        self.assertEqual(self.read(MANIFEST_PATH), before)

    def test_記録を読めないと書き換えない(self) -> None:
        self.write(MANIFEST_PATH, '{"version": 1}\n')
        code, _, error = self.record()
        self.assertEqual(code, 1)
        self.assertIn("追従の記録に、項目 syncedCommit が無い", error)
        self.assertEqual(self.read(MANIFEST_PATH), '{"version": 1}\n')

    def test_履歴を変えない(self) -> None:
        self.write(PAGING, PAGING_TEXT + "しきい値の決まりを足した\n")
        self.commit("ページングの決まりを変えた")
        before = self.repository_state()
        code, _, _ = self.record()
        self.assertEqual(code, 0)
        after = self.repository_state()
        for key in ("head", "commits", "branches", "tags", "index"):
            with self.subTest(key=key):
                self.assertEqual(after[key], before[key])
        # 変わったのは、記録のファイルだけである。
        changed = {path for path in before["files"] if after["files"][path] != before["files"][path]}
        self.assertEqual(changed, {os.path.join("skills", ".manifest.json")})
        self.assertEqual(set(after["files"]), set(before["files"]))


class ManifestFormTest(unittest.TestCase):
    COMMIT = "a" * 40

    def parse(self, **changes: object):
        data = json.loads(manifest_text(self.COMMIT))
        data.update(changes)
        return MANIFEST.parse_manifest(json.dumps(data))

    def assert_rejected(self, reason: str, **changes: object) -> None:
        with self.assertRaises(MANIFEST.ManifestError) as raised:
            self.parse(**changes)
        self.assertIn(reason, str(raised.exception))

    def test_決めた3つの項目を読む(self) -> None:
        manifest = self.parse()
        self.assertEqual(manifest.synced_commit, self.COMMIT)
        self.assertEqual(manifest.source(ITEMS).pages, ("references/basics.md", "references/layout.md"))
        self.assertEqual(manifest.source(ITEMS).platforms, ("ios", "android"))
        self.assertEqual(manifest.source(ENGINE).platforms, ("ios",))
        self.assertIsNone(manifest.source(ENGINE).excluded)
        self.assertEqual(manifest.source(HISTORY).pages, ())
        self.assertIn("履歴", manifest.source(HISTORY).excluded)
        self.assertEqual(manifest.api_exclusions, {"ios": {"body": "利用者が呼ばない"}, "android": {}})
        self.assertIsNone(manifest.source("kasane/concepts/unknown.md"))

    def test_JSONでない記録を読まない(self) -> None:
        with self.assertRaises(MANIFEST.ManifestError):
            MANIFEST.parse_manifest("{ 壊れた記録")
        with self.assertRaises(MANIFEST.ManifestError):
            MANIFEST.parse_manifest("[]")

    def test_読めない版とcommitのIDを読まない(self) -> None:
        self.assert_rejected("version", version=2)
        self.assert_rejected("syncedCommit", syncedCommit="a064aca")
        self.assert_rejected("syncedCommit", syncedCommit="A" * 40)
        self.assert_rejected("syncedCommit", syncedCommit=None)

    def test_掛かる1枚も理由も持たない源泉を読まない(self) -> None:
        self.assert_rejected("sources", sources=[])
        self.assert_rejected("どちらか片方だけ", sources=[{"path": PAGING}])
        self.assert_rejected("どちらか片方だけ", sources=[{"path": PAGING, "pages": ["SKILL.md"], "excluded": "理由"}])
        self.assert_rejected("pages", sources=[{"path": PAGING, "pages": []}])
        self.assert_rejected("excluded", sources=[{"path": PAGING, "excluded": " "}])
        self.assert_rejected("同じ 1 枚", sources=[{"path": PAGING, "pages": ["SKILL.md", "SKILL.md"]}])

    def test_形の違う源泉を読まない(self) -> None:
        page = {"pages": ["SKILL.md"]}
        self.assert_rejected("path", sources=[page])
        self.assert_rejected("相対のパスではない", sources=[{"path": "/kasane/concepts/a.md", **page}])
        self.assert_rejected("相対のパスではない", sources=[{"path": "../other/a.md", **page}])
        self.assert_rejected("同じパス", sources=[{"path": PAGING, **page}, {"path": PAGING, **page}])
        self.assert_rejected("platforms", sources=[{"path": PAGING, **page, "platforms": ["web"]}])
        self.assert_rejected("platforms", sources=[{"path": PAGING, **page, "platforms": []}])
        self.assert_rejected("platforms", sources=[{"path": PAGING, "excluded": "理由", "platforms": ["ios"]}])
        self.assert_rejected("決めていない項目", sources=[{"path": PAGING, **page, "note": "覚え書き"}])

    def test_形の違う載せない名前の一覧を読まない(self) -> None:
        self.assert_rejected("apiExclusions", apiExclusions={"ios": []})
        self.assert_rejected("apiExclusions", apiExclusions={"ios": [], "android": [], "web": []})
        self.assert_rejected("一覧ではない", apiExclusions={"ios": {}, "android": []})
        self.assert_rejected("name と reason", apiExclusions={"ios": ["body"], "android": []})
        self.assert_rejected("reason", apiExclusions={"ios": [{"name": "body", "reason": ""}], "android": []})
        duplicated = [{"name": "body", "reason": "理由"}, {"name": "body", "reason": "理由"}]
        self.assert_rejected("同じ名前", apiExclusions={"ios": duplicated, "android": []})

    def test_commitのIDだけを書き換える(self) -> None:
        text = manifest_text(self.COMMIT)
        replaced = MANIFEST.replace_synced_commit(text, "b" * 40)
        self.assertEqual(replaced, text.replace(self.COMMIT, "b" * 40))
        with self.assertRaises(MANIFEST.ManifestError):
            MANIFEST.replace_synced_commit('{"version": 1}', "b" * 40)


if __name__ == "__main__":
    unittest.main()
