#!/usr/bin/env python3
"""iOS の配布物を、利用者の立場でビルドして確かめる。

利用者役 (verification/ios/) は、本ライブラリを package KsCollectionView-SPM の product
KsCollectionView として取る SwiftPM のパッケージである。その利用者役を、リリースの構成で、
Simulator 向けと実機向けの 2 つの行き先にビルドする。行き先は、特定の端末を指さない総称の
指定で、Simulator は選ばず、起動もしない。実機向けは、署名なしでビルドする。

配布物をどこから取るかは、切り替えで決まる。ビルドと成功の条件は、どちらでも同じである。

  local      今の本体 (ios/) から、配信用リポジトリのルートに置くのと同じ写しを一時の
             ディレクトリに作り、利用者役にその写しをパスで参照させる。版は使わない
  published  写しを作らない。利用者役に、配信用リポジトリの URL を、渡した版の完全一致で
             参照させる

行うことは、順に次のとおり。子プロセス (写しを作る道具・xcodebuild) の出力は、加工せずに
そのまま流す。どれかが失敗したら、後ろを始めずに、その時点で失敗で終わる。

  1. 引数を確かめる
  2. (local だけ) 写しを、一時のディレクトリの下の KsCollectionView-SPM に作る
  3. 利用者役を一時のディレクトリに写し、ひな形に参照の行を差し込んでマニフェストを書く
  4. Simulator 向けにビルドする
  5. 実機向けにビルドする

git が追跡しているファイルは変えない。書くのは、一時のディレクトリ (写し・利用者役の写し・
ビルドの出力) だけで、確認が終わると消す。

Xcode は、PATH の上の xcodebuild をそのまま使う。どの Xcode を使うかは、呼ぶ側が決める
(環境変数 DEVELOPER_DIR か xcode-select)。本体のマニフェストが求める版より古い Xcode では、
依存を解決できずにビルドが失敗する。

使い方:
  python3 scripts/ci/verify-consumer-ios.py --mode local
  python3 scripts/ci/verify-consumer-ios.py --mode published --version 1.2.3

終了コード:
  0  2 つの行き先のビルドが、どちらも成功した
  1  写しの作成・利用者役の準備・ビルドのどれかが失敗した
  2  引数の誤り (知らない切り替え・published で版が無い)。何も始めていない
"""

from __future__ import annotations

import argparse
import dataclasses
import os
import re
import shutil
import subprocess
import sys
import tempfile

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))

sys.path.insert(0, HERE)
import ci_report  # noqa: E402

MODES = ("local", "published")

# 利用者がマニフェストに書く package の名前。SwiftPM は、参照先のパスや URL の末尾の名前を
# package の名前として扱うので、写しのディレクトリもこの名前にする。
PACKAGE_NAME = "KsCollectionView-SPM"
PRODUCT_NAME = "KsCollectionView"
DISTRIBUTION_URL = f"https://github.com/kamusoft/{PACKAGE_NAME}"

SNAPSHOT_TOOL = os.path.join("scripts", "distribution", "sync-spm-snapshot.py")
CONSUMER = os.path.join("verification", "ios")
MANIFEST_TEMPLATE = os.path.join(CONSUMER, "Package.swift.template")
CONSUMER_SOURCES = os.path.join(CONSUMER, "Sources")
# ひな形の中の、参照の行を差し込む場所。
DEPENDENCY_PLACEHOLDER = "@KSCV_DEPENDENCY@"

# 一時のディレクトリの中の配置。利用者役の写しと写しを隣に置き、相対のパスで参照させる。
WORK_CONSUMER = "consumer"
WORK_DERIVED_DATA = "DerivedData"

SCHEME = "VerificationApp"
CONFIGURATION = "Release"


@dataclasses.dataclass(frozen=True)
class Destination:
    title: str
    specifier: str
    # xcodebuild に足すビルドの設定。
    settings: tuple[str, ...] = ()


