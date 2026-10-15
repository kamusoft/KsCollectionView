#!/usr/bin/env python3
"""公開の宣言の名前が、利用者向け Skill に現れているかを報告する。

各プラットフォームの本体のソースから、公開の宣言の名前 (型・関数と修飾子・プロパティ・列挙の値)
を拾い、そのプラットフォームの Skill の英語版と日本語版のそれぞれに、一度も現れない名前を
漏れとして出す。相手のプラットフォームの名前は数えない。引数の名前と初期化の宣言は拾わない。
iOS の、利用者向けでない印 (@_spi) の付いた宣言も拾わない。拾い方の細部と限界は、
public_api.py の冒頭に書いてある。

  プラットフォーム  ソースの置き場                        Skill
  iOS               ios/Sources/                          skills/{en,ja}/kscollectionview-ios/
  Android           android/kscollectionview/src/main/    skills/{en,ja}/kscollectionview-android/

名前が現れるかどうかは、Skill の中の Markdown (.md) のすべての文面 (本文とコードブロック) から、
名前そのものを探して決める。名前の前後に英数字と "_" が続く場所は数えない (ほかの名前の一部を
数えないため)。大文字と小文字は区別する。短い一般の言葉と同じ名前 (end・all・key など) は、
英語の本文の中の同じ言葉でも現れたことになる。

追従の記録 (skills/.manifest.json) の apiExclusions にある名前は、漏れとして出さない。
apiExclusions にあるのに、ソースの公開の宣言に無くなった名前は、古い項目として出す。

Skill もソースも記録も書き換えない。git も呼ばない。

使い方:
  python3 scripts/docs/check-api-coverage.py                  # このリポジトリを確かめる
  python3 scripts/docs/check-api-coverage.py --list           # 拾った名前の一覧も出す
  python3 scripts/docs/check-api-coverage.py --root <ルート>  # 別の作業ツリーを確かめる

終了コード:
  0  漏れが無い (古い項目だけがあるときも 0。古い項目は出力に出る)
  1  漏れがある
  2  引数の誤り
  3  確かめられなかった (公開の宣言を 1 つも拾えない・Skill が無い・記録を読めない)。
     漏れが 0 件とは出さない
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(HERE))

sys.path.insert(0, HERE)
import public_api  # noqa: E402
import skills_manifest  # noqa: E402

SKILLS = "skills"
LANGUAGES = (("en", "英語版"), ("ja", "日本語版"))

EXIT_OK = 0
EXIT_MISSING = 1
EXIT_USAGE = 2
EXIT_UNCHECKED = 3


class CoverageError(Exception):
    """確かめられなかった。メッセージは、そのまま利用者に見せる。"""


def skill_directory(language: str, platform: public_api.Platform) -> str:
    return f"{SKILLS}/{language}/{platform.skill}"


def read_skill(root: str, language: str, platform: public_api.Platform) -> str:
    """Skill の中の Markdown のすべての文面を、つないで返す。"""
    relative = skill_directory(language, platform)
    base = os.path.join(root, *relative.split("/"))
    if not os.path.isdir(base):
        raise CoverageError(f"{platform.title} の Skill が無い: {relative}")
    texts: list[str] = []
    for directory, _, names in sorted(os.walk(base)):
        for name in sorted(names):
            if name.endswith(".md"):
                with open(os.path.join(directory, name), encoding="utf-8") as f:
                    texts.append(f.read())
    if not texts:
        raise CoverageError(f"{platform.title} の Skill に、Markdown が 1 枚も無い: {relative}")
    return "\n".join(texts)


def appears(name: str, text: str) -> bool:
    return re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", text) is not None


def describe(declarations: list[public_api.Declaration]) -> str:
    """名前を持つ宣言を、人が読む 1 行にする (何の宣言で、どこにあるか)。"""
    parts = []
    for declaration in declarations:
        owner = f"{declaration.owner} の" if declaration.owner else "最上位の"
        parts.append(f"{owner}{declaration.kind} ({declaration.path}:{declaration.line})")
    return " / ".join(parts)


def check(root: str, list_names: bool) -> int:
    manifest = skills_manifest.load_manifest(root)

    # 先に、すべてのプラットフォームと言語を読む。どれかを読めなければ、何も報告せずに止める。
    collected = []
    for platform in public_api.PLATFORMS:
        extraction = public_api.collect(root, platform)
        names = extraction.names()
        if not names:
            raise CoverageError(
                f"{platform.title} の公開の宣言を 1 つも拾えない: {platform.source_root}"
                f" (置き場が変わっていないか、public_api.py の拾い方が合っているかを確かめる)"
            )
        skills = {language: read_skill(root, language, platform) for language, _ in LANGUAGES}
        collected.append((platform, extraction, names, skills))

    missing_count = 0
    stale_count = 0
    for platform, extraction, names, skills in collected:
        exclusions = manifest.api_exclusions[platform.key]
        named = sum(len(declarations) for declarations in names.values())
        print(
            f"{platform.title}: 拾った名前 {len(names)} 個 (名前を持つ宣言 {named} 個)"
            f"・載せないと決めた名前 {len(exclusions)} 個"
        )
        if list_names:
            for name in sorted(names):
                mark = " [載せないと決めた名前]" if name in exclusions else ""
                print(f"  名前: {name}{mark} — {describe(names[name])}")
        for unparsed in extraction.unparsed:
            print(f"  読み取れなかった public の行: {unparsed.path}:{unparsed.line}: {unparsed.text}")
        for language, language_title in LANGUAGES:
            for name in sorted(names):
                if name in exclusions or appears(name, skills[language]):
                    continue
                missing_count += 1
                print(
                    f"  漏れ: {platform.title} / {language_title} ({skill_directory(language, platform)}):"
                    f" {name} — {describe(names[name])}"
                )
        for name in sorted(exclusions):
            if name not in names:
                stale_count += 1
                print(
                    f"  古い項目: {platform.title}: {name} — 載せないと決めた名前の一覧にあるが、"
                    f"ソースの公開の宣言に無い ({skills_manifest.MANIFEST_PATH} の apiExclusions.{platform.key})"
                )

    if stale_count:
        print(f"古い項目 {stale_count} 件")
    if missing_count:
        print(f"公開の宣言の名前の網羅: 漏れ {missing_count} 件")
        return EXIT_MISSING
    print("公開の宣言の名前の網羅: 漏れ 0 件")
    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="公開の宣言の名前が、利用者向け Skill に現れているかを報告する")
    parser.add_argument("--root", default=REPOSITORY_ROOT, help="リポジトリのルート (既定は、このリポジトリ)")
    parser.add_argument("--list", action="store_true", dest="list_names", help="拾った名前の一覧も出す")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.root):
        print(f"エラー: リポジトリのルートが、実在するディレクトリではない: {args.root}", file=sys.stderr)
        return EXIT_USAGE
    try:
        return check(os.path.abspath(args.root), args.list_names)
    except (CoverageError, skills_manifest.ManifestError, OSError) as error:
        print(f"エラー: {error}", file=sys.stderr)
        return EXIT_UNCHECKED


if __name__ == "__main__":
    sys.exit(main())
