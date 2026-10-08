"""検証 CI のスクリプトが共有する、結果の出力。

各スクリプトは、人が読む概要 (Markdown) と、失敗の理由を出力する。GitHub Actions の上では、
概要は実行の結果のページに、失敗の理由は注釈として現れる。手元では、どちらも標準出力に出るだけになる。
"""

from __future__ import annotations

import os
import sys


def emit_summary(lines: list[str]) -> None:
    """概要を標準出力に出し、環境変数 GITHUB_STEP_SUMMARY が指すファイルがあれば追記する。"""
    text = "\n".join(lines) + "\n"
    sys.stdout.write(text)
    sys.stdout.flush()
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(text + "\n")


def emit_errors(messages: list[str]) -> None:
    """失敗の理由を、GitHub Actions が注釈として拾う形で 1 件 1 行ずつ出す。"""
    for message in messages:
        # 注釈は 1 行で終わるので、改行を含む理由は空白でつなぐ。
        print("::error::" + " ".join(message.splitlines()))
    sys.stdout.flush()
