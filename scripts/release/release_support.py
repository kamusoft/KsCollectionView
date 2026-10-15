"""リリースの道具 (scripts/release/) が共有する部品。

版の形・配布物の座標・GitHub Actions への出力・HTTP の呼び出し・上限つきの待ち・POM の読み取り・
git の呼び出し・SwiftPM の写しの作成と中身の比べ方を置く。どれも Python の標準のライブラリだけで書く。
"""

from __future__ import annotations

import dataclasses
import http.client
import os
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ElementTree
from collections.abc import Callable

# 版の形 (cross/ADR-0021)。semver の X.Y.Z か、プレリリースの X.Y.Z-alpha.N・-beta.N・-rc.N (N は 1 以上)。
# プレリリースの語を 3 つに絞るのは、Maven の版の比較で正式版より前に並ぶ語だけを使うためである。
# 数の頭に 0 を付けた形 (01.2.3 など) は semver に合わないので受け付けない。
VERSION_PATTERN = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(alpha|beta|rc)\.[1-9][0-9]*)?")
VERSION_FORMS = "X.Y.Z か X.Y.Z-alpha.N・X.Y.Z-beta.N・X.Y.Z-rc.N (N は 1 以上)"

# commit の ID の形 (git の SHA-1 の 40 桁の小文字の 16 進)。
COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")

# 配布物の座標 (cross/ADR-0003・cross/ADR-0015)。
MAVEN_GROUP = "jp.kamusoft"
MAVEN_ARTIFACT = "kscollectionview"
MAIN_BRANCH_REF = "refs/heads/main"
SPM_REPOSITORY_URL = "https://github.com/kamusoft/KsCollectionView-SPM.git"

# Maven Central の取得先。認証なしで読める。
MAVEN_CENTRAL_URL = "https://repo1.maven.org/maven2"

POM_NAMESPACE = "{http://maven.apache.org/POM/4.0.0}"

# git の作業の場所を外から固定する環境変数。hook の中などから呼ばれると設定されていて、
# -C で指したディレクトリではなく、呼び出し元のリポジトリを読んでしまう。
GIT_LOCATION_VARIABLES = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_COMMON_DIR",
    "GIT_PREFIX",
    "GIT_NAMESPACE",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
)


class ReleaseError(Exception):
    """道具が失敗で終わる理由。メッセージはそのまま利用者に見せる。"""


def check_version(version: str) -> str | None:
    """版が決めた形なら None、違えば理由を返す。"""
    if VERSION_PATTERN.fullmatch(version):
        return None
    return f"版の形が違う: {version!r} (受け付ける形: {VERSION_FORMS})"


def check_commit(commit: str) -> str | None:
    """commit の ID が 40 桁の小文字の 16 進なら None、違えば理由を返す。"""
    if COMMIT_PATTERN.fullmatch(commit):
        return None
    return f"commit の ID の形が違う: {commit!r} (40 桁の小文字の 16 進で渡す)"


def parse_bool(value: str, name: str) -> bool:
    """workflow の入力の真偽 ("true" / "false") を読む。それ以外は誤りにする。"""
    if value == "true":
        return True
    if value == "false":
        return False
    raise ReleaseError(f"{name} は true か false で渡す (渡された値: {value!r})")


def artifact_directory(maven_repository: str, version: str) -> str:
    """Maven のリポジトリ (ディレクトリ) の中の、その版の発行物の置き場。"""
    return os.path.join(maven_repository, *MAVEN_GROUP.split("."), MAVEN_ARTIFACT, version)


def artifact_url(maven_url: str, version: str, suffix: str) -> str:
    """Maven のリポジトリ (URL) の中の、その版のファイルの URL。suffix は ".pom" など。"""
    group_path = MAVEN_GROUP.replace(".", "/")
    return f"{maven_url.rstrip('/')}/{group_path}/{MAVEN_ARTIFACT}/{version}/{MAVEN_ARTIFACT}-{version}{suffix}"


# ---- GitHub Actions への出力 ----


