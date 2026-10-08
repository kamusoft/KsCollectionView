#!/usr/bin/env python3
"""main 宛ての Pull Request の出どころを確かめる。

main に入るのは、同じリポジトリの develop の内容だけに限る (cross/ADR-0010)。
ブランチの保護は宛先しか縛らないので、出どころはこのスクリプトで確かめる。
ブランチの名前だけを見ると、別のリポジトリ (fork) の同じ名前のブランチも通ってしまうため、
出どころのリポジトリも確かめる。

使い方:
  python3 scripts/ci/check-pr-head.py [--event-name <名前>] [--base-ref <ブランチ>]
      [--head-ref <ブランチ>] [--repository <owner/name>] [--head-repository <owner/name>]

  引数を省くと、次の環境変数から読む。値はシェルに直に展開せず、環境変数で渡す
  (ブランチの名前にはシェルの特殊文字が入り得る)。

  引数                 環境変数                   workflow で渡す値
  --event-name         GITHUB_EVENT_NAME          (ランナーが設定する)
  --base-ref           GITHUB_BASE_REF            (ランナーが設定する)
  --head-ref           GITHUB_HEAD_REF            (ランナーが設定する)
  --repository         GITHUB_REPOSITORY          (ランナーが設定する)
  --head-repository    KS_PR_HEAD_REPOSITORY      github.event.pull_request.head.repo.full_name

終了コード:
  0  確認が通った / 確認の対象でない (push での起動、main 以外に宛てた Pull Request など)
  1  出どころが別のリポジトリ / 出どころが develop でない / 出どころを読み取れない
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ci_report  # noqa: E402

PROTECTED_BASE = "main"
ALLOWED_HEAD = "develop"


def judge(
    event_name: str,
    base_ref: str,
    head_ref: str,
    repository: str,
    head_repository: str,
) -> tuple[bool, str]:
    """(確認が通ったか, 理由または結果の説明) を返す。"""
    if not event_name.startswith("pull_request"):
        return True, f"Pull Request での起動ではないため、出どころは確かめない (起動: {event_name or '不明'})"
    if base_ref != PROTECTED_BASE:
        return True, f"{PROTECTED_BASE} 宛ての Pull Request ではないため、出どころは確かめない (宛先: {base_ref or '不明'})"
    if not repository or not head_repository or not head_ref:
        return False, (
            f"{PROTECTED_BASE} 宛ての Pull Request の出どころを読み取れない"
            f" (リポジトリ: {repository or '空'} / 出どころのリポジトリ: {head_repository or '空'}"
            f" / 出どころのブランチ: {head_ref or '空'})"
        )
    if head_repository != repository:
        return False, (
            f"{PROTECTED_BASE} 宛ての Pull Request の出どころが別のリポジトリである"
            f" (出どころ: {head_repository} / 受け付けるのは {repository} のブランチだけ)"
        )
    if head_ref != ALLOWED_HEAD:
        return False, (
            f"{PROTECTED_BASE} 宛ての Pull Request の出どころが {ALLOWED_HEAD} でない"
            f" (出どころ: {head_ref})"
        )
    return True, f"出どころは {repository} の {ALLOWED_HEAD}"


def main(argv: list[str] | None = None) -> int:
    env = os.environ
    parser = argparse.ArgumentParser(description="main 宛ての Pull Request の出どころを確かめる")
    parser.add_argument("--event-name", default=env.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--base-ref", default=env.get("GITHUB_BASE_REF", ""))
    parser.add_argument("--head-ref", default=env.get("GITHUB_HEAD_REF", ""))
    parser.add_argument("--repository", default=env.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--head-repository", default=env.get("KS_PR_HEAD_REPOSITORY", ""))
    args = parser.parse_args(argv)

    passed, message = judge(
        args.event_name, args.base_ref, args.head_ref, args.repository, args.head_repository
    )
    if passed:
        print(message)
        return 0
    ci_report.emit_errors([message])
    return 1


if __name__ == "__main__":
    sys.exit(main())
