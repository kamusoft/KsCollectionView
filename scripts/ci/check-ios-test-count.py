#!/usr/bin/env python3
"""iOS のテストの実行件数を、xcodebuild の出力の記録から確かめる。

テストが 1 件も実行されなくても xcodebuild は成功で終わるので、終了コードだけでは
検証したことにならない (cross/ADR-0013)。このスクリプトは記録の集計の行を読み、
スキップを除いた実行の件数が 1 件以上あることを確かめる。

使い方:
  python3 scripts/ci/check-ios-test-count.py --label <対象の名前> --log <記録のファイル>

  --label  概要と失敗の理由に出す対象の名前 (例: "iOS 本体")
  --log    xcodebuild test の出力を残したファイル (run-logged.py の --log と同じパス)

終了コード:
  0  スキップを除いた実行が 1 件以上ある
  1  記録が無い / 集計の行が無い / 実行が 0 件 / 全件がスキップ
  2  引数の誤り

件数の読み方:
  XCTest は、テストのまとまり (スイート) が終わるたびに
  「Executed N tests, with S tests skipped and F failures (U unexpected) in ...」の行を出す。
  まとまりは入れ子になるので、いちばん外側のまとまりの行だけを足す。外側かどうかは
  「Test Suite '...' started」と「Test Suite '...' passed / failed」の行の対応で決める。
  対応を読み取れない記録では、最後の集計の行を全体の件数として使い、その旨を概要に書く。

  テストの失敗の有無はここでは合否にしない (xcodebuild の終了コードが決める)。
  クラスごとの突き合わせも行わない。
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ci_report  # noqa: E402

SUITE_START = re.compile(r"^\s*Test Suite '.+' started at\b")
SUITE_END = re.compile(r"^\s*Test Suite '.+' (?:passed|failed) at\b")
EXECUTED = re.compile(
    r"^\s*Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?\b"
)


@dataclass
class Tally:
    """記録から読んだ件数。"""

    tests: int = 0
    skipped: int = 0
    failures: int = 0
    # 件数に数えた集計の行 (概要にそのまま出す)。
    lines: list[str] = field(default_factory=list)
    # 記録に集計の行が 1 つでもあったか。
    found: bool = False
    # まとまりの対応を読み取れず、最後の集計の行を使ったか。
    fallback: bool = False

    @property
    def executed(self) -> int:
        """スキップを除いた実行の件数。"""
        return self.tests - self.skipped


def tally_log(text: str) -> Tally:
    """記録の本文から件数を読む。"""
    tally = Tally()
    depth = 0
    # 直前に終わったまとまりが、いちばん外側だったか。集計の行はまとまりの終わりの直後に出る。
    closed_outermost = False
    last: tuple[int, int, int, str] | None = None

    for raw in text.splitlines():
        if SUITE_START.match(raw):
            depth += 1
            closed_outermost = False
            continue
        if SUITE_END.match(raw):
            depth = max(depth - 1, 0)
            closed_outermost = depth == 0
            continue
        matched = EXECUTED.match(raw)
        if not matched:
            continue
        tally.found = True
        counts = (int(matched.group(1)), int(matched.group(2) or 0), int(matched.group(3)))
        last = (*counts, raw.strip())
        if closed_outermost:
            tally.tests += counts[0]
            tally.skipped += counts[1]
            tally.failures += counts[2]
            tally.lines.append(raw.strip())
        closed_outermost = False

    if tally.found and not tally.lines and last is not None:
        tally.tests, tally.skipped, tally.failures = last[0], last[1], last[2]
        tally.lines.append(last[3])
        tally.fallback = True
    return tally


def judge(label: str, tally: Tally | None) -> list[str]:
    """失敗の理由を返す。空なら合格。tally が None のときは記録が無い。"""
    if tally is None:
        return [f"{label}: テストの実行の記録が無いため、実行の件数を確かめられなかった"]
    if not tally.found:
        return [
            f"{label}: 記録に件数の集計の行が無いため、実行の件数を確かめられなかった"
            " (テストが始まる前に止まったか、出力の書式が変わった可能性がある)"
        ]
    if tally.tests == 0:
        return [f"{label}: テストが 1 件も実行されていない"]
    if tally.executed <= 0:
        return [
            f"{label}: スキップを除くと 1 件も実行されていない"
            f" (集計 {tally.tests} 件のうちスキップ {tally.skipped} 件)"
        ]
    return []


def build_summary(label: str, tally: Tally | None, reasons: list[str]) -> list[str]:
    lines = [f"## {label} のテストの実行件数", ""]
    if tally is not None and tally.found:
        lines += [
            "| 集計の件数 | スキップ | スキップを除く実行 | 失敗 |",
            "|---:|---:|---:|---:|",
            f"| {tally.tests} | {tally.skipped} | {tally.executed} | {tally.failures} |",
            "",
            "```",
            *tally.lines,
            "```",
        ]
        if tally.fallback:
            lines += ["", "まとまりの対応を記録から読み取れなかったため、最後の集計の行を全体の件数として使った。"]
    else:
        lines += ["件数を読み取れなかった。"]
    if reasons:
        lines += ["", "### 件数の検査の失敗", ""]
        lines += [f"- {reason}" for reason in reasons]
    return lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="iOS のテストの実行件数を確かめる")
    parser.add_argument("--label", required=True, help="概要と失敗の理由に出す対象の名前")
    parser.add_argument("--log", required=True, help="xcodebuild test の出力を残したファイル")
    args = parser.parse_args(argv)

    tally: Tally | None = None
    if os.path.isfile(args.log):
        # 記録にはビルドの出力も混ざる。文字として読めないバイトがあっても件数は読めるようにする。
        with open(args.log, encoding="utf-8", errors="replace") as f:
            tally = tally_log(f.read())

    reasons = judge(args.label, tally)
    ci_report.emit_summary(build_summary(args.label, tally, reasons))
    ci_report.emit_errors(reasons)
    return 1 if reasons else 0


if __name__ == "__main__":
    sys.exit(main())