def write_outputs(values: dict[str, str]) -> None:
    """step の出力を、環境変数 GITHUB_OUTPUT が指すファイルに書く。無ければ標準出力にだけ出す。

    値は 1 行に限る (複数行の書き方を使わず、値に改行が混ざった誤りを止める)。
    """
    lines = []
    for key, value in values.items():
        if "\n" in value or "\r" in value:
            raise ReleaseError(f"step の出力 {key} に改行が入っている")
        lines.append(f"{key}={value}")
    for line in lines:
        print(f"出力: {line}")
    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as f:
            f.write("".join(line + "\n" for line in lines))
    sys.stdout.flush()


def emit_errors(messages: list[str]) -> None:
    """失敗の理由を、GitHub Actions が注釈として拾う形で 1 件 1 行ずつ出す。"""
    for message in messages:
        print("::error::" + " ".join(message.splitlines()))
    sys.stdout.flush()


def emit_summary(lines: list[str]) -> None:
    """概要を標準出力に出し、環境変数 GITHUB_STEP_SUMMARY が指すファイルがあれば追記する。"""
    text = "\n".join(lines) + "\n"
    sys.stdout.write(text)
    sys.stdout.flush()
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(text + "\n")


# ---- HTTP ----


class TransportError(Exception):
    """相手に届かなかった・応答を受け取れなかった。応答の状態は分からない。"""


@dataclasses.dataclass(frozen=True)
class HttpResponse:
    status: int
    body: bytes
    headers: dict[str, str]

    def text(self) -> str:
        return self.body.decode("utf-8", errors="replace")


def http_request(
    method: str,
    url: str,
    headers: dict[str, str] | None = None,
    data: bytes | None = None,
    timeout: float = 60.0,
) -> HttpResponse:
    """HTTP で 1 回呼ぶ。状態が 4xx・5xx でも例外にせず、応答として返す。

    相手に届かない・時間内に応答が無いときは TransportError を投げる。
    """
    request = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return HttpResponse(response.status, response.read(), dict(response.headers.items()))
    except urllib.error.HTTPError as error:
        body = error.read() if error.fp is not None else b""
        return HttpResponse(error.code, body, dict(error.headers.items()) if error.headers else {})
    except (urllib.error.URLError, http.client.HTTPException, socket.timeout, TimeoutError, ConnectionError) as error:
        raise TransportError(f"{method} {url} に届かない: {error}") from error


# ---- 上限つきの待ち ----


class WaitTimeout(ReleaseError):
    """待ちの上限に達した。"""


