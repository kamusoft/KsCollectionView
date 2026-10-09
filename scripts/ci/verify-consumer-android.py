#!/usr/bin/env python3
"""Android の配布物を、利用者の立場でビルドして確かめる。

利用者役 (verification/android/) は、本ライブラリを Maven の座標の 1 行で取るアプリである。
その利用者役のリリースを、コード縮小 (R8) を有効にして組み立て、実行時の依存に本ライブラリの
座標が指定の版で現れることを確かめる。利用者役は起動しない。

配布物をどこから取るかは、切り替えで決まる。組み立てと成功の条件は、どちらでも同じである。

  local      今の本体 (android/) を、一時のディレクトリの Maven リポジトリへ発行し、利用者役に
             そこだけから取らせる。版を渡さなければ、本体のバージョンカタログの版を使う
  published  発行しない。渡した版を、利用者役に Maven Central だけから取らせる

行うことは、順に次のとおり。子プロセス (Gradle) の出力は、加工せずにそのまま流す。
どれかが失敗したら、後ろを始めずに、その時点で失敗で終わる。

  1. 引数を確かめる
  2. (local だけ) 本体を、一時のディレクトリの Maven リポジトリへ発行する
  3. 利用者役のリリースを組み立てる
  4. コード縮小の対応表 (mapping.txt) ができていることを確かめる
  5. 実行時の依存の一覧を出し、本ライブラリの座標が指定の版で解決されていることを確かめる

git が追跡しているファイルは変えない。書くのは、一時のディレクトリと、Gradle のビルドの出力
(android/ と verification/android/ の下の、追跡の対象外の場所) だけである。利用者の既定の
手元の Maven リポジトリ (~/.m2) には発行しない。

Android SDK の場所は、Gradle が読む。環境変数 ANDROID_HOME で渡す
(各ビルドルートの local.properties に書いてあれば、それでもよい)。

使い方:
  python3 scripts/ci/verify-consumer-android.py --mode local
  python3 scripts/ci/verify-consumer-android.py --mode local --version 1.2.3
  python3 scripts/ci/verify-consumer-android.py --mode published --version 1.2.3

終了コード:
  0  組み立てと依存の確認が、どちらも成功した
  1  発行・組み立て・確認のどれかが失敗した
  2  引数の誤り (知らない切り替え・published で版が無い)。何も始めていない
"""

from __future__ import annotations

import argparse
import dataclasses
import os
import re
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

GROUP = "jp.kamusoft"
ARTIFACT = "kscollectionview"
COORDINATE = f"{GROUP}:{ARTIFACT}"

LIBRARY_BUILD = "android"
CONSUMER_BUILD = os.path.join("verification", "android")
VERSION_CATALOG = os.path.join(LIBRARY_BUILD, "gradle", "libs.versions.toml")
# コード縮小を有効にしたリリースの組み立てで、ここに対応表ができる。
MAPPING = os.path.join(CONSUMER_BUILD, "app", "build", "outputs", "mapping", "release", "mapping.txt")

PUBLISH_TASK = f":{ARTIFACT}:publishToMavenLocal"
ASSEMBLE_TASK = ":app:assembleRelease"
DEPENDENCIES_TASK = ":app:dependencies"
RUNTIME_CONFIGURATION = "releaseRuntimeClasspath"

# 手元への発行のタスクの発行先を変える、Maven のシステムプロパティ。付け忘れると、
# 既定の手元の Maven リポジトリ (~/.m2) に発行される。
LOCAL_REPOSITORY_PROPERTY = "maven.repo.local"

# 版に使える文字。Gradle の引数とディレクトリの名前にそのまま使うので、先頭の `-` と区切りの文字を通さない。
VERSION_PATTERN = re.compile(r"[0-9A-Za-z][0-9A-Za-z.+_-]*")

# 依存の一覧の中の、本ライブラリの行。`座標:求めた版` の後ろに、別の版に解決されたときは
# ` -> 解決された版`、解決できなかったときは ` FAILED` が付く。
DEPENDENCY_LINE = re.compile(
    rf"{re.escape(COORDINATE)}:(?P<requested>[^\s:]+)(?: -> (?P<resolved>\S+))?(?P<failed> FAILED)?"
)


class VerificationError(Exception):
    """確認が失敗した。メッセージは、そのまま失敗の理由として出す。"""


class UsageError(Exception):
    """引数が範囲の外にある。"""


@dataclasses.dataclass(frozen=True)
class Request:
    mode: str
    # local で渡されなければ None (本体のバージョンカタログの版を使う)。
    version: str | None


