#!/usr/bin/env python3
"""Android の発行物 (Maven のリポジトリのディレクトリに置いたもの) を、送る前に確かめる。

リリースの workflow は、組み立ての段で署名しない発行物を作って利用者役で確かめ、公開のジョブで
署名して組み立て直してから Maven Central へ送る。この道具は、次を確かめる。何も書き換えず、
何も送らない。

--reference だけを渡したとき (組み立ての段の発行物):
  - その版の置き場に、POM・Gradle のモジュールの情報 (.module)・AAR がある
  - POM の座標が jp.kamusoft:kscollectionview:<版> で、版が入力の版である (-SNAPSHOT ではない)
  - --commit を渡したら、POM の scm の tag (元になった commit) がその commit である

--signed も渡したとき (公開のジョブで署名して組み立て直した発行物)、上に加えて:
  - 署名したほうの発行物のファイルのそれぞれに、署名 (.asc) があり、中身が ASCII armor の
    PGP の署名の形である
  - 両方の発行物のファイルの一覧が同じで、各ファイルの中身がバイト単位で同じである
    (比べるのは発行物のファイルだけ。署名 (.asc)・チェックサム (.md5・.sha1・.sha256・.sha512)・
    maven-metadata は比べない)

ビルドが同じ入力から同じバイトを作ること (Gradle の既定で、アーカイブの時刻とファイルの順が
固定される) を前提にしている。前提が崩れると、中身が同じでも食い違いとして止まる。

使い方:
  python3 scripts/release/check-android-artifacts.py --version <版> --reference <Maven のリポジトリ>
      [--signed <Maven のリポジトリ>] [--commit <ID>]

  Maven のリポジトリは、-Dmaven.repo.local で publishToMavenLocal の行き先にしたディレクトリなど、
  jp/kamusoft/kscollectionview/<版>/ を含むディレクトリを渡す。

secret は要らない。ネットワークは使わない。step の出力は無い。

終了コード:
  0  確かめが通った
  1  確かめが外れた (発行物が欠けている・座標や commit が違う・署名が欠けている・中身が違う)
  2  引数の誤り
"""

from __future__ import annotations

import argparse
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import release_support as support  # noqa: E402

SIGNATURE_SUFFIX = ".asc"
CHECKSUM_SUFFIXES = (".md5", ".sha1", ".sha256", ".sha512")
REQUIRED_SUFFIXES = (".pom", ".module", ".aar")
SIGNATURE_HEADER = b"-----BEGIN PGP SIGNATURE-----"


def is_publication_file(name: str) -> bool:
    """発行物のファイルか (署名・チェックサム・maven-metadata でないか)。"""
    if name.startswith("maven-metadata"):
        return False
    return not name.endswith((SIGNATURE_SUFFIX, *CHECKSUM_SUFFIXES))


def publication_files(directory: str) -> list[str]:
    return sorted(
        name for name in os.listdir(directory) if os.path.isfile(os.path.join(directory, name)) and is_publication_file(name)
    )


def read_bytes(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


def check_publication(maven_repository: str, version: str, commit: str | None, label: str) -> tuple[str, list[str], list[str]]:
    """1 つの発行物の置き場を確かめる。(置き場, 発行物のファイルの一覧, 問題の一覧) を返す。"""
    directory = support.artifact_directory(maven_repository, version)
    if not os.path.isdir(directory):
        return directory, [], [f"{label}: 版 {version} の発行物の置き場が無い ({directory})"]
    files = publication_files(directory)
    problems = []
    prefix = f"{support.MAVEN_ARTIFACT}-{version}"
    for suffix in REQUIRED_SUFFIXES:
        if prefix + suffix not in files:
            problems.append(f"{label}: {prefix}{suffix} が無い")
    pom_name = prefix + ".pom"
    if pom_name in files:
        try:
            pom = support.read_pom(read_bytes(os.path.join(directory, pom_name)).decode("utf-8"))
        except (support.ReleaseError, UnicodeDecodeError) as error:
            problems.append(f"{label}: POM を読めない: {error}")
        else:
            expected = {"groupId": support.MAVEN_GROUP, "artifactId": support.MAVEN_ARTIFACT, "version": version}
            for key, value in expected.items():
                if pom[key] != value:
                    problems.append(f"{label}: POM の {key} が {pom[key]!r} (期待: {value!r})")
            if commit is not None and pom["scmTag"] != commit:
                problems.append(f"{label}: POM の元になった commit (scm の tag) が {pom['scmTag']!r} (期待: {commit!r})")
    return directory, files, problems


def check_signed(reference_directory: str, reference_files: list[str], signed_directory: str, signed_files: list[str]) -> list[str]:
    problems = []
    for name in signed_files:
        signature = os.path.join(signed_directory, name + SIGNATURE_SUFFIX)
        if not os.path.isfile(signature):
            problems.append(f"署名したほう: {name} の署名 ({name}{SIGNATURE_SUFFIX}) が無い")
        elif not read_bytes(signature).lstrip().startswith(SIGNATURE_HEADER):
            problems.append(f"署名したほう: {name}{SIGNATURE_SUFFIX} が PGP の署名の形でない")
    only_reference = sorted(set(reference_files) - set(signed_files))
    only_signed = sorted(set(signed_files) - set(reference_files))
    if only_reference:
        problems.append(f"組み立ての段にだけある発行物: {', '.join(only_reference)}")
    if only_signed:
        problems.append(f"署名したほうにだけある発行物: {', '.join(only_signed)}")
    for name in sorted(set(reference_files) & set(signed_files)):
        if read_bytes(os.path.join(reference_directory, name)) != read_bytes(os.path.join(signed_directory, name)):
            problems.append(f"中身が組み立ての段と違う: {name}")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Android の発行物を、送る前に確かめる")
    parser.add_argument("--version", required=True)
    parser.add_argument("--reference", required=True, help="組み立ての段の発行物の Maven のリポジトリ")
    parser.add_argument("--signed", help="署名して組み立て直した発行物の Maven のリポジトリ")
    parser.add_argument("--commit", help="POM に書かれているはずの、元になった commit")
    args = parser.parse_args(argv)

    problems = []
    for problem in (support.check_version(args.version), args.commit is not None and support.check_commit(args.commit)):
        if problem:
            problems.append(problem)
    if problems:
        support.emit_errors(problems)
        return 1

    reference_directory, reference_files, problems = check_publication(args.reference, args.version, args.commit, "組み立ての段")
    checked = [f"組み立ての段: {reference_directory} ({len(reference_files)} ファイル)"]
    if args.signed is not None:
        signed_directory, signed_files, signed_problems = check_publication(args.signed, args.version, args.commit, "署名したほう")
        problems.extend(signed_problems)
        if os.path.isdir(signed_directory) and os.path.isdir(reference_directory):
            problems.extend(check_signed(reference_directory, reference_files, signed_directory, signed_files))
        checked.append(f"署名したほう: {signed_directory} ({len(signed_files)} ファイル)")

    if problems:
        support.emit_errors(problems)
        return 1
    support.emit_summary([f"Android の発行物 {support.MAVEN_GROUP}:{support.MAVEN_ARTIFACT}:{args.version} を確かめた", *checked])
    return 0


if __name__ == "__main__":
    sys.exit(main())
