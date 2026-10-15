#!/usr/bin/env python3
"""Maven Central (Sonatype Central Portal) の Publisher API を操作する。リリースの workflow の公開のジョブが呼ぶ。

Android の発行物は、公開のプラグインが保留 (USER_MANAGED) のまま送る。プラグインは送った後の
検証の決着を待たず、保留の送信を後から公開するタスクも持たないので、送った後の操作はこの道具が
API を直に呼んで行う (cross/ADR-0022)。

コマンド:
  published       その版が公開済みかを API で確かめる (GET /api/v1/publisher/published)
  extract-id      送信のビルドのログから送信の ID (deployment id) を読み、控えのファイルに書く
  inspect         前の試行の控えを読み、その送信の状態から、この試行ですることを決める
  settle          送信の検証の決着 (VALIDATED か FAILED) を待つ。FAILED なら取り下げて失敗で終わる
  publish         検証済みの送信に公開を指示する (公開の処理に入っていれば何もしない)
  wait-published  送信が公開済み (PUBLISHED) になるのを待つ。FAILED なら失敗で終わる (取り下げない)
  drop            保留の送信を取り下げる。公開の処理に入った送信は取り下げない

inspect が決めること (step の出力 action):
  控えが無い                                   upload          新しく送る
  PENDING・VALIDATING・VALIDATED               reuse           送り直さず、その送信の決着を待って公開を指示する
  PUBLISHING                                   wait-published  送り直さず、公開も指示し直さず、公開済みを待つ
  PUBLISHED                                    published       送らず、公開も指示しない
  FAILED・見つからない (取り下げ済み)          upload          控えを使わず、新しく送る

控えのファイル (JSON) は、extract-id が `<控えのディレクトリ>/deployment-<試行の番号>.json` に書く。
inspect は、控えのディレクトリの中で試行の番号がいちばん大きいものを読む。控えは消さない。

使い方:
  python3 scripts/release/central-portal.py published --version <版>
  python3 scripts/release/central-portal.py extract-id --log <ビルドのログ> --version <版>
      --receipts <控えのディレクトリ> [--attempt <試行の番号>]
  python3 scripts/release/central-portal.py inspect --version <版> --receipts <控えのディレクトリ>
  python3 scripts/release/central-portal.py settle --deployment-id <ID> [--timeout-minutes 60]
  python3 scripts/release/central-portal.py publish --deployment-id <ID>
  python3 scripts/release/central-portal.py wait-published --deployment-id <ID> [--timeout-minutes 120]
  python3 scripts/release/central-portal.py drop --deployment-id <ID> [--timeout-minutes 10]

  共通: [--base-url <URL>] (既定は環境変数 KS_CENTRAL_PORTAL_URL、無ければ https://central.sonatype.com)
        [--interval-seconds <秒>] (待つコマンドの問い合わせの間隔。既定 30)
  --attempt を省くと、環境変数 GITHUB_RUN_ATTEMPT (無ければ 1) を使う。

secret: extract-id 以外は、Central Portal の user token を環境変数 KS_CENTRAL_USERNAME・
KS_CENTRAL_PASSWORD で受け取る (Gradle の mavenCentralUsername・mavenCentralPassword と同じ値)。
値は出力に出さない。extract-id は secret を使わず、ネットワークも使わない。

GitHub Actions の step の出力 (環境変数 GITHUB_OUTPUT のファイル):
  published       published=<true|false>
  extract-id      deployment-id=<ID>  receipt=<控えのファイル>
  inspect         action=<upload|reuse|wait-published|published>  deployment-id=<ID>  (控えが無ければ ID は空)
  settle          state=<VALIDATED|PUBLISHING|PUBLISHED>
  publish         state=<PUBLISHING|PUBLISHED>  (指示を受け付けた後の状態。指示の直後は PUBLISHING とする)
  wait-published  state=PUBLISHED
  drop            dropped=<true|false>  (false は、送信が見つからず取り下げるものが無かった)

待つコマンド (settle・wait-published・drop) は上限を持ち、上限に達したら失敗で終わる。
問い合わせが届かない・5xx・429 のときは、上限まで問い合わせを続ける。認証の誤り (401・403) では
すぐに失敗で終わる。

終了コード:
  0  成功
  1  失敗 (検証の失敗・待ちの上限・API の誤り・ログに ID が無い・控えが読めない など)
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import base64
import glob
import json
import os
import re
import sys
import urllib.parse

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

DEFAULT_BASE_URL = "https://central.sonatype.com"
DEFAULT_INTERVAL_SECONDS = 30.0

# 状態の値 (Central Portal の Publisher API)。
PENDING_STATES = ("PENDING", "VALIDATING")
VALIDATED = "VALIDATED"
PUBLISHING = "PUBLISHING"
PUBLISHED = "PUBLISHED"
FAILED = "FAILED"
KNOWN_STATES = (*PENDING_STATES, VALIDATED, PUBLISHING, PUBLISHED, FAILED)
# 見つからない (取り下げ済み) を表す、この道具の中だけの印。
NOT_FOUND = "NOT_FOUND"

# 公開のプラグインが、保留で送った後にログに出す 1 行。
UPLOAD_LINE_PATTERN = re.compile(r"Uploaded bundle to Central Portal as (?P<type>\S+), deployment id: (?P<id>[^\s,]+)")
MANUAL_PUBLISHING_TYPE = "USER_MANAGED"

LEFTOVER_HINT = (
    "Central Portal (https://central.sonatype.com/publishing/deployments) に、この run の保留の送信が"
    "残っていないかを確かめ、残っていれば取り下げる (手順はリリースの手順の文書)"
)


class TransientApiError(support.ReleaseError):
    """問い合わせが届かなかった・一時的な誤り (5xx・429) が返った。待つ処理では問い合わせを続ける。"""


class PortalApi:
    def __init__(self, base_url: str, username: str, password: str, timeout: float = 60.0):
        token = base64.b64encode(f"{username}:{password}".encode()).decode()
        self.base_url = base_url.rstrip("/")
        self.headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
        self.timeout = timeout

    def call(self, method: str, path: str, query: dict[str, str] | None = None) -> support.HttpResponse:
        url = self.base_url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        try:
            response = support.http_request(method, url, headers=self.headers, timeout=self.timeout)
        except support.TransportError as error:
            raise TransientApiError(str(error)) from error
        if response.status in (401, 403):
            raise support.ReleaseError(
                f"Central Portal の認証が通らない ({method} {path} が {response.status})。user token を確かめる"
            )
        if response.status == 429 or response.status >= 500:
            raise TransientApiError(f"{method} {path} が {response.status} を返した: {response.text()[:200]}")
        return response

    def status(self, deployment_id: str) -> tuple[str, dict]:
        """送信の状態と応答の中身を返す。見つからなければ (NOT_FOUND, {})。"""
        response = self.call("POST", "/api/v1/publisher/status", {"id": deployment_id})
        if response.status == 404:
            return NOT_FOUND, {}
        if response.status != 200:
            raise support.ReleaseError(f"送信 {deployment_id} の状態を読めない ({response.status}): {response.text()[:200]}")
        try:
            content = json.loads(response.body)
        except json.JSONDecodeError as error:
            raise support.ReleaseError(f"送信 {deployment_id} の状態の応答を読めない: {error}") from error
        state = content.get("deploymentState")
        if state not in KNOWN_STATES:
            raise support.ReleaseError(f"送信 {deployment_id} の状態が知らない値: {state!r}")
        return state, content

    def published(self, version: str) -> bool:
        query = {"namespace": support.MAVEN_GROUP, "name": support.MAVEN_ARTIFACT, "version": version}
        response = self.call("GET", "/api/v1/publisher/published", query)
        if response.status != 200:
            raise support.ReleaseError(f"公開済みかを確かめられない ({response.status}): {response.text()[:200]}")
        try:
            value = json.loads(response.body).get("published")
        except (json.JSONDecodeError, AttributeError) as error:
            raise support.ReleaseError(f"公開済みかの応答を読めない: {error}") from error
        if not isinstance(value, bool):
            raise support.ReleaseError(f"公開済みかの応答に真偽が無い: {response.text()[:200]}")
        return value

    def publish(self, deployment_id: str) -> support.HttpResponse:
        return self.call("POST", f"/api/v1/publisher/deployment/{urllib.parse.quote(deployment_id)}")

    def drop(self, deployment_id: str) -> support.HttpResponse:
        return self.call("DELETE", f"/api/v1/publisher/deployment/{urllib.parse.quote(deployment_id)}")


def describe_errors(content: dict) -> str:
    errors = content.get("errors")
    if not errors:
        return "(理由の記載なし)"
    return json.dumps(errors, ensure_ascii=False)[:2000]


def wait_for_states(
    api: PortalApi,
    deployment_id: str,
    targets: tuple[str, ...],
    timeout_seconds: float,
    interval_seconds: float,
    description: str,
    clock=None,
    sleep=None,
) -> tuple[str, dict]:
    """送信の状態が targets のどれかになるまで待つ。一時的な誤りでは問い合わせを続ける。"""

    def probe():
        try:
            state, content = api.status(deployment_id)
        except TransientApiError as error:
            return False, f"問い合わせの誤り ({error})"
        if state in targets:
            return True, (state, content)
        print(f"送信 {deployment_id} の状態: {state}")
        return False, state

    options = {}
    if clock is not None:
        options["clock"] = clock
    if sleep is not None:
        options["sleep"] = sleep
    return support.wait_until(probe, timeout_seconds, interval_seconds, description, **options)


# ---- コマンド ----


def command_published(api: PortalApi, version: str) -> dict[str, str]:
    value = api.published(version)
    print(f"版 {version} は Central Portal で{'公開済み' if value else '未公開'}")
    return {"published": "true" if value else "false"}


def command_extract_id(log_path: str, version: str, receipts: str, attempt: str) -> dict[str, str]:
    try:
        with open(log_path, encoding="utf-8", errors="replace") as f:
            log = f.read()
    except OSError as error:
        raise support.ReleaseError(f"送信のビルドのログを読めない: {error}。{LEFTOVER_HINT}") from error
    matches = list(UPLOAD_LINE_PATTERN.finditer(log))
    identifiers = {match.group("id") for match in matches}
    if not identifiers:
        raise support.ReleaseError(f"送信のビルドのログに、送信の ID の行が無い。{LEFTOVER_HINT}")
    if len(identifiers) > 1:
        raise support.ReleaseError(f"送信のビルドのログに、送信の ID が複数ある ({', '.join(sorted(identifiers))})。{LEFTOVER_HINT}")
    types = {match.group("type") for match in matches}
    if types != {MANUAL_PUBLISHING_TYPE}:
        raise support.ReleaseError(
            f"送信が保留 ({MANUAL_PUBLISHING_TYPE}) でない ({', '.join(sorted(types))})。"
            "自動で公開する設定 (mavenCentralAutomaticPublishing) を渡していないかを確かめる"
        )
    if not attempt.isdigit() or int(attempt) < 1:
        raise support.ReleaseError(f"試行の番号が 1 以上の整数でない: {attempt!r}")
    deployment_id = identifiers.pop()
    os.makedirs(receipts, exist_ok=True)
    receipt = os.path.abspath(os.path.join(receipts, f"deployment-{int(attempt)}.json"))
    with open(receipt, "w", encoding="utf-8") as f:
        json.dump({"deploymentId": deployment_id, "version": version, "attempt": int(attempt)}, f)
        f.write("\n")
    print(f"送信の ID: {deployment_id} (控え: {receipt})")
    return {"deployment-id": deployment_id, "receipt": receipt}


def latest_receipt(receipts: str, version: str) -> dict | None:
    """控えのディレクトリの中で、試行の番号がいちばん大きい控えを返す。無ければ None。"""
    found = []
    for path in glob.glob(os.path.join(receipts, "**", "deployment-*.json"), recursive=True):
        try:
            with open(path, encoding="utf-8") as f:
                content = json.load(f)
            attempt = int(content["attempt"])
            deployment_id = str(content["deploymentId"])
            receipt_version = str(content["version"])
        except (OSError, ValueError, KeyError, TypeError) as error:
            raise support.ReleaseError(f"送信の控えを読めない: {path}: {error}") from error
        if receipt_version != version:
            raise support.ReleaseError(f"送信の控えの版 ({receipt_version}) が、今回の版 ({version}) と違う: {path}")
        found.append((attempt, deployment_id, path))
    if not found:
        return None
    attempt, deployment_id, path = max(found)
    return {"attempt": attempt, "deploymentId": deployment_id, "path": path}


def command_inspect(api: PortalApi, version: str, receipts: str) -> dict[str, str]:
    receipt = latest_receipt(receipts, version) if os.path.isdir(receipts) else None
    if receipt is None:
        print("前の試行の送信の控えは無い。新しく送る")
        return {"action": "upload", "deployment-id": ""}
    deployment_id = receipt["deploymentId"]
    try:
        state, _ = api.status(deployment_id)
    except TransientApiError as error:
        raise support.ReleaseError(f"前の試行の送信 {deployment_id} の状態を読めない: {error}") from error
    if state in (*PENDING_STATES, VALIDATED):
        action, note = "reuse", "送り直さず、その送信の決着を待って公開を指示する"
    elif state == PUBLISHING:
        action, note = "wait-published", "送り直さず、公開も指示し直さず、公開済みを待つ"
    elif state == PUBLISHED:
        action, note = "published", "公開済みなので、送らず、公開も指示しない"
    else:
        action, note = "upload", "控えを使わず、新しく送る"
    print(f"前の試行 ({receipt['attempt']} 回目) の送信 {deployment_id} の状態: {state}。{note}")
    return {"action": action, "deployment-id": deployment_id if action != "upload" else ""}


def try_drop(api: PortalApi, deployment_id: str) -> bool:
    """取り下げを 1 回だけ試み、取り下げたかを返す。見つからなければ False。"""
    response = api.drop(deployment_id)
    if response.status in (200, 204):
        return True
    if response.status == 404:
        return False
    raise support.ReleaseError(f"送信 {deployment_id} を取り下げられない ({response.status}): {response.text()[:200]}")


def command_settle(api: PortalApi, deployment_id: str, timeout: float, interval: float) -> dict[str, str]:
    state, content = wait_for_states(
        api, deployment_id, (VALIDATED, FAILED, PUBLISHING, PUBLISHED, NOT_FOUND), timeout, interval,
        f"送信 {deployment_id} の検証の決着",
    )
    if state == NOT_FOUND:
        raise support.ReleaseError(f"送信 {deployment_id} が見つからない (取り下げ済みか、ID の誤り)")
    if state == FAILED:
        reasons = describe_errors(content)
        try:
            dropped = try_drop(api, deployment_id)
            drop_note = "取り下げた" if dropped else "取り下げるものが見つからなかった"
        except support.ReleaseError as error:
            drop_note = f"取り下げに失敗した ({error})。{LEFTOVER_HINT}"
        raise support.ReleaseError(f"送信 {deployment_id} の検証が失敗した: {reasons}。保留の送信は{drop_note}")
    print(f"送信 {deployment_id} の検証の決着: {state}")
    return {"state": state}


def command_publish(api: PortalApi, deployment_id: str) -> dict[str, str]:
    state, _ = api.status(deployment_id)
    if state in (PUBLISHING, PUBLISHED):
        print(f"送信 {deployment_id} は公開の処理に入っている ({state})。公開を指示し直さない")
        return {"state": state}
    if state != VALIDATED:
        raise support.ReleaseError(f"送信 {deployment_id} は検証済みでないので、公開を指示できない (状態: {state})")
    try:
        response = api.publish(deployment_id)
    except TransientApiError as error:
        # 指示が届いたかが分からない。状態を読み直して、公開の処理に入っていれば成功とする。
        state, _ = api.status(deployment_id)
        if state in (PUBLISHING, PUBLISHED):
            print(f"公開の指示の応答を受け取れなかったが、送信 {deployment_id} は公開の処理に入っている ({state})")
            return {"state": state}
        raise support.ReleaseError(f"送信 {deployment_id} に公開を指示できない: {error}") from error
    if response.status not in (200, 204):
        raise support.ReleaseError(f"送信 {deployment_id} に公開を指示できない ({response.status}): {response.text()[:200]}")
    print(f"送信 {deployment_id} に公開を指示した")
    return {"state": PUBLISHING}


def command_wait_published(api: PortalApi, deployment_id: str, timeout: float, interval: float) -> dict[str, str]:
    state, content = wait_for_states(
        api, deployment_id, (PUBLISHED, FAILED, NOT_FOUND), timeout, interval, f"送信 {deployment_id} の公開",
    )
    if state == FAILED:
        raise support.ReleaseError(f"送信 {deployment_id} の公開が失敗した: {describe_errors(content)}")
    if state == NOT_FOUND:
        raise support.ReleaseError(f"送信 {deployment_id} が見つからない (取り下げ済みか、ID の誤り)")
    print(f"送信 {deployment_id} は公開済み")
    return {"state": PUBLISHED}


def command_drop(api: PortalApi, deployment_id: str, timeout: float, interval: float) -> dict[str, str]:
    state, _ = wait_for_states(
        api, deployment_id, (VALIDATED, FAILED, PUBLISHING, PUBLISHED, NOT_FOUND), timeout, interval,
        f"取り下げの前の、送信 {deployment_id} の検証の決着",
    )
    if state == NOT_FOUND:
        print(f"送信 {deployment_id} は見つからない。取り下げるものは無い")
        return {"dropped": "false"}
    if state in (PUBLISHING, PUBLISHED):
        raise support.ReleaseError(f"送信 {deployment_id} は公開の処理に入っている ({state})。取り下げない")
    dropped = try_drop(api, deployment_id)
    print(f"送信 {deployment_id} を{'取り下げた' if dropped else '取り下げようとしたが、見つからなかった'}")
    return {"dropped": "true" if dropped else "false"}


# ---- 入口 ----


def portal_api(base_url: str) -> PortalApi:
    username = os.environ.get("KS_CENTRAL_USERNAME", "")
    password = os.environ.get("KS_CENTRAL_PASSWORD", "")
    if not username or not password:
        raise support.ReleaseError("Central Portal の user token が無い (環境変数 KS_CENTRAL_USERNAME・KS_CENTRAL_PASSWORD)")
    return PortalApi(base_url, username, password)


def main(argv: list[str] | None = None) -> int:
    env = os.environ
    parser = argparse.ArgumentParser(description="Central Portal の Publisher API を操作する")
    parser.add_argument("--base-url", default=env.get("KS_CENTRAL_PORTAL_URL") or DEFAULT_BASE_URL)
    parser.add_argument("--interval-seconds", type=float, default=DEFAULT_INTERVAL_SECONDS)
    commands = parser.add_subparsers(dest="command", required=True)

    published = commands.add_parser("published")
    published.add_argument("--version", required=True)

    extract = commands.add_parser("extract-id")
    extract.add_argument("--log", required=True)
    extract.add_argument("--version", required=True)
    extract.add_argument("--receipts", required=True)
    extract.add_argument("--attempt", default=env.get("GITHUB_RUN_ATTEMPT") or "1")

    inspect = commands.add_parser("inspect")
    inspect.add_argument("--version", required=True)
    inspect.add_argument("--receipts", required=True)

    for name, default_minutes in (("settle", "60"), ("wait-published", "120"), ("drop", "10")):
        waiting = commands.add_parser(name)
        waiting.add_argument("--deployment-id", required=True)
        waiting.add_argument("--timeout-minutes", default=default_minutes)

    publish = commands.add_parser("publish")
    publish.add_argument("--deployment-id", required=True)

    args = parser.parse_args(argv)

    try:
        if getattr(args, "version", None) is not None:
            problem = support.check_version(args.version)
            if problem:
                raise support.ReleaseError(problem)
        if args.interval_seconds <= 0:
            raise support.ReleaseError(f"--interval-seconds は 0 より大きくする (渡された値: {args.interval_seconds})")

        if args.command == "extract-id":
            outputs = command_extract_id(args.log, args.version, args.receipts, args.attempt)
        else:
            api = portal_api(args.base_url)
            if args.command == "published":
                outputs = command_published(api, args.version)
            elif args.command == "inspect":
                outputs = command_inspect(api, args.version, args.receipts)
            elif args.command == "publish":
                outputs = command_publish(api, args.deployment_id)
            else:
                timeout = support.minutes_to_seconds(args.timeout_minutes, "--timeout-minutes")
                handler = {"settle": command_settle, "wait-published": command_wait_published, "drop": command_drop}[args.command]
                outputs = handler(api, args.deployment_id, timeout, args.interval_seconds)
        support.write_outputs(outputs)
    except support.ReleaseError as error:
        support.emit_errors(str(error).splitlines())
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