def parse_request(argv: list[str] | None) -> Request:
    """引数を確かめる。範囲の外なら UsageError を投げる。"""
    parser = argparse.ArgumentParser(description="Android の配布物を、利用者の立場でビルドして確かめる")
    # choices は使わない。知らない値のときの文言を、自分で決めるためである。
    parser.add_argument("--mode", required=True, help="配布物をどこから取るか (local | published)")
    parser.add_argument("--version", default="", help="取る版 (published では必須。local で空なら本体のバージョンカタログの版)")
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


def catalog_version(repository_root: str) -> str:
    """本体のバージョンカタログから、本ライブラリの版を読む。"""
    path = os.path.join(repository_root, VERSION_CATALOG)
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError as error:
        raise VerificationError(f"本体のバージョンカタログを読めない: {VERSION_CATALOG} ({error})") from error

    section = ""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("["):
            section = stripped
            continue
        match = re.fullmatch(rf'{re.escape(ARTIFACT)}\s*=\s*"([^"]+)"\s*(#.*)?', stripped)
        if section == "[versions]" and match:
            return match.group(1)
    raise VerificationError(f"本体のバージョンカタログに {ARTIFACT} の版が無い: {VERSION_CATALOG}")


def gradle_command(build_directory: str, arguments: list[str]) -> list[str]:
    # --console=plain: 進み具合の表示を上書きさせず、タスクの行を記録に残す。
    return [os.path.join(build_directory, "gradlew"), "--console=plain", *arguments]


def run_gradle(build_directory: str, arguments: list[str]) -> int:
    """Gradle を流す。出力は、この確認の出力へそのまま流れる (子プロセスが同じ出力先を継ぐ)。"""
    # 自分の出力を先に出し切る。子プロセスの出力と、順が入れ替わらないようにするためである。
    sys.stdout.flush()
    sys.stderr.flush()
    try:
        return subprocess.run(gradle_command(build_directory, arguments), cwd=build_directory, check=False).returncode
    except OSError as error:
        raise VerificationError(f"Gradle を実行できない: {build_directory} ({error})") from error


def run_gradle_and_read(build_directory: str, arguments: list[str]) -> tuple[int, str]:
    """Gradle を流し、標準出力を、この確認の出力へそのまま流しながら読み取る。

    シェルの `コマンド | tee` とは違い、Gradle の終了コードをそのまま返す。
    """
    sys.stdout.flush()
    sys.stderr.flush()
    captured: list[str] = []
    try:
        with subprocess.Popen(
            gradle_command(build_directory, arguments),
            cwd=build_directory,
            stdout=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        ) as process:
            assert process.stdout is not None
            for line in process.stdout:
                sys.stdout.write(line)
                captured.append(line)
            sys.stdout.flush()
            return process.wait(), "".join(captured)
    except OSError as error:
        raise VerificationError(f"Gradle を実行できない: {build_directory} ({error})") from error


def announce(title: str) -> None:
    print(f"==== {title} ====", flush=True)


def publish_library(repository_root: str, version: str, maven_repository: str) -> None:
    """本体を、作業用の Maven リポジトリへ発行する。"""
    announce(f"本体を作業用の Maven リポジトリへ発行する ({COORDINATE}:{version})")
    code = run_gradle(
        os.path.join(repository_root, LIBRARY_BUILD),
        [f"-D{LOCAL_REPOSITORY_PROPERTY}={maven_repository}", f"-Pversion={version}", PUBLISH_TASK],
    )
    if code != 0:
        raise VerificationError(f"本体の発行が失敗した (Gradle の終了コード {code})。理由は、上の Gradle の出力にある")

    # 求めた版が、渡した場所に発行されたことを確かめる。発行先や版がずれたまま先へ進むと、
    # 利用者役が解決できない理由が、発行の側にあることが分からなくなる。
    pom = os.path.join(maven_repository, *GROUP.split("."), ARTIFACT, version, f"{ARTIFACT}-{version}.pom")
    if not os.path.isfile(pom):
        raise VerificationError(
            f"発行は成功で終わったが、作業用の Maven リポジトリに {COORDINATE}:{version} の POM が無い"
        )


def consumer_arguments(request_mode: str, version: str, maven_repository: str | None) -> list[str]:
    """利用者役のビルドに渡す、取得元と版の指定。"""
    arguments = [f"-PksCollectionViewMode={request_mode}", f"-PksCollectionViewVersion={version}"]
    if maven_repository is not None:
        arguments.append(f"-PksCollectionViewRepository={maven_repository}")
    return arguments