def wait_until(
    probe: Callable[[], tuple[bool, object]],
    timeout_seconds: float,
    interval_seconds: float,
    description: str,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> object:
    """probe が (True, 値) を返すまで、間を空けて呼び直す。上限に達したら WaitTimeout を投げる。

    probe は (終わったか, 値) を返す。終わっていないときの値は、上限に達したときの理由に載せる。
    上限は、最初の呼び出しの前に決める。呼び出しや待ちに時間がかかっても、上限を過ぎた後に
    もう一度待つことはない。
    """
    if timeout_seconds <= 0:
        raise ReleaseError(f"{description}の待ちの上限は 0 より大きくする (渡された値: {timeout_seconds} 秒)")
    if interval_seconds <= 0:
        raise ReleaseError(f"{description}の問い合わせの間隔は 0 より大きくする (渡された値: {interval_seconds} 秒)")
    deadline = clock() + timeout_seconds
    attempts = 0
    while True:
        attempts += 1
        done, value = probe()
        if done:
            return value
        remaining = deadline - clock()
        if remaining <= 0:
            raise WaitTimeout(
                f"{description}が上限 ({format_duration(timeout_seconds)}) までに終わらなかった"
                f" (問い合わせ {attempts} 回、最後の状態: {value})"
            )
        sleep(min(interval_seconds, remaining))


def format_duration(seconds: float) -> str:
    if seconds >= 60 and seconds % 60 == 0:
        return f"{int(seconds // 60)} 分"
    return f"{seconds:g} 秒"


def minutes_to_seconds(value: str, name: str) -> float:
    """引数の分 (小数を含む) を秒にする。0 以下や数でない値は誤りにする。"""
    try:
        minutes = float(value)
    except ValueError as error:
        raise ReleaseError(f"{name} は分の数で渡す (渡された値: {value!r})") from error
    if minutes <= 0:
        raise ReleaseError(f"{name} は 0 より大きくする (渡された値: {value!r})")
    return minutes * 60


# ---- POM ----


def read_pom(text: str) -> dict[str, str | None]:
    """POM から、座標と scm の tag (元になった commit) を読む。読めなければ ReleaseError。"""
    try:
        root = ElementTree.fromstring(text)
    except ElementTree.ParseError as error:
        raise ReleaseError(f"POM を XML として読めない: {error}") from error

    # Gradle が書く POM は名前空間つき。名前空間の無い POM も同じように読む。
    namespace = POM_NAMESPACE if root.tag.startswith(POM_NAMESPACE) else ""

    def find(*names: str) -> str | None:
        element = root
        for name in names:
            element = element.find(namespace + name)
            if element is None:
                return None
        if element.text is None:
            return None
        return element.text.strip()

    return {
        "groupId": find("groupId"),
        "artifactId": find("artifactId"),
        "version": find("version"),
        "scmTag": find("scm", "tag"),
    }


# ---- git ----


def git_environment(isolated: bool = False) -> dict[str, str]:
    environment = {key: value for key, value in os.environ.items() if key not in GIT_LOCATION_VARIABLES}
    # 対話の入力 (認証の問い合わせ) を待って止まらないようにする。
    environment["GIT_TERMINAL_PROMPT"] = "0"
    if isolated:
        # 利用者とランナーの設定 (改行の変換・除外の指定など) を読ませない。
        environment["GIT_CONFIG_GLOBAL"] = os.devnull
        environment["GIT_CONFIG_SYSTEM"] = os.devnull
    return environment


def run_git(directory: str, *arguments: str, check: bool = True, isolated: bool = False) -> subprocess.CompletedProcess:
    """directory で git を呼ぶ。check が真で失敗したら ReleaseError。

    isolated が真なら、利用者とランナーの git の設定を読まない (中身を比べるときに、設定で結果が
    変わらないようにするため)。
    """
    result = subprocess.run(
        ["git", "-C", directory, *arguments],
        capture_output=True,
        text=True,
        env=git_environment(isolated),
    )
    if check and result.returncode != 0:
        raise ReleaseError(f"git {' '.join(arguments)} が失敗した: {result.stderr.strip()}")
    return result


def remote_tag_commit(directory: str, remote: str, tag: str) -> str | None:
    """remote の tag が指す commit を返す。tag が無ければ None。注釈つきの tag は commit まで辿る。"""
    result = run_git(directory, "ls-remote", "--tags", remote, f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}", check=False)
    if result.returncode != 0:
        raise ReleaseError(f"{remote} の tag を読めない: {result.stderr.strip()}")
    direct = peeled = None
    for line in result.stdout.splitlines():
        object_id, _, ref = line.partition("\t")
        if ref == f"refs/tags/{tag}":
            direct = object_id
        elif ref == f"refs/tags/{tag}^{{}}":
            peeled = object_id
    return peeled or direct


# ---- SwiftPM の写し ----

# 写しを作る道具の、リポジトリのルートからの場所。
SNAPSHOT_SCRIPT = os.path.join("scripts", "distribution", "sync-spm-snapshot.py")


def build_snapshot(repository_root: str, destination: str) -> None:
    """repository_root の作業ツリーから、配信用リポジトリの写しを destination に作る。"""
    result = subprocess.run(
        [sys.executable, os.path.join(repository_root, SNAPSHOT_SCRIPT), destination],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ReleaseError(f"写しを作れない: {(result.stdout + result.stderr).strip()}")


def tree_of_directory(directory: str) -> str:
    """ディレクトリの中身を git の tree にしたときの ID を返す (中身を比べるため)。

    directory の中に git の管理情報を作るので、比べるためだけに作った写しに使う。
    """
    run_git(directory, "init", "--quiet", isolated=True)
    run_git(directory, "add", "--all", isolated=True)
    return run_git(directory, "write-tree", isolated=True).stdout.strip()
