#!/usr/bin/env python3
"""検証 CI のスクリプトのテストを、まとめて流す入口。

scripts/ci/tests の下の test_*.py をすべて流す。手元と、検証 CI の lint のジョブの両方から呼ぶ。
どの作業ディレクトリから呼んでもよい。

使い方:
  python3 scripts/ci/run-tests.py          # 全件
  python3 scripts/ci/run-tests.py -v       # テストの名前を 1 件ずつ出す

終了コード:
  0  全件が通った
  1  失敗したテストがある / スキップを除いて 1 件も実行されなかった
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import os
import sys
import unittest

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS_DIR = os.path.join(HERE, "tests")


def run(tests_dir: str, verbose: bool = False, stream=None) -> int:
    """tests_dir の下のテストを流して、終了コードを返す。"""
    suite = unittest.defaultTestLoader.discover(tests_dir, pattern="test_*.py", top_level_dir=tests_dir)
    result = unittest.TextTestRunner(stream=stream, verbosity=2 if verbose else 1).run(suite)

    executed = result.testsRun - len(result.skipped)
    failed = len(result.failures) + len(result.errors) + len(result.unexpectedSuccesses)
    print(f"実行 {executed} 件 / 失敗 {failed} 件 / スキップ {len(result.skipped)} 件")
    if executed <= 0:
        # テストの置き場が空でも、探索が壊れていても、ここで止める。
        print("::error::検査のスクリプトのテストが 1 件も実行されなかった")
        return 1
    return 0 if result.wasSuccessful() else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="検証 CI のスクリプトのテストを流す")
    parser.add_argument("-v", "--verbose", action="store_true", help="テストの名前を 1 件ずつ出す")
    args = parser.parse_args(argv)
    return run(TESTS_DIR, args.verbose)


if __name__ == "__main__":
    sys.exit(main())
