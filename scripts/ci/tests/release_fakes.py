"""リリースの道具のテストが共有する、偽の相手と道具。

外部 (Central Portal・Maven Central・GitHub) の代わりに、127.0.0.1 で待ち受ける偽の HTTP サーバを
立てる。テストは本物の外部へ通信しない。
"""

from __future__ import annotations

import dataclasses
import http.server
import json
import os
import subprocess
import threading
import urllib.parse
from collections.abc import Callable
from unittest import mock

import support

RELEASE_DIR = os.path.join(support.REPOSITORY_ROOT, "scripts", "release")

# 偽のサーバへの通信が、手元の proxy の設定で外へ向かわないようにする。
NO_PROXY = {"no_proxy": "127.0.0.1,localhost", "NO_PROXY": "127.0.0.1,localhost"}


def load(name: str):
    return support.load_script(name, RELEASE_DIR)


@dataclasses.dataclass
class Request:
    method: str
    path: str
    query: dict[str, str]
    headers: dict[str, str]


# 応答: (状態, 本文)。本文は bytes・str・JSON にできる値のどれか。
Response = tuple[int, object]


class FakeServer:
    """handler(Request) -> Response で応答する偽の HTTP サーバ。受けた要求を requests に残す。

    with で使う。入っている間、url が待ち受け先を指す。
    """

    def __init__(self, handler: Callable[[Request], Response]):
        self.handler = handler
        self.requests: list[Request] = []
        self._server = None
        self._thread = None
        self._environment = None

    def __enter__(self) -> FakeServer:
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def _respond(self):
                parsed = urllib.parse.urlsplit(self.path)
                request = Request(
                    self.command,
                    parsed.path,
                    dict(urllib.parse.parse_qsl(parsed.query)),
                    {key: value for key, value in self.headers.items()},
                )
                fake.requests.append(request)
                status, body = fake.handler(request)
                if isinstance(body, (dict, list, bool)):
                    payload = json.dumps(body).encode()
                elif isinstance(body, str):
                    payload = body.encode()
                else:
                    payload = body or b""
                self.send_response(status)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            do_GET = do_POST = do_DELETE = do_PUT = _respond

            def log_message(self, *arguments):  # 標準エラー出力を汚さない。
                pass

        self._server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self._thread = threading.Thread(target=self._server.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
        self._thread.start()
        self._environment = mock.patch.dict(os.environ, NO_PROXY)
        self._environment.start()
        return self

    def __exit__(self, *exc_info):
        self._environment.stop()
        self._server.shutdown()
        self._server.server_close()
        self._thread.join()

    @property
    def url(self) -> str:
        host, port = self._server.server_address
        return f"http://{host}:{port}"

    def requests_to(self, method: str, path_prefix: str = "") -> list[Request]:
        return [request for request in self.requests if request.method == method and request.path.startswith(path_prefix)]


def git(directory: str, *arguments: str) -> str:
    """使い捨てのリポジトリで git を呼ぶ。利用者の設定 (署名・hook の雛形など) を読ませない。"""
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update({"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull})
    result = subprocess.run(
        [
            "git", "-C", directory,
            "-c", "user.name=test", "-c", "user.email=test@example.com",
            "-c", "init.defaultBranch=main", "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false",
            *arguments,
        ],
        capture_output=True,
        text=True,
        env=environment,
        check=True,
    )
    return result.stdout.strip()


def pom_text(version: str, commit: str | None, group: str = "jp.kamusoft", artifact: str = "kscollectionview") -> str:
    tag = f"\n    <tag>{commit}</tag>" if commit else ""
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<project xmlns="http://maven.apache.org/POM/4.0.0">\n'
        "  <modelVersion>4.0.0</modelVersion>\n"
        f"  <groupId>{group}</groupId>\n"
        f"  <artifactId>{artifact}</artifactId>\n"
        f"  <version>{version}</version>\n"
        "  <scm>\n"
        "    <url>https://github.com/kamusoft/KsCollectionView</url>"
        f"{tag}\n"
        "  </scm>\n"
        "</project>\n"
    )
