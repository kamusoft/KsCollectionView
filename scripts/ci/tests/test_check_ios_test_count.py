"""iOS のテストの実行件数の検査のテスト。"""

from __future__ import annotations

import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("check-ios-test-count.py")


def xcodebuild_log(classes: list[tuple[str, int, int]], *, bundle: str = "KsCollectionViewTests.xctest") -> str:
    """xcodebuild test の出力を模した記録を作る。classes は (クラスの名前, 件数, スキップ) の並び。"""
    stamp = "2026-10-08 10:00:00.000"
    total = sum(count for _, count, _ in classes)
    skipped = sum(skip for _, _, skip in classes)

    def executed(count: int, skip: int) -> str:
        middle = f"{skip} test{'' if skip == 1 else 's'} skipped and " if skip else ""
        return (
            f"\t Executed {count} test{'' if count == 1 else 's'}, with {middle}0 failures (0 unexpected)"
            " in 0.123 (0.130) seconds"
        )

    lines = [
        "Testing started",
        f"Test Suite 'All tests' started at {stamp}",
        f"Test Suite '{bundle}' started at {stamp}",
    ]
    for name, count, skip in classes:
        lines.append(f"Test Suite '{name}' started at {stamp}")
        for index in range(count):
            state = "skipped" if index < skip else "passed"
            lines.append(f"Test Case '-[KsCollectionViewTests.{name} test{index}]' started.")
            lines.append(f"Test Case '-[KsCollectionViewTests.{name} test{index}]' {state} (0.001 seconds).")
        lines.append(f"Test Suite '{name}' passed at {stamp}.")
        lines.append(executed(count, skip))
    lines.append(f"Test Suite '{bundle}' passed at {stamp}.")
    lines.append(executed(total, skipped))
    lines.append(f"Test Suite 'All tests' passed at {stamp}.")
    lines.append(executed(total, skipped))
    lines.append("** TEST SUCCEEDED **")
    return "\n".join(lines) + "\n"


class CheckIosTestCountTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.summary = os.path.join(self.directory.name, "summary.md")

    def run_check(self, log_text: str | None) -> tuple[int, str]:
        log = os.path.join(self.directory.name, "xcodebuild.log")
        if log_text is not None:
            support.write(log, log_text)
        code, stdout, _ = support.run_main(
            SCRIPT, ["--label", "iOS 本体", "--log", log], env={"GITHUB_STEP_SUMMARY": self.summary}
        )
        return code, stdout

    def read_summary(self) -> str:
        with open(self.summary, encoding="utf-8") as f:
            return f.read()

    def test_通常の記録なら成功し件数とスキップの件数が概要に出る(self) -> None:
        code, stdout = self.run_check(xcodebuild_log([("KsEngineTests", 5, 1), ("KsLayoutTests", 3, 0)]))
        self.assertEqual(code, 0)
        self.assertNotIn("::error::", stdout)
        # 入れ子のまとまりを二重に数えず、いちばん外側の 8 件だけを数える。
        self.assertIn("| 8 | 1 | 7 | 0 |", self.read_summary())
        self.assertIn("iOS 本体", self.read_summary())

    def test_外側のまとまりが複数あれば足し合わせる(self) -> None:
        text = xcodebuild_log([("KsEngineTests", 4, 0)]) + xcodebuild_log(
            [("SampleModelTests", 2, 0)], bundle="KsCollectionViewSamplesTests.xctest"
        )
        code, _ = self.run_check(text)
        self.assertEqual(code, 0)
        self.assertIn("| 6 | 0 | 6 | 0 |", self.read_summary())

    def test_単数形の集計の行も読める(self) -> None:
        code, _ = self.run_check(xcodebuild_log([("KsEngineTests", 1, 0)]))
        self.assertEqual(code, 0)
        self.assertIn("| 1 | 0 | 1 | 0 |", self.read_summary())

    def test_実行が0件なら失敗する(self) -> None:
        code, stdout = self.run_check(xcodebuild_log([]))
        self.assertEqual(code, 1)
        self.assertIn("::error::iOS 本体: テストが 1 件も実行されていない", stdout)
        self.assertIn("件数の検査の失敗", self.read_summary())

    def test_全件がスキップなら失敗する(self) -> None:
        code, stdout = self.run_check(xcodebuild_log([("KsEngineTests", 3, 3)]))
        self.assertEqual(code, 1)
        self.assertIn("スキップを除くと 1 件も実行されていない", stdout)
        self.assertIn("| 3 | 3 | 0 | 0 |", self.read_summary())

    def test_集計の行が無ければ失敗する(self) -> None:
        code, stdout = self.run_check("Build started\n** BUILD FAILED **\n")
        self.assertEqual(code, 1)
        self.assertIn("件数の集計の行が無いため、実行の件数を確かめられなかった", stdout)

    def test_記録が無ければ失敗する(self) -> None:
        code, stdout = self.run_check(None)
        self.assertEqual(code, 1)
        self.assertIn("テストの実行の記録が無いため、実行の件数を確かめられなかった", stdout)
        self.assertIn("件数を読み取れなかった", self.read_summary())

    def test_まとまりの対応を読めない記録では最後の集計の行を使う(self) -> None:
        text = (
            "\t Executed 2 tests, with 0 failures (0 unexpected) in 0.1 (0.1) seconds\n"
            "\t Executed 9 tests, with 1 test skipped and 0 failures (0 unexpected) in 0.5 (0.5) seconds\n"
        )
        code, _ = self.run_check(text)
        self.assertEqual(code, 0)
        self.assertIn("| 9 | 1 | 8 | 0 |", self.read_summary())
        self.assertIn("最後の集計の行を全体の件数として使った", self.read_summary())

    def test_失敗のあるまとまりも件数に数える(self) -> None:
        stamp = "2026-10-08 10:00:00.000"
        text = "\n".join(
            [
                f"Test Suite 'All tests' started at {stamp}",
                f"Test Suite 'KsEngineTests' started at {stamp}",
                f"Test Suite 'KsEngineTests' failed at {stamp}.",
                "\t Executed 4 tests, with 2 failures (0 unexpected) in 0.1 (0.1) seconds",
                f"Test Suite 'All tests' failed at {stamp}.",
                "\t Executed 4 tests, with 2 failures (0 unexpected) in 0.1 (0.1) seconds",
            ]
        )
        code, _ = self.run_check(text)
        # テストの失敗はこの検査の合否にしない (流したコマンドの終了コードが決める)。
        self.assertEqual(code, 0)
        self.assertIn("| 4 | 0 | 4 | 2 |", self.read_summary())


if __name__ == "__main__":
    unittest.main()