def assemble_consumer(repository_root: str, arguments: list[str]) -> None:
    """利用者役のリリースを組み立て、コード縮小の対応表ができたことを確かめる。"""
    mapping = os.path.join(repository_root, MAPPING)
    # 前の回の対応表を消しておく。残っていると、今回コード縮小が走らなくても、あるように見える。
    if os.path.lexists(mapping):
        os.remove(mapping)

    announce("利用者役のリリースを組み立てる (コード縮小あり)")
    code = run_gradle(os.path.join(repository_root, CONSUMER_BUILD), [*arguments, ASSEMBLE_TASK])
    if code != 0:
        raise VerificationError(
            f"利用者役の組み立てが失敗した (Gradle の終了コード {code})。理由は、上の Gradle の出力にある"
        )
    if not os.path.isfile(mapping) or os.path.getsize(mapping) == 0:
        raise VerificationError(
            f"組み立ては成功で終わったが、コード縮小の対応表が無い: {MAPPING} (コード縮小が走っていない)"
        )


def resolved_versions(dependency_tree: str) -> list[str]:
    """依存の一覧から、本ライブラリが解決された版を集める。

    解決できなかった行があれば VerificationError を投げる。
    """
    versions: list[str] = []
    for line in dependency_tree.splitlines():
        match = DEPENDENCY_LINE.search(line)
        if not match:
            continue
        if match.group("failed"):
            raise VerificationError(f"依存の一覧で、本ライブラリが解決できていない: {line.strip()}")
        versions.append(match.group("resolved") or match.group("requested"))
    return versions


def check_dependencies(repository_root: str, arguments: list[str], version: str) -> None:
    """実行時の依存に、本ライブラリの座標が指定の版で現れることを確かめる。"""
    announce(f"利用者役の実行時の依存を確かめる ({RUNTIME_CONFIGURATION})")
    code, output = run_gradle_and_read(
        os.path.join(repository_root, CONSUMER_BUILD),
        [*arguments, "--quiet", DEPENDENCIES_TASK, "--configuration", RUNTIME_CONFIGURATION],
    )
    if code != 0:
        raise VerificationError(
            f"依存の一覧を取れなかった (Gradle の終了コード {code})。理由は、上の Gradle の出力にある"
        )
    versions = resolved_versions(output)
    if not versions:
        raise VerificationError(f"実行時の依存の一覧に {COORDINATE} が無い")
    unexpected = sorted({found for found in versions if found != version})
    if unexpected:
        raise VerificationError(
            f"{COORDINATE} が、指定の版 {version} ではなく {' / '.join(unexpected)} に解決されている"
        )


def verify(request: Request, repository_root: str) -> str:
    """確認を行い、確かめた版を返す。失敗したら VerificationError を投げる。"""
    if request.mode == "published":
        assert request.version is not None
        version = request.version
        arguments = consumer_arguments(request.mode, version, None)
        assemble_consumer(repository_root, arguments)
        check_dependencies(repository_root, arguments, version)
        return version

    version = request.version or catalog_version(repository_root)
    with tempfile.TemporaryDirectory(prefix="kscollectionview-maven-") as maven_repository:
        # Gradle が発行先の表記を揃えても食い違わないように、実体のパスにしておく。
        maven_repository = os.path.realpath(maven_repository)
        publish_library(repository_root, version, maven_repository)
        arguments = consumer_arguments(request.mode, version, maven_repository)
        assemble_consumer(repository_root, arguments)
        check_dependencies(repository_root, arguments, version)
    return version


def main(argv: list[str] | None = None) -> int:
    try:
        request = parse_request(argv)
    except UsageError as error:
        ci_report.emit_errors([str(error)])
        return 2

    try:
        version = verify(request, REPOSITORY_ROOT)
    except VerificationError as error:
        ci_report.emit_errors([str(error)])
        return 1

    source = "作業用の Maven リポジトリ (今の本体を発行したもの)" if request.mode == "local" else "Maven Central"
    ci_report.emit_summary(
        [
            "### Android の利用者の立場のビルドの確認",
            "",
            f"- 切り替え: `{request.mode}` (取得元: {source})",
            f"- 確かめた座標: `{COORDINATE}:{version}`",
            "- 利用者役のリリースの組み立て (コード縮小あり): 成功",
            f"- 実行時の依存 (`{RUNTIME_CONFIGURATION}`) に、上の座標が指定の版で現れる: 確認した",
        ]
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
