"""公開リポジトリの体裁のファイルが、決めた形を保っているかのテスト。

確かめるのは、後から崩れても気付きにくい形だけにする: ライセンスの文面と名義、
英語と日本語の 2 枚の構成の一致、案内どうしの導線、Issue のフォームの必須の項目。
"""

from __future__ import annotations

import os
import re
import unittest

import support

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


if __name__ == "__main__":
    unittest.main()
