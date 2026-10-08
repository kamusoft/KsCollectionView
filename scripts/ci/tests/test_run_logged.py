"""コマンドを流して出力を記録に残すスクリプトのテスト。"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest

import support

SCRIPT_PATH = support.script_path("run-logged.py")


class RunLoggedTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.log = os.path.join(self.directory.name, "logs", "run.log")

    def run_logged(self, *command: str, log: str | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, "-B", SCRIPT_PATH, "--log", log or self.log, "--", *command],
            capture_output=True,
            encoding="utf-8",
            timeout=60,
        )

    def python(self, code: str) -> tuple[str, ...]:
        return (sys.executable, "-c", code)

    def read_log(self) -> str:
        with open(self.log, encoding="utf-8") as f:
            return f.read()

    def test_コマンドが成功すれば0を返し出力が表示と記録の両方に残る(self) -> None:
        completed = self.run_logged(
            *self.python("import sys; print('標準出力の行'); print('標準エラー出力の行', file=sys.stderr)")
        )
        self.assertEqual(completed.returncode, 0)
        for text in (completed.stdout, self.read_log()):
            self.assertIn("標準出力の行", text)
            self.assertIn("標準エラー出力の行", text)

    def test_コマンドの失敗がそのまま返る(self) -> None:
        completed = self.run_logged(*self.python("print('途中までの出力'); raise SystemExit(7)"))
        self.assertEqual(completed.returncode, 7)
        # 失敗したときも、そこまでの出力は記録に残る。
        self.assertIn("途中までの出力", self.read_log())

    def test_前の実行の記録は残らない(self) -> None:
        support.write(self.log, "前の実行の記録\n")
        completed = self.run_logged(*self.python("print('今回の出力')"))
        self.assertEqual(completed.returncode, 0)
        self.assertNotIn("前の実行の記録", self.read_log())
        self.assertIn("今回の出力", self.read_log())

    def test_コマンドが見つからなければ127を返す(self) -> None:
        completed = self.run_logged("ks-no-such-command-for-test")
        self.assertEqual(completed.returncode, 127)
        self.assertIn("コマンドが見つからない", completed.stderr)

    def test_コマンドがシグナルで止まれば失敗を返す(self) -> None:
        completed = self.run_logged(*self.python("import os, signal; os.kill(os.getpid(), signal.SIGKILL)"))
        self.assertEqual(completed.returncode, 128 + 9)

    def test_記録のファイルを作れなければコマンドを流さず失敗する(self) -> None:
        blocker = support.write(os.path.join(self.directory.name, "blocker"), "")
        marker = os.path.join(self.directory.name, "marker")
        completed = self.run_logged(
            *self.python(f"open({marker!r}, 'w').close()"), log=os.path.join(blocker, "run.log")
        )
        self.assertEqual(completed.returncode, 2)
        self.assertFalse(os.path.exists(marker))

    def test_コマンドを渡さなければ引数の誤りになる(self) -> None:
        completed = subprocess.run(
            [sys.executable, "-B", SCRIPT_PATH, "--log", self.log], capture_output=True, encoding="utf-8", timeout=60
        )
        self.assertEqual(completed.returncode, 2)

    def test_コマンドの引数はそのまま渡る(self) -> None:
        completed = self.run_logged(*self.python("import sys; print(sys.argv[1:])"), "--log", "a b", "-x")
        self.assertEqual(completed.returncode, 0)
        self.assertIn("['--log', 'a b', '-x']", completed.stdout)


if __name__ == "__main__":
    unittest.main()
