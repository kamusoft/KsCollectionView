"""公開リポジトリの体裁のファイルが、決めた形を保っているかのテスト。

確かめるのは、後から崩れても気付きにくい形だけにする: ライセンスの文面と名義、
英語と日本語の 2 枚の構成の一致、案内どうしの導線、Issue のフォームの必須の項目、
ルートの README の節の並び・画像・Skill への導線、Skill の索引の 2 枚の見出しの並び、
利用者向けの文書の検査の結果、
追従の記録の形、Pull Request のひな形の変更の節と書き方。

利用者向けの文書の検査 (README の最小コード例・インストール例・Skill 自身の整合) は、
今のリポジトリの実物に対して流す。Skill が源泉 (概念の文書・本体のソース) からずれている
ことは、ここでは確かめない (源泉を変えた push を、Skill を直すまで落とし続けないため)。
"""

from __future__ import annotations

import os
import re
import unittest

import support

DOCS_DIR = os.path.join(support.REPOSITORY_ROOT, "scripts", "docs")
USER_DOCS = support.load_script("user_docs.py")
README_EXAMPLES = support.load_script("check-readme-examples.py")
SKILLS_CHECK = support.load_script("check-skills.py")
SKILLS_MANIFEST = support.load_script("skills_manifest.py", DOCS_DIR)
RELEASE_NOTES = support.load_script("build-release-notes.py", os.path.join(support.REPOSITORY_ROOT, "scripts", "release"))

HEADING = re.compile(r"^(#{1,6})\s+\S")
FENCE = re.compile(r"^\s*(```|~~~)")


