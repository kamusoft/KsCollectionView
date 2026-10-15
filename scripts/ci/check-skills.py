#!/usr/bin/env python3
"""利用者向け Skill (skills/{en,ja}/<名前>/) 自身の整合を確かめる。

Skill は、言語のディレクトリ (skills/en・skills/ja) の直下のディレクトリ 1 つである。渡した
リポジトリのルートの下の skills/ だけを読み、何も書き換えない。確かめるのは、次の 5 つ。

  1. 英語版と日本語版の一致
     Skill の集合・Skill の中のファイルの集合・見出しの深さの並び・コードブロックの中身
     (言語の名前を含む) と順番が同じである
  2. SKILL.md の frontmatter
     name・description・license・metadata.language・metadata.source の 5 項目だけを持つ。
     name がディレクトリの名前と同じで、metadata.language が置き場の言語と合う
  3. 相対のリンク
     リンクの先が、その Skill のディレクトリの中に実在する。Skill の外へ出るリンクは違反
     (知識を Skill の外に委ねる参照を持たない。cross/ADR-0019)。
     Markdown の書き方のリンク・画像と、HTML の書き方 (href・src の値) の両方を見る
  4. URL
     一覧にある URL (完全一致) か、見本の URL の前置き (前方一致) に当たるものだけである
     (操作の対象になる URL だけを持つ。cross/ADR-0019)
  5. 内部の言葉
     一覧にある言葉が、本文にもコードブロックにも現れない

2〜5 は、Skill の中の Markdown (.md) のすべてを見る。1 のファイルの集合は、Markdown でない
ファイルも数える。許可する URL と内部の言葉の一覧は、user-docs-rules.json に置いてある。

内部の言葉は、大文字と小文字を区別せずに探す。言葉の端が英数字のときは、その外側に英数字が
続かない場所だけを数える (ほかの単語の一部を数えないため)。

skills/ が無いとき、Skill が 1 つも無いときは、違反にする (何も確かめずに成功しない)。

使い方:
  python3 scripts/ci/check-skills.py <リポジトリのルート>
  python3 scripts/ci/check-skills.py .

終了コード:
  0  違反が無い
  1  違反がある
  2  引数の誤り (ルートが実在するディレクトリでない)。何も確かめていない
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import urllib.parse

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, HERE)
import ci_report  # noqa: E402
import user_docs  # noqa: E402

SKILLS = "skills"
LANGUAGES = ("en", "ja")
LANGUAGE_TITLES = {"en": "英語版", "ja": "日本語版"}
SKILL_FILE = "SKILL.md"
# frontmatter が持つ項目。入れ子は "." でつないで書く。
FRONTMATTER_FIELDS = ("name", "description", "license", "metadata.language", "metadata.source")
# OS が作る、追跡しないファイル。Skill のファイルとして数えない。
IGNORED_FILES = (".DS_Store",)

FRONTMATTER_FENCE = "---"
TOP_LEVEL_FIELD = re.compile(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$")
NESTED_FIELD = re.compile(r"^\s+([A-Za-z_][\w-]*):\s*(.*?)\s*$")

INLINE_CODE = re.compile(r"`[^`]*`")
INLINE_LINK = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REFERENCE_LINK = re.compile(r"^ {0,3}\[[^\]]+\]:\s*<?([^\s>]+)>?")
# HTML で書いたリンクと画像の先 (href・src の値)。タグが複数行に分かれていても拾えるように、
# タグの名前は見ない。値は、引用符で囲んだものと、囲んでいないものの両方を読む。
HTML_LINK = re.compile(r"""(?<![\w-])(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))""", re.IGNORECASE)
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
WEB_SCHEMES = ("http://", "https://")


def relative_path(*parts: str) -> str:
    """違反の文面に出す、"/" 区切りのリポジトリ相対のパス。"""
    return "/".join(parts)


def skill_names(root: str, language: str) -> list[str]:
    """言語のディレクトリの直下の Skill の名前を返す。"""
    base = os.path.join(root, SKILLS, language)
    if not os.path.isdir(base):
        return []
    return sorted(name for name in os.listdir(base) if os.path.isdir(os.path.join(base, name)))


def skill_files(skill_directory: str) -> list[str]:
    """Skill の中のファイルを、Skill のディレクトリからの "/" 区切りの相対のパスで返す。"""
    found: list[str] = []
    for directory, _, names in os.walk(skill_directory):
        for name in names:
            if name in IGNORED_FILES:
                continue
            relative = os.path.relpath(os.path.join(directory, name), skill_directory)
            found.append(relative.replace(os.sep, "/"))
    return sorted(found)


# ---- frontmatter ----


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def parse_frontmatter(text: str) -> tuple[dict[str, str], list[str]]:
    """frontmatter の項目を、名前 → 値 の対応で返す。読み取れなかった点も返す。

    読むのは「名前: 値」の行と、1 段だけの入れ子である。ほかの書き方は、読み取れない行として返す。
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != FRONTMATTER_FENCE:
        return {}, ["frontmatter が無い (先頭の行が --- でない)"]
    end = next((index for index, line in enumerate(lines[1:], start=1) if line.strip() == FRONTMATTER_FENCE), None)
    if end is None:
        return {}, ["frontmatter が閉じていない (終わりの --- が無い)"]

    fields: dict[str, str] = {}
    problems: list[str] = []
    # 値を持たない項目。次の行からの入れ子の親になる。
    parent: str | None = None
    parent_has_children = False

    def record(name: str, value: str) -> None:
        if name in fields:
            problems.append(f"frontmatter の項目 {name} が、2 回書かれている")
        fields[name] = unquote(value)

    def close_parent() -> None:
        # 値も入れ子も持たない項目は、空の値の項目として数える。
        if parent is not None and not parent_has_children:
            record(parent, "")

    for number, line in enumerate(lines[1:end], start=2):
        if not line.strip():
            continue
        top = TOP_LEVEL_FIELD.match(line)
        nested = NESTED_FIELD.match(line)
        if top:
            close_parent()
            parent, parent_has_children = None, False
            if top.group(2):
                record(top.group(1), top.group(2))
            else:
                parent = top.group(1)
        elif nested and parent is not None:
            parent_has_children = True
            record(f"{parent}.{nested.group(1)}", nested.group(2))
        else:
            problems.append(f"frontmatter の {number} 行目を読み取れない: {line.strip()!r}")
    close_parent()
    return fields, problems


