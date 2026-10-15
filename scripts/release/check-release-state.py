#!/usr/bin/env python3
"""リリースを始めてよいかを、外へ何も送らずに確かめる。リリースの workflow の最初のジョブが呼ぶ。

3 つの確かめを、それぞれ別のコマンドで行う。どれも何も書き換えず、何も送らない。

  inputs     入力の版の形と、起動したブランチ
             - 版は X.Y.Z か X.Y.Z-alpha.N・-beta.N・-rc.N (N は 1 以上) に限る (cross/ADR-0021)
             - 本番 (dry-run でない起動) は main からだけ受け付ける。dry-run はどのブランチからでもよい
  tags       本リポジトリと配信用リポジトリの、版と同じ名前の tag
             - 本リポジトリ: tag が無いか、起動した commit を指していれば続ける (後者は再実行)
             - 配信用リポジトリ: tag が無いか、起動した commit から作った写しと同じ中身
               (git の tree) の commit を指していれば続ける (後者は再実行)
             - どちらかが別のものを指していれば止まる
  published  Maven Central の取得先にある、その版の POM
             - POM が無ければ (404) 未公開として続ける
             - あれば、POM の scm の tag (元になった commit) が起動した commit と同じときだけ続ける
               (再実行)。違う・書かれていない・読めないときは止まる
             - 取得先への反映は公開より遅れることがある。公開の直後の再実行で、ここが未公開と
               判定することがあるので、公開のジョブは送る前に Central Portal の API でもう一度
               確かめる (central-portal.py published)

使い方:
  python3 scripts/release/check-release-state.py inputs --version <版> --dry-run <true|false> [--ref <ref>]
  python3 scripts/release/check-release-state.py tags --version <版> [--commit <ID>]
      [--remote <名前か URL>] [--spm-url <URL>] [--repository-root <ディレクトリ>]
  python3 scripts/release/check-release-state.py published --version <版> [--commit <ID>] [--maven-url <URL>]

  省いた引数は環境変数から読む: --ref は GITHUB_REF、--commit は GITHUB_SHA。
  --remote の既定は origin、--spm-url の既定は配信用リポジトリ、--maven-url の既定は repo1.maven.org。
  tags は --repository-root (既定はこのリポジトリ) で git を呼び、配信用リポジトリの tag があるときは、
  その作業ツリーから写しを作る (scripts/distribution/sync-spm-snapshot.py)。作業ツリーの HEAD は
  --commit と同じでなければならない。

GitHub Actions の step の出力 (環境変数 GITHUB_OUTPUT のファイル):
  inputs     version=<版>  production=<true|false>  on-main=<true|false>
  tags       main-tag=<absent|matches>  spm-tag=<absent|matches>
  published  published=<true|false>

secret は要らない。ネットワークは tags (git の ls-remote と fetch) と published (HTTP の GET) が使う。

終了コード:
  0  確かめが通った (続けてよい)
  1  確かめが外れた / 読めなかった (止まる)
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import os
import sys
import tempfile

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))


# ---- inputs ----


def check_inputs(version: str, dry_run: str, ref: str) -> dict[str, str]:
    """入力を確かめて、step の出力を返す。外れたら ReleaseError。"""
    problems = []
    version_problem = support.check_version(version)
    if version_problem:
        problems.append(version_problem)
    production = False
    try:
        production = not support.parse_bool(dry_run, "dry-run")
    except support.ReleaseError as error:
        problems.append(str(error))
    on_main = ref == support.MAIN_BRANCH_REF
    if production and not on_main:
        problems.append(
            f"本番 (dry-run でない起動) は main からだけ受け付ける (起動した ref: {ref or '不明'})。"
            " 公開しない試しなら dry-run を true にして起動する"
        )
    if problems:
        raise support.ReleaseError("\n".join(problems))
    return {
        "version": version,
        "production": "true" if production else "false",
        "on-main": "true" if on_main else "false",
    }


# ---- tags ----


# 写しの作り方と中身の比べ方は、公開のジョブが写しを置くとき (place-spm-snapshot.py) と同じものを使う。
build_snapshot = support.build_snapshot
tree_of_directory = support.tree_of_directory


def snapshot_tree(repository_root: str, work_directory: str) -> str:
    destination = os.path.join(work_directory, "snapshot")
    build_snapshot(repository_root, destination)
    return tree_of_directory(destination)


def remote_tag_tree(remote_url: str, tag: str, work_directory: str) -> tuple[str, str]:
    """remote の tag を取ってきて、(commit の ID, tree の ID) を返す。"""
    directory = os.path.join(work_directory, "spm")
    os.makedirs(directory)
    support.run_git(directory, "init", "--quiet")
    support.run_git(directory, "fetch", "--quiet", "--depth", "1", "--no-tags", remote_url, f"refs/tags/{tag}")
    commit = support.run_git(directory, "rev-parse", "FETCH_HEAD^{commit}").stdout.strip()
    tree = support.run_git(directory, "rev-parse", "FETCH_HEAD^{tree}").stdout.strip()
    return commit, tree


def check_tags(version: str, commit: str, remote: str, spm_url: str, repository_root: str) -> tuple[dict[str, str], list[str]]:
    """両リポジトリの tag を確かめて、(step の出力, 結果の説明) を返す。外れたら ReleaseError。"""
    problems = []
    notes = []
    outputs = {}

    main_target = support.remote_tag_commit(repository_root, remote, version)
    if main_target is None:
        outputs["main-tag"] = "absent"
        notes.append(f"本リポジトリに tag {version} は無い")
    elif main_target == commit:
        outputs["main-tag"] = "matches"
        notes.append(f"本リポジトリの tag {version} は起動した commit を指す (再実行として続ける)")
    else:
        problems.append(
            f"本リポジトリの tag {version} が、起動した commit ({commit}) とは別の commit ({main_target}) を指す"
        )

    spm_target = support.remote_tag_commit(repository_root, spm_url, version)
    if spm_target is None:
        outputs["spm-tag"] = "absent"
        notes.append(f"配信用リポジトリに tag {version} は無い")
    else:
        head = support.run_git(repository_root, "rev-parse", "HEAD").stdout.strip()
        if head != commit:
            raise support.ReleaseError(
                f"写しを作る作業ツリーの HEAD ({head}) が、起動した commit ({commit}) と違う"
            )
        with tempfile.TemporaryDirectory(prefix="release-tags-") as work_directory:
            expected_tree = snapshot_tree(repository_root, work_directory)
            tagged_commit, tagged_tree = remote_tag_tree(spm_url, version, work_directory)
        if tagged_tree == expected_tree:
            outputs["spm-tag"] = "matches"
            notes.append(
                f"配信用リポジトリの tag {version} は、起動した commit から作った写しと同じ中身の commit"
                f" ({tagged_commit}) を指す (再実行として続ける)"
            )
        else:
            problems.append(
                f"配信用リポジトリの tag {version} が指す commit ({tagged_commit}) の中身が、"
                f"起動した commit ({commit}) から作った写しと違う"
            )

    if problems:
        raise support.ReleaseError("\n".join(problems))
    return outputs, notes


# ---- published ----


def check_published(version: str, commit: str, maven_url: str) -> tuple[dict[str, str], str]:
    """取得先の POM を確かめて、(step の出力, 結果の説明) を返す。外れたら ReleaseError。"""
    url = support.artifact_url(maven_url, version, ".pom")
    try:
        response = support.http_request("GET", url)
    except support.TransportError as error:
        raise support.ReleaseError(f"公開済みかを確かめられない: {error}") from error
    if response.status == 404:
        return {"published": "false"}, f"版 {version} は Maven Central の取得先にまだ無い ({url})"
    if response.status != 200:
        raise support.ReleaseError(f"公開済みかを確かめられない: GET {url} が {response.status} を返した")
    pom = support.read_pom(response.text())
    source_commit = pom["scmTag"]
    if not source_commit:
        raise support.ReleaseError(f"公開済みの版 {version} の POM に、元になった commit (scm の tag) が無い ({url})")
    if source_commit != commit:
        raise support.ReleaseError(
            f"版 {version} は、別の commit ({source_commit}) から作ったものが公開済みである"
            f" (起動した commit: {commit})。同じ版では公開できない"
        )
    return {"published": "true"}, f"版 {version} は、起動した commit から作ったものが公開済み (再実行として続ける)"


# ---- 入口 ----


def require_commit(commit: str) -> str:
    problem = support.check_commit(commit)
    if problem:
        raise support.ReleaseError(problem)
    return commit


def main(argv: list[str] | None = None) -> int:
    env = os.environ
    parser = argparse.ArgumentParser(description="リリースを始めてよいかを確かめる")
    commands = parser.add_subparsers(dest="command", required=True)

    inputs = commands.add_parser("inputs", help="入力の版の形と、起動したブランチ")
    inputs.add_argument("--version", required=True)
    inputs.add_argument("--dry-run", required=True)
    inputs.add_argument("--ref", default=env.get("GITHUB_REF", ""))

    tags = commands.add_parser("tags", help="両リポジトリの tag")
    tags.add_argument("--version", required=True)
    tags.add_argument("--commit", default=env.get("GITHUB_SHA", ""))
    tags.add_argument("--remote", default="origin")
    tags.add_argument("--spm-url", default=support.SPM_REPOSITORY_URL)
    tags.add_argument("--repository-root", default=REPOSITORY_ROOT)

    published = commands.add_parser("published", help="Maven Central の取得先にある POM")
    published.add_argument("--version", required=True)
    published.add_argument("--commit", default=env.get("GITHUB_SHA", ""))
    published.add_argument("--maven-url", default=support.MAVEN_CENTRAL_URL)

    args = parser.parse_args(argv)

    try:
        if args.command == "inputs":
            outputs = check_inputs(args.version, args.dry_run, args.ref)
            print(f"入力を受け付けた (版: {args.version} / 本番: {outputs['production']} / ref: {args.ref or '不明'})")
        elif args.command == "tags":
            version_problem = support.check_version(args.version)
            if version_problem:
                raise support.ReleaseError(version_problem)
            outputs, notes = check_tags(
                args.version, require_commit(args.commit), args.remote, args.spm_url, args.repository_root
            )
            for note in notes:
                print(note)
        else:
            version_problem = support.check_version(args.version)
            if version_problem:
                raise support.ReleaseError(version_problem)
            outputs, note = check_published(args.version, require_commit(args.commit), args.maven_url)
            print(note)
        support.write_outputs(outputs)
    except support.ReleaseError as error:
        support.emit_errors(str(error).splitlines())
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