# ビルドする行き先。上から順にビルドし、すべてが成功したときだけ確認が成功する。
DESTINATIONS = (
    Destination("Simulator 向け", "generic/platform=iOS Simulator"),
    # 実機向けのビルドは、既定では署名を求める。確かめるのはビルドできることだけなので、署名を外す。
    Destination("実機向け", "generic/platform=iOS", ("CODE_SIGNING_ALLOWED=NO",)),
)

# 版に使える文字。マニフェストの文字列にそのまま差し込むので、引用符と逆斜線を通さない。
VERSION_PATTERN = re.compile(r"[0-9A-Za-z][0-9A-Za-z.+_-]*")


class VerificationError(Exception):
    """確認が失敗した。メッセージは、そのまま失敗の理由として出す。"""


class UsageError(Exception):
    """引数が範囲の外にある。"""


@dataclasses.dataclass(frozen=True)
class Request:
    mode: str
    # local で渡されなければ None。local では使わない。
    version: str | None


def parse_request(argv: list[str] | None) -> Request:
    """引数を確かめる。範囲の外なら UsageError を投げる。"""
    parser = argparse.ArgumentParser(description="iOS の配布物を、利用者の立場でビルドして確かめる")
    # choices は使わない。知らない値のときの文言を、自分で決めるためである。
    parser.add_argument("--mode", required=True, help="配布物をどこから取るか (local | published)")
    parser.add_argument("--version", default="", help="取る版 (published では必須。local では使わない)")
    args = parser.parse_args(argv)

    if args.mode not in MODES:
        raise UsageError(f"--mode は {' か '.join(MODES)} のどちらかにする: {args.mode!r}")
    # workflow は、版の入力が空のときに空の文字列を渡す。空は「渡していない」と同じに扱う。
    version = args.version.strip() or None
    if version is not None and not VERSION_PATTERN.fullmatch(version):
        raise UsageError(f"--version に使えない文字がある: {version!r}")
    if args.mode == "published" and version is None:
        raise UsageError("--mode published では --version が必須である (取る版を決められない)")
    return Request(mode=args.mode, version=version)


def dependency_line(request: Request) -> str:
    """利用者役のマニフェストに差し込む、配布物への参照の行。"""
    if request.mode == "published":
        return f'.package(url: "{DISTRIBUTION_URL}", exact: "{request.version}"),'
    return f'.package(path: "../{PACKAGE_NAME}"),'


def render_manifest(template: str, dependency: str) -> str:
    """ひな形の差し込み口を、参照の行に置き換える。"""
    # 差し込み口は、ちょうど 1 つ。0 なら参照の無いマニフェストに、2 つ以上なら意図しない場所まで
    # 置き換えたマニフェストになる。
    count = template.count(DEPENDENCY_PLACEHOLDER)
    if count != 1:
        raise VerificationError(
            f"利用者役のマニフェストのひな形に、差し込み口 {DEPENDENCY_PLACEHOLDER} が"
            f" ちょうど 1 つ無い ({count} つ): {MANIFEST_TEMPLATE}"
        )
    return template.replace(DEPENDENCY_PLACEHOLDER, dependency)


def announce(title: str) -> None:
    print(f"==== {title} ====", flush=True)


def run(command: list[str], working_directory: str, what: str) -> int:
    """コマンドを流す。出力は、この確認の出力へそのまま流れる (子プロセスが同じ出力先を継ぐ)。"""
    # 自分の出力を先に出し切る。子プロセスの出力と、順が入れ替わらないようにするためである。
    sys.stdout.flush()
    sys.stderr.flush()
    try:
        return subprocess.run(command, cwd=working_directory, check=False).returncode
    except OSError as error:
        raise VerificationError(f"{what}を実行できない ({error})") from error


def create_snapshot(repository_root: str, snapshot: str) -> None:
    """今の本体から、写しを作る。"""
    announce(f"今の ios/ から写しを作る ({PACKAGE_NAME})")
    code = run(
        [sys.executable, os.path.join(repository_root, SNAPSHOT_TOOL), snapshot],
        repository_root,
        "写しを作る道具",
    )
    if code != 0:
        raise VerificationError(f"写しの作成が失敗した (終了コード {code})。理由は、上の出力にある")
    # 写しが、渡した場所にできたことを確かめる。場所がずれたまま先へ進むと、利用者役が
    # 解決できない理由が、写しの側にあることが分からなくなる。
    if not os.path.isfile(os.path.join(snapshot, "Package.swift")):
        raise VerificationError("写しの作成は成功で終わったが、写しにマニフェスト (Package.swift) が無い")


