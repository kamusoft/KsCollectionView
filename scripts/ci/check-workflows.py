#!/usr/bin/env python3
"""workflow の定義が、道具の固定と権限の決まりを守っているかを確かめる。

確かめること (cross/ADR-0013 の検証 CI が前提にする決まり):
  1. 外部の action と再利用 workflow は、commit の ID (40 桁の 16 進数) で指定する。
     タグやブランチの名前は後から付け替えられるので使わない。
     同じリポジトリの中の指定 (`./` で始まる) は対象にしない
  2. ランナーは版を指定した名前で選ぶ。最新を指す名前 (`latest` を含む名前) と、
     版を読み取れない選び方 (式・ランナーのグループ・`self-hosted` のように版の番号を
     持たない名前) は使わない。版は、名前を `-` で区切った 2 つ目より後ろの、数字と `.` だけの
     部分として読む (`ubuntu-24.04`・`xcode-27`・`macos-15-xlarge`)
  3. 権限は、リポジトリの内容の読み取りだけにする。workflow の先頭で `permissions` を明示し、
     中身は `contents: read` だけ (または空、値が `none` の項目) にする。ジョブごとの指定も同じ
  4. ランナーの上で step を走らせるジョブ (`runs-on` を持つジョブ) は、時間の上限
     (`timeout-minutes`) を 1 以上の整数で持つ。式で書いた上限と、整数でない値は、
     上限を確かめられないので使わない。値の大小は見ない。
     再利用 workflow を呼ぶだけのジョブ (`uses` を持つジョブ) は `timeout-minutes` を書けないので
     対象にしない (呼ばれる側のジョブが上限を持つ)

使い方:
  python3 scripts/ci/check-workflows.py [--root <ディレクトリ>] [<workflow のファイル>...]

  ファイルを省くと、--root (既定は作業ディレクトリ) の下の .github/workflows/*.yml と *.yaml を
  すべて確かめる。ファイルを渡すと、そのファイルだけを確かめる。

終了コード:
  0  違反が無い
  1  違反がある / 確かめる workflow が 1 本も無い / 読み取れない書き方がある
  2  引数の誤り

  違反は「ファイル:行: 内容」の形で 1 件ずつ示す。

読み取れる書き方:
  YAML のうち、workflow でふつうに使う形だけを読む (標準のライブラリに YAML の読み取りが無いため)。
  次の書き方は、検査をすり抜ける経路になるので、違反として止める:
  複数行にまたがる `{...}` や `[...]`、中身のある `{...}`、アンカーとエイリアス (`&` `*` `<<`)、
  行頭のタブ、閉じていない引用符。
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ci_report  # noqa: E402

KEY_VALUE = re.compile(r"""^(?P<key>"[^"]*"|'[^']*'|[^\s:#"'\[\]{}&*!|>-][^:]*?|-[^\s:][^:]*?)\s*:(?:\s+(?P<value>.*))?$""")
BLOCK_SCALAR = re.compile(r"^[|>](?:[+-]?\d?|\d[+-]?)$")
PINNED_ACTION = re.compile(r"^[\w.-]+/[\w.-]+(?:/[^@\s]+)?@[0-9a-f]{40}$")
PINNED_IMAGE = re.compile(r"^docker://\S+@sha256:[0-9a-f]{64}$")
RUNNER_VERSION = re.compile(r"^\d+(?:\.\d+)*$")
TIMEOUT_MINUTES = re.compile(r"^[1-9]\d*$")


