#!/usr/bin/env python3
"""Maven Central の取得先に、その版の発行物が現れるまで待つ。

Central Portal で公開済み (PUBLISHED) になってから、利用者が取得する先 (repo1.maven.org) に
現れるまでには時間がかかる。この道具は、その版の POM・Gradle のモジュールの情報 (.module)・AAR が
どれも取得できる (200) まで、間を空けて問い合わせる。

上限に達したら失敗で終わる。上限の既定は 120 分。届かない・404・5xx は「まだ現れていない」として
問い合わせを続ける。

--commit を渡すと、現れた POM の scm の tag (元になった commit) がその commit であることも確かめる。
違えば失敗で終わる。リリースの workflow は、公開の後の確認と、公開のジョブで Central Portal が
公開済みと答えたのに取得先にまだ POM が無いとき (公開の直後の再実行) の、両方で使う。

使い方:
  python3 scripts/release/wait-for-maven-central.py --version <版> [--commit <ID>]
      [--timeout-minutes 120] [--interval-seconds 60] [--maven-url <URL>]

  --maven-url の既定は https://repo1.maven.org/maven2。

secret は要らない。step の出力は無い。

終了コード:
  0  発行物が現れた (--commit を渡したときは、commit も合っていた)
  1  上限までに現れなかった / POM の commit が違う・書かれていない
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

DEFAULT_TIMEOUT_MINUTES = "120"
DEFAULT_INTERVAL_SECONDS = 60.0
WATCHED_SUFFIXES = (".pom", ".module", ".aar")


def probe_files(maven_url: str, version: str):
    """取得先を 1 回問い合わせる。(すべて現れたか, POM の中身か、まだのときの状況) を返す。"""
    missing = []
    pom_text = None
    for suffix in WATCHED_SUFFIXES:
        url = support.artifact_url(maven_url, version, suffix)
        try:
            response = support.http_request("GET", url)
        except support.TransportError as error:
            missing.append(f"{suffix} (届かない: {error})")
            continue
        if response.status != 200:
            missing.append(f"{suffix} ({response.status})")
            continue
        if suffix == ".pom":
            pom_text = response.text()
    if missing:
        status = "まだ取得できない: " + ", ".join(missing)
        print(status)
        return False, status
    return True, pom_text


def wait_for_release(
    maven_url: str,
    version: str,
    commit: str | None,
    timeout_seconds: float,
    interval_seconds: float,
    clock=None,
    sleep=None,
) -> str:
    """発行物が現れるまで待ち、結果の説明を返す。外れたら ReleaseError。"""
    options = {}
    if clock is not None:
        options["clock"] = clock
    if sleep is not None:
        options["sleep"] = sleep
    pom_text = support.wait_until(
        lambda: probe_files(maven_url, version),
        timeout_seconds,
        interval_seconds,
        f"Maven Central の取得先に版 {version} が現れるの",
        **options,
    )
    if commit is None:
        return f"版 {version} が Maven Central の取得先に現れた"
    source_commit = support.read_pom(pom_text)["scmTag"]
    if not source_commit:
        raise support.ReleaseError(f"版 {version} の POM に、元になった commit (scm の tag) が無い")
    if source_commit != commit:
        raise support.ReleaseError(
            f"版 {version} の POM の元になった commit ({source_commit}) が、起動した commit ({commit}) と違う"
        )
    return f"版 {version} が Maven Central の取得先に現れ、POM の元になった commit は {commit}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Maven Central の取得先に版が現れるまで待つ")
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit")
    parser.add_argument("--timeout-minutes", default=DEFAULT_TIMEOUT_MINUTES)
    parser.add_argument("--interval-seconds", type=float, default=DEFAULT_INTERVAL_SECONDS)
    parser.add_argument("--maven-url", default=support.MAVEN_CENTRAL_URL)
    args = parser.parse_args(argv)

    try:
        for problem in (support.check_version(args.version), args.commit is not None and support.check_commit(args.commit)):
            if problem:
                raise support.ReleaseError(problem)
        timeout = support.minutes_to_seconds(args.timeout_minutes, "--timeout-minutes")
        print(wait_for_release(args.maven_url, args.version, args.commit, timeout, args.interval_seconds))
    except support.ReleaseError as error:
        support.emit_errors(str(error).splitlines())
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
