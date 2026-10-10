#!/usr/bin/env python3
"""README の例が、利用者役と同じであることを確かめる。

確かめるのは 2 つ。どちらも、渡したリポジトリのルートの下のファイルだけを読み、何も書き換えない。

最小コード例
  ルートの README の 2 枚 (README.md・README_ja.md) の、最小コード例の節にある Swift と
  Kotlin のコードブロックが、利用者役の画面のファイルの全体と同じ内容であること。節は、
  見出しの文面で見つける。節・コードブロック・利用者役のファイルのどれかが見つからない
  ときは、違反にする。

インストール例
  ルートの README の 2 枚と、各プラットフォームの SKILL.md (英語版と日本語版) の、コード
  ブロックの中の依存の宣言の行について、次を確かめる。
    - 値 (Package URL・package の名前・product の名前・Maven の座標) が、利用者役が公開済みの
      配布物を取るときに使う値と同じである
    - 版の位置が {version} で、具体の版が無い (cross/ADR-0018)
    - 最新の版の確かめ先の URL が、同じファイルにある
    - README は SwiftPM と Gradle の両方の例を、iOS の SKILL.md は SwiftPM の例を、Android の
      SKILL.md は Gradle の例を持つ
    - 英語版と日本語版で、例の種類と数が同じである
  対象のファイルが無いとき、対象のファイルに例が無いときは、違反にする。

依存の宣言の行として数えるのは、コードブロックの中の、次の形の行である。文の中に書いた
同じ字面は数えない。

  SwiftPM の Package URL の行   .package(url: "<Package URL>", exact: "{version}")
  SwiftPM の product の行       .product(name: "<product>", package: "<package>")
  Gradle の依存の行             implementation("<group>:<artifact>:{version}")

コードブロックの中で、本ライブラリの Package URL か Maven の座標 (どちらも利用者役の使う値) に
触れている行は、上の形でなければ違反にする。行末にコメントを足した行・別の書き方 (Groovy・
api(...))・複数行に分けた宣言のどれに具体の版を書いても、通さないためである。

比べる相手の値は、次から取る。
  - iOS の確認のスクリプト (scripts/ci/verify-consumer-ios.py) が、公開済みの配布物を取る
    ときに利用者役のマニフェストへ差し込む行
  - 利用者役のマニフェストのひな形 (verification/ios/Package.swift.template) の product の行
  - Android の利用者役 (verification/android/app/build.gradle.kts) の、版を変数で書いた依存の行
最新の版の確かめ先の URL は、一覧のデータ (user-docs-rules.json) から取る。

使い方:
  python3 scripts/ci/check-readme-examples.py <リポジトリのルート>
  python3 scripts/ci/check-readme-examples.py .

終了コード:
  0  違反が無い
  1  違反がある / 比べる相手の値を読み取れない
  2  引数の誤り (ルートが実在するディレクトリでない)。何も比べていない
"""

from __future__ import annotations

import argparse
import dataclasses
import importlib.util
import os
import re
import sys

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, HERE)
import ci_report  # noqa: E402
import user_docs  # noqa: E402

VERSION_PLACEHOLDER = "{version}"


@dataclasses.dataclass(frozen=True)
class Readme:
    path: str
    # 最小コード例の節の見出しの文面。
    example_heading: str


READMES = (
    Readme("README.md", "Minimal code examples"),
    Readme("README_ja.md", "最小コード例"),
)


@dataclasses.dataclass(frozen=True)
class Platform:
    title: str
    # README のコードブロックの言語の名前。
    language: str
    # 利用者役の画面のファイル。
    source: str


PLATFORMS = (
    Platform("iOS", "swift", "verification/ios/Sources/VerificationApp/ItemListScreen.swift"),
    Platform("Android", "kotlin", "verification/android/app/src/main/kotlin/ItemListScreen.kt"),
)