def check_frontmatter(text: str, skill: str, language: str) -> list[str]:
    fields, problems = parse_frontmatter(text)
    if not fields and problems:
        return problems
    for name in fields:
        if name not in FRONTMATTER_FIELDS:
            problems.append(f"frontmatter に、決めていない項目がある: {name}")
    for name in FRONTMATTER_FIELDS:
        if name not in fields:
            problems.append(f"frontmatter に、項目 {name} が無い")
        elif not fields[name]:
            problems.append(f"frontmatter の項目 {name} の値が空である")
    if fields.get("name") and fields["name"] != skill:
        problems.append(f"frontmatter の name ({fields['name']}) が、ディレクトリの名前 ({skill}) と違う")
    if fields.get("metadata.language") and fields["metadata.language"] != language:
        problems.append(
            f"frontmatter の metadata.language ({fields['metadata.language']}) が、置き場の言語 ({language}) と違う"
        )
    return problems


# ---- リンク・URL・内部の言葉 ----


def link_targets(document: user_docs.Document) -> list[tuple[int, str]]:
    """コードの外に書かれたリンクの先を、(行の番号, 先) の並びで返す。"""
    found: list[tuple[int, str]] = []
    for number, line in document.prose:
        # 文の中のコードは、リンクとして読まない。
        plain = INLINE_CODE.sub("", line)
        found.extend((number, target) for target in INLINE_LINK.findall(plain))
        reference = REFERENCE_LINK.match(plain)
        if reference:
            found.append((number, reference.group(1)))
        for html in HTML_LINK.finditer(plain):
            found.append((number, next(value for value in html.groups() if value is not None).strip()))
    return found


