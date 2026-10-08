"""テストをまとめて流す入口のテスト。"""

from __future__ import annotations

import contextlib
import io
import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("run-tests.py")

PASSING = """
import unittest

class PassingTest(unittest.TestCase):
    def test_passes(self):
        self.assertTrue(True)
"""

FAILING = """
import unittest

class FailingTest(unittest.TestCase):
    def test_fails(self):
        self.fail("わざと失敗させる")
"""

SKIPPED = """
import unittest

class SkippedTest(unittest.TestCase):
    @unittest.skip("わざとスキップする")
    def test_skipped(self):
        pass
"""


class RunTestsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)

    def run_entry(self, files: dict[str, str]) -> tuple[int, str]:
        for name, text in files.items():
            support.write(os.path.join(self.directory.name, name), text)
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = SCRIPT.run(self.directory.name, stream=io.StringIO())
        return code, stdout.getvalue()

    def test_全件が通れば成功する(self) -> None:
        # テストのモジュールの名前は、本物のテストと重ならないものにする (読み込みは名前で共有される)。
        code, stdout = self.run_entry({"test_entry_fixture_passing.py": PASSING})
        self.assertEqual(code, 0)
        self.assertIn("実行 1 件 / 失敗 0 件", stdout)

    def test_失敗するテストがあれば失敗する(self) -> None:
        code, stdout = self.run_entry(
            {"test_entry_fixture_passing2.py": PASSING, "test_entry_fixture_failing.py": FAILING}
        )
        self.assertEqual(code, 1)
        self.assertIn("失敗 1 件", stdout)

    def test_テストが1件も無ければ失敗する(self) -> None:
        code, stdout = self.run_entry({})
        self.assertEqual(code, 1)
        self.assertIn("1 件も実行されなかった", stdout)

    def test_全件がスキップなら失敗する(self) -> None:
        code, stdout = self.run_entry({"test_entry_fixture_skipped.py": SKIPPED})
        self.assertEqual(code, 1)
        self.assertIn("1 件も実行されなかった", stdout)

    def test_読み込めないテストがあれば失敗する(self) -> None:
        code, _ = self.run_entry(
            {"test_entry_fixture_passing3.py": PASSING, "test_entry_fixture_broken.py": "import 存在しないモジュール\n"}
        )
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
