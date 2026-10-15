"""利用者向け Skill の追従の記録 (skills/.manifest.json) を読む。

追従の道具 (skills-refresh.py・check-api-coverage.py) が共有する。記録の形は次のとおり。

  version        記録の形の版。今は 1
  syncedCommit   前回追従したときに見た commit の ID (16 進の 40 桁)
  sources        差分を出す対象の一覧。1 件は次の項目を持つ
                   path       リポジトリのルートからの "/" 区切りの相対のパス
                   pages      その源泉が掛かる Skill の 1 枚の一覧。言語とプラットフォームを
                              抜いた、Skill のディレクトリからの相対のパス (SKILL.md・
                              references/paging.md など)。複数に掛かる源泉は、すべてを書く
                   platforms  片方のプラットフォームの Skill にだけ掛かるときに書く
                              (ios・android)。書かなければ、両方に掛かる
                   excluded   Skill に掛からない源泉の、掛からない理由
                 pages と excluded は、どちらか片方だけを書く
  apiExclusions  Skill に載せないと決めた公開の宣言の名前。プラットフォーム (ios・android)
                 ごとの一覧で、1 件は name (名前) と reason (載せない理由) を持つ
"""

from __future__ import annotations

import dataclasses
import json
import os
import re

MANIFEST_PATH = "skills/.manifest.json"
VERSION = 1
PLATFORM_KEYS = ("ios", "android")
COMMIT_ID = re.compile(r"[0-9a-f]{40}")
# 記録のファイルの中の、commit の ID の値。記録の更新は、ここだけを書き換える。
SYNCED_COMMIT_VALUE = re.compile(r'("syncedCommit"\s*:\s*")([^"]*)(")')


class ManifestError(Exception):
    """記録が無い、または決めた形で読めない。メッセージは、そのまま利用者に見せる。"""


@dataclasses.dataclass(frozen=True)
class Source:
    path: str
    # 掛かる Skill の 1 枚。外すと決めた源泉は空。
    pages: tuple[str, ...]
    platforms: tuple[str, ...]
    # 外すと決めた理由。Skill に掛かる源泉は None。
    excluded: str | None

    def describe_pages(self) -> str:
        """掛かる 1 枚を、人が読む 1 行にする。"""
        if self.excluded is not None:
            return f"Skill に掛からない (理由: {self.excluded})"
        pages = "・".join(self.pages)
        if self.platforms != PLATFORM_KEYS:
            pages += f" ({'・'.join(self.platforms)} の Skill だけ)"
        return pages


@dataclasses.dataclass(frozen=True)
class Manifest:
    synced_commit: str
    sources: tuple[Source, ...]
    # プラットフォーム → (名前 → 載せない理由)。
    api_exclusions: dict[str, dict[str, str]]

    def source(self, path: str) -> Source | None:
        for source in self.sources:
            if source.path == path:
                return source
        return None


def manifest_file(root: str) -> str:
    return os.path.join(root, *MANIFEST_PATH.split("/"))


def read_manifest_text(root: str) -> str:
    try:
        with open(manifest_file(root), encoding="utf-8") as f:
            return f.read()
    except OSError as error:
        raise ManifestError(f"追従の記録を読めない: {MANIFEST_PATH} ({error.strerror or error})") from error


