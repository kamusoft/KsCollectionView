"""利用者向けの文書 (ルートの README と skills/) の検査が共有する道具。

Markdown を、検査に要る分だけ読む (コードの囲み・見出し・URL)。文法を解く道具は使わない。
許可する URL と内部の言葉の一覧 (user-docs-rules.json) も、ここから読む。
"""

from __future__ import annotations

import dataclasses
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
RULES_PATH = os.path.join(HERE, "user-docs-rules.json")

# 一覧の中で、URL の役割を表す名前。
ROLE_LATEST_VERSION = "latest-version"

HEADING = re.compile(r"^(#{1,6})\s+(\S.*?)\s*$")
FENCE_OPEN = re.compile(r"^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)[^`]*$")
# URL に使われる文字だけを拾う。日本語の文が空白なしで続いていても、そこで切れる。
URL = re.compile(r"https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'*+,;=%{}]+")
# 文の終わりの記号は、URL の一部として扱わない。
URL_TRAILING = ".,;:!?'"


class UsageError(Exception):
    """引数が範囲の外にある。"""


class RulesError(Exception):
    """一覧のデータを読み取れない。"""


@dataclasses.dataclass(frozen=True)
class CodeBlock:
    # 囲みの始まりの行に書かれた言語の名前。無ければ空の文字列。
    language: str
    # 囲みの中身。行ごとに改行で終わる。
    text: str
    # 囲みの始まりの行の番号 (1 始まり)。
    line: int


@dataclasses.dataclass(frozen=True)
class Heading:
    level: int
    title: str
    line: int


@dataclasses.dataclass(frozen=True)
class Document:
    headings: tuple[Heading, ...]
    code_blocks: tuple[CodeBlock, ...]
    # 囲みの外の行。(行の番号, 文面) の並び。
    prose: tuple[tuple[int, str], ...]
    # 閉じていない囲みの、始まりの行の番号。無ければ None。
    unclosed_fence: int | None


@dataclasses.dataclass(frozen=True)
class Rules:
    # 役割 → URL。完全一致で許可する。
    allowed_urls: dict[str, str]
    # 前方一致で許可する、見本の URL の前置き。
    sample_url_prefixes: tuple[str, ...]
    internal_terms: tuple[str, ...]


def require_root(root: str) -> str:
    """リポジトリのルートが実在するディレクトリであることを確かめ、絶対のパスで返す。"""
    if not os.path.isdir(root):
        raise UsageError(f"リポジトリのルートが、実在するディレクトリではない: {root}")
    return os.path.abspath(root)


def read_text(path: str) -> str | None:
    """ファイルを読む。ファイルが無ければ None を返す。"""
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read()


def parse_markdown(text: str) -> Document:
    """見出し・コードの囲み・囲みの外の行に分ける。"""
    headings: list[Heading] = []
    blocks: list[CodeBlock] = []
    prose: list[tuple[int, str]] = []
    # 開いている囲み: (記号, 長さ, 言語, 始まりの行, 中身の行)。
    opened: tuple[str, int, str, int, list[str]] | None = None

    for number, line in enumerate(text.splitlines(), start=1):
        if opened is not None:
            mark, length, language, start, body = opened
            closing = line.strip()
            # 閉じるのは、同じ記号だけでできた、始まりと同じかそれより長い行。
            if len(closing) >= length and set(closing) == {mark}:
                blocks.append(CodeBlock(language, "".join(f"{row}\n" for row in body), start))
                opened = None
            else:
                body.append(line)
            continue
        fence = FENCE_OPEN.match(line)
        if fence:
            opened = (fence.group(1)[0], len(fence.group(1)), fence.group(2), number, [])
            continue
        prose.append((number, line))
        heading = HEADING.match(line)
        if heading:
            headings.append(Heading(len(heading.group(1)), heading.group(2), number))

    return Document(
        headings=tuple(headings),
        code_blocks=tuple(blocks),
        prose=tuple(prose),
        unclosed_fence=opened[3] if opened is not None else None,
    )


def find_urls(text: str) -> list[str]:
    """文面の中の URL を、現れる順に返す。"""
    return [found.group(0).rstrip(URL_TRAILING) for found in URL.finditer(text)]


def load_rules(path: str = RULES_PATH) -> Rules:
    """一覧のデータを読む。形が決めたとおりでなければ RulesError を投げる。"""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as error:
        raise RulesError(f"一覧のデータを読み取れない: {os.path.basename(path)} ({error})") from error

    try:
        allowed = {str(entry["role"]): str(entry["url"]) for entry in data["allowedUrls"]}
        entries = len(data["allowedUrls"])
        prefixes = tuple(str(prefix) for prefix in data["sampleUrlPrefixes"])
        terms = tuple(str(term) for term in data["internalTerms"])
    except (KeyError, TypeError) as error:
        raise RulesError(f"一覧のデータの形が、決めたものと違う: {os.path.basename(path)} ({error!r})") from error

    if len(allowed) != entries:
        raise RulesError("一覧のデータの URL の役割の名前が、重なっている")
    # 空の値は、何でも通す・何にでも当たる決まりになるので、読み込みの時点で止める。
    if not allowed or not all(allowed.values()) or not all(prefixes) or not terms or not all(terms):
        raise RulesError("一覧のデータに、空の値がある (URL・見本の URL の前置き・内部の言葉)")
    return Rules(allowed_urls=allowed, sample_url_prefixes=prefixes, internal_terms=terms)
