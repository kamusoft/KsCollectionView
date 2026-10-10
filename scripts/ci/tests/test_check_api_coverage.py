"""公開の宣言の名前の網羅を報告する道具と、公開の宣言の行の拾い方のテスト。

道具は、一時のディレクトリに作ったひな形 (両プラットフォームのソース・4 つの Skill・追従の記録)
に対して流す。今のリポジトリの実物には流さない (公開の宣言を足した push を、Skill を直すまで
落とし続けないため)。
"""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import unittest

import support

DOCS_DIR = os.path.join(support.REPOSITORY_ROOT, "scripts", "docs")
SCRIPT = support.load_script("check-api-coverage.py", DOCS_DIR)
PUBLIC_API = support.load_script("public_api.py", DOCS_DIR)

IOS = PUBLIC_API.platform_of("ios")
ANDROID = PUBLIC_API.platform_of("android")

IOS_SOURCE = "ios/Sources/KsCollectionView/KsSample.swift"
ANDROID_SOURCE = "android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsSample.kt"

SWIFT_TEXT = """\
import SwiftUI

/// 一覧。public という語を含むコメントは拾わない。
public struct KsSample: View {
    public var body: some View { EmptyView() }

    public init() {}

    public func onSampleTap(_ action: @escaping () -> Void) -> KsSample {
        self
    }
}

public enum KsSampleMode: Sendable {
    case compact
    case regular(Int)
}
"""
KOTLIN_TEXT = """\
package jp.kamusoft.kscollectionview

/** 一覧。public という語を含むコメントは拾わない。 */
@Composable
public fun KsSample(mode: KsSampleMode) {
}

public enum class KsSampleMode {
    Compact,
    Regular,
}

public class KsSampleOptions(
    public val threshold: Float = 1f,
)
"""
IOS_NAMES = ["KsSample", "KsSampleMode", "body", "compact", "onSampleTap", "regular"]
ANDROID_NAMES = ["Compact", "KsSample", "KsSampleMode", "KsSampleOptions", "Regular", "threshold"]


def names_of(platform, text: str) -> list[str]:
    return sorted(PUBLIC_API.extract(platform, "Sample", text).names())


def skill_text(names: list[str]) -> str:
    listed = "\n".join(f"- `{name}`" for name in names)
    return f"# Skill\n\n{listed}\n"


def tree(directory: str) -> dict[str, bytes]:
    entries: dict[str, bytes] = {}
    for current, _, files in os.walk(directory):
        for name in files:
            path = os.path.join(current, name)
            with open(path, "rb") as f:
                entries[os.path.relpath(path, directory)] = f.read()
    return entries


