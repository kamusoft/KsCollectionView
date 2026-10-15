#!/usr/bin/env python3
"""リリースの対象の commit に検証 CI の記録が無いとき、直近で検証 CI が成功した commit の成功で
代えてよいかを確かめる。リリースの事前の確認で、手順の文書のコマンドから呼ぶ。

検証 CI は、develop への push のうち、変更したパスが決まったもの (開発の記録など) だけの push では
起動しない。そういう push が develop の先端にあると、対象の commit には検証 CI の記録が無い。
このとき、直近で検証 CI が成功した commit (--base) から対象の commit (--target) までの変更が、
検証 CI を起動しないパスだけなら、その成功で代えてよい。それ以外の変更があれば代えられない。

起動しないパスは、検証 CI の入口 (.github/workflows/ci.yml) の push の paths-ignore を、対象の
commit の版から読む。値を手で写さないので、ci.yml の paths-ignore を変えても判定がずれない。
ci.yml そのものの変更は paths-ignore に入っていないので、代えられない変更として扱われる。

比べるのは、--base と --target の中身の差 (git diff --no-renames) である。検証 CI が確かめた中身と、
リリースする中身の違いを見るためである。名前の変更は、元の名前の削除と新しい名前の追加として扱う。

paths-ignore の書き方は、GitHub の filter pattern のうち、`*` (斜線を含まない任意の文字の並び) と
`**` (斜線を含む任意の文字の並び) だけを読む。ほかの特別な文字 (`?`・`+`・`[`・`]`・先頭の `!`) を
含む pattern があれば、判定を誤らないよう、読めないとして失敗で終わる。

何も書き換えず、何も送らない。git は、ci.yml の読み取り・祖先の関係の確かめ・差の一覧にだけ使う。

使い方:
  python3 scripts/release/check-ci-skipped-changes.py --base <直近で検証 CI が成功した commit>
      --target <対象の commit> [--repository-root <ディレクトリ>]

終了コード:
  0  代えてよい (差がすべて、検証 CI を起動しないパス)
  1  代えられない (起動するパスの変更がある / --base が --target の祖先でない) / 読めなかった
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))
WORKFLOW_PARSER = os.path.join(REPOSITORY_ROOT, "scripts", "ci", "check-workflows.py")
CI_WORKFLOW = ".github/workflows/ci.yml"

# 読む pattern の特別な文字は `*` だけ。ほかの特別な文字を含む pattern は読まない。
UNSUPPORTED_PATTERN = re.compile(r"[?+\[\]]|^!")


def load_parser():
    """workflow の読み取り方を、workflow の定義の検査から読み込む (同じ書き方の範囲だけを読む)。"""
    spec = importlib.util.spec_from_file_location("release_check_workflows", WORKFLOW_PARSER)
    module = importlib.util.module_from_spec(spec)
    # dataclass は、定義したモジュールを sys.modules から引く。
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def ignored_patterns(workflow_text: str) -> list[str]:
    """ci.yml の本文から、push の paths-ignore を読む。読めなければ ReleaseError。"""
    parser = load_parser()
    nodes, problems = parser.parse(CI_WORKFLOW, workflow_text)
    if problems:
        raise support.ReleaseError(f"{CI_WORKFLOW} を読めない: {[problem.render() for problem in problems]}")

    def find(*path: str):
        for node in nodes:
            if node.key is not None and node.path == path:
                return node
        return None

    if find("on", "push", "paths") is not None:
        raise support.ReleaseError(f"{CI_WORKFLOW} の push が paths で絞り込んでいる。この道具は paths-ignore だけを読む")
    owner = find("on", "push", "paths-ignore")
    patterns = [parser.unquote(value) for _, value in parser.values_of(nodes, owner)] if owner is not None else []
    if not patterns:
        raise support.ReleaseError(
            f"{CI_WORKFLOW} の push に paths-ignore が無い (検証 CI は、どの push でも起動するはずである)"
        )
    unsupported = [pattern for pattern in patterns if UNSUPPORTED_PATTERN.search(pattern)]
    if unsupported:
        raise support.ReleaseError(f"{CI_WORKFLOW} の paths-ignore に、読めない形の pattern がある: {unsupported}")
    return patterns


def pattern_to_regex(pattern: str) -> re.Pattern:
    """GitHub の filter pattern (`*` と `**` だけ) を、パス全体に当てる正規表現にする。"""
    parts = []
    for index, chunk in enumerate(pattern.split("**")):
        if index:
            parts.append(".*")
        parts.append("[^/]*".join(re.escape(piece) for piece in chunk.split("*")))
    return re.compile("".join(parts))


def matching_pattern(path: str, patterns: list[str]) -> str | None:
    for pattern in patterns:
        if pattern_to_regex(pattern).fullmatch(path):
            return pattern
    return None


def changed_paths(repository_root: str, base: str, target: str) -> list[str]:
    result = support.run_git(repository_root, "diff", "--no-renames", "--name-only", "-z", base, target, isolated=True)
    return sorted(path for path in result.stdout.split("\0") if path)


def check(repository_root: str, base: str, target: str) -> tuple[list[tuple[str, str]], list[str]]:
    """(起動しないパスの変更と当たった pattern, 起動するパスの変更) を返す。読めなければ ReleaseError。"""
    for name, commit in (("--base", base), ("--target", target)):
        problem = support.check_commit(commit)
        if problem:
            raise support.ReleaseError(f"{name}: {problem}")
        if support.run_git(repository_root, "cat-file", "-e", f"{commit}^{{commit}}", check=False).returncode != 0:
            raise support.ReleaseError(f"{name} の commit ({commit}) が手元に無い (git fetch してから流す)")
    ancestor = support.run_git(repository_root, "merge-base", "--is-ancestor", base, target, check=False)
    if ancestor.returncode != 0:
        raise support.ReleaseError(
            f"検証 CI が成功した commit ({base}) が、対象の commit ({target}) の祖先でない。その成功では代えられない"
        )
    workflow = support.run_git(repository_root, "show", f"{target}:{CI_WORKFLOW}", check=False)
    if workflow.returncode != 0:
        raise support.ReleaseError(f"対象の commit の {CI_WORKFLOW} を読めない: {workflow.stderr.strip()}")
    patterns = ignored_patterns(workflow.stdout)
    skipped, triggering = [], []
    for path in changed_paths(repository_root, base, target):
        pattern = matching_pattern(path, patterns)
        if pattern is None:
            triggering.append(path)
        else:
            skipped.append((path, pattern))
    return skipped, triggering


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="検証 CI の成功を、記録の無い対象の commit に代えてよいかを確かめる")
    parser.add_argument("--base", required=True, help="直近で検証 CI が成功した commit")
    parser.add_argument("--target", required=True, help="対象の commit")
    parser.add_argument("--repository-root", default=REPOSITORY_ROOT)
    args = parser.parse_args(argv)

    try:
        skipped, triggering = check(args.repository_root, args.base, args.target)
    except support.ReleaseError as error:
        support.emit_errors(str(error).splitlines())
        return 1
    for path, pattern in skipped:
        print(f"起動しないパス: {path} ({pattern})")
    if triggering:
        for path in triggering:
            print(f"起動するパス: {path}")
        support.emit_errors(
            [f"{args.base} から {args.target} までに、検証 CI を起動するパスの変更が {len(triggering)} 件ある。代えられない"]
        )
        return 1
    if not skipped:
        print(f"{args.base} と {args.target} の中身に差は無い。検証 CI の成功で代えてよい")
    else:
        print(f"差の {len(skipped)} 件はすべて、検証 CI を起動しないパスである。{args.base} の検証 CI の成功で代えてよい")
    return 0


if __name__ == "__main__":
    sys.exit(main())
