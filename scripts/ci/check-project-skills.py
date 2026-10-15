#!/usr/bin/env python3
"""プロジェクト内の Skill (開発の作業で使う Skill) の置き場の形を確かめる。

プロジェクト内の Skill は、実体を .agents/skills/<名前>/ に 1 つだけ置き、Claude Code が読む
.claude/skills/<名前> を、その実体を指す相対のシンボリックリンクにする。codex は .agents/skills/ を、
Claude Code は .claude/skills/ を読むので、実体を 1 つにして 2 つの CLI に同じものを読ませる
(cross/ADR-0020)。利用者へ配る Skill (skills/) は、この検査の対象ではない (check-skills.py が見る)。

渡したリポジトリのルートの下を読むだけで、何も書き換えない。確かめるのは、次のとおり。

  実体 (.agents/skills/ の直下のディレクトリ 1 つずつ)
    - SKILL.md がある
    - SKILL.md の frontmatter の name が、ディレクトリの名前と同じである
    - SKILL.md の frontmatter の description が空でない
    - .claude/skills/<名前> がある・シンボリックリンクである・リンクの値が相対のパスである・
      リンクの先が、その実体のディレクトリである
  リンク (.claude/skills/ の直下のシンボリックリンク 1 つずつ)
    - リンクの先が、.agents/skills/ の下の同じ名前の実体である
      (.claude/skills/ に直接置いた、リンクでないディレクトリは見ない)

.agents/skills/ が無いとき、実体が 1 つも無いときは、違反にする (何も確かめずに成功しない)。

使い方:
  python3 scripts/ci/check-project-skills.py <リポジトリのルート>
  python3 scripts/ci/check-project-skills.py .

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

# 追跡しないファイル (バイトコードのキャッシュ) を作業ツリーに作らない。
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, HERE)
import ci_report  # noqa: E402

AGENTS_SKILLS = os.path.join(".agents", "skills")
CLAUDE_SKILLS = os.path.join(".claude", "skills")
SKILL_FILE = "SKILL.md"

FRONTMATTER_FENCE = "---"
TOP_LEVEL_FIELD = re.compile(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$")


def read_frontmatter(path: str) -> dict[str, str] | None:
    """SKILL.md の frontmatter の、最上位の項目を返す。frontmatter が無ければ None を返す。

    値は、前後の引用符を外した文字列にする。入れ子の項目は読まない。
    """
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines or lines[0].strip() != FRONTMATTER_FENCE:
        return None
    fields: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == FRONTMATTER_FENCE:
            return fields
        match = TOP_LEVEL_FIELD.match(line)
        if match:
            value = match.group(2)
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            fields[match.group(1)] = value
    # 閉じる区切りが無い。
    return None


def list_entries(directory: str) -> list[str]:
    """ディレクトリの直下の名前を、隠しファイルを除いて並べる。"""
    if not os.path.isdir(directory):
        return []
    return sorted(name for name in os.listdir(directory) if not name.startswith("."))


def check_entity(root: str, name: str) -> list[str]:
    """実体 1 つの SKILL.md と、それを指すリンクを確かめる。"""
    violations: list[str] = []
    entity = os.path.join(root, AGENTS_SKILLS, name)
    entity_label = f"{AGENTS_SKILLS}/{name}"
    skill_file = os.path.join(entity, SKILL_FILE)

    if not os.path.isfile(skill_file):
        violations.append(f"{entity_label}: {SKILL_FILE} が無い")
    else:
        fields = read_frontmatter(skill_file)
        if fields is None:
            violations.append(f"{entity_label}/{SKILL_FILE}: frontmatter が無い")
        else:
            if fields.get("name") != name:
                violations.append(
                    f"{entity_label}/{SKILL_FILE}: frontmatter の name ({fields.get('name') or '無し'}) が、"
                    f"ディレクトリの名前 ({name}) と違う"
                )
            if not fields.get("description"):
                violations.append(f"{entity_label}/{SKILL_FILE}: frontmatter の description が無い")

    link = os.path.join(root, CLAUDE_SKILLS, name)
    link_label = f"{CLAUDE_SKILLS}/{name}"
    if not os.path.lexists(link):
        violations.append(f"{link_label}: リンクが無い ({entity_label} を指す相対のリンクを置く)")
    elif not os.path.islink(link):
        violations.append(f"{link_label}: シンボリックリンクでない ({entity_label} を指す相対のリンクにする)")
    else:
        target = os.readlink(link)
        if os.path.isabs(target):
            violations.append(f"{link_label}: リンクの値が絶対のパスである ({target})。相対のパスにする")
        if os.path.realpath(link) != os.path.realpath(entity):
            violations.append(f"{link_label}: リンクの先 ({target}) が、実体 {entity_label} でない")
    return violations


def check_links(root: str, entity_names: set[str]) -> list[str]:
    """.claude/skills/ の直下のリンクが、同じ名前の実体を指していることを確かめる。

    実体のあるリンクは check_entity が見るので、ここでは実体の無いリンクだけを見る。
    """
    violations: list[str] = []
    for name in list_entries(os.path.join(root, CLAUDE_SKILLS)):
        link = os.path.join(root, CLAUDE_SKILLS, name)
        if not os.path.islink(link) or name in entity_names:
            continue
        violations.append(
            f"{CLAUDE_SKILLS}/{name}: リンクの先 ({os.readlink(link)}) が、"
            f"実体 {AGENTS_SKILLS}/{name} でない (実体が無い)"
        )
    return violations


def check_project_skills(root: str) -> tuple[list[str], list[str]]:
    """置き場の形を確かめて、(違反, 確かめた実体の名前) を返す。"""
    agents_dir = os.path.join(root, AGENTS_SKILLS)
    if not os.path.isdir(agents_dir):
        return [f"{AGENTS_SKILLS}: ディレクトリが無い"], []
    names = [name for name in list_entries(agents_dir) if os.path.isdir(os.path.join(agents_dir, name))]
    if not names:
        return [f"{AGENTS_SKILLS}: Skill が 1 つも無い"], []

    violations: list[str] = []
    for name in names:
        violations.extend(check_entity(root, name))
    violations.extend(check_links(root, set(names)))
    return violations, names


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="プロジェクト内の Skill の置き場の形を確かめる")
    parser.add_argument("root", help="リポジトリのルート")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.root):
        ci_report.emit_errors([f"リポジトリのルートが、実在するディレクトリではない: {args.root}"])
        return 2

    violations, names = check_project_skills(args.root)
    if violations:
        ci_report.emit_errors(violations)
        print(f"プロジェクト内の Skill の置き場の検査: 違反 {len(violations)} 件")
        return 1
    print(f"プロジェクト内の Skill の置き場の検査: 違反なし (Skill {len(names)} つ: {'・'.join(names)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