# 比べる相手の値の出どころ。
IOS_CONSUMER_SCRIPT = "scripts/ci/verify-consumer-ios.py"
IOS_MANIFEST_TEMPLATE = "verification/ios/Package.swift.template"
ANDROID_BUILD_FILE = "verification/android/app/build.gradle.kts"

# 例の種類。違反の文面にも使う。
SWIFTPM_PACKAGE = "SwiftPM の Package URL の行"
SWIFTPM_PRODUCT = "SwiftPM の product の行"
GRADLE = "Gradle の依存の行"
SWIFTPM_KINDS = (SWIFTPM_PACKAGE, SWIFTPM_PRODUCT)
ALL_KINDS = (SWIFTPM_PACKAGE, SWIFTPM_PRODUCT, GRADLE)

LANGUAGES = ("en", "ja")
# インストール例を持つファイルの組 (英語版, 日本語版) と、持つはずの例の種類。
INSTALL_TARGETS: tuple[tuple[tuple[str, str], tuple[str, ...]], ...] = (
    (("README.md", "README_ja.md"), ALL_KINDS),
    (tuple(f"skills/{language}/kscollectionview-ios/SKILL.md" for language in LANGUAGES), SWIFTPM_KINDS),
    (tuple(f"skills/{language}/kscollectionview-android/SKILL.md" for language in LANGUAGES), (GRADLE,)),
)

PACKAGE_LINE = re.compile(r'^\s*\.package\(\s*url:\s*"(?P<url>[^"]*)"\s*,\s*(?P<requirement>.*?)\s*\)\s*,?\s*$')
PRODUCT_LINE = re.compile(
    r'^\s*\.product\(\s*name:\s*"(?P<product>[^"]*)"\s*,\s*package:\s*"(?P<package>[^"]*)"\s*\)\s*,?\s*$'
)
GRADLE_LINE = re.compile(r'^\s*implementation\(\s*"(?P<notation>[^"]*)"\s*\)\s*$')
# 利用者役の依存の行のうち、版を変数で書いたもの (本ライブラリの行)。
GRADLE_CONSUMER_LINE = re.compile(
    r'^\s*implementation\(\s*"(?P<group>[^":$]+):(?P<artifact>[^":$]+):\$\{?\w+\}?"\s*\)\s*$'
)


class SourceError(Exception):
    """比べる相手の値を読み取れない。メッセージは、そのまま違反として出す。"""


@dataclasses.dataclass(frozen=True)
class Expected:
    """利用者役が、公開済みの配布物を取るときに使う値。"""

    package_url: str
    # Package URL の後ろに書く、版の指定。版の位置は {version}。
    requirement: str
    product: str
    package: str
    # Maven の座標 (group:artifact)。
    coordinate: str


def local_path(root: str, relative: str) -> str:
    """"/" 区切りのリポジトリ相対のパスを、この OS のパスへ組み立てる。"""
    return os.path.join(root, *relative.split("/"))


# ---- 最小コード例 ----


def example_blocks(document: user_docs.Document, heading_title: str) -> list[user_docs.CodeBlock] | None:
    """最小コード例の節の中のコードブロックを返す。節がちょうど 1 つ無ければ None を返す。"""
    found = [heading for heading in document.headings if heading.title == heading_title]
    if len(found) != 1:
        return None
    section = found[0]
    # 節は、同じ深さか、それより浅い次の見出しの手前まで。
    end = min(
        (heading.line for heading in document.headings if heading.line > section.line and heading.level <= section.level),
        default=None,
    )
    return [block for block in document.code_blocks if block.line > section.line and (end is None or block.line < end)]


def first_difference(example: str, source: str) -> str:
    """2 つの文面が最初に食い違う行を、違反の文面に添える形で返す。"""
    example_lines, source_lines = example.splitlines(), source.splitlines()
    for number, (left, right) in enumerate(zip(example_lines, source_lines), start=1):
        if left != right:
            return f"{number} 行目が違う (README: {left!r} / 利用者役: {right!r})"
    if len(example_lines) != len(source_lines):
        return f"行の数が違う (README: {len(example_lines)} 行 / 利用者役: {len(source_lines)} 行)"
    return "末尾の改行が違う"