def read(*parts: str) -> str:
    with open(os.path.join(support.REPOSITORY_ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def heading_levels(text: str) -> list[int]:
    """見出しの深さを、現れる順に返す。コードの囲みの中は数えない。"""
    levels = []
    fenced = False
    for line in text.splitlines():
        if FENCE.match(line):
            fenced = not fenced
            continue
        matched = HEADING.match(line)
        if matched and not fenced:
            levels.append(len(matched.group(1)))
    return levels


def required_fields(form: str) -> dict[str, bool]:
    """Issue のフォームの入力の項目を、id → 必須かどうか の対応で返す。"""
    fields: dict[str, bool] = {}
    current: str | None = None
    for line in form.splitlines():
        id_match = re.match(r"^\s+id:\s*(\S+)\s*$", line)
        if id_match:
            current = id_match.group(1)
            fields[current] = False
            continue
        if current is not None and re.match(r"^\s+required:\s*true\s*$", line):
            fields[current] = True
    return fields


def labels(form: str) -> list[str]:
    matched = re.search(r"^labels:\n((?:\s+-\s+\S+\n)+)", form, flags=re.MULTILINE)
    return re.findall(r"-\s+(\S+)", matched.group(1)) if matched else []


def section_text(readme: str, title: str) -> str:
    """README の、見出し (深さ 2) の文面が title の節の本文を返す。コードの囲みの中は含まない。"""
    document = USER_DOCS.parse_markdown(read(readme))
    tops = [heading for heading in document.headings if heading.level <= 2]
    start = next(heading for heading in tops if heading.level == 2 and heading.title == title)
    following = [heading.line for heading in tops if heading.line > start.line]
    end = following[0] if following else float("inf")
    return "\n".join(line for number, line in document.prose if start.line < number < end)


def link_targets(text: str) -> list[str]:
    return re.findall(r"\]\(([^)\s]+)\)", text)


class LicenseTest(unittest.TestCase):
    def test_ルートにMITLicenseがあり名義がkamusoftである(self) -> None:
        text = read("LICENSE")
        self.assertTrue(text.startswith("MIT License\n"))
        self.assertIn("\nCopyright (c) kamusoft\n", text)
        # 標準の文面の、許諾・条件・免責の 3 つの段落があること。
        self.assertIn("Permission is hereby granted, free of charge, to any person obtaining a copy", text)
        self.assertIn("The above copyright notice and this permission notice shall be included in all", text)
        self.assertIn('THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND', text)


class ReadmeTest(unittest.TestCase):
    def test_2枚の見出しの数と順番が一致する(self) -> None:
        english = heading_levels(read("README.md"))
        japanese = heading_levels(read("README_ja.md"))
        self.assertGreater(len(english), 1)
        self.assertEqual(english, japanese)

    def test_どちらもライセンスと貢献の案内への導線を持つ(self) -> None:
        self.assertIn("](LICENSE)", read("README.md"))
        self.assertIn("](.github/CONTRIBUTING.md)", read("README.md"))
        self.assertIn("](LICENSE)", read("README_ja.md"))
        self.assertIn("](.github/CONTRIBUTING_ja.md)", read("README_ja.md"))

    def test_2枚が互いを指している(self) -> None:
        self.assertIn("](README_ja.md)", read("README.md"))
        self.assertIn("](README.md)", read("README_ja.md"))


class ReadmeSectionsTest(unittest.TestCase):
    # README の節 (深さ 2 の見出し) の文面。この順で、これだけを持つ。
    SECTIONS = {
        "README.md": [
            "Overview and key features",
            "Screenshots",
            "Supported platforms",
            "Installation",
            "Minimal code examples",
            "Skills",
            "Repository structure",
            "Contributing",
            "License",
        ],
        "README_ja.md": [
            "概要と特徴",
            "スクリーンショット",
            "対応プラットフォーム",
            "インストール",
            "最小コード例",
            "Skill",
            "リポジトリ構成",
            "貢献",
            "ライセンス",
        ],
    }
    SCREENSHOTS = {
        f"assets/{platform}-{screen}.png" for platform in ("ios", "android") for screen in ("list", "grid", "grouping")
    }
    SKILL_LINKS = {
        "README.md": {
            "skills/en/kscollectionview-ios/SKILL.md",
            "skills/en/kscollectionview-android/SKILL.md",
            "skills/README.md",
        },
        "README_ja.md": {
            "skills/ja/kscollectionview-ios/SKILL.md",
            "skills/ja/kscollectionview-android/SKILL.md",
            "skills/README_ja.md",
        },
    }

    def test_2枚が9つの節をこの順で持つ(self) -> None:
        for readme, expected in self.SECTIONS.items():
            with self.subTest(readme=readme):
                headings = USER_DOCS.parse_markdown(read(readme)).headings
                self.assertEqual([heading.title for heading in headings if heading.level == 2], expected)
                self.assertEqual([heading.level for heading in headings if heading.level == 1], [1])

    def test_スクリーンショットの節が6枚の画像を指し画像が実在する(self) -> None:
        for readme, sections in self.SECTIONS.items():
            with self.subTest(readme=readme):
                section = section_text(readme, sections[1])
                images = re.findall(r'<img\s[^>]*?src="([^"]+)"', section) + [
                    target for target in re.findall(r"!\[[^\]]*\]\(([^)\s]+)\)", section)
                ]
                # 6 枚を、ルートからの相対のパスで 1 回ずつ指している。
                self.assertEqual(sorted(images), sorted(self.SCREENSHOTS))
                for image in images:
                    self.assertTrue(os.path.isfile(os.path.join(support.REPOSITORY_ROOT, *image.split("/"))), image)

    def test_Skillへの導線が自分の言語のSkillと索引を指し先が実在する(self) -> None:
        for readme, sections in self.SECTIONS.items():
            with self.subTest(readme=readme):
                targets = set(link_targets(section_text(readme, sections[5])))
                self.assertEqual(targets, self.SKILL_LINKS[readme])
                for target in targets:
                    self.assertTrue(os.path.isfile(os.path.join(support.REPOSITORY_ROOT, *target.split("/"))), target)


class SkillsIndexTest(unittest.TestCase):
    def test_Skillの索引の2枚の見出しの深さの並びが一致する(self) -> None:
        english = heading_levels(read("skills", "README.md"))
        japanese = heading_levels(read("skills", "README_ja.md"))
        self.assertGreater(len(english), 1)
        self.assertEqual(english, japanese)


class UserDocsCheckTest(unittest.TestCase):
    """利用者向けの文書の 3 つの検査を、今のリポジトリの実物に流す。"""

    def test_READMEの最小コード例が利用者役の画面と一致する(self) -> None:
        violations, matched = README_EXAMPLES.check_minimal_examples(support.REPOSITORY_ROOT)
        self.assertEqual(violations, [])
        # README の 2 枚 × 2 つのプラットフォーム。
        self.assertEqual(matched, 4)

    def test_インストール例が利用者役の値と一致する(self) -> None:
        violations, checked = README_EXAMPLES.check_install_examples(support.REPOSITORY_ROOT, USER_DOCS.load_rules())
        self.assertEqual(violations, [])
        self.assertGreater(checked, 0)

    def test_READMEの例の検査が違反なしで終わる(self) -> None:
        code, out, _ = support.run_main(README_EXAMPLES, [support.REPOSITORY_ROOT])
        self.assertEqual(code, 0, out)
        self.assertIn("違反なし", out)

    def test_Skill自身の整合の検査が違反なしで終わる(self) -> None:
        violations, skill_count, markdown_count = SKILLS_CHECK.check_skills(support.REPOSITORY_ROOT, USER_DOCS.load_rules())
        self.assertEqual(violations, [])
        # 2 つのプラットフォーム × 2 つの言語。
        self.assertEqual(skill_count, 4)
        self.assertGreater(markdown_count, 0)
        code, out, _ = support.run_main(SKILLS_CHECK, [support.REPOSITORY_ROOT])
        self.assertEqual(code, 0, out)
        self.assertIn("違反なし", out)


class SkillsManifestTest(unittest.TestCase):
    """追従の記録の形。源泉の今の内容と、記録の commit が履歴にあるかは、ここでは確かめない。"""

    def test_記録が決めた3つの項目を持つ(self) -> None:
        manifest = SKILLS_MANIFEST.load_manifest(support.REPOSITORY_ROOT)
        self.assertRegex(manifest.synced_commit, r"^[0-9a-f]{40}$")
        self.assertGreater(len(manifest.sources), 0)
        self.assertEqual(set(manifest.api_exclusions), {"ios", "android"})

    def test_源泉が掛かる1枚か掛からない理由のどちらかを持つ(self) -> None:
        for source in SKILLS_MANIFEST.load_manifest(support.REPOSITORY_ROOT).sources:
            with self.subTest(source=source.path):
                self.assertTrue(bool(source.pages) != bool(source.excluded))

    def test_掛かる1枚がSkillに実在する(self) -> None:
        skills = {"ios": "kscollectionview-ios", "android": "kscollectionview-android"}
        for source in SKILLS_MANIFEST.load_manifest(support.REPOSITORY_ROOT).sources:
            for platform in source.platforms:
                for language in ("en", "ja"):
                    for page in source.pages:
                        path = os.path.join("skills", language, skills[platform], *page.split("/"))
                        with self.subTest(source=source.path, page=path):
                            self.assertTrue(os.path.isfile(os.path.join(support.REPOSITORY_ROOT, path)))


class ContributingTest(unittest.TestCase):
    def test_2枚の見出しの数と順番が一致する(self) -> None:
        english = heading_levels(read(".github", "CONTRIBUTING.md"))
        japanese = heading_levels(read(".github", "CONTRIBUTING_ja.md"))
        self.assertGreater(len(english), 1)
        self.assertEqual(english, japanese)

    def test_どちらの言語でも方針が読める(self) -> None:
        english = read(".github", "CONTRIBUTING.md")
        self.assertIn("do not accept pull requests from external contributors", english)
        self.assertIn("GitHub Issues", english)
        self.assertIn("in English or Japanese", english)
        japanese = read(".github", "CONTRIBUTING_ja.md")
        self.assertIn("外部のコントリビューターからの Pull Request は受け付けていません", japanese)
        self.assertIn("GitHub Issue で受け付けます", japanese)
        self.assertIn("英語でも日本語でも", japanese)

    def test_2枚が互いを指している(self) -> None:
        self.assertIn("](CONTRIBUTING_ja.md)", read(".github", "CONTRIBUTING.md"))
        self.assertIn("](CONTRIBUTING.md)", read(".github", "CONTRIBUTING_ja.md"))


class IssueFormTest(unittest.TestCase):
    DIRECTORY = (".github", "ISSUE_TEMPLATE")
    # フォームごとの、必須の項目の id と、付けるラベル。
    EXPECTED = {
        "bug_report.yml": (
            {"version", "platform", "reproduction_steps", "actual_behavior", "expected_behavior"},
            "bug",
        ),
        "feature_request.yml": ({"problem_to_solve", "current_impact", "alternatives_considered"}, "enhancement"),
        "question.yml": ({"version", "platform", "attempts", "references_consulted"}, "question"),
    }

    def test_フォームは3本だけである(self) -> None:
        names = sorted(os.listdir(os.path.join(support.REPOSITORY_ROOT, *self.DIRECTORY)))
        self.assertEqual(names, sorted([*self.EXPECTED, "config.yml"]))

    def test_各フォームが決めた項目を必須にしている(self) -> None:
        for name, (expected, _) in self.EXPECTED.items():
            with self.subTest(form=name):
                fields = required_fields(read(*self.DIRECTORY, name))
                self.assertEqual({field for field, required in fields.items() if required}, expected)

    def test_各フォームが決めたラベルを付ける(self) -> None:
        for name, (_, label) in self.EXPECTED.items():
            with self.subTest(form=name):
                self.assertEqual(labels(read(*self.DIRECTORY, name)), [label])

    def test_各フォームが英語でも日本語でもよいと案内している(self) -> None:
        for name in self.EXPECTED:
            with self.subTest(form=name):
                self.assertIn("in English or Japanese", read(*self.DIRECTORY, name))

    def test_プラットフォームはiOSとAndroidから選ぶ(self) -> None:
        for name in ("bug_report.yml", "question.yml"):
            with self.subTest(form=name):
                form = read(*self.DIRECTORY, name)
                matched = re.search(r"options:\n((?:\s+-\s+.+\n)+)", form)
                self.assertIsNotNone(matched)
                self.assertEqual(re.findall(r"-\s+(.+)", matched.group(1)), ["iOS", "Android"])

    def test_空のIssueを作れない設定である(self) -> None:
        config = read(*self.DIRECTORY, "config.yml")
        self.assertRegex(config, r"(?m)^blank_issues_enabled:\s*false\s*$")
        # 外部への案内のリンクは置かない。
        self.assertRegex(config, r"(?m)^contact_links:\s*\[\]\s*$")


class PullRequestTemplateTest(unittest.TestCase):
    """Pull Request のひな形。変更の節の内容が、リリースノートの組み立ての材料になる (cross/ADR-0023)。"""

    PATH = (".github", "pull_request_template.md")

    def setUp(self) -> None:
        self.template = read(*self.PATH)

    def with_section(self, *lines: str) -> str:
        """ひな形の変更の節の書き方の注釈の後ろに、行を書き足した本文を返す。"""
        return self.template.rstrip("\n") + "\n" + "\n".join(lines) + "\n"

    def test_変更の節が1つだけあり書き方は注釈としてノートに載らない(self) -> None:
        self.assertEqual(self.template.splitlines().count("## Changes"), 1)
        # 何も書き足さないままの本文は、節が空としてリリースの前に止まる (書き忘れを通さない)。
        entries, problems = RELEASE_NOTES.parse_changes(self.template)
        self.assertIsNone(entries)
        self.assertEqual(len(problems), 1)
        self.assertIn("変更の節が空", problems[0])

    def test_書き方に従って書いた節は読める(self) -> None:
        entries, problems = RELEASE_NOTES.parse_changes(self.with_section("- none"))
        self.assertEqual((entries, problems), ([], []))
        entries, problems = RELEASE_NOTES.parse_changes(
            self.with_section("- feature: Add a new option.", "- fix: Fix a crash.")
        )
        self.assertEqual(problems, [])
        self.assertEqual(entries, [("feature", "Add a new option."), ("fix", "Fix a crash.")])

    def test_書き方に行の形と種類と変更が無いときと言語の決まりがある(self) -> None:
        section = self.template.split("## Changes", 1)[1]
        comment = re.search(r"<!--(.*?)-->", section, flags=re.DOTALL)
        self.assertIsNotNone(comment)
        guidance = comment.group(1)
        for text in (
            "release notes",
            "`- <kind>: <description>`",
            "breaking, feature, fix, docs",
            "`- none`",
            "in English",
            "Do not list internal work",
            "stops the release",
        ):
            with self.subTest(text=text):
                self.assertIn(text, guidance)
        # ひな形の種類は、組み立ての道具が読む種類と同じである。
        self.assertEqual(list(RELEASE_NOTES.KINDS), ["breaking", "feature", "fix", "docs"])


if __name__ == "__main__":
    unittest.main()