class CoverageTestCase(unittest.TestCase):
    """すべての名前が Skill に現れている、正常なひな形を用意する。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = directory.name
        self.write(IOS_SOURCE, SWIFT_TEXT)
        self.write(ANDROID_SOURCE, KOTLIN_TEXT)
        for language in ("en", "ja"):
            self.write_skill(language, IOS, IOS_NAMES)
            self.write_skill(language, ANDROID, ANDROID_NAMES)
        self.write_manifest()

    def write(self, relative: str, text: str) -> None:
        support.write(os.path.join(self.root, *relative.split("/")), text)

    def write_skill(self, language: str, platform, names: list[str]) -> None:
        # 名前を 2 枚に分けて書く (Skill のどの 1 枚に現れてもよいことを確かめるため)。
        half = len(names) // 2
        self.write(f"skills/{language}/{platform.skill}/SKILL.md", skill_text(names[:half]))
        self.write(f"skills/{language}/{platform.skill}/references/basics.md", skill_text(names[half:]))

    def write_manifest(self, ios: list[str] | None = None, android: list[str] | None = None) -> None:
        manifest = {
            "version": 1,
            "syncedCommit": "0" * 40,
            "sources": [{"path": "kasane/concepts/core/sample.md", "pages": ["SKILL.md"]}],
            "apiExclusions": {
                "ios": [{"name": name, "reason": "利用者が呼ばない"} for name in ios or []],
                "android": [{"name": name, "reason": "利用者が呼ばない"} for name in android or []],
            },
        }
        self.write("skills/.manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    def run_tool(self, *arguments: str) -> tuple[int, str, str]:
        return support.run_main(SCRIPT, ["--root", self.root, *arguments])


class CoverageReportTest(CoverageTestCase):
    def test_すべての名前が現れていれば漏れは0件で成功する(self) -> None:
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("漏れ 0 件", out)
        self.assertIn("iOS: 拾った名前 6 個", out)
        self.assertIn("Android: 拾った名前 6 個", out)
        self.assertNotIn("漏れ:", out)

    def test_現れない名前がプラットフォームと言語と名前で報告される(self) -> None:
        missing = [name for name in IOS_NAMES if name != "onSampleTap"]
        for language in ("en", "ja"):
            self.write_skill(language, IOS, missing)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("漏れ: iOS / 英語版 (skills/en/kscollectionview-ios): onSampleTap", out)
        self.assertIn("漏れ: iOS / 日本語版 (skills/ja/kscollectionview-ios): onSampleTap", out)
        self.assertIn(f"{IOS_SOURCE}:9", out)
        self.assertIn("漏れ 2 件", out)
        self.assertNotIn("漏れ 0 件", out)

    def test_片方の言語にだけ無い名前も報告される(self) -> None:
        self.write_skill("ja", ANDROID, [name for name in ANDROID_NAMES if name != "threshold"])
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("漏れ: Android / 日本語版 (skills/ja/kscollectionview-android): threshold", out)
        self.assertNotIn("英語版", out)
        self.assertIn("漏れ 1 件", out)

    def test_載せないと決めた名前は報告されない(self) -> None:
        for language in ("en", "ja"):
            self.write_skill(language, IOS, [name for name in IOS_NAMES if name != "body"])
        self.write_manifest(ios=["body"])
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("載せないと決めた名前 1 個", out)
        self.assertIn("漏れ 0 件", out)

    def test_載せないと決めた名前は相手のプラットフォームでは効かない(self) -> None:
        for language in ("en", "ja"):
            self.write_skill(language, IOS, [name for name in IOS_NAMES if name != "body"])
        self.write_manifest(android=["body"])
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("漏れ: iOS / 英語版 (skills/en/kscollectionview-ios): body", out)

    def test_載せないと決めた名前の宣言が無くなると古い項目として出る(self) -> None:
        self.write_manifest(android=["removedName"])
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("古い項目: Android: removedName", out)
        self.assertIn("古い項目 1 件", out)
        self.assertIn("漏れ 0 件", out)

    def test_利用者向けでない印の付いた宣言は拾わない(self) -> None:
        self.write(
            IOS_SOURCE,
            SWIFT_TEXT
            + "\n@_spi(KsMeasurement)\n@MainActor\npublic enum KsSampleDiagnostics {\n"
            + "    @_spi(KsMeasurement)\n    public static func resetCounters() {}\n}\n",
        )
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("iOS: 拾った名前 6 個", out)
        self.assertNotIn("KsSampleDiagnostics", out)
        self.assertNotIn("resetCounters", out)

    def test_相手のプラットフォームの名前を漏れに数えない(self) -> None:
        # threshold は Android にだけある公開の宣言で、iOS の Skill には無い。
        self.assertNotIn("threshold", IOS_NAMES)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertNotIn("漏れ: iOS", out)

    def test_ほかの名前の一部として現れても現れたことにならない(self) -> None:
        for language in ("en", "ja"):
            self.write_skill(language, IOS, [name for name in IOS_NAMES if name != "body"] + ["bodyText", "_body"])
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("skills/en/kscollectionview-ios): body", out)

    def test_本文に書かれた名前も現れたことになる(self) -> None:
        for language in ("en", "ja"):
            self.write(f"skills/{language}/{IOS.skill}/SKILL.md", "# Skill\n\n" + " と ".join(IOS_NAMES) + " を使う。\n")
            os.remove(os.path.join(self.root, "skills", language, IOS.skill, "references", "basics.md"))
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)

    def test_一覧の指定で拾った名前がすべて出る(self) -> None:
        self.write_manifest(ios=["body"])
        code, out, _ = self.run_tool("--list")
        self.assertEqual(code, 0, out)
        self.assertIn(f"名前: onSampleTap — KsSample の関数 ({IOS_SOURCE}:9)", out)
        self.assertIn("名前: body [載せないと決めた名前]", out)
        self.assertIn(f"名前: Compact — KsSampleMode の列挙の値 ({ANDROID_SOURCE}:9)", out)
        self.assertIn(f"名前: threshold — KsSampleOptions のプロパティ ({ANDROID_SOURCE}:14)", out)


class CoverageFailureTest(CoverageTestCase):
    def assert_unchecked(self, code: int, out: str, error: str, reason: str) -> None:
        self.assertEqual(code, 3)
        self.assertIn(reason, error)
        self.assertNotIn("漏れ 0 件", out)

    def test_宣言を1つも拾えないと失敗する(self) -> None:
        shutil.move(os.path.join(self.root, "ios", "Sources"), os.path.join(self.root, "ios", "Moved"))
        code, out, error = self.run_tool()
        self.assert_unchecked(code, out, error, "iOS の公開の宣言を 1 つも拾えない: ios/Sources")

    def test_公開の宣言の無いソースだけでも失敗する(self) -> None:
        self.write(ANDROID_SOURCE, "package jp.kamusoft.kscollectionview\n\ninternal class KsHidden\n")
        code, out, error = self.run_tool()
        self.assert_unchecked(code, out, error, "Android の公開の宣言を 1 つも拾えない")

    def test_Skillが片方の言語に無いと失敗する(self) -> None:
        shutil.rmtree(os.path.join(self.root, "skills", "ja", ANDROID.skill))
        code, out, error = self.run_tool()
        self.assert_unchecked(code, out, error, "Android の Skill が無い: skills/ja/kscollectionview-android")

    def test_SkillにMarkdownが無いと失敗する(self) -> None:
        directory = os.path.join(self.root, "skills", "en", IOS.skill)
        shutil.rmtree(directory)
        os.makedirs(directory)
        code, out, error = self.run_tool()
        self.assert_unchecked(code, out, error, "iOS の Skill に、Markdown が 1 枚も無い")

    def test_失敗するときは片方のプラットフォームの結果も出さない(self) -> None:
        shutil.rmtree(os.path.join(self.root, "skills", "ja", ANDROID.skill))
        _, out, _ = self.run_tool()
        self.assertEqual(out, "")

    def test_追従の記録を読めないと失敗する(self) -> None:
        os.remove(os.path.join(self.root, "skills", ".manifest.json"))
        code, out, error = self.run_tool()
        self.assert_unchecked(code, out, error, "追従の記録を読めない")

    def test_追従の記録が項目を欠いていると失敗する(self) -> None:
        self.write("skills/.manifest.json", '{"version": 1, "syncedCommit": "' + "0" * 40 + '", "sources": []}\n')
        code, out, error = self.run_tool()
        self.assert_unchecked(code, out, error, "追従の記録")

    def test_無いルートは引数の誤りで終わる(self) -> None:
        code, out, error = support.run_main(SCRIPT, ["--root", os.path.join(self.root, "nowhere")])
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertIn("実在するディレクトリではない", error)


class CoverageReadOnlyTest(CoverageTestCase):
    def test_漏れが無いときに何も書き換えない(self) -> None:
        before = tree(self.root)
        self.run_tool("--list")
        self.assertEqual(tree(self.root), before)

    def test_漏れがあるときも何も書き換えない(self) -> None:
        self.write_skill("ja", IOS, ["KsSample"])
        self.write_manifest(android=["removedName"])
        before = tree(self.root)
        code, _, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertEqual(tree(self.root), before)


class SwiftExtractionTest(unittest.TestCase):
    def test_型と関数とプロパティと列挙の値を拾う(self) -> None:
        extraction = PUBLIC_API.extract(IOS, "Sample.swift", SWIFT_TEXT)
        found = [(d.line, d.kind, d.owner, d.name) for d in extraction.declarations]
        self.assertEqual(
            found,
            [
                (4, "型", "", "KsSample"),
                (5, "プロパティ", "KsSample", "body"),
                (7, "初期化", "KsSample", None),
                (9, "関数", "KsSample", "onSampleTap"),
                (14, "型", "", "KsSampleMode"),
                (15, "列挙の値", "KsSampleMode", "compact"),
                (16, "列挙の値", "KsSampleMode", "regular"),
            ],
        )
        self.assertEqual(extraction.unparsed, ())

    def test_引数の名前と初期化の宣言は名前として拾わない(self) -> None:
        text = "public struct KsBox {\n    public init(width: Double, label title: String) {}\n}\n"
        self.assertEqual(names_of(IOS, text), ["KsBox"])

    def test_修飾の付いた宣言を拾う(self) -> None:
        text = (
            "public final class KsController {\n"
            "    public private(set) static var count = 0\n"
            "    public static let shared = KsController()\n"
            "    @MainActor public static func reset() {}\n"
            "    nonisolated public func describe() -> String { \"\" }\n"
            "    public typealias Key = String\n"
            "    public subscript(index: Int) -> Int { index }\n"
            "}\n"
        )
        self.assertEqual(names_of(IOS, text), ["Key", "KsController", "count", "describe", "reset", "shared"])

    def test_公開でない宣言は拾わない(self) -> None:
        text = (
            "struct KsInternal {\n    var value = 0\n    func run() {}\n}\n"
            "public struct KsOpen {\n    var hidden = 0\n    internal func helper() {}\n    private let secret = 1\n}\n"
        )
        self.assertEqual(names_of(IOS, text), ["KsOpen"])

    def test_1行に並べた値と値を持つ値を拾う(self) -> None:
        text = "public enum KsEdge {\n    case top, bottom\n    indirect case nested(KsEdge)\n    case raw = 3\n}\n"
        self.assertEqual(names_of(IOS, text), ["KsEdge", "bottom", "nested", "raw", "top"])

    def test_switchのcaseと公開でないenumのcaseは拾わない(self) -> None:
        text = (
            "public enum KsEdge {\n    case top\n\n"
            "    public var title: String {\n        switch self {\n        case .top: return \"top\"\n        }\n    }\n}\n"
            "enum KsHiddenEdge {\n    case secret\n}\n"
        )
        self.assertEqual(names_of(IOS, text), ["KsEdge", "title", "top"])

    def test_印の付いた型は中の宣言も値も拾わない(self) -> None:
        text = (
            "@_spi(KsMeasurement)\n@MainActor\npublic enum KsDiagnostics {\n"
            "    case hiddenValue\n    public static func reset() {}\n}\n"
            "public struct KsAfter {\n    @_spi(KsMeasurement) public var probe: Int { 0 }\n    public var shown: Int { 0 }\n}\n"
        )
        self.assertEqual(names_of(IOS, text), ["KsAfter", "shown"])

    def test_公開でないextensionの中のpublicの宣言に型の名前が付く(self) -> None:
        text = "extension KsSample {\n    public func paging() -> KsSample { self }\n    func helper() {}\n}\n"
        extraction = PUBLIC_API.extract(IOS, "Sample.swift", text)
        self.assertEqual([(d.owner, d.name) for d in extraction.declarations], [("KsSample", "paging")])

    def test_publicのextensionとprotocolの直下は書かなくても拾う(self) -> None:
        text = (
            "public extension KsSample {\n    func shared() {}\n    private func hidden() {}\n    var flag: Bool { true }\n}\n"
            "public protocol KsSource {\n    associatedtype Item\n    func load() async\n    var count: Int { get }\n}\n"
        )
        self.assertEqual(names_of(IOS, text), ["Item", "KsSource", "count", "flag", "load", "shared"])

    def test_コメントと文字列の中のpublicは宣言として読まない(self) -> None:
        text = (
            "/* public struct KsCommented {\n   public var value = 0\n*/\n"
            "struct KsLogger {\n"
            "    func warn(_ key: String) {\n"
            '        logger.warning("public func fake() \\(key, privacy: .public)")\n'
            "        // public func alsoFake()\n"
            "    }\n}\n"
        )
        extraction = PUBLIC_API.extract(IOS, "Sample.swift", text)
        self.assertEqual(extraction.declarations, ())
        self.assertEqual(extraction.unparsed, ())

    def test_中身を持たない宣言の後ろの囲みを取り違えない(self) -> None:
        text = (
            "public protocol KsMarker {}\n"
            "public typealias KsAlias = Int\n"
            "enum KsHiddenEdge {\n    case secret\n}\n"
            "public enum KsEdge {\n    case top\n}\n"
        )
        self.assertEqual(names_of(IOS, text), ["KsAlias", "KsEdge", "KsMarker", "top"])

    def test_名前を読み取れないpublicの行は別に返す(self) -> None:
        text = "public struct KsValue {\n    public static func == (lhs: KsValue, rhs: KsValue) -> Bool { true }\n}\n"
        extraction = PUBLIC_API.extract(IOS, "Sample.swift", text)
        self.assertEqual(sorted(extraction.names()), ["KsValue"])
        self.assertEqual([(u.line, u.text) for u in extraction.unparsed], [(2, text.splitlines()[1].strip())])

    def test_複数行の宣言は名前のある行だけを拾う(self) -> None:
        text = "public struct KsValue {\n    public func scrollTo(\n        _ id: Int,\n        animated: Bool = true\n    ) {}\n}\n"
        extraction = PUBLIC_API.extract(IOS, "Sample.swift", text)
        self.assertEqual([(line, text_) for _, line, text_ in extraction.lines()], [(1, "public struct KsValue {"), (2, "public func scrollTo(")])


class KotlinExtractionTest(unittest.TestCase):
    def test_型と関数とプロパティと列挙の値を拾う(self) -> None:
        extraction = PUBLIC_API.extract(ANDROID, "Sample.kt", KOTLIN_TEXT)
        found = [(d.line, d.kind, d.owner, d.name) for d in extraction.declarations]
        self.assertEqual(
            found,
            [
                (5, "関数", "", "KsSample"),
                (8, "型", "", "KsSampleMode"),
                (9, "列挙の値", "KsSampleMode", "Compact"),
                (10, "列挙の値", "KsSampleMode", "Regular"),
                (13, "型", "", "KsSampleOptions"),
                (14, "プロパティ", "KsSampleOptions", "threshold"),
            ],
        )
        self.assertEqual(extraction.unparsed, ())

    def test_publicと書かれていないコンストラクタのプロパティを拾う(self) -> None:
        text = (
            "public sealed interface KsColumns {\n"
            "    public data class Fixed(val portrait: Int, val landscape: Int) : KsColumns {\n"
            "        public constructor(count: Int) : this(count, count)\n"
            "    }\n"
            "    public data class Grid(\n"
            "        val columns: KsColumns,\n"
            "        var rowSpacing: Dp = 0.dp,\n"
            "    ) : KsColumns\n"
            "}\n"
        )
        extraction = PUBLIC_API.extract(ANDROID, "Sample.kt", text)
        found = [(d.line, d.kind, d.owner, d.name) for d in extraction.declarations]
        self.assertEqual(
            found,
            [
                (1, "型", "", "KsColumns"),
                (2, "型", "KsColumns", "Fixed"),
                (2, "プロパティ", "KsColumns.Fixed", "portrait"),
                (2, "プロパティ", "KsColumns.Fixed", "landscape"),
                (3, "初期化", "KsColumns.Fixed", None),
                (5, "型", "KsColumns", "Grid"),
                (6, "プロパティ", "KsColumns.Grid", "columns"),
                (7, "プロパティ", "KsColumns.Grid", "rowSpacing"),
            ],
        )
        # 1 行に複数の宣言があっても、行としては 1 回だけ数える。
        self.assertEqual([line for _, line, _ in extraction.lines()], [1, 2, 3, 5, 6, 7])

    def test_クラスの宣言と同じ行のプロパティを拾う(self) -> None:
        text = (
            "public sealed interface KsImageSource {\n"
            "    public data class File(public val file: java.io.File) : KsImageSource\n"
            "    public data class Resource(@param:DrawableRes public val id: Int) : KsImageSource\n"
            "    public data object None : KsImageSource\n"
            "}\n"
        )
        extraction = PUBLIC_API.extract(ANDROID, "Sample.kt", text)
        self.assertEqual(
            [(d.owner, d.name) for d in extraction.declarations],
            [
                ("", "KsImageSource"),
                ("KsImageSource", "File"),
                ("KsImageSource.File", "file"),
                ("KsImageSource", "Resource"),
                ("KsImageSource.Resource", "id"),
                ("KsImageSource", "None"),
            ],
        )

    def test_引数と公開でないコンストラクタのプロパティは拾わない(self) -> None:
        text = (
            "public class KsScope<Item> internal constructor(\n"
            "    plain: Int,\n"
            "    private val hidden: Int,\n"
            "    internal var alsoHidden: Int,\n"
            "    val shown: Int,\n"
            "    val callback: (value: Int) -> Unit = { val local = it },\n"
            ") {\n"
            "    public fun template(key: Any, content: (Item) -> Unit) {\n        val local = key\n    }\n"
            "}\n"
            "internal class KsHidden(val leaked: Int)\n"
        )
        self.assertEqual(names_of(ANDROID, text), ["KsScope", "callback", "shown", "template"])

    def test_型引数と拡張の受け手を飛ばして名前を読む(self) -> None:
        text = (
            "public fun <Item> KsList(items: List<Item>) {}\n"
            "public fun <K : Comparable<K>, V> Map<K, V>.ksSorted(): List<V> = emptyList()\n"
            "public val KsLayout.isList: Boolean get() = true\n"
            "public val <T> List<T>.ksLast: T get() = last()\n"
            "public suspend inline fun rememberKsState(): Int = 0\n"
            "public typealias KsKey = String\n"
            "public fun interface KsAction { public fun run() }\n"
            "public annotation class KsDsl\n"
        )
        self.assertEqual(
            names_of(ANDROID, text),
            ["KsAction", "KsDsl", "KsKey", "KsList", "isList", "ksLast", "ksSorted", "rememberKsState", "run"],
        )

    def test_引数や中身を持つ値と区切りの後ろのメンバーを読み分ける(self) -> None:
        text = (
            "public enum class KsEdge(public val code: Int) {\n"
            "    @Deprecated(\"old\") Top(1),\n"
            "    Bottom(\n        2,\n    ),\n"
            "    Side(3) {\n        override fun toString(): String = \"side\"\n    },\n"
            "    Left(4), Right(5);\n"
            "\n"
            "    public fun isVertical(): Boolean = this == Top\n"
            "    internal val hidden = 0\n"
            "}\n"
        )
        self.assertEqual(names_of(ANDROID, text), ["Bottom", "KsEdge", "Left", "Right", "Side", "Top", "code", "isVertical"])

    def test_公開でないenumの値は拾わない(self) -> None:
        text = "internal enum class KsHidden {\n    Secret,\n}\npublic enum class KsShown {\n    Open,\n}\n"
        self.assertEqual(names_of(ANDROID, text), ["KsShown", "Open"])

    def test_名前の無いcompanionは行としてだけ数える(self) -> None:
        text = "public open class KsList(\n    public val spacing: Int = 0,\n) : KsLayout {\n    public companion object : KsList()\n}\n"
        extraction = PUBLIC_API.extract(ANDROID, "Sample.kt", text)
        self.assertEqual(sorted(extraction.names()), ["KsList", "spacing"])
        self.assertEqual([line for _, line, _ in extraction.lines()], [1, 2, 4])
        self.assertEqual(extraction.unparsed, ())

    def test_中身を持たない宣言の後ろの囲みを取り違えない(self) -> None:
        text = (
            "public enum class KsEmpty\n"
            "internal fun helper() {\n    Fake,\n}\n"
            "public data object KsEnd : KsDestination\n"
            "internal fun other() {\n    Another,\n}\n"
        )
        self.assertEqual(names_of(ANDROID, text), ["KsEmpty", "KsEnd"])

    def test_コメントと文字列の中のpublicは宣言として読まない(self) -> None:
        text = (
            "/**\n * public fun fake()\n */\n"
            "internal fun warn() {\n"
            '    log("public class Fake(val x: Int)")\n'
            "    val brace = '{'\n"
            '    val raw = """\n        public fun alsoFake()\n    """\n'
            "}\n"
        )
        extraction = PUBLIC_API.extract(ANDROID, "Sample.kt", text)
        self.assertEqual(extraction.declarations, ())
        self.assertEqual(extraction.unparsed, ())

    def test_名前を読み取れないpublicの行は別に返す(self) -> None:
        text = "public class KsValue {\n    public operator fun (other: KsValue) {}\n}\n"
        extraction = PUBLIC_API.extract(ANDROID, "Sample.kt", text)
        self.assertEqual(sorted(extraction.names()), ["KsValue"])
        self.assertEqual([u.line for u in extraction.unparsed], [2])


class SourceLocationTest(unittest.TestCase):
    def test_本体のソースのパスからプラットフォームを引く(self) -> None:
        self.assertEqual(PUBLIC_API.platform_for_path(IOS_SOURCE), IOS)
        self.assertEqual(PUBLIC_API.platform_for_path(ANDROID_SOURCE), ANDROID)
        self.assertIsNone(PUBLIC_API.platform_for_path("samples/ios/Sources/Sample.swift"))
        self.assertIsNone(PUBLIC_API.platform_for_path("ios/Sources/KsCollectionView/Notes.md"))
        self.assertIsNone(PUBLIC_API.platform_for_path("android/kscollectionview/src/test/kotlin/KsSampleTest.kt"))


if __name__ == "__main__":
    unittest.main()
