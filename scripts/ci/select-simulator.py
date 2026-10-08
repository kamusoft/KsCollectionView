#!/usr/bin/env python3
"""テストに使う iOS Simulator を選ぶ。

使える iPhone の Simulator のうち、OS の版が最も新しいものを 1 つ選び、その UDID を標準出力に出す。
機種の名前はランナーのイメージの更新で変わるので、名前を決め打ちにせず、実行のときにある中から選ぶ。

使い方:
  python3 scripts/ci/select-simulator.py                    # xcrun simctl の一覧から選ぶ
  python3 scripts/ci/select-simulator.py --catalog <file>   # 保存済みの一覧 (JSON) から選ぶ

  --catalog  `xcrun simctl list devices available --json` の出力を保存したファイル。
             省くと、このスクリプトが同じコマンドを実行して読む

出力:
  標準出力      選んだ Simulator の UDID (1 行)
  標準エラー出力  選んだ機種の名前と OS の版、または失敗の理由

  例: udid=$(python3 scripts/ci/select-simulator.py)
      xcodebuild test -destination "platform=iOS Simulator,id=${udid}" ...

終了コード:
  0  選べた
  1  使える iPhone の Simulator が無い / 一覧を取得できない・読めない
  2  引数の誤り

同じ版の iPhone が複数あるときは、名前の順で最初のものを選ぶ (実行ごとに結果が変わらないようにするため)。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass

RUNTIME_IOS = re.compile(r"\.iOS-(\d+(?:-\d+)*)$")


@dataclass(frozen=True)
class Simulator:
    version: tuple[int, ...]
    name: str
    udid: str


def candidates(catalog: dict) -> list[Simulator]:
    """一覧から、使える iPhone の Simulator を取り出す。"""
    found: list[Simulator] = []
    devices_by_runtime = catalog.get("devices")
    if not isinstance(devices_by_runtime, dict):
        return found
    for runtime, devices in devices_by_runtime.items():
        matched = RUNTIME_IOS.search(runtime)
        if not matched or not isinstance(devices, list):
            continue
        version = tuple(int(part) for part in matched.group(1).split("-"))
        for device in devices:
            if not isinstance(device, dict):
                continue
            name = device.get("name", "")
            udid = device.get("udid", "")
            # isAvailable の無い古い形式は使えないものとして扱う (使えると決めつけない)。
            if device.get("isAvailable") is not True:
                continue
            if not name.startswith("iPhone") or not udid:
                continue
            found.append(Simulator(version, name, udid))
    return found


def select(catalog: dict) -> Simulator | None:
    """OS の版が最も新しい iPhone を返す。無ければ None。"""
    found = candidates(catalog)
    if not found:
        return None
    newest = max(simulator.version for simulator in found)
    return min(
        (simulator for simulator in found if simulator.version == newest),
        key=lambda simulator: (simulator.name, simulator.udid),
    )


def load_catalog(path: str | None) -> dict:
    """一覧を読む。読めないときは ValueError を投げる。"""
    if path is None:
        try:
            completed = subprocess.run(
                ["xcrun", "simctl", "list", "devices", "available", "--json"],
                check=False,
                capture_output=True,
                text=True,
            )
        except OSError as error:
            raise ValueError(f"xcrun を実行できない: {error}") from error
        if completed.returncode != 0:
            raise ValueError(
                f"Simulator の一覧の取得が終了コード {completed.returncode} で失敗した: "
                + completed.stderr.strip()
            )
        text = completed.stdout
    else:
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except OSError as error:
            raise ValueError(f"一覧のファイルを読めない: {error}") from error
    try:
        catalog = json.loads(text)
    except json.JSONDecodeError as error:
        raise ValueError(f"Simulator の一覧を JSON として読めない: {error}") from error
    if not isinstance(catalog, dict):
        raise ValueError("Simulator の一覧が想定した形でない")
    return catalog


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="テストに使う iOS Simulator を選ぶ")
    parser.add_argument("--catalog", help="simctl の一覧 (JSON) を保存したファイル")
    args = parser.parse_args(argv)

    try:
        catalog = load_catalog(args.catalog)
    except ValueError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1

    chosen = select(catalog)
    if chosen is None:
        print("::error::使える iPhone の Simulator が見つからない", file=sys.stderr)
        return 1

    version = ".".join(str(part) for part in chosen.version)
    print(f"選んだ Simulator: {chosen.name} (iOS {version})", file=sys.stderr)
    print(chosen.udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
