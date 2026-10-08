"""Android のテストの実行件数の検査のテスト。"""

from __future__ import annotations

import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("check-android-test-count.py")

PACKAGE = "jp.kamusoft.sample"
TASK = "testDebugUnitTest"


def kotlin_test(name: str, tests: int = 2) -> str:
    methods = "\n".join(f"    @Test\n    fun case{index}() {{}}\n" for index in range(tests))
    return f"package {PACKAGE}\n\nimport org.junit.Test\n\ninternal class {name} {{\n{methods}}}\n"


def result_xml(name: str, tests: int, skipped: int = 0, failures: int = 0) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<testsuite name="{PACKAGE}.{name}" tests="{tests}" skipped="{skipped}" failures="{failures}" errors="0">\n'
        "</testsuite>\n"
    )


class CheckAndroidTestCountTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = self.directory.name
        self.summary = os.path.join(self.root, "summary.md")
        self.previous = os.getcwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, self.previous)

    def add_source(self, module: str, name: str, text: str | None = None, source_set: str = "test") -> None:
        path = os.path.join(module, "src", source_set, "kotlin", *PACKAGE.split("."), f"{name}.kt")
        support.write(path, text if text is not None else kotlin_test(name))

    def add_result(self, module: str, name: str, tests: int = 2, skipped: int = 0, task: str = TASK) -> str:
        path = os.path.join(module, "build", "test-results", task, f"TEST-{PACKAGE}.{name}.xml")
        return support.write(path, result_xml(name, tests, skipped))

    def run_check(self, *targets: str, extra: list[str] | None = None) -> tuple[int, str]:
        argv = [item for target in targets for item in ("--target", target)] + (extra or [])
        code, stdout, _ = support.run_main(SCRIPT, argv, env={"GITHUB_STEP_SUMMARY": self.summary})
        return code, stdout

    def read_summary(self) -> str:
        with open(self.summary, encoding="utf-8") as f:
            return f.read()

    def healthy(self, module: str, names: tuple[str, ...] = ("AlphaTest", "BetaTest")) -> None:
        for name in names:
            self.add_source(module, name)
            self.add_result(module, name)

    def test_結果がそろっていれば成功し件数とクラスごとの内訳が概要に出る(self) -> None:
        self.healthy("library")
        self.healthy("app", names=("GammaTest",))
        self.add_result("library", "AlphaTest", tests=5, skipped=1)
        code, stdout = self.run_check(f"本体=library:{TASK}", f"Sample=app:{TASK}")
        self.assertEqual(code, 0)
        self.assertNotIn("::error::", stdout)
        summary = self.read_summary()
        self.assertIn("| 本体 | 7 | 1 | 6 | 0 | 2 | 2 |", summary)
        self.assertIn("| Sample | 2 | 0 | 2 | 0 | 1 | 1 |", summary)
        self.assertIn(f"| {PACKAGE}.AlphaTest | 5 | 1 | 0 |", summary)
        self.assertIn(f"| {PACKAGE}.GammaTest | 2 | 0 | 0 |", summary)

    def test_結果のファイルが無ければ失敗し対象が示される(self) -> None:
        self.healthy("library")
        self.add_source("app", "GammaTest")
        code, stdout = self.run_check(f"本体=library:{TASK}", f"Sample=app:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("::error::Sample:", stdout)
        self.assertIn("テストの結果のファイルが無い", stdout)
        self.assertNotIn("::error::本体:", stdout)

    def test_別のタスクの結果は数えない(self) -> None:
        # 結果の置き場の名前はタスクの名前。読み替えを誤ると、別のタスクの結果で通ってしまう。
        self.add_source("library", "AlphaTest")
        self.add_result("library", "AlphaTest", task="testReleaseUnitTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("テストの結果のファイルが無い", stdout)

    def test_実行が0件なら失敗し対象が示される(self) -> None:
        self.add_source("library", "AlphaTest")
        self.add_result("library", "AlphaTest", tests=0)
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("::error::本体: テストが 1 件も実行されていない", stdout)

    def test_全件がスキップなら失敗し対象が示される(self) -> None:
        self.add_source("library", "AlphaTest")
        self.add_result("library", "AlphaTest", tests=3, skipped=3)
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("::error::本体: スキップを除くと実行が 0 件である", stdout)

    def test_一部のクラスの結果しか無ければ失敗し現れなかったクラスが示される(self) -> None:
        self.healthy("library")
        self.add_source("library", "MissingTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("結果に現れないクラスがある", stdout)
        self.assertIn(f"{PACKAGE}.MissingTest", stdout)
        self.assertNotIn(f"{PACKAGE}.AlphaTest,", stdout)

    def test_テストのクラスを1つも導けなければ失敗する(self) -> None:
        # 結果はあるのに、ソースからクラスを導けない (置き場の指定の誤りや、導き方の退化)。
        self.add_result("library", "AlphaTest")
        self.add_source("library", "Support", "package jp.kamusoft.sample\n\ninternal fun helper() = 1\n")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("テストのクラスを 1 つも導けなかった", stdout)

    def test_テストのソースの置き場が無くても失敗する(self) -> None:
        self.add_result("library", "AlphaTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("テストのクラスを 1 つも導けなかった", stdout)

    def test_テストを持たない補助のクラスと抽象クラスは期待に数えない(self) -> None:
        self.healthy("library")
        self.add_source(
            "library",
            "Helpers",
            f"package {PACKAGE}\n\ninternal class Recorder {{\n    fun record() {{}}\n}}\n\n"
            "internal abstract class BaseTest {\n    @Test\n    fun shared() {}\n}\n\n"
            "internal object Fixtures {\n    val value = 1\n}\n",
        )
        code, _ = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 0)

    def test_1つのファイルに複数のテストのクラスがあればそれぞれを期待する(self) -> None:
        self.healthy("library")
        self.add_source(
            "library",
            "Pair",
            f"package {PACKAGE}\n\nclass FirstTest {{\n    @Test fun a() {{}}\n}}\n\n"
            "class SecondTest {\n    @org.junit.Test\n    fun b() {}\n}\n",
        )
        self.add_result("library", "FirstTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn(f"{PACKAGE}.SecondTest", stdout)
        self.assertNotIn(f"{PACKAGE}.FirstTest", stdout.split("::error::")[1])

    def test_注釈と同じ行に宣言したクラスも期待に含める(self) -> None:
        # 結果には AlphaTest と BetaTest しか無い。同じ行に注釈の付いたクラスを読み落とすと、
        # 期待の集合が縮んだまま成功で終わってしまう。
        self.healthy("library")
        self.add_source(
            "library",
            "Annotated",
            f"package {PACKAGE}\n\n"
            "@RunWith(RobolectricTestRunner::class) class SameLineTest {\n    @Test\n    fun a() {}\n}\n\n"
            '@Config(sdk = [34]) @Suppress("abstract") internal class TwoAnnotationsTest {\n    @Test\n    fun b() {}\n}\n\n'
            "@RunWith(RobolectricTestRunner::class) abstract class SameLineBase {\n    @Test\n    fun c() {}\n}\n",
        )
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("結果に現れないクラスがある", stdout)
        self.assertIn(f"{PACKAGE}.SameLineTest", stdout)
        self.assertIn(f"{PACKAGE}.TwoAnnotationsTest", stdout)
        self.assertNotIn("SameLineBase", stdout)
        self.assertNotIn("属するクラスを導けない", stdout)

    def test_注釈と同じ行に宣言したクラスの結果があれば成功する(self) -> None:
        self.healthy("library")
        self.add_source(
            "library",
            "Annotated",
            f"package {PACKAGE}\n\n"
            "@RunWith(RobolectricTestRunner::class) class SameLineTest {\n    @Test\n    fun a() {}\n}\n",
        )
        self.add_result("library", "SameLineTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 0, stdout)
        self.assertIn("| 本体 | 6 | 0 | 6 | 0 | 3 | 3 |", self.read_summary())

    # @Test の印の書き方ごとの入力。どれも OddTest がテストのクラス。
    ODD_TEST_SOURCES = {
        "ほかの注釈の後ろに同じ行で書いた印": (
            f"package {PACKAGE}\n\nclass OddTest {{\n"
            '    @Suppress("unused") @Test fun a() {}\n    @Ignore @Test fun b() {}\n}\n'
        ),
        "クラスの宣言と同じ行に書いた印": f"package {PACKAGE}\n\nclass OddTest {{ @Test fun a() {{}} }}\n",
        "行頭に書いた印": f"package {PACKAGE}\n\nclass OddTest {{\n@Test\nfun a() {{}}\n}}\n",
    }

    def test_印の書き方が違うクラスも結果が無ければ失敗する(self) -> None:
        # 結果には AlphaTest と BetaTest しか無い。印を読み落とすと、期待の集合が縮んだまま成功で終わる。
        for title, source in self.ODD_TEST_SOURCES.items():
            with self.subTest(title):
                self.healthy("library")
                self.add_source("library", "Odd", source)
                code, stdout = self.run_check(f"本体=library:{TASK}")
                self.assertEqual(code, 1, stdout)
                self.assertIn(f"結果に現れないクラスがある: {PACKAGE}.OddTest", stdout)
                self.assertNotIn("属するクラスを導けない", stdout)

    def test_印の書き方が違うクラスも結果がそろっていれば成功する(self) -> None:
        for title, source in self.ODD_TEST_SOURCES.items():
            with self.subTest(title):
                self.healthy("library")
                self.add_source("library", "Odd", source)
                self.add_result("library", "OddTest")
                code, stdout = self.run_check(f"本体=library:{TASK}")
                self.assertEqual(code, 0, stdout)
                self.assertIn("| 本体 | 6 | 0 | 6 | 0 | 3 | 3 |", self.read_summary())

    def test_同じ行に並べた複数のクラスの印はそれぞれのクラスに数える(self) -> None:
        self.healthy("library")
        self.add_source(
            "library",
            "OneLine",
            f"package {PACKAGE}\n\nclass FirstTest {{ @Test fun a() {{}} }} class SecondTest {{ @Test fun b() {{}} }}\n",
        )
        self.add_result("library", "FirstTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn(f"結果に現れないクラスがある: {PACKAGE}.SecondTest", stdout)

    def test_同じ行に宣言した抽象クラスの印は期待に数えない(self) -> None:
        self.healthy("library")
        self.add_source("library", "Base", f"package {PACKAGE}\n\nabstract class BaseTest {{ @Test fun a() {{}} }}\n")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 0, stdout)

    def test_属するクラスを決められない行頭の印は失敗にする(self) -> None:
        # 字下げしないクラスの 2 つ目の印は、行頭の関数の後ろにあるので属するクラスを決められない。
        # クラスの結果がそろっていても、黙って通さない。
        self.healthy("library")
        path = os.path.join("library", "src", "test", "kotlin", *PACKAGE.split("."), "Flat.kt")
        self.add_source(
            "library",
            "Flat",
            f"package {PACKAGE}\n\nclass FlatTest {{\n@Test\nfun a() {{}}\n@Ignore @Test\nfun b() {{}}\n}}\n",
        )
        self.add_result("library", "FlatTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("属するクラスを導けない @Test がある", stdout)
        self.assertIn(f"{path}:6", stdout)
        self.assertNotIn(f"{path}:4", stdout)

    def test_バッククォートの名前と一覧に無い修飾子で始まるクラスも期待に含める(self) -> None:
        self.healthy("library")
        self.add_source(
            "library",
            "Unusual",
            f"package {PACKAGE}\n\n"
            "class `quoted name` {\n    @Test\n    fun a() {}\n}\n\n"
            "value class WrappedTest(val raw: Int) {\n    @Test\n    fun b() {}\n}\n",
        )
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn(f"{PACKAGE}.WrappedTest", stdout)
        self.assertIn(f"{PACKAGE}.quoted name", stdout)

    def test_クラスの宣言として読めない行の後ろのテストは直前のクラスに数えず失敗にする(self) -> None:
        # 宣言を読み落としたとき、その中の @Test を直前のクラスのものとして数えると、
        # 読み落としたクラスが結果に無くても成功で終わってしまう。
        self.healthy("library")
        path = os.path.join("library", "src", "test", "kotlin", *PACKAGE.split("."), "Unreadable.kt")
        self.add_source(
            "library",
            "Unreadable",
            f"package {PACKAGE}\n\nclass ReadableTest {{\n    @Test\n    fun a() {{}}\n}}\n\n"
            "typealias Later = Int\n    @Test\n    fun b() {}\n",
        )
        self.add_result("library", "ReadableTest")
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("::error::本体: テストのソースに、属するクラスを導けない @Test がある", stdout)
        self.assertIn(f"{path}:9", stdout)
        self.assertNotIn("結果に現れないクラスがある", stdout)

    def test_テストを持たない行頭の宣言はクラスでなくても失敗にしない(self) -> None:
        self.healthy("library")
        self.add_source(
            "library",
            "TopLevel",
            f"package {PACKAGE}\n\nimport org.junit.Test\n\n@Suppress(\"unused\")\nprivate fun helper() = 1\n\n"
            "private val fixture = object : Runnable {\n    override fun run() {}\n}\n\n"
            "@Retention\nannotation class Marker\n",
        )
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 0, stdout)

    def test_ビルドの種類ごとのソースの置き場も期待に含める(self) -> None:
        self.healthy("app")
        self.add_source("app", "DebugOnlyTest", source_set="testDebug")
        self.add_source("app", "ReleaseOnlyTest", source_set="testRelease")
        code, stdout = self.run_check(f"Sample=app:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn(f"{PACKAGE}.DebugOnlyTest", stdout)
        # 別の種類のタスクのソースは、このタスクの期待に含めない。
        self.assertNotIn("ReleaseOnlyTest", stdout)

    def test_前の実行の結果は数えない(self) -> None:
        self.healthy("library")
        stale = self.add_result("library", "RemovedTest", tests=40)
        marker = support.write(os.path.join(self.root, "marker"), "")
        os.utime(marker, (1_000_000_000, 1_000_000_000))
        os.utime(stale, (999_999_000, 999_999_000))
        code, _ = self.run_check(f"本体=library:{TASK}", extra=["--stale-before", marker])
        self.assertEqual(code, 0)
        summary = self.read_summary()
        self.assertIn("| 本体 | 4 | 0 | 4 | 0 | 2 | 2 |", summary)
        self.assertIn("前の実行の残りとして数えなかった結果のファイル: 1 件", summary)

    def test_前の実行の結果しか無ければ失敗する(self) -> None:
        self.add_source("library", "AlphaTest")
        stale = self.add_result("library", "AlphaTest")
        marker = support.write(os.path.join(self.root, "marker"), "")
        os.utime(marker, (1_000_000_000, 1_000_000_000))
        os.utime(stale, (999_999_000, 999_999_000))
        code, stdout = self.run_check(f"本体=library:{TASK}", extra=["--stale-before", marker])
        self.assertEqual(code, 1)
        self.assertIn("テストの結果のファイルが無い", stdout)
        self.assertIn("前の実行の残りとして数えなかったファイル: 1 件", stdout)

    def test_読めない結果のファイルがあれば失敗する(self) -> None:
        self.healthy("library")
        support.write(
            os.path.join("library", "build", "test-results", TASK, f"TEST-{PACKAGE}.BrokenTest.xml"), "<testsuite"
        )
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("結果のファイルを読めない", stdout)

    def test_件数の属性が無い結果のファイルは読めないものとして扱う(self) -> None:
        self.healthy("library")
        support.write(
            os.path.join("library", "build", "test-results", TASK, f"TEST-{PACKAGE}.AlphaTest.xml"),
            f'<testsuite name="{PACKAGE}.AlphaTest"></testsuite>',
        )
        code, stdout = self.run_check(f"本体=library:{TASK}")
        self.assertEqual(code, 1)
        self.assertIn("結果のファイルを読めない", stdout)

    def test_組を渡さなければ引数の誤りになる(self) -> None:
        code, _ = self.run_check()
        self.assertEqual(code, 2)

    def test_組の形が誤っていれば引数の誤りになる(self) -> None:
        for target in ("library", "本体=library", f"=library:{TASK}", "本体=:x"):
            with self.subTest(target=target):
                code, _ = self.run_check(target)
                self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
