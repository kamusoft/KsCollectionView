#!/usr/bin/env python3
"""コマンドを流し、出力をそのまま表示しながら記録のファイルに残す。

シェルの `コマンド | tee 記録` は、既定ではパイプの最後 (tee) の終了コードを返すので、
コマンドが失敗しても成功に見える。このスクリプトは、流したコマンドの終了コードをそのまま返す。

使い方:
  python3 scripts/ci/run-logged.py --log <記録のファイル> -- <コマンド> [引数...]

  --log  出力を残すファイル。コマンドを始める前に空にして作り直すので、
         前の実行の記録が残っていても、読めるのは今回の出力だけになる。
         置き場のディレクトリが無ければ作る
  --     これより後ろを、流すコマンドとして扱う。コマンドはこのスクリプトの作業ディレクトリで動く

  標準出力と標準エラー出力は、1 本にまとめて表示し、同じ内容を記録に書く。

終了コード:
  流したコマンドの終了コードをそのまま返す。ほかは次のとおり。
  1    コマンドは成功したが、記録を書き切れなかった
  2    引数の誤り / 記録のファイルを作れない (コマンドは流さない)
  126  コマンドを実行できない (実行の権限が無いなど)
  127  コマンドが見つからない
  128+N  コマンドがシグナル N で止まった
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys


def run(command: list[str], log_path: str) -> int:
    directory = os.path.dirname(os.path.abspath(log_path))
    try:
        os.makedirs(directory, exist_ok=True)
        log = open(log_path, "wb")
    except OSError as error:
        print(f"::error::記録のファイルを作れない: {error}", file=sys.stderr)
        return 2

    with log:
        try:
            process = subprocess.Popen(
                command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0
            )
        except FileNotFoundError:
            print(f"::error::コマンドが見つからない: {command[0]}", file=sys.stderr)
            return 127
        except OSError as error:
            print(f"::error::コマンドを実行できない: {error}", file=sys.stderr)
            return 126

        echo = sys.stdout.buffer
        echo_alive = True
        log_error: OSError | None = None
        assert process.stdout is not None
        try:
            # 表示や記録に失敗しても、読み出しは最後まで続ける。途中でやめると、
            # コマンドが出力の詰まりで止まり、終了コードを受け取れなくなる。
            while chunk := process.stdout.read(65536):
                if echo_alive:
                    try:
                        echo.write(chunk)
                        echo.flush()
                    except OSError:
                        echo_alive = False
                if log_error is None:
                    try:
                        log.write(chunk)
                        log.flush()
                    except OSError as error:
                        log_error = error
        except KeyboardInterrupt:
            process.terminate()
        code = process.wait()

    if code < 0:
        return 128 - code
    if code == 0 and log_error is not None:
        print(f"::error::記録を書き切れなかった: {log_error}", file=sys.stderr)
        return 1
    return code


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="コマンドを流して出力を記録に残す")
    parser.add_argument("--log", required=True, help="出力を残すファイル")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="-- に続けて、流すコマンド")
    args = parser.parse_args(argv)

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("流すコマンドを -- の後ろに指定する")
    return run(command, args.log)


if __name__ == "__main__":
    sys.exit(main())
