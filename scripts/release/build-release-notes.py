#!/usr/bin/env python3
"""リリースノートを、main に入った Pull Request の本文の変更の節から組み立てる (cross/ADR-0023)。

リリースの workflow の最初のジョブが、run の中で 1 回だけ呼ぶ。組み立てたノートはファイルに書き、
workflow が artifact に置いて、Release の本文に使う (Pull Request の本文は読み直さない)。

範囲:
  公開済みの Release (draft でないもの) の tag のうち、起動した commit から main の first-parent を
  辿って最初に当たるものから、起動した commit までに main に入った Pull Request のすべて。
  そういう Release が無ければ、main の最初から。今回の版と同じ名前の Release は起点に使わない
  (Release を作った後の再実行で、範囲が空にならないようにするため)。
  Pull Request は、マージした commit (merge_commit_sha) が範囲の first-parent の commit に
  含まれるものを、宛先が main の閉じた Pull Request から選ぶ。

変更の節の読み方:
  - 本文の改行を揃え、注釈 (HTML のコメント) を除いてから読む
  - 節は `## Changes` の行の次から、次の `## ` で始まる行の前 (無ければ本文の終わり) まで
  - 空の行は読まない。残った行は、どれも `- <種類>: <説明>` (種類は breaking・feature・fix・docs、
    説明は空でない) か、節全体が `- none` の 1 行だけでなければならない

次のどれかに当たる Pull Request があれば、どの Pull Request のどの行かをすべて示して止まる:
  節が無い / 節が 2 つ以上ある / 節が空 / 読めない行がある (見出し・地の文・知らない種類・説明が空) /
  `- none` とほかの行が混ざっている

組み立て:
  種類ごとに見出しを分け、breaking・feature・fix・docs の順に並べる。同じ種類の中は、main に
  入った順と節の中の行の順。各行の末尾に Pull Request の番号を添える。範囲のすべての
  Pull Request が `- none` なら (範囲に Pull Request が無いときも)、利用者向けの変更が無いことを
  示す 1 行にする。

起動したのが main でないとき (--ref が refs/heads/main でない) は、何も読まずに組み立てを飛ばす
(main 以外からの dry-run)。

使い方:
  python3 scripts/release/build-release-notes.py --version <版> --output <ノートのファイル>
      [--commit <ID>] [--ref <ref>] [--repository <owner/name>] [--api-url <URL>]
      [--repository-root <ディレクトリ>]

  省いた引数は環境変数から読む: --commit は GITHUB_SHA、--ref は GITHUB_REF、--repository は
  GITHUB_REPOSITORY、--api-url は GITHUB_API_URL (無ければ https://api.github.com)。
  GitHub の API には、環境変数 GITHUB_TOKEN があればその token で認証する (Release の一覧と
  Pull Request の一覧を読むだけで、書き込みはしない)。
  --repository-root (既定はこのリポジトリ) で git を呼び、first-parent の履歴と Release の tag を読む。
  作業ツリーには、起動した commit までの履歴と tag が要る (actions/checkout なら fetch-depth: 0)。

GitHub Actions の step の出力 (環境変数 GITHUB_OUTPUT のファイル):
  built=<true|false>  組み立てたか (main 以外からの起動なら false)
  notes-file=<パス>   組み立てたノートのファイル (built が true のときだけ)

終了コード:
  0  組み立てた / main 以外からの起動なので飛ばした
  1  範囲の Pull Request に読めない変更の節がある / 履歴や API を読めない
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import sys
import urllib.parse

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))

CHANGES_HEADING = "## Changes"
# 種類と、ノートでの見出し。並びがノートの並びになる。
KINDS = {
    "breaking": "Breaking changes",
    "feature": "Features",
    "fix": "Fixes",
    "docs": "Documentation",
}
NO_CHANGES_LINE = "No user-facing changes in this release."
ENTRY_PATTERN = re.compile(r"- (?P<kind>[a-z]+):(?P<description>.*)")
NONE_LINE = "- none"
COMMENT_PATTERN = re.compile(r"<!--.*?-->", re.DOTALL)
PAGE_SIZE = 100
# ページを辿る数の上限。応答が壊れていて終わらないときの備え。
MAX_PAGES = 50


@dataclasses.dataclass(frozen=True)
class PullRequest:
    number: int
    body: str
    merge_commit: str


@dataclasses.dataclass(frozen=True)
class Entry:
    kind: str
    description: str
    number: int


# ---- 変更の節 ----


def parse_changes(body: str) -> tuple[list[tuple[str, str]] | None, list[str]]:
    """本文の変更の節を読む。

    (行の一覧, 問題の一覧) を返す。行の一覧は (種類, 説明) の並びで、`- none` の節なら空の並び。
    問題があるときの行の一覧は None。
    """
    text = COMMENT_PATTERN.sub("", (body or "").replace("\r\n", "\n").replace("\r", "\n"))
    lines = text.split("\n")
    heading_indexes = [index for index, line in enumerate(lines) if line.rstrip() == CHANGES_HEADING]
    if not heading_indexes:
        return None, [f"変更の節 ({CHANGES_HEADING}) が無い"]
    if len(heading_indexes) > 1:
        return None, [f"変更の節 ({CHANGES_HEADING}) が {len(heading_indexes)} つある"]

    section = []
    for line in lines[heading_indexes[0] + 1 :]:
        if line.startswith("## "):
            break
        if line.strip():
            section.append(line.rstrip())
    if not section:
        return None, ["変更の節が空 (注釈と空の行しか無い)"]

    if NONE_LINE in section:
        if section == [NONE_LINE]:
            return [], []
        return None, [f"変更の節で `{NONE_LINE}` とほかの行が混ざっている"]

    entries = []
    problems = []
    for line in section:
        match = ENTRY_PATTERN.fullmatch(line)
        if match is None or match.group("kind") not in KINDS:
            problems.append(f"読めない行: {line!r} (`- <種類>: <説明>`、種類は {'・'.join(KINDS)})")
            continue
        description = match.group("description").strip()
        if not description:
            problems.append(f"説明の無い行: {line!r}")
            continue
        entries.append((match.group("kind"), description))
    if problems:
        return None, problems
    return entries, []


def render_notes(entries: list[Entry]) -> str:
    if not entries:
        return NO_CHANGES_LINE + "\n"
    blocks = []
    for kind, title in KINDS.items():
        lines = [f"- {entry.description} (#{entry.number})" for entry in entries if entry.kind == kind]
        if lines:
            blocks.append("\n".join([f"### {title}", "", *lines]))
    return "\n\n".join(blocks) + "\n"


def build_notes(pull_requests: list[PullRequest]) -> str:
    """範囲の Pull Request からノートを組み立てる。読めない節があれば ReleaseError。"""
    entries = []
    problems = []
    for pull_request in pull_requests:
        parsed, found = parse_changes(pull_request.body)
        if found:
            problems.extend(f"Pull Request #{pull_request.number}: {problem}" for problem in found)
            continue
        entries.extend(Entry(kind, description, pull_request.number) for kind, description in parsed)
    if problems:
        raise support.ReleaseError("\n".join(problems))
    return render_notes(entries)


# ---- 範囲 ----


def first_parent_commits(repository_root: str, commit: str) -> list[str]:
    """commit から first-parent を辿った commit の並び (新しい順、commit 自身を含む)。"""
    output = support.run_git(repository_root, "rev-list", "--first-parent", commit).stdout
    return output.split()


def tag_commit(repository_root: str, tag: str) -> str:
    result = support.run_git(repository_root, "rev-parse", "--verify", "--quiet", f"refs/tags/{tag}^{{commit}}", check=False)
    if result.returncode != 0:
        raise support.ReleaseError(
            f"Release の tag {tag} が作業ツリーに無い (履歴と tag をすべて取得してから流す。actions/checkout なら fetch-depth: 0)"
        )
    return result.stdout.strip()


def range_commits(repository_root: str, commit: str, release_tags: list[str]) -> tuple[list[str], str | None]:
    """範囲の first-parent の commit (古い順) と、起点にした Release の tag (無ければ None) を返す。"""
    chain = first_parent_commits(repository_root, commit)
    positions = {sha: index for index, sha in enumerate(chain)}
    start_tag = None
    start_index = len(chain)
    for tag in release_tags:
        index = positions.get(tag_commit(repository_root, tag))
        if index is not None and index < start_index:
            start_index = index
            start_tag = tag
    return list(reversed(chain[:start_index])), start_tag


# ---- GitHub の API ----


class GitHubApi:
    def __init__(self, api_url: str, repository: str, token: str | None):
        self.base = f"{api_url.rstrip('/')}/repos/{repository}"
        self.headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if token:
            self.headers["Authorization"] = f"Bearer {token}"

    def pages(self, path: str, query: dict[str, str]) -> list[dict]:
        items = []
        for page in range(1, MAX_PAGES + 1):
            parameters = urllib.parse.urlencode({**query, "per_page": str(PAGE_SIZE), "page": str(page)})
            url = f"{self.base}/{path}?{parameters}"
            try:
                response = support.http_request("GET", url, headers=self.headers)
            except support.TransportError as error:
                raise support.ReleaseError(f"GitHub の API を読めない: {error}") from error
            if response.status != 200:
                raise support.ReleaseError(f"GitHub の API を読めない: GET {url} が {response.status} を返した")
            try:
                chunk = json.loads(response.body)
            except json.JSONDecodeError as error:
                raise support.ReleaseError(f"GitHub の API の応答を読めない: GET {url}: {error}") from error
            if not isinstance(chunk, list):
                raise support.ReleaseError(f"GitHub の API の応答が一覧でない: GET {url}")
            items.extend(chunk)
            if len(chunk) < PAGE_SIZE:
                return items
        raise support.ReleaseError(f"GitHub の API の {path} の一覧が {MAX_PAGES} ページを超えた")

    def published_release_tags(self) -> list[str]:
        return [release["tag_name"] for release in self.pages("releases", {}) if not release.get("draft")]

    def merged_pull_requests(self) -> list[dict]:
        items = self.pages("pulls", {"state": "closed", "base": "main"})
        return [item for item in items if item.get("merged_at") and item.get("merge_commit_sha")]


def collect_pull_requests(api: GitHubApi, repository_root: str, commit: str, version: str) -> tuple[list[PullRequest], str | None]:
    """範囲の Pull Request を main に入った順に返す。あわせて起点の Release の tag を返す。"""
    release_tags = [tag for tag in api.published_release_tags() if tag != version]
    commits, start_tag = range_commits(repository_root, commit, release_tags)
    order = {sha: index for index, sha in enumerate(commits)}
    selected = [
        PullRequest(item["number"], item.get("body") or "", item["merge_commit_sha"])
        for item in api.merged_pull_requests()
        if item["merge_commit_sha"] in order
    ]
    selected.sort(key=lambda pull_request: order[pull_request.merge_commit])
    return selected, start_tag


# ---- 入口 ----


def main(argv: list[str] | None = None) -> int:
    env = os.environ
    parser = argparse.ArgumentParser(description="リリースノートを組み立てる")
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", required=True, help="ノートを書くファイル")
    parser.add_argument("--commit", default=env.get("GITHUB_SHA", ""))
    parser.add_argument("--ref", default=env.get("GITHUB_REF", ""))
    parser.add_argument("--repository", default=env.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--api-url", default=env.get("GITHUB_API_URL") or "https://api.github.com")
    parser.add_argument("--repository-root", default=REPOSITORY_ROOT)
    args = parser.parse_args(argv)

    try:
        if args.ref != support.MAIN_BRANCH_REF:
            print(f"main 以外からの起動 (ref: {args.ref or '不明'}) なので、リリースノートを組み立てない")
            support.write_outputs({"built": "false"})
            return 0
        for problem in (support.check_version(args.version), support.check_commit(args.commit)):
            if problem:
                raise support.ReleaseError(problem)
        if not args.repository:
            raise support.ReleaseError("リポジトリ (owner/name) が分からない。--repository か GITHUB_REPOSITORY で渡す")

        api = GitHubApi(args.api_url, args.repository, env.get("GITHUB_TOKEN"))
        pull_requests, start_tag = collect_pull_requests(api, args.repository_root, args.commit, args.version)
        notes = build_notes(pull_requests)

        output = os.path.abspath(args.output)
        os.makedirs(os.path.dirname(output), exist_ok=True)
        with open(output, "w", encoding="utf-8") as f:
            f.write(notes)
        numbers = ", ".join(f"#{pull_request.number}" for pull_request in pull_requests) or "なし"
        support.emit_summary(
            [
                f"## リリースノート ({args.version})",
                "",
                f"範囲の起点: {start_tag or 'main の最初'} / Pull Request: {numbers}",
                "",
                notes.rstrip("\n"),
            ]
        )
        support.write_outputs({"built": "true", "notes-file": output})
    except support.ReleaseError as error:
        support.emit_errors(str(error).splitlines())
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