def require_text(value: object, what: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ManifestError(f"追従の記録の {what} が、空でない文字列ではない")
    return value


def parse_source(entry: object, index: int) -> Source:
    what = f"sources の {index} 件目"
    if not isinstance(entry, dict):
        raise ManifestError(f"追従の記録の {what} が、項目の組ではない")
    path = require_text(entry.get("path"), f"{what} の path")
    if path.startswith(("/", "./", "../")) or "\\" in path:
        raise ManifestError(f"追従の記録の {what} の path が、リポジトリのルートからの相対のパスではない: {path}")
    unknown = set(entry) - {"path", "pages", "platforms", "excluded"}
    if unknown:
        raise ManifestError(f"追従の記録の {what} ({path}) に、決めていない項目がある: {'・'.join(sorted(unknown))}")
    if ("pages" in entry) == ("excluded" in entry):
        raise ManifestError(f"追従の記録の {what} ({path}) は、pages と excluded のどちらか片方だけを持つ")

    if "excluded" in entry:
        if "platforms" in entry:
            raise ManifestError(f"追従の記録の {what} ({path}) は、Skill に掛からないのに platforms を持つ")
        return Source(path, (), PLATFORM_KEYS, require_text(entry["excluded"], f"{what} ({path}) の excluded"))

    pages = entry["pages"]
    if not isinstance(pages, list) or not pages:
        raise ManifestError(f"追従の記録の {what} ({path}) の pages が、1 件以上の一覧ではない")
    for page in pages:
        require_text(page, f"{what} ({path}) の pages の値")
    if len(set(pages)) != len(pages):
        raise ManifestError(f"追従の記録の {what} ({path}) の pages に、同じ 1 枚が重なっている")
    platforms = entry.get("platforms", list(PLATFORM_KEYS))
    if not isinstance(platforms, list) or not platforms or not set(platforms) <= set(PLATFORM_KEYS):
        raise ManifestError(
            f"追従の記録の {what} ({path}) の platforms が、{'・'.join(PLATFORM_KEYS)} の 1 つ以上の一覧ではない"
        )
    return Source(path, tuple(pages), tuple(key for key in PLATFORM_KEYS if key in platforms), None)


def parse_manifest(text: str) -> Manifest:
    try:
        data = json.loads(text)
    except ValueError as error:
        raise ManifestError(f"追従の記録を JSON として読めない: {MANIFEST_PATH} ({error})") from error
    if not isinstance(data, dict):
        raise ManifestError("追従の記録が、項目の組ではない")
    for field in ("version", "syncedCommit", "sources", "apiExclusions"):
        if field not in data:
            raise ManifestError(f"追従の記録に、項目 {field} が無い")
    if data["version"] != VERSION:
        raise ManifestError(f"追従の記録の version が、この道具の読める版 ({VERSION}) ではない: {data['version']!r}")

    synced_commit = data["syncedCommit"]
    if not isinstance(synced_commit, str) or not COMMIT_ID.fullmatch(synced_commit):
        raise ManifestError("追従の記録の syncedCommit が、16 進の 40 桁の commit の ID ではない")

    entries = data["sources"]
    if not isinstance(entries, list) or not entries:
        raise ManifestError("追従の記録の sources が、1 件以上の一覧ではない")
    sources = tuple(parse_source(entry, index) for index, entry in enumerate(entries, start=1))
    paths = [source.path for source in sources]
    duplicated = sorted({path for path in paths if paths.count(path) > 1})
    if duplicated:
        raise ManifestError(f"追従の記録の sources に、同じパスが重なっている: {'・'.join(duplicated)}")

    raw_exclusions = data["apiExclusions"]
    if not isinstance(raw_exclusions, dict) or set(raw_exclusions) != set(PLATFORM_KEYS):
        raise ManifestError(f"追従の記録の apiExclusions が、{'・'.join(PLATFORM_KEYS)} の 2 つの項目を持つ組ではない")
    exclusions: dict[str, dict[str, str]] = {}
    for key in PLATFORM_KEYS:
        items = raw_exclusions[key]
        if not isinstance(items, list):
            raise ManifestError(f"追従の記録の apiExclusions.{key} が、一覧ではない")
        names: dict[str, str] = {}
        for index, item in enumerate(items, start=1):
            what = f"apiExclusions.{key} の {index} 件目"
            if not isinstance(item, dict) or set(item) != {"name", "reason"}:
                raise ManifestError(f"追従の記録の {what} が、name と reason の 2 つだけを持つ組ではない")
            name = require_text(item["name"], f"{what} の name")
            if name in names:
                raise ManifestError(f"追従の記録の apiExclusions.{key} に、同じ名前が重なっている: {name}")
            names[name] = require_text(item["reason"], f"{what} ({name}) の reason")
        exclusions[key] = names

    return Manifest(synced_commit, sources, exclusions)


def load_manifest(root: str) -> Manifest:
    return parse_manifest(read_manifest_text(root))


def replace_synced_commit(text: str, commit: str) -> str:
    """記録の文面の、commit の ID だけを書き換えた文面を返す。ほかの文字は変えない。"""
    found = SYNCED_COMMIT_VALUE.findall(text)
    if len(found) != 1:
        raise ManifestError("追従の記録の中に、syncedCommit の値がちょうど 1 つ見つからない")
    return SYNCED_COMMIT_VALUE.sub(lambda matched: matched.group(1) + commit + matched.group(3), text)