def check_minimal_examples(root: str) -> tuple[list[str], int]:
    """最小コード例を比べる。(違反の一覧, 一致した例の数) を返す。"""
    violations: list[str] = []
    matched = 0

    sources: dict[str, str | None] = {}
    for platform in PLATFORMS:
        sources[platform.title] = user_docs.read_text(local_path(root, platform.source))
        if sources[platform.title] is None:
            violations.append(f"{platform.source}: 利用者役の画面のファイルが無い ({platform.title})")

    for readme in READMES:
        text = user_docs.read_text(local_path(root, readme.path))
        if text is None:
            violations.append(f"{readme.path}: ファイルが無い")
            continue
        document = user_docs.parse_markdown(text)
        if document.unclosed_fence is not None:
            violations.append(f"{readme.path}:{document.unclosed_fence}: コードブロックが閉じていない")
            continue
        blocks = example_blocks(document, readme.example_heading)
        if blocks is None:
            violations.append(f"{readme.path}: 最小コード例の節の見出し「{readme.example_heading}」が、ちょうど 1 つ無い")
            continue
        for platform in PLATFORMS:
            examples = [block for block in blocks if block.language == platform.language]
            if len(examples) != 1:
                violations.append(
                    f"{readme.path}: 最小コード例の節に、{platform.title} の例"
                    f" ({platform.language} のコードブロック) がちょうど 1 つ無い ({len(examples)} つ)"
                )
                continue
            source = sources[platform.title]
            if source is None:
                continue
            if examples[0].text != source:
                violations.append(
                    f"{readme.path}:{examples[0].line}: {platform.title} の最小コード例が、利用者役の画面の"
                    f"ファイル ({platform.source}) と違う: {first_difference(examples[0].text, source)}"
                )
                continue
            matched += 1
    return violations, matched


# ---- インストール例 ----


def consumer_package_line(root: str) -> str:
    """iOS の確認のスクリプトが、公開済みの配布物を取るときに差し込む行を返す。"""
    path = local_path(root, IOS_CONSUMER_SCRIPT)
    if not os.path.isfile(path):
        raise SourceError(f"{IOS_CONSUMER_SCRIPT}: iOS の確認のスクリプトが無い (インストール例と比べる値を取れない)")
    # 同じ名前のモジュールを読み込み済みでも、渡したルートの下のものを読む。
    name = f"_user_docs_consumer_ios_{abs(hash(path))}"
    saved_path = list(sys.path)
    try:
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        # dataclass は、定義したモジュールを sys.modules から引く。
        sys.modules[name] = module
        spec.loader.exec_module(module)
        return str(module.dependency_line(module.Request(mode="published", version=VERSION_PLACEHOLDER)))
    except Exception as error:  # noqa: BLE001 — 読み込み先の誤りは、種類を問わず違反として出す。
        raise SourceError(
            f"{IOS_CONSUMER_SCRIPT}: 公開済みの配布物を取るときに差し込む行を取れない ({error!r})"
        ) from error
    finally:
        sys.modules.pop(name, None)
        sys.path[:] = saved_path


def single_match(root: str, relative: str, pattern: re.Pattern[str], what: str) -> re.Match[str]:
    """ファイルの中で、形に当たる行がちょうど 1 つあることを確かめて返す。"""
    text = user_docs.read_text(local_path(root, relative))
    if text is None:
        raise SourceError(f"{relative}: ファイルが無い (インストール例と比べる値を取れない)")
    found = [matched for matched in map(pattern.match, text.splitlines()) if matched]
    if len(found) != 1:
        raise SourceError(f"{relative}: {what}が、ちょうど 1 つ無い ({len(found)} つ)")
    return found[0]