def check_links(document: user_docs.Document, file_path: str, skill_directory: str) -> list[str]:
    problems: list[str] = []
    skill_real = os.path.realpath(skill_directory)
    for number, target in link_targets(document):
        if target.startswith("#") or target.startswith(WEB_SCHEMES):
            # 同じファイルの中への移動と、URL。URL は、URL の検査が見る。
            continue
        if SCHEME.match(target):
            problems.append(f"{number} 行目: http・https でないリンクがある: {target}")
            continue
        path = urllib.parse.unquote(re.split(r"[#?]", target, maxsplit=1)[0])
        if path.startswith("/"):
            problems.append(f"{number} 行目: Skill の外のファイルへのリンクがある: {target}")
            continue
        resolved = os.path.realpath(os.path.join(os.path.dirname(file_path), *path.split("/")))
        if os.path.commonpath([skill_real, resolved]) != skill_real:
            problems.append(f"{number} 行目: Skill の外のファイルへのリンクがある: {target}")
        elif not os.path.exists(resolved):
            problems.append(f"{number} 行目: リンクの先が無い: {target}")
    return problems


def check_urls(text: str, rules: user_docs.Rules) -> list[str]:
    problems: list[str] = []
    allowed = set(rules.allowed_urls.values())
    for number, line in enumerate(text.splitlines(), start=1):
        for url in user_docs.find_urls(line):
            if url in allowed or url.startswith(rules.sample_url_prefixes):
                continue
            problems.append(f"{number} 行目: 許可した一覧に無い URL がある: {url}")
    return problems


def term_pattern(term: str) -> re.Pattern[str]:
    """内部の言葉を探す形を作る。端が英数字のときは、外側に英数字が続かない場所だけに当てる。"""
    before = r"(?<![A-Za-z0-9])" if term[0].isascii() and term[0].isalnum() else ""
    after = r"(?![A-Za-z0-9])" if term[-1].isascii() and term[-1].isalnum() else ""
    return re.compile(before + re.escape(term) + after, re.IGNORECASE)


def check_terms(text: str, rules: user_docs.Rules) -> list[str]:
    problems: list[str] = []
    patterns = [(term, term_pattern(term)) for term in rules.internal_terms]
    for number, line in enumerate(text.splitlines(), start=1):
        for term, pattern in patterns:
            if pattern.search(line):
                problems.append(f"{number} 行目: 内部の言葉がある: {term}")
    return problems


# ---- 英語版と日本語版の一致 ----


def describe_names(names: set[str]) -> str:
    return "・".join(sorted(names))


def check_pair(root: str, skill: str, common_files: list[str]) -> list[str]:
    """同じ Skill の英語版と日本語版の、同じ名前の Markdown を比べる。"""
    violations: list[str] = []
    for file in common_files:
        if not file.endswith(".md"):
            continue
        documents = []
        for language in LANGUAGES:
            text = user_docs.read_text(os.path.join(root, SKILLS, language, skill, *file.split("/")))
            documents.append(user_docs.parse_markdown(text or ""))
        english, japanese = documents
        if english.unclosed_fence is not None or japanese.unclosed_fence is not None:
            # 閉じていないコードブロックは、ファイルごとの検査が違反として出す。
            continue
        where = f"{relative_path(SKILLS, 'ja', skill, file)} (英語版: {relative_path(SKILLS, 'en', skill, file)})"

        english_levels = [heading.level for heading in english.headings]
        japanese_levels = [heading.level for heading in japanese.headings]
        if english_levels != japanese_levels:
            violations.append(
                f"{where}: 見出しの深さの並びが、英語版と日本語版で違う"
                f" (英語版 {english_levels} / 日本語版 {japanese_levels})"
            )

        if len(english.code_blocks) != len(japanese.code_blocks):
            violations.append(
                f"{where}: コードブロックの数が、英語版と日本語版で違う"
                f" (英語版 {len(english.code_blocks)} つ / 日本語版 {len(japanese.code_blocks)} つ)"
            )
            continue
        for index, (left, right) in enumerate(zip(english.code_blocks, japanese.code_blocks), start=1):
            if (left.language, left.text) != (right.language, right.text):
                violations.append(
                    f"{where}: {index} つ目のコードブロックが、英語版と日本語版で違う"
                    f" (英語版 {left.line} 行目から / 日本語版 {right.line} 行目から)"
                )
    return violations