@dataclass(frozen=True)
class Problem:
    path: str
    line: int
    message: str

    def render(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


@dataclass(frozen=True)
class Node:
    """読み取った 1 行。key が None なら、並びの要素として書かれた値だけの行。"""

    line: int
    # 入れ子の位置を表すキーの並び (自分のキーを含む)。並びの要素であることは含めない。
    path: tuple[str, ...]
    key: str | None
    # 値。同じ行に値が無い (入れ子が続く、または複数行の文字列) なら None。
    value: str | None


def strip_comment(line: str) -> str:
    """引用符の外にあるコメントを取り除く。"""
    quote = ""
    for index, char in enumerate(line):
        if quote:
            if char == quote:
                quote = ""
            continue
        if char in "\"'":
            quote = char
        elif char == "#" and (index == 0 or line[index - 1] in " \t"):
            return line[:index]
    return line


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def unsupported_value(value: str) -> str | None:
    """読み取れない書き方の値なら、その説明を返す。"""
    if value[0] in "&*":
        return "アンカーとエイリアスは読み取れない"
    if value[0] == "{" and value != "{}":
        return "中身のある `{...}` は読み取れない (1 行に 1 項目ずつ書く)"
    if value[0] == "[" and not value.endswith("]"):
        return "複数行にまたがる `[...]` は読み取れない"
    if value[0] in "\"'" and (len(value) < 2 or value[-1] != value[0]):
        return "閉じていない引用符は読み取れない"
    return None


def parse(path: str, text: str) -> tuple[list[Node], list[Problem]]:
    """workflow の本文を、キーの入れ子の位置つきの行の並びにする。"""
    nodes: list[Node] = []
    problems: list[Problem] = []
    # (キーの桁, キー) の積み重ね。今の行より桁が浅いものだけが親として残る。
    stack: list[tuple[int, str]] = []
    # 複数行の文字列 (`|` `>`) の中にいる間、その始まりのキーの桁。中身はこれより深い桁に書かれる。
    block_indent: int | None = None

    for number, raw in enumerate(text.splitlines(), start=1):
        if block_indent is not None:
            body = raw.strip()
            if not body or len(raw) - len(raw.lstrip(" ")) > block_indent:
                continue
            block_indent = None

        leading = raw[: len(raw) - len(raw.lstrip(" \t"))]
        content = strip_comment(raw).rstrip()
        if not content.strip():
            continue
        if "\t" in leading:
            problems.append(Problem(path, number, "行頭のタブは読み取れない"))
            continue
        indent = len(content) - len(content.lstrip(" "))
        text_part = content.strip()
        if text_part in ("---", "..."):
            continue

        line_indent = indent
        while text_part == "-" or text_part.startswith("- "):
            rest = text_part[1:]
            indent += 1 + (len(rest) - len(rest.lstrip(" ")))
            text_part = rest.strip()
        if not text_part:
            continue

        while stack and stack[-1][0] >= indent:
            stack.pop()
        parents = tuple(key for _, key in stack)

        matched = KEY_VALUE.match(text_part)
        if not matched:
            reason = unsupported_value(text_part)
            if reason:
                problems.append(Problem(path, number, reason))
            elif BLOCK_SCALAR.match(text_part):
                block_indent = line_indent
            else:
                nodes.append(Node(number, parents, None, unquote(text_part)))
            continue

        key = unquote(matched.group("key"))
        value = matched.group("value")
        value = value.strip() if value is not None else None
        if key == "<<":
            problems.append(Problem(path, number, "アンカーとエイリアスは読み取れない"))
            continue
        if value:
            reason = unsupported_value(value)
            if reason:
                problems.append(Problem(path, number, reason))
                continue
            if BLOCK_SCALAR.match(value):
                block_indent = indent
                value = None
        else:
            value = None
        stack.append((indent, key))
        nodes.append(Node(number, parents + (key,), key, value))
    return nodes, problems


def values_of(nodes: list[Node], owner: Node) -> list[tuple[int, str]]:
    """キーの値を (行, 値) の並びで返す。1 行の値・`[a, b]`・並びの要素のどれで書かれていても読む。"""
    if owner.value is not None:
        if owner.value.startswith("["):
            inner = owner.value[1:-1]
            return [(owner.line, unquote(part)) for part in inner.split(",") if part.strip()]
        return [(owner.line, unquote(owner.value))]
    return [
        (node.line, node.value)
        for node in nodes
        if node.key is None and node.path == owner.path and node.line > owner.line and node.value is not None
    ]


def children_of(nodes: list[Node], owner: Node) -> list[Node]:
    """キーの直下のキーを返す。"""
    found = []
    for node in nodes:
        if node.line <= owner.line or node.key is None:
            continue
        if node.path == owner.path:
            # 同じ位置に同じ名前のキーがもう一度現れたら、そこから先は別の入れ子。
            break
        if node.path[:-1] == owner.path:
            found.append(node)
    return found


def check_uses(path: str, node: Node) -> list[Problem]:
    value = unquote(node.value or "")
    if not value:
        return [Problem(path, node.line, "uses の指定が空である")]
    if value.startswith("./"):
        return []
    if value.startswith("docker://"):
        if PINNED_IMAGE.match(value):
            return []
        return [Problem(path, node.line, f"外部のイメージをダイジェストで指定していない: {value}")]
    if PINNED_ACTION.match(value):
        return []
    return [Problem(path, node.line, f"外部の action を commit の ID で指定していない: {value}")]


def check_runner_labels(path: str, job: str, labels: list[tuple[int, str]], line: int) -> list[Problem]:
    if not labels:
        return [Problem(path, line, f"ジョブ {job}: ランナーの指定を読み取れない")]
    problems = []
    for label_line, label in labels:
        if "${{" in label:
            problems.append(
                Problem(path, label_line, f"ジョブ {job}: ランナーを式で選んでいるため、版を確かめられない: {label}")
            )
        elif "latest" in label.lower():
            problems.append(
                Problem(path, label_line, f"ジョブ {job}: 最新を指す名前でランナーを選んでいる: {label}")
            )
        elif not any(RUNNER_VERSION.match(part) for part in label.split("-")[1:]):
            problems.append(
                Problem(path, label_line, f"ジョブ {job}: 版を読み取れない名前でランナーを選んでいる: {label}")
            )
    return problems


def check_runs_on(path: str, nodes: list[Node], node: Node) -> list[Problem]:
    job = node.path[1]
    children = children_of(nodes, node)
    if not children:
        return check_runner_labels(path, job, values_of(nodes, node), node.line)
    problems = []
    labels_seen = False
    for child in children:
        if child.key == "labels":
            labels_seen = True
            problems += check_runner_labels(path, job, values_of(nodes, child), child.line)
        elif child.key == "group":
            problems.append(
                Problem(path, child.line, f"ジョブ {job}: ランナーのグループで選んでいるため、版を確かめられない")
            )
        else:
            problems.append(Problem(path, child.line, f"ジョブ {job}: ランナーの指定を読み取れない: {child.key}"))
    if not labels_seen and not problems:
        problems.append(Problem(path, node.line, f"ジョブ {job}: ランナーの指定を読み取れない"))
    return problems


def check_permissions(path: str, nodes: list[Node], node: Node) -> list[Problem]:
    where = "workflow" if len(node.path) == 1 else f"ジョブ {node.path[1]}"
    if node.value is not None:
        if node.value == "{}":
            return []
        return [
            Problem(path, node.line, f"{where}: リポジトリの内容の読み取り以外の権限がある: permissions: {node.value}")
        ]
    problems = []
    for child in children_of(nodes, node):
        value = unquote(child.value or "")
        if value == "none" or (child.key == "contents" and value == "read"):
            continue
        problems.append(
            Problem(path, child.line, f"{where}: リポジトリの内容の読み取り以外の権限がある: {child.key}: {value or '(空)'}")
        )
    return problems


def check_timeout(path: str, nodes: list[Node], runs_on: Node) -> list[Problem]:
    """ランナーの上で走るジョブが、時間の上限を読み取れる形で持っているかを確かめる。"""
    job = runs_on.path[1]
    owner = runs_on.path[:2]
    timeouts = [node for node in nodes if node.path == owner + ("timeout-minutes",)]
    if not timeouts:
        line = min(node.line for node in nodes if node.path[:2] == owner)
        return [Problem(path, line, f"ジョブ {job}: 時間の上限 (timeout-minutes) が無い")]
    problems = []
    for node in timeouts:
        value = node.value or ""
        if "${{" in value:
            problems.append(
                Problem(path, node.line, f"ジョブ {job}: 時間の上限を式で書いているため、上限を確かめられない: {value}")
            )
        elif not TIMEOUT_MINUTES.match(value):
            problems.append(
                Problem(path, node.line, f"ジョブ {job}: 時間の上限を 1 以上の整数として読み取れない: {value or '(空)'}")
            )
    return problems


def check_text(path: str, text: str) -> tuple[list[Problem], dict[str, int]]:
    """workflow 1 本の本文を確かめる。違反と、確かめた箇所の数を返す。"""
    nodes, problems = parse(path, text)
    counts = {"uses": 0, "runs-on": 0, "permissions": 0}

    jobs = sorted({node.path[1] for node in nodes if len(node.path) >= 2 and node.path[0] == "jobs"})
    if not jobs:
        problems.append(Problem(path, 1, "ジョブを 1 つも読み取れない (workflow の定義として読めない)"))

    top_level_permissions = False
    for node in nodes:
        if node.key is None:
            continue
        if node.path == ("permissions",):
            top_level_permissions = True
            counts["permissions"] += 1
            problems += check_permissions(path, nodes, node)
        elif len(node.path) == 3 and node.path[0] == "jobs" and node.key == "permissions":
            counts["permissions"] += 1
            problems += check_permissions(path, nodes, node)
        elif len(node.path) == 3 and node.path[0] == "jobs" and node.key == "runs-on":
            counts["runs-on"] += 1
            problems += check_runs_on(path, nodes, node)
            problems += check_timeout(path, nodes, node)
        elif node.key == "uses" and node.path[0] == "jobs" and (
            len(node.path) == 3 or (len(node.path) == 4 and node.path[2] == "steps")
        ):
            counts["uses"] += 1
            problems += check_uses(path, node)

    if not top_level_permissions:
        problems.append(
            Problem(path, 1, "workflow の先頭に permissions の指定が無い (リポジトリの既定の権限が使われる)")
        )

    for job in jobs:
        keys = {node.key for node in nodes if len(node.path) == 3 and node.path[:2] == ("jobs", job)}
        if "runs-on" not in keys and "uses" not in keys:
            line = min(node.line for node in nodes if node.path[:2] == ("jobs", job))
            problems.append(Problem(path, line, f"ジョブ {job}: runs-on も uses も読み取れない"))

    return sorted(problems, key=lambda problem: problem.line), counts


def discover(root: str) -> list[str]:
    directory = os.path.join(glob.escape(root), ".github", "workflows")
    return sorted(glob.glob(os.path.join(directory, "*.yml")) + glob.glob(os.path.join(directory, "*.yaml")))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="workflow の定義を確かめる")
    parser.add_argument("--root", default=".", help="リポジトリのルート (既定は作業ディレクトリ)")
    parser.add_argument("files", nargs="*", help="確かめる workflow のファイル (省くと全部)")
    args = parser.parse_args(argv)

    files = args.files or discover(args.root)
    if not files:
        ci_report.emit_errors(["確かめる workflow が 1 本も無い (.github/workflows の下に *.yml / *.yaml が無い)"])
        return 1

    problems: list[Problem] = []
    totals = {"uses": 0, "runs-on": 0, "permissions": 0}
    for path in files:
        display = os.path.relpath(path, args.root) if not args.files else path
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except (OSError, UnicodeDecodeError) as error:
            problems.append(Problem(display, 1, f"workflow のファイルを読めない: {error}"))
            continue
        found, counts = check_text(display, text)
        problems += found
        for name, count in counts.items():
            totals[name] += count

    print(
        f"確かめた workflow: {len(files)} 本 (uses {totals['uses']} 箇所 / runs-on {totals['runs-on']} 箇所"
        f" / permissions {totals['permissions']} 箇所)"
    )
    if problems:
        for problem in problems:
            print(problem.render())
        ci_report.emit_errors([problem.render() for problem in problems])
        return 1
    print("違反は無い")
    return 0


if __name__ == "__main__":
    sys.exit(main())
