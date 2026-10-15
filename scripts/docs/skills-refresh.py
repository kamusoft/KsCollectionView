#!/usr/bin/env python3
"""利用者向け Skill の追従のために、前回の追従から変わった源泉を出し、追従の記録を更新する。

追従は、オーナーが頼んだときに、プロジェクト内の追従の Skill が、前回追従した commit からの
源泉の差分をもとに行う (cross/ADR-0020)。覚えておくのは、その commit の ID 1 つである。

追従の記録は skills/.manifest.json にある (形は skills_manifest.py の冒頭)。使い方は 2 つ。

status
  記録の commit (syncedCommit) から今の作業ツリーまでの間に変わった源泉と、見直す Skill の
  1 枚を出す。commit していない変更と、まだ追跡していない新しいファイルも数える。
  次の 5 つを、分けて出す。

    変わった源泉              記録の sources にあるパスのうち、内容が変わったもの (足された・
                              消えたものを含む)。掛かる 1 枚をすべて添える。Skill に掛からない
                              と決めた源泉は、理由を添えて出す
    対応の決まっていない源泉  kasane/concepts/ の下の概念の文書 (index.md・log.md・rules.md を
                              除く .md) のうち、記録の sources に無いもの
    名前の変わった源泉        記録にあるパスが無くなり、対応の決まっていない文書の中に、
                              前の内容と半分以上が同じものがあるとき。前の名前と今の名前を出す
    無くなった源泉            記録にあるパスが無くなり、名前の変わった先も見つからないもの
    公開の宣言の増減          本体のソース (ios/Sources/・android/kscollectionview/src/main/) の
                              公開の宣言の行のうち、足された行と消えた行。公開の宣言でない行の
                              変更は出さない

  --diff を付けると、変わった源泉・名前の変わった源泉・無くなった源泉の、差分の本文も出す。
  無くなった源泉は、記録の commit の時点の内容の全行が、消えた行として出る。
  何も書き換えない。記録の commit が手元の履歴に無いときと、記録を読めないときは、失敗で終わる。

record [<commit>]
  記録の commit の ID を、渡した commit (渡さなければ今の先頭の commit) に書き換える。
  書き換えるのは、記録のファイルの中のこの ID だけで、ほかの文字は変えない。
  次のときは、書き換えずに失敗で終わる。
    - 渡した commit が、手元の履歴に無い
    - 対象のパス (記録の sources のパスと、kasane/concepts/ の下の概念の文書) に、commit して
      いない変更がある (追跡していない新しいファイルと、index にだけ残っている変更を含む)。
      記録する commit に入っていない変更が、追従済みの扱いになるのを防ぐためである

公開の宣言の行は、check-api-coverage.py と同じ拾い方 (public_api.py) で拾う。前の内容と今の
内容のそれぞれから宣言の行を拾い、文面で比べる。行の場所が動いただけのものは出ない。
1 行の宣言の名前・引数・型を変えると、前の行が消えた行、今の行が足された行として出る。
複数行にわたる宣言の、続きの行だけを変えたときは出ない (名前のある行が変わらないため)。

git の commit・add・push・tag は行わない。git は、commit の実在・commit の時点の内容・
変わったファイルの一覧を読むためだけに呼ぶ。ネットワークは使わない。

使い方:
  python3 scripts/docs/skills-refresh.py status
  python3 scripts/docs/skills-refresh.py status --diff
  python3 scripts/docs/skills-refresh.py record
  python3 scripts/docs/skills-refresh.py record <commit>
  どちらも、--root <ルート> で別の作業ツリーを指せる (既定は、このリポジトリ)

終了コード:
  0  status: 一覧を出した (変わった源泉があっても 0) / record: 記録を書き換えた
  1  失敗した (理由を標準エラー出力に出す)。status は一覧を出さず、record は記録を変えない
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import difflib
import os
import subprocess
import sys

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))

sys.path.insert(0, HERE)
import public_api  # noqa: E402
import skills_manifest  # noqa: E402

CONCEPTS_ROOT = "kasane/concepts"
# 概念の文書の置き場にあるが、概念の文書ではないファイル (目次・履歴・配置の決まり)。
NON_CONCEPT_NAMES = ("index.md", "log.md", "rules.md")
# 名前の変わった源泉とみなす、前の内容と今の内容の近さの下限。
RENAME_SIMILARITY = 0.5

# git の作業の場所を外から固定する環境変数。hook の中から呼ばれると設定されていて、
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


class RefreshError(Exception):
    """確かめられなかった、または書き換えられなかった。メッセージは、そのまま利用者に見せる。"""


@dataclasses.dataclass(frozen=True)
class ChangedSource:
    source: skills_manifest.Source
    # "変わった"・"足された"・"消えた"。
    change: str
    before: str | None
    after: str | None


@dataclasses.dataclass(frozen=True)
class RenamedSource:
    source: skills_manifest.Source
    new_path: str
    before: str
    after: str


@dataclasses.dataclass(frozen=True)
class Status:
    synced_commit: str
    changed: list[ChangedSource]
    unmapped: list[str]
    renamed: list[RenamedSource]
    # 無くなった源泉。before は記録の commit の時点の内容で、その時点にも無ければ None。
    removed: list[ChangedSource]
    # (パス, 行の文面) の並び。
    added_declarations: list[tuple[str, str]]
    removed_declarations: list[tuple[str, str]]


# ---- git と作業ツリーを読む ----


def run_git(root: str, *arguments: str) -> subprocess.CompletedProcess:
    environment = {key: value for key, value in os.environ.items() if key not in GIT_LOCATION_VARIABLES}
    # 読むだけの呼び出しが、index の書き直しを始めないようにする。
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    try:
        return subprocess.run(
            ["git", "-C", root, *arguments],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=environment,
            check=False,
        )
    except OSError as error:
        raise RefreshError(f"git を実行できない: {error}") from error


def require_repository(root: str) -> None:
    result = run_git(root, "rev-parse", "--show-toplevel")
    if result.returncode != 0:
        raise RefreshError(f"git のリポジトリではない: {root}")
    if os.path.realpath(result.stdout.strip()) != os.path.realpath(root):
        raise RefreshError(f"リポジトリのルートではない (ルートは {result.stdout.strip()}): {root}")


def resolve_commit(root: str, revision: str) -> str | None:
    """revision が手元の履歴の commit を指していれば、その ID (40 桁) を返す。"""
    result = run_git(root, "rev-parse", "--verify", "--quiet", "--end-of-options", f"{revision}^{{commit}}")
    commit = result.stdout.strip()
    return commit if result.returncode == 0 and skills_manifest.COMMIT_ID.fullmatch(commit) else None


def committed_text(root: str, commit: str, path: str) -> str | None:
    """commit の時点の、ファイルの内容を返す。その時点に無ければ None。"""
    result = run_git(root, "show", f"{commit}:{path}")
    return result.stdout if result.returncode == 0 else None


def working_text(root: str, path: str) -> str | None:
    """今の作業ツリーの、ファイルの内容を返す。無ければ None。"""
    full = os.path.join(root, *path.split("/"))
    if not os.path.isfile(full):
        return None
    with open(full, encoding="utf-8") as f:
        return f.read()


def changed_paths(root: str, since: str, pathspecs: list[str]) -> list[str]:
    """since から今の作業ツリーまでの間に、内容が変わった・足された・消えたパスを返す。

    commit していない変更と、追跡していない新しいファイル (無視の指定に当たるものを除く) を含む。
    """
    tracked = run_git(root, "diff", "--name-only", "--no-renames", "-z", since, "--", *pathspecs)
    untracked = run_git(root, "ls-files", "--others", "--exclude-standard", "-z", "--", *pathspecs)
    for result in (tracked, untracked):
        if result.returncode != 0:
            raise RefreshError(f"変わったファイルを調べられない ({result.stderr.strip() or 'git が失敗した'})")
    return sorted({path for path in (tracked.stdout + untracked.stdout).split("\0") if path})


def staged_paths(root: str, pathspecs: list[str]) -> list[str]:
    """index の内容が、今の先頭の commit と違うパスを返す。

    変更を index に載せた後で、作業ツリーだけを commit の内容に戻すと、作業ツリーと commit の
    比較 (changed_paths) には出ない。commit していない変更は、index に残っている。
    """
    result = run_git(root, "diff", "--cached", "--name-only", "--no-renames", "-z", "HEAD", "--", *pathspecs)
    if result.returncode != 0:
        raise RefreshError(f"index に残っている変更を調べられない ({result.stderr.strip() or 'git が失敗した'})")
    return sorted(path for path in result.stdout.split("\0") if path)


def is_concept_document(path: str) -> bool:
    """パスが、概念の文書の置き場の下の、概念の文書を指しているか。"""
    return (
        path.startswith(CONCEPTS_ROOT + "/")
        and path.endswith(".md")
        and path.rsplit("/", 1)[1] not in NON_CONCEPT_NAMES
    )


def concept_documents(root: str) -> list[str]:
    """今の作業ツリーの、概念の文書の一覧を返す。"""
    base = os.path.join(root, *CONCEPTS_ROOT.split("/"))
    found: list[str] = []
    for directory, _, names in os.walk(base):
        for name in names:
            relative = os.path.relpath(os.path.join(directory, name), root).replace(os.sep, "/")
            if is_concept_document(relative):
                found.append(relative)
    return sorted(found)


# ---- status ----


def similarity(before: str, after: str) -> float:
    return difflib.SequenceMatcher(None, before.splitlines(), after.splitlines(), autojunk=False).ratio()


def declaration_changes(root: str, since: str) -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
    """本体のソースの、公開の宣言の行の増減を返す: (足された行, 消えた行)。"""
    roots = [platform.source_root for platform in public_api.PLATFORMS]
    before: list[tuple[str, str]] = []
    after: list[tuple[str, str]] = []
    for path in changed_paths(root, since, roots):
        platform = public_api.platform_for_path(path)
        if platform is None:
            continue
        for text, lines in ((committed_text(root, since, path), before), (working_text(root, path), after)):
            if text is not None:
                lines.extend((path, line) for _, _, line in public_api.extract(platform, path, text).lines())

    # 行の文面で比べる。ファイルの名前だけが変わった宣言は、増減に数えない。
    before_count = collections.Counter(line for _, line in before)
    after_count = collections.Counter(line for _, line in after)
    added_left = after_count - before_count
    removed_left = before_count - after_count
    added: list[tuple[str, str]] = []
    removed: list[tuple[str, str]] = []
    for entries, left, out in ((after, added_left, added), (before, removed_left, removed)):
        for path, line in entries:
            if left[line] > 0:
                left[line] -= 1
                out.append((path, line))
    return added, removed


def compute_status(root: str) -> Status:
    require_repository(root)
    manifest = skills_manifest.load_manifest(root)
    since = resolve_commit(root, manifest.synced_commit)
    if since is None:
        raise RefreshError(
            f"追従の記録の commit が、手元の履歴に無い: {manifest.synced_commit}"
            " (履歴を浅く取得していないか、別のリポジトリの記録でないかを確かめる)。"
            "変わった源泉を調べていない"
        )

    changed: list[ChangedSource] = []
    missing: list[tuple[skills_manifest.Source, str | None]] = []
    for source in manifest.sources:
        before, after = committed_text(root, since, source.path), working_text(root, source.path)
        if after is None:
            missing.append((source, before))
        elif before is None:
            changed.append(ChangedSource(source, "足された", None, after))
        elif before != after:
            changed.append(ChangedSource(source, "変わった", before, after))

    known = {source.path for source in manifest.sources}
    unmapped = [path for path in concept_documents(root) if path not in known]

    renamed: list[RenamedSource] = []
    removed: list[ChangedSource] = []
    for source, before in missing:
        best: tuple[float, str, str] | None = None
        if before is not None:
            for path in unmapped:
                after = working_text(root, path) or ""
                ratio = similarity(before, after)
                if ratio >= RENAME_SIMILARITY and (best is None or ratio > best[0]):
                    best = (ratio, path, after)
        if best is None:
            removed.append(ChangedSource(source, "消えた", before, None))
        else:
            renamed.append(RenamedSource(source, best[1], before or "", best[2]))
            unmapped.remove(best[1])

    added_declarations, removed_declarations = declaration_changes(root, since)
    return Status(since, changed, unmapped, renamed, removed, added_declarations, removed_declarations)


def unified_diff(before: str | None, after: str | None, before_path: str, after_path: str) -> list[str]:
    return [
        line.rstrip("\n")
        for line in difflib.unified_diff(
            (before or "").splitlines(keepends=True),
            (after or "").splitlines(keepends=True),
            fromfile=before_path if before is not None else "/dev/null",
            tofile=after_path if after is not None else "/dev/null",
        )
    ]


def print_status(status: Status, with_diff: bool) -> None:
    print(f"追従の記録の commit: {status.synced_commit}")
    print("比べた範囲: この commit から、今の作業ツリーまで (commit していない変更を含む)")

    print()
    if status.changed:
        print(f"変わった源泉: {len(status.changed)} 件")
        for entry in status.changed:
            print(f"  {entry.source.path} ({entry.change})")
            print(f"    見直す 1 枚: {entry.source.describe_pages()}")
    else:
        print("変わった源泉は無い")

    if status.unmapped:
        print()
        print(f"対応の決まっていない源泉: {len(status.unmapped)} 件 (追従の記録の sources に、掛かる 1 枚か、掛からない理由を足す)")
        for path in status.unmapped:
            print(f"  {path}")
    if status.renamed:
        print()
        print(f"名前の変わった源泉: {len(status.renamed)} 件 (追従の記録の sources のパスを直す)")
        for entry in status.renamed:
            print(f"  {entry.source.path} → {entry.new_path}")
            print(f"    見直す 1 枚: {entry.source.describe_pages()}")
    if status.removed:
        print()
        print(f"無くなった源泉: {len(status.removed)} 件 (追従の記録の sources から外すか、パスを直す)")
        for entry in status.removed:
            print(f"  {entry.source.path}")
            print(f"    掛かっていた 1 枚: {entry.source.describe_pages()}")

    print()
    if status.added_declarations or status.removed_declarations:
        print(
            f"公開の宣言の増減: 足された行 {len(status.added_declarations)} 行"
            f"・消えた行 {len(status.removed_declarations)} 行"
        )
        for path, line in status.removed_declarations:
            print(f"  - {path}: {line}")
        for path, line in status.added_declarations:
            print(f"  + {path}: {line}")
    else:
        print("公開の宣言の増減は無い")

    if with_diff:
        diffs = (
            [unified_diff(entry.before, entry.after, entry.source.path, entry.source.path) for entry in status.changed]
            + [unified_diff(entry.before, entry.after, entry.source.path, entry.new_path) for entry in status.renamed]
            # 記録の commit の時点にも無かった源泉は、出す差分が無い。
            + [
                unified_diff(entry.before, None, entry.source.path, entry.source.path)
                for entry in status.removed
                if entry.before is not None
            ]
        )
        for lines in diffs:
            print()
            for line in lines:
                print(line)


def command_status(root: str, with_diff: bool) -> int:
    print_status(compute_status(root), with_diff)
    return 0


# ---- record ----


def command_record(root: str, revision: str | None) -> int:
    require_repository(root)
    text = skills_manifest.read_manifest_text(root)
    manifest = skills_manifest.parse_manifest(text)

    commit = resolve_commit(root, revision or "HEAD")
    if commit is None:
        raise RefreshError(f"記録する commit が、手元の履歴に無い: {revision or 'HEAD'}。追従の記録は変えていない")

    targets = [source.path for source in manifest.sources] + [CONCEPTS_ROOT]
    dirty = [
        path
        for path in sorted(set(changed_paths(root, "HEAD", targets)) | set(staged_paths(root, targets)))
        if manifest.source(path) is not None or is_concept_document(path)
    ]
    if dirty:
        raise RefreshError(
            "対象のパスに、commit していない変更がある"
            " (追跡していない新しいファイルと、index にだけ残っている変更を含む): "
            + "・".join(dirty)
            + "。先に commit してから、記録を更新する。追従の記録は変えていない"
        )

    updated = skills_manifest.replace_synced_commit(text, commit)
    # 書く前に、書き換えた文面が記録として読めることを確かめる。
    skills_manifest.parse_manifest(updated)
    if updated != text:
        with open(skills_manifest.manifest_file(root), "w", encoding="utf-8", newline="") as f:
            f.write(updated)
    print(f"追従の記録の commit を書き換えた: {manifest.synced_commit} → {commit} ({skills_manifest.MANIFEST_PATH})")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="利用者向け Skill の追従のために、変わった源泉を出し、記録を更新する")
    commands = parser.add_subparsers(dest="command", required=True)
    status = commands.add_parser("status", help="前回の追従から変わった源泉と、見直す Skill の 1 枚を出す")
    status.add_argument("--diff", action="store_true", help="変わった源泉の、差分の本文も出す")
    record = commands.add_parser("record", help="追従の記録の commit を書き換える")
    record.add_argument("commit", nargs="?", help="記録する commit (渡さなければ、今の先頭の commit)")
    for command in (status, record):
        command.add_argument("--root", default=REPOSITORY_ROOT, help="リポジトリのルート (既定は、このリポジトリ)")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.root):
        print(f"エラー: リポジトリのルートが、実在するディレクトリではない: {args.root}", file=sys.stderr)
        return 2
    root = os.path.abspath(args.root)
    try:
        if args.command == "status":
            return command_status(root, args.diff)
        return command_record(root, args.commit)
    except (RefreshError, skills_manifest.ManifestError, OSError) as error:
        print(f"エラー: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
