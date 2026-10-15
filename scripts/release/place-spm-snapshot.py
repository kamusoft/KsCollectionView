#!/usr/bin/env python3
"""利用者役で確かめた SwiftPM の写しを、配信用リポジトリの作業コピーにそのまま置く。リリースの
workflow の公開のジョブが、写しを push する前に呼ぶ。

公開の前に確かめるのは、工程が実際に公開する成果物である。写しを作業コピーに作り直すと、確かめた
写しとは別のものを push することになるので、確かめた写し (同じ run の artifact) の中身をそのまま置く。

次の順に行い、1 つでも外れたら失敗で終わる。

  1. 確かめた写しの中身が、起動した commit の作業ツリーから作った写しと同じであることを確かめる。
     比べ方は、配信用リポジトリの tag の照合 (check-release-state.py tags) と同じで、ディレクトリの
     中身を git の tree にした ID で比べる。同じなら、push した写しに付けた tag は、後の再実行の照合でも
     同じ中身と判定される。ここで外れたときは、作業コピーを変えない
  2. 作業コピーの中身を、.git を除いて消し、確かめた写しの中身を置く。作業コピーとして受け付ける形と
     消し方は、写しを作る道具 (scripts/distribution/sync-spm-snapshot.py) と同じである
  3. 変更を index に載せ (git add --all)、index の tree が確かめた写しの tree と同じであることを
     確かめる。外れたときは、作業コピーは置き換えた状態のまま残る (push しないで止まる)

git は、index に載せることと、tree の ID を読むことにだけ使う。commit・push・tag は行わない。
利用者とランナーの git の設定は読まない (設定で中身の比べ方が変わらないようにするため)。
ネットワークは使わない。

使い方:
  python3 scripts/release/place-spm-snapshot.py --snapshot <確かめた写し> --destination <作業コピー>
      [--commit <ID>] [--repository-root <ディレクトリ>]

  --commit を省くと環境変数 GITHUB_SHA を読む。--repository-root (既定はこのリポジトリ) の作業ツリーの
  HEAD は --commit と同じでなければならない。

終了コード:
  0  置いた (index に載せた)
  1  確かめが外れた / 置けなかった
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))
SYNC_SCRIPT = os.path.join(REPOSITORY_ROOT, "scripts", "distribution", "sync-spm-snapshot.py")

# 写しのルートに必ずある項目。空の写しや、別のディレクトリを渡した誤りを先に止める。
REQUIRED_ENTRY = "Package.swift"

# 写しの作り方と中身の比べ方は、配信用リポジトリの tag の照合と同じものを使う。
build_snapshot = support.build_snapshot
tree_of_directory = support.tree_of_directory


def load_sync_module():
    """作業コピーの確かめ方と消し方を、写しを作る道具から読み込む。"""
    spec = importlib.util.spec_from_file_location("release_sync_spm_snapshot", SYNC_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    # dataclass は、定義したモジュールを sys.modules から引く。
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def check_snapshot(snapshot: str) -> str:
    """確かめた写しのディレクトリを確かめて、絶対パスを返す。"""
    path = os.path.realpath(os.path.abspath(snapshot))
    if not os.path.isdir(path):
        raise support.ReleaseError(f"確かめた写しのディレクトリが無い: {path}")
    if not os.path.isfile(os.path.join(path, REQUIRED_ENTRY)):
        raise support.ReleaseError(f"確かめた写しのルートに {REQUIRED_ENTRY} が無い: {path}")
    for current, directories, files in os.walk(path):
        if ".git" in directories or ".git" in files:
            raise support.ReleaseError(f"確かめた写しの中に git の管理情報 (.git) がある: {current}")
    return path


def copy_contents(source: str, destination: str) -> None:
    """source の直下の項目を、destination の直下へ写す。シンボリックリンクは指す先を写さない。"""
    for name in sorted(os.listdir(source)):
        source_path = os.path.join(source, name)
        target_path = os.path.join(destination, name)
        if os.path.isdir(source_path) and not os.path.islink(source_path):
            shutil.copytree(source_path, target_path, symlinks=True)
        else:
            shutil.copy2(source_path, target_path, follow_symlinks=False)


def place(snapshot: str, destination: str, commit: str, repository_root: str) -> str:
    """確かめた写しを作業コピーに置き、index の tree の ID を返す。外れたら ReleaseError。"""
    snapshot = check_snapshot(snapshot)
    head = support.run_git(repository_root, "rev-parse", "HEAD").stdout.strip()
    if head != commit:
        raise support.ReleaseError(f"写しを作る作業ツリーの HEAD ({head}) が、起動した commit ({commit}) と違う")

    # 1. 確かめた写しと、起動した commit から作った写しを比べる。どちらも一時の写しに git の
    # 管理情報を作って比べ、確かめた写しそのものと作業コピーには触れない。
    with tempfile.TemporaryDirectory(prefix="release-place-spm-") as work_directory:
        verified_copy = os.path.join(work_directory, "verified")
        shutil.copytree(snapshot, verified_copy, symlinks=True)
        verified_tree = tree_of_directory(verified_copy)
        expected = os.path.join(work_directory, "expected")
        build_snapshot(repository_root, expected)
        expected_tree = tree_of_directory(expected)
    if verified_tree != expected_tree:
        raise support.ReleaseError(
            f"確かめた写し (tree {verified_tree}) が、起動した commit ({commit}) から作った写し"
            f" (tree {expected_tree}) と違う。作業コピーは変えていない"
        )

    # 2. 作業コピーの中身を、確かめた写しに置き換える。
    sync = load_sync_module()
    try:
        target = sync.check_destination(repository_root, destination)
    except sync.SnapshotError as error:
        raise support.ReleaseError(f"作業コピーとして受け付けられない: {error}") from error
    if not os.path.isdir(target) or not os.path.lexists(os.path.join(target, ".git")):
        raise support.ReleaseError(f"配信用リポジトリの作業コピーでない (.git が無い): {target}")
    try:
        sync.clear_destination(target)
        copy_contents(snapshot, target)
    except OSError as error:
        raise support.ReleaseError(f"写しを置いている途中で失敗した。作業コピーは中途半端な状態である: {target} ({error})") from error

    # 3. index に載せ、index の中身が確かめた写しと同じことを確かめる。
    support.run_git(target, "add", "--all", isolated=True)
    placed_tree = support.run_git(target, "write-tree", isolated=True).stdout.strip()
    if placed_tree != verified_tree:
        raise support.ReleaseError(
            f"作業コピーの index の中身 (tree {placed_tree}) が、確かめた写し (tree {verified_tree}) と違う。"
            " push しない"
        )
    return placed_tree


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="利用者役で確かめた SwiftPM の写しを、配信用リポジトリの作業コピーに置く")
    parser.add_argument("--snapshot", required=True, help="確かめた写し (artifact を取り込んだディレクトリ)")
    parser.add_argument("--destination", required=True, help="配信用リポジトリの作業コピー")
    parser.add_argument("--commit", default=os.environ.get("GITHUB_SHA", ""))
    parser.add_argument("--repository-root", default=REPOSITORY_ROOT)
    args = parser.parse_args(argv)

    try:
        problem = support.check_commit(args.commit)
        if problem:
            raise support.ReleaseError(problem)
        tree = place(args.snapshot, args.destination, args.commit, args.repository_root)
    except support.ReleaseError as error:
        support.emit_errors(str(error).splitlines())
        return 1
    print(f"確かめた写しを作業コピーに置いた (tree {tree}): {args.destination}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