def load_expected(root: str) -> Expected:
    """比べる相手の値を、利用者役から取る。取れなければ SourceError を投げる。"""
    line = consumer_package_line(root)
    package = PACKAGE_LINE.match(line)
    if package is None or VERSION_PLACEHOLDER not in package.group("requirement"):
        raise SourceError(f"{IOS_CONSUMER_SCRIPT}: 差し込む行が、Package URL と版の指定の形でない: {line!r}")
    product = single_match(root, IOS_MANIFEST_TEMPLATE, PRODUCT_LINE, "product の行")
    gradle = single_match(root, ANDROID_BUILD_FILE, GRADLE_CONSUMER_LINE, "版を変数で書いた依存の行")
    return Expected(
        package_url=package.group("url"),
        requirement=package.group("requirement"),
        product=product.group("product"),
        package=product.group("package"),
        coordinate=f"{gradle.group('group')}:{gradle.group('artifact')}",
    )


def check_install_line(kind: str, matched: re.Match[str], expected: Expected) -> list[str]:
    """依存の宣言の 1 行を、利用者役の値と比べる。違う点を返す。"""
    problems: list[str] = []
    if kind == SWIFTPM_PACKAGE:
        if matched.group("url") != expected.package_url:
            problems.append(
                f"Package URL が、利用者役の使う値と違う ({matched.group('url')!r}。利用者役: {expected.package_url!r})"
            )
        if matched.group("requirement") != expected.requirement:
            problems.append(
                f"版の指定が {expected.requirement} でない ({matched.group('requirement')})。"
                f"版の位置には {VERSION_PLACEHOLDER} を置き、具体の版を書かない"
            )
    elif kind == SWIFTPM_PRODUCT:
        if matched.group("product") != expected.product:
            problems.append(
                f"product の名前が、利用者役の使う値と違う ({matched.group('product')!r}。利用者役: {expected.product!r})"
            )
        if matched.group("package") != expected.package:
            problems.append(
                f"package の名前が、利用者役の使う値と違う ({matched.group('package')!r}。利用者役: {expected.package!r})"
            )
    else:
        parts = matched.group("notation").split(":")
        coordinate, version = ":".join(parts[:2]), ":".join(parts[2:])
        if coordinate != expected.coordinate:
            problems.append(f"Maven の座標が、利用者役の使う値と違う ({coordinate!r}。利用者役: {expected.coordinate!r})")
        if version != VERSION_PLACEHOLDER:
            problems.append(
                f"版の位置が {VERSION_PLACEHOLDER} でない ({version!r})。具体の版を書かない"
            )
    return problems


INSTALL_PATTERNS = ((SWIFTPM_PACKAGE, PACKAGE_LINE), (SWIFTPM_PRODUCT, PRODUCT_LINE), (GRADLE, GRADLE_LINE))


def off_form_problems(line: str, expected: Expected) -> list[str]:
    """本ライブラリの値に触れているのに、決めた形でない行の問題を返す。

    決めた形でない行は、版の位置を読み取れない。具体の版を書いても見分けられないので、
    行そのものを違反にする。
    """
    own_values = (
        (
            expected.package_url,
            "Package URL",
            PACKAGE_LINE,
            f'.package(url: "{expected.package_url}", {expected.requirement})',
        ),
        (
            expected.coordinate,
            "Maven の座標",
            GRADLE_LINE,
            f'implementation("{expected.coordinate}:{VERSION_PLACEHOLDER}")',
        ),
    )
    return [
        f"本ライブラリの {title} ({value}) に触れている行が、決めた形 {form} でない ({line.strip()})。"
        f"1 行で、この形のとおりに書く。版の位置には {VERSION_PLACEHOLDER} を置き、具体の版を書かない"
        for value, title, pattern, form in own_values
        if value in line and not pattern.match(line)
    ]