def prepare_consumer(repository_root: str, consumer: str, dependency: str) -> None:
    """利用者役を作業用のディレクトリに写し、参照の行を差し込んだマニフェストを書く。"""
    announce("利用者役を作業用のディレクトリに写す")
    try:
        with open(os.path.join(repository_root, MANIFEST_TEMPLATE), encoding="utf-8") as f:
            template = f.read()
        manifest = render_manifest(template, dependency)
        shutil.copytree(os.path.join(repository_root, CONSUMER_SOURCES), os.path.join(consumer, "Sources"))
        with open(os.path.join(consumer, "Package.swift"), "w", encoding="utf-8") as f:
            f.write(manifest)
    except OSError as error:
        raise VerificationError(f"利用者役を作業用のディレクトリに写せない: {CONSUMER} ({error})") from error
    # 何を参照してビルドしたかを、記録に残す。
    print(f"配布物への参照: {dependency}", flush=True)


def build_command(destination: Destination, derived_data: str) -> list[str]:
    return [
        "xcodebuild",
        "build",
        "-scheme",
        SCHEME,
        "-destination",
        destination.specifier,
        "-configuration",
        CONFIGURATION,
        "-derivedDataPath",
        derived_data,
        *destination.settings,
    ]


def build_consumer(consumer: str, derived_data: str, destination: Destination) -> None:
    announce(f"利用者役をビルドする: {destination.title} ({destination.specifier}・{CONFIGURATION})")
    code = run(build_command(destination, derived_data), consumer, "xcodebuild ")
    if code != 0:
        raise VerificationError(
            f"利用者役のビルドが失敗した: {destination.title} (xcodebuild の終了コード {code})。"
            "理由は、上の xcodebuild の出力にある"
        )


def verify(request: Request, repository_root: str) -> str:
    """確認を行い、利用者役に差し込んだ参照の行を返す。失敗したら VerificationError を投げる。"""
    dependency = dependency_line(request)
    with tempfile.TemporaryDirectory(prefix="kscollectionview-consumer-ios-") as work:
        # xcodebuild が場所の表記を揃えても食い違わないように、実体のパスにしておく。
        work = os.path.realpath(work)
        if request.mode == "local":
            create_snapshot(repository_root, os.path.join(work, PACKAGE_NAME))
        consumer = os.path.join(work, WORK_CONSUMER)
        prepare_consumer(repository_root, consumer, dependency)
        for destination in DESTINATIONS:
            build_consumer(consumer, os.path.join(work, WORK_DERIVED_DATA), destination)
    return dependency


def main(argv: list[str] | None = None) -> int:
    try:
        request = parse_request(argv)
    except UsageError as error:
        ci_report.emit_errors([str(error)])
        return 2

    if request.mode == "local" and request.version is not None:
        print(f"local では版を使わない (写しをパスで参照する)。渡された版: {request.version}", flush=True)

    try:
        dependency = verify(request, REPOSITORY_ROOT)
    except VerificationError as error:
        ci_report.emit_errors([str(error)])
        return 1

    source = (
        "今の ios/ から作った写し"
        if request.mode == "local"
        else f"配信用リポジトリ ({DISTRIBUTION_URL}) の版 {request.version}"
    )
    ci_report.emit_summary(
        [
            "### iOS の利用者の立場のビルドの確認",
            "",
            f"- 切り替え: `{request.mode}` (取得元: {source})",
            f"- 配布物への参照: `{dependency}`",
            f"- 利用者が書く依存: package `{PACKAGE_NAME}` の product `{PRODUCT_NAME}`",
            *(
                f"- ビルド: {destination.title} (`{destination.specifier}`・{CONFIGURATION}): 成功"
                for destination in DESTINATIONS
            ),
        ]
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