def check_skill_files(root: str, language: str, skill: str, files: list[str], rules: user_docs.Rules) -> list[str]:
    """1 つの Skill の中の Markdown を、1 枚ずつ確かめる。"""
    violations: list[str] = []
    skill_directory = os.path.join(root, SKILLS, language, skill)
    if SKILL_FILE not in files:
        violations.append(f"{relative_path(SKILLS, language, skill)}: {SKILL_FILE} が無い")
    for file in files:
        if not file.endswith(".md"):
            continue
        where = relative_path(SKILLS, language, skill, file)
        file_path = os.path.join(skill_directory, *file.split("/"))
        text = user_docs.read_text(file_path) or ""
        document = user_docs.parse_markdown(text)
        problems: list[str] = []
        if document.unclosed_fence is not None:
            problems.append(f"{document.unclosed_fence} 行目: コードブロックが閉じていない")
        if file == SKILL_FILE:
            problems.extend(check_frontmatter(text, skill, language))
        problems.extend(check_links(document, file_path, skill_directory))
        problems.extend(check_urls(text, rules))
        problems.extend(check_terms(text, rules))
        violations.extend(f"{where}: {problem}" for problem in problems)
    return violations


def check_skills(root: str, rules: user_docs.Rules) -> tuple[list[str], int, int]:
    """skills/ を確かめる。(違反の一覧, 確かめた Skill の数, 確かめた Markdown の数) を返す。"""
    if not os.path.isdir(os.path.join(root, SKILLS)):
        return [f"{SKILLS}/ が無い"], 0, 0
    names = {language: skill_names(root, language) for language in LANGUAGES}
    if not any(names.values()):
        return [f"{SKILLS}/ の下に、Skill が 1 つも無い ({SKILLS}/en・{SKILLS}/ja の直下のディレクトリ)"], 0, 0

    violations: list[str] = []
    english_names, japanese_names = set(names["en"]), set(names["ja"])
    for language, only in (("en", english_names - japanese_names), ("ja", japanese_names - english_names)):
        if only:
            violations.append(
                f"{relative_path(SKILLS, language)}: {LANGUAGE_TITLES[language]}にだけある Skill がある: {describe_names(only)}"
            )

    files = {
        (language, skill): skill_files(os.path.join(root, SKILLS, language, skill))
        for language in LANGUAGES
        for skill in names[language]
    }
    markdown_count = 0
    for (language, skill), found in files.items():
        violations.extend(check_skill_files(root, language, skill, found, rules))
        markdown_count += sum(1 for file in found if file.endswith(".md"))

    for skill in sorted(english_names & japanese_names):
        english_files, japanese_files = set(files[("en", skill)]), set(files[("ja", skill)])
        for language, only in (("en", english_files - japanese_files), ("ja", japanese_files - english_files)):
            if only:
                violations.append(
                    f"{relative_path(SKILLS, language, skill)}: {LANGUAGE_TITLES[language]}にだけあるファイルがある:"
                    f" {describe_names(only)}"
                )
        violations.extend(check_pair(root, skill, sorted(english_files & japanese_files)))

    return violations, len(files), markdown_count


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="利用者向け Skill 自身の整合を確かめる")
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

    violations, skill_count, markdown_count = check_skills(root, rules)
    if violations:
        ci_report.emit_errors(violations)
        print(f"Skill 自身の整合の検査: 違反 {len(violations)} 件")
        return 1
    # 違反が無いのに何も確かめていなければ、検査が空振りしている。
    if skill_count == 0 or markdown_count == 0:
        ci_report.emit_errors(["Skill 自身の整合の検査が、確かめるはずのものを確かめずに終わった"])
        return 1
    print(f"Skill 自身の整合の検査: 違反なし (Skill {skill_count} つ・Markdown {markdown_count} 枚)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