def check_install_file(
    root: str, relative: str, required: tuple[str, ...], expected: Expected, latest_version_url: str
) -> tuple[list[str], dict[str, int] | None]:
    """1 つのファイルのインストール例を確かめる。(違反の一覧, 種類ごとの行の数) を返す。

    ファイルを読めなかったときは、行の数を None にする。
    """
    text = user_docs.read_text(local_path(root, relative))
    if text is None:
        return [f"{relative}: ファイルが無い (インストール例を確かめられない)"], None
    document = user_docs.parse_markdown(text)
    if document.unclosed_fence is not None:
        return [f"{relative}:{document.unclosed_fence}: コードブロックが閉じていない"], None

    violations: list[str] = []
    counts = {kind: 0 for kind in ALL_KINDS}
    for block in document.code_blocks:
        for offset, line in enumerate(block.text.splitlines(), start=1):
            for kind, pattern in INSTALL_PATTERNS:
                matched = pattern.match(line)
                if not matched:
                    continue
                counts[kind] += 1
                for problem in check_install_line(kind, matched, expected):
                    violations.append(f"{relative}:{block.line + offset}: {kind}: {problem}")
            for problem in off_form_problems(line, expected):
                violations.append(f"{relative}:{block.line + offset}: {problem}")

    for kind in required:
        if counts[kind] == 0:
            violations.append(f"{relative}: インストール例に、{kind}が無い (コードブロックの中に書く)")
    if latest_version_url not in user_docs.find_urls(text):
        violations.append(f"{relative}: 最新の版の確かめ先の URL が無い ({latest_version_url})")
    return violations, counts


def check_install_examples(root: str, rules: user_docs.Rules) -> tuple[list[str], int]:
    """インストール例を確かめる。(違反の一覧, 確かめた依存の宣言の行の数) を返す。"""
    latest_version_url = rules.allowed_urls.get(user_docs.ROLE_LATEST_VERSION)
    if latest_version_url is None:
        return [f"一覧のデータに、最新の版の確かめ先 (役割 {user_docs.ROLE_LATEST_VERSION}) の URL が無い"], 0
    try:
        expected = load_expected(root)
    except SourceError as error:
        return [str(error)], 0

    violations: list[str] = []
    checked = 0
    for pair, required in INSTALL_TARGETS:
        counted: list[dict[str, int] | None] = []
        for relative in pair:
            found, counts = check_install_file(root, relative, required, expected, latest_version_url)
            violations.extend(found)
            counted.append(counts)
            checked += sum(counts.values()) if counts else 0
        english, japanese = counted
        if english is not None and japanese is not None and english != japanese:
            differing = "・".join(
                f"{kind} {english[kind]} つ / {japanese[kind]} つ" for kind in ALL_KINDS if english[kind] != japanese[kind]
            )
            violations.append(
                f"{pair[0]} と {pair[1]}: 英語版と日本語版で、インストール例の種類と数が違う ({differing})"
            )
    return violations, checked


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="README の例が、利用者役と同じであることを確かめる")
    parser.add_argument("root", help="リポジトリのルート")
    args = parser.parse_args(argv)

    try:
        root = user_docs.require_root(args.root)
    except user_docs.UsageError as error:
        ci_report.emit_errors([str(error)])
        return 2

    try:
        rules = user_docs.load_rules()
    except user_docs.RulesError as error:
        ci_report.emit_errors([str(error)])
        return 1

    example_violations, matched = check_minimal_examples(root)
    install_violations, checked = check_install_examples(root, rules)
    violations = example_violations + install_violations
    if violations:
        ci_report.emit_errors(violations)
        print(f"README の例の検査: 違反 {len(violations)} 件")
        return 1

    # 違反が無いのに何も比べていなければ、検査が空振りしている。
    if matched != len(READMES) * len(PLATFORMS) or checked == 0:
        ci_report.emit_errors(["README の例の検査が、比べるはずのものを比べずに終わった"])
        return 1
    print(f"README の例の検査: 違反なし (一致した最小コード例 {matched} つ・確かめた依存の宣言の行 {checked} 行)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
