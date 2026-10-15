#!/usr/bin/env python3
"""SwiftPM の配信用リポジトリ (KsCollectionView-SPM) のルートに置く写しを作る。

SwiftPM は、git のリポジトリのルートにあるマニフェストしか解決できない。このリポジトリの
マニフェストは ios/ の下にあるので、配信用リポジトリのルートに、本体の写しを置いて配る
(cross/ADR-0015)。

行き先のディレクトリの中身を、次の 5 点だけにする。行き先に元からあった中身は、.git を除いて消す。
行き先がまだ無ければ、作ってから写す。

  写しの中の場所    元
  Package.swift     ios/Package.swift (内容を変えない)
  Sources/          ios/Sources/ のうち、git が追跡しているファイル
  Tests/            ios/Tests/ のうち、git が追跡しているファイル
  LICENSE           LICENSE
  README.md         scripts/distribution/spm-readme.template.md

追跡しているファイルは、作業ツリーにある今の内容を写す。追跡していないファイル
(手元のビルドの出力など) は写さない。

行き先の中身を消す道具なので、消す前に次をすべて確かめる。1 つでも外れたら、行き先を
作りも消しもせずに、失敗で終わる。

  1. 元の 5 点がすべてある
  2. 行き先が、このリポジトリの中でも、このリポジトリを含むディレクトリでもない
  3. 行き先が、まだ無いパスか、空のディレクトリか、配信用リポジトリの作業コピー
     (git の最上位で、origin が配信用リポジトリを指す) である
  4. 行き先が作業コピーなら、その git の管理情報の場所 (管理ディレクトリと、共通の管理
     ディレクトリ) が、行き先そのものでも、消す対象 (行き先の直下の .git 以外) の中でもない

4 で見るのは、この 2 つの場所だけである。通常の clone・worktree でない構成 (オブジェクトの
借用先 objects/info/alternates や、管理ディレクトリの中のシンボリックリンクが、行き先の中を
指す作業コピーなど) は確かめない。そういう作業コピーを渡すと、写しはできるが、行き先の
commit を読めなくなることがある。

git の commit・push・tag は行わない。git は、追跡しているファイルの一覧と、行き先の
最上位・origin・管理情報の場所を読むためだけに呼ぶ。写した結果は、行き先の作業ツリーの変更として残る。
ネットワークは使わない。何度流しても、同じ結果になる。

使い方:
  python3 scripts/distribution/sync-spm-snapshot.py <行き先のディレクトリ>

終了コード:
  0  写しを作った
  1  確認が外れた (行き先は変えていない) / 写している途中で失敗した
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import dataclasses
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))

# 配信用リポジトリ。行き先に中身があるときは、origin がここを指す作業コピーだけを受け付ける。
DISTRIBUTION_REPOSITORY = "kamusoft/KsCollectionView-SPM"

MANIFEST = os.path.join("ios", "Package.swift")
SOURCES = os.path.join("ios", "Sources")
TESTS = os.path.join("ios", "Tests")
LICENSE = "LICENSE"
README_TEMPLATE = os.path.join("scripts", "distribution", "spm-readme.template.md")

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


class SnapshotError(Exception):
    """確認が外れた、または写せなかった。メッセージは、そのまま利用者に見せる。"""


@dataclasses.dataclass(frozen=True)
class Sources:
    """写しの元。パスはすべて、リポジトリのルートからの相対。"""

    source_files: list[str]
    test_files: list[str]


def run_git(directory: str, *arguments: str) -> subprocess.CompletedProcess:
    environment = {key: value for key, value in os.environ.items() if key not in GIT_LOCATION_VARIABLES}
    try:
        return subprocess.run(
            ["git", "-C", directory, *arguments],
            capture_output=True,
            text=True,
            env=environment,
            check=False,
        )
    except OSError as error:
        raise SnapshotError(f"git を実行できない: {error}") from error


def tracked_files(repository_root: str, directory: str) -> list[str]:
    """directory の下の、git が追跡しているファイルを返す。"""
    # -z を付けないと、ASCII でない名前が引用符つきのエスケープで返る。
    result = run_git(repository_root, "ls-files", "-z", "--", directory)
    if result.returncode != 0:
        raise SnapshotError(
            f"追跡しているファイルを調べられない: {directory} ({result.stderr.strip() or 'git が失敗した'})"
        )
    return sorted(path for path in result.stdout.split("\0") if path)


def collect_sources(repository_root: str) -> Sources:
    """元の 5 点がすべてあることを確かめて、写すファイルの一覧を返す。"""
    missing = [
        path
        for path in (MANIFEST, LICENSE, README_TEMPLATE)
        if not os.path.isfile(os.path.join(repository_root, path))
    ]
    files: dict[str, list[str]] = {}
    for directory in (SOURCES, TESTS):
        if not os.path.isdir(os.path.join(repository_root, directory)):
            missing.append(directory + os.sep)
            continue
        tracked = tracked_files(repository_root, directory)
        if not tracked:
            # 空の写しを黙って作らない。
            missing.append(f"{directory}{os.sep} (git が追跡しているファイルが 1 つも無い)")
            continue
        # 追跡しているが作業ツリーから消えているファイルを、写している途中ではなく、消す前に見つける。
        missing.extend(
            f"{path} (追跡しているが、作業ツリーに無い)"
            for path in tracked
            if not os.path.lexists(os.path.join(repository_root, path))
        )
        files[directory] = tracked
    if missing:
        raise SnapshotError("写しの元が欠けている: " + " / ".join(missing))
    return Sources(source_files=files[SOURCES], test_files=files[TESTS])


def is_within(path: str, container: str) -> bool:
    """path が、container そのものか、container の下にあるかを返す。path は、まだ無くてもよい。

    パスの文字列ではなく、ファイルの実体で比べる。大文字と小文字を区別しないファイルシステムや
    シンボリックリンクで、同じ場所に別の書き方でたどり着けるためである。
    """
    current = path
    while True:
        if os.path.exists(current) and os.path.samefile(current, container):
            return True
        parent = os.path.dirname(current)
        if parent == current:
            return False
        current = parent


def is_distribution_origin(url: str) -> bool:
    # 末尾の斜線と .git の有無だけを吸収して、受け付ける形を列挙して突き合わせる。
    # 部分一致で見ると、別の持ち主の下にある同じ名前のリポジトリも通ってしまう。
    normalized = url.strip().rstrip("/").removesuffix(".git")
    return normalized in (
        f"https://github.com/{DISTRIBUTION_REPOSITORY}",
        f"ssh://git@github.com/{DISTRIBUTION_REPOSITORY}",
        f"git@github.com:{DISTRIBUTION_REPOSITORY}",
    )


def check_working_copy(destination: str) -> None:
    """中身のある行き先が、配信用リポジトリの作業コピーであることを確かめる。"""
    refusal = f"行き先に中身があり、配信用リポジトリ ({DISTRIBUTION_REPOSITORY}) の作業コピーでもない: {destination}"

    toplevel = run_git(destination, "rev-parse", "--show-toplevel")
    if toplevel.returncode != 0 or not toplevel.stdout.strip():
        raise SnapshotError(f"{refusal} (git のリポジトリではない)")
    toplevel_path = toplevel.stdout.strip()
    if not os.path.isdir(toplevel_path) or not os.path.samefile(toplevel_path, destination):
        raise SnapshotError(f"{refusal} (git の最上位ではない。最上位: {toplevel_path})")

    # 設定に書かれた値をそのまま読む。remote get-url は、利用者の設定 (insteadOf) で書き換えた値を返す。
    origin = run_git(destination, "config", "--get", "remote.origin.url")
    origin_url = origin.stdout.strip()
    if origin.returncode != 0 or not origin_url:
        raise SnapshotError(f"{refusal} (origin が無い)")
    if not is_distribution_origin(origin_url):
        raise SnapshotError(f"{refusal} (origin: {origin_url})")

    check_git_directories(destination)


def check_git_directories(destination: str) -> None:
    """作業コピーの git の管理情報が、行き先そのものにも、消す対象の中にも無いことを確かめる。

    管理情報は、行き先の直下の .git にあるとは限らない。.git が「管理情報は別のディレクトリにある」と
    指すファイルで、その実体が行き先の中にあると、.git だけを残しても commit と tag が消える。
    worktree では、作業ツリーごとの管理情報と、共通の管理情報 (commit と tag を持つ) が別の場所にある。

    見るのは、この 2 つの場所 (管理ディレクトリと、共通の管理ディレクトリ) だけである。管理情報が
    さらに別の場所を指す構成 (オブジェクトの借用先 objects/info/alternates や、管理ディレクトリの中の
    シンボリックリンク。通常の clone・worktree ではできない) は見ない。その指す先が行き先の中にあると、
    確認を通って消える。
    """
    # 共通の管理情報の場所は、相対のパスで返ることがある。その基点は行き先である。
    result = run_git(destination, "rev-parse", "--absolute-git-dir", "--git-common-dir")
    locations = [os.path.join(destination, line) for line in result.stdout.splitlines() if line]
    if result.returncode != 0 or len(locations) != 2:
        raise SnapshotError(
            f"行き先の git の管理情報の場所を調べられない: {destination} ({result.stderr.strip() or 'git が失敗した'})"
        )
    # 管理情報の場所が行き先そのものだと、HEAD や objects が行き先の直下に並ぶ。どの子ディレクトリの
    # 「中」にも当たらないので、下の並びの確認より先に見る。
    for location in locations:
        if os.path.exists(location) and os.path.samefile(location, destination):
            raise SnapshotError(
                f"行き先の git の管理情報の場所が、行き先そのものである: {location}"
                " (管理情報を行き先の外か、行き先の直下の .git に置いた作業コピーを渡す)"
            )
    # clear_destination が消すものと同じ並びで見る。シンボリックリンクは、指す先を消さない。
    for name in os.listdir(destination):
        path = os.path.join(destination, name)
        if name == ".git" or os.path.islink(path) or not os.path.isdir(path):
            continue
        for location in locations:
            if is_within(location, path):
                raise SnapshotError(
                    f"行き先の git の管理情報が、消す対象の中にある: {location}"
                    " (管理情報を行き先の外か、行き先の直下の .git に置いた作業コピーを渡す)"
                )


def check_destination(repository_root: str, destination_argument: str) -> str:
    """行き先を消してよい場所かを確かめて、行き先の絶対パスを返す。何も作らず、何も消さない。"""
    destination = os.path.realpath(os.path.abspath(destination_argument))

    if is_within(destination, repository_root):
        raise SnapshotError(f"行き先がこのリポジトリの中にある: {destination}")
    if os.path.exists(destination) and is_within(repository_root, destination):
        raise SnapshotError(f"行き先がこのリポジトリを含むディレクトリである: {destination}")

    if not os.path.lexists(destination):
        return destination
    if not os.path.isdir(destination):
        raise SnapshotError(f"行き先がディレクトリではない: {destination}")
    if os.listdir(destination):
        check_working_copy(destination)
    return destination


def clear_destination(destination: str) -> None:
    """行き先の中身を、.git を除いて消す。.git は、worktree ではファイルになる。

    残すのは名前が .git の項目だけである。git の管理情報が行き先の直下にも、ほかの項目の中にも
    無いことは、check_git_directories が先に確かめている。
    """
    for name in os.listdir(destination):
        if name == ".git":
            continue
        path = os.path.join(destination, name)
        if os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path)
        else:
            os.unlink(path)


def copy_file(source: str, target: str) -> None:
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copy(source, target, follow_symlinks=False)


def write_snapshot(repository_root: str, sources: Sources, destination: str) -> None:
    def source(path: str) -> str:
        return os.path.join(repository_root, path)

    copy_file(source(MANIFEST), os.path.join(destination, "Package.swift"))
    copy_file(source(LICENSE), os.path.join(destination, "LICENSE"))
    copy_file(source(README_TEMPLATE), os.path.join(destination, "README.md"))
    # 追跡しているファイルのパスは ios/ から始まる。写しでは ios/ を除いた場所に置く。
    for path in sources.source_files + sources.test_files:
        copy_file(source(path), os.path.join(destination, os.path.relpath(path, "ios")))


def sync(repository_root: str, destination_argument: str) -> tuple[str, Sources]:
    """写しを作り、(行き先の絶対パス, 写した元) を返す。確認が外れたら、何も変えずに SnapshotError を出す。"""
    repository_root = os.path.realpath(repository_root)
    sources = collect_sources(repository_root)
    destination = check_destination(repository_root, destination_argument)

    # ここから先で、行き先を変える。
    try:
        os.makedirs(destination, exist_ok=True)
        clear_destination(destination)
        write_snapshot(repository_root, sources, destination)
    except OSError as error:
        raise SnapshotError(
            f"写している途中で失敗した。行き先の中身は中途半端な状態である: {destination} ({error})"
        ) from error
    return destination, sources


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SwiftPM の配信用リポジトリのルートに置く写しを作る")
    parser.add_argument(
        "destination",
        help="行き先のディレクトリ (まだ無いパス・空のディレクトリ・配信用リポジトリの作業コピーのどれか)",
    )
    args = parser.parse_args(argv)

    try:
        destination, sources = sync(REPOSITORY_ROOT, args.destination)
    except (SnapshotError, OSError) as error:
        print(f"エラー: {error}", file=sys.stderr)
        return 1

    print(
        f"写しを作った: {destination}"
        f" (Sources {len(sources.source_files)} ファイル / Tests {len(sources.test_files)} ファイル)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
