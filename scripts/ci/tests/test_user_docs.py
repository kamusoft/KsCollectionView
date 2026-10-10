"""利用者向けの文書の検査が共有する道具と、一覧のデータのテスト。

一覧のデータ (user-docs-rules.json) は、置いてある実物を読んで、決めた形を保っていることを確かめる。
"""

from __future__ import annotations

import json
import os
import tempfile
import unittest

import support

USER_DOCS = support.load_script("user_docs.py")


class RulesFileTest(unittest.TestCase):
    def test_完全一致で許可するURLは決めた4つの役割を持つ(self) -> None:
        rules = USER_DOCS.load_rules()
        self.assertEqual(
            rules.allowed_urls,
            {
                "package": "https://github.com/kamusoft/KsCollectionView-SPM",
                "repository": "https://github.com/kamusoft/KsCollectionView",
                "latest-version": "https://github.com/kamusoft/KsCollectionView/releases",
                "issue-report": "https://github.com/kamusoft/KsCollectionView/issues",
            },
        )

    def test_前方一致で許可するのは見本のURLの前置きだけである(self) -> None:
        self.assertEqual(USER_DOCS.load_rules().sample_url_prefixes, ("https://example.com/",))

    def test_本リポジトリのURLを前方一致で許可していない(self) -> None:
        # 前方一致にすると、本リポジトリの中の文書への URL まで通ってしまう。
        rules = USER_DOCS.load_rules()
        for prefix in rules.sample_url_prefixes:
            for url in rules.allowed_urls.values():
                self.assertFalse(url.startswith(prefix), (prefix, url))

    def test_内部の言葉の一覧が空でなく重なりが無い(self) -> None:
        terms = USER_DOCS.load_rules().internal_terms
        self.assertGreater(len(terms), 0)
        self.assertEqual(len(terms), len({term.lower() for term in terms}))
        self.assertIn("ADR", terms)
        self.assertIn("利用者役", terms)


class LoadRulesTest(unittest.TestCase):
    VALID = {
        "version": 1,
        "allowedUrls": [{"role": "package", "url": "https://example.org/package", "note": "説明"}],
        "sampleUrlPrefixes": ["https://example.com/"],
        "internalTerms": ["ADR"],
    }

    def load(self, data) -> object:
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "rules.json")
            text = data if isinstance(data, str) else json.dumps(data, ensure_ascii=False)
            support.write(path, text)
            return USER_DOCS.load_rules(path)

    def test_決めた形のデータを読める(self) -> None:
        rules = self.load(self.VALID)
        self.assertEqual(rules.allowed_urls, {"package": "https://example.org/package"})
        self.assertEqual(rules.sample_url_prefixes, ("https://example.com/",))
        self.assertEqual(rules.internal_terms, ("ADR",))

    def test_ファイルが無いと読み取れない(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(USER_DOCS.RulesError):
                USER_DOCS.load_rules(os.path.join(directory, "missing.json"))

    def test_JSONとして読めないと読み取れない(self) -> None:
        with self.assertRaises(USER_DOCS.RulesError):
            self.load("{")

    def test_項目が欠けていると読み取れない(self) -> None:
        for missing in ("allowedUrls", "sampleUrlPrefixes", "internalTerms"):
            with self.subTest(missing=missing):
                data = {key: value for key, value in self.VALID.items() if key != missing}
                with self.assertRaises(USER_DOCS.RulesError):
                    self.load(data)

    def test_空の値があると読み取れない(self) -> None:
        cases = {
            "URL が空": {"allowedUrls": [{"role": "package", "url": ""}]},
            "URL が 1 つも無い": {"allowedUrls": []},
            "前置きが空": {"sampleUrlPrefixes": [""]},
            "内部の言葉が空": {"internalTerms": [""]},
            "内部の言葉が 1 つも無い": {"internalTerms": []},
        }
        for title, change in cases.items():
            with self.subTest(case=title):
                with self.assertRaises(USER_DOCS.RulesError):
                    self.load({**self.VALID, **change})

    def test_役割の名前が重なっていると読み取れない(self) -> None:
        entries = [
            {"role": "package", "url": "https://example.org/a"},
            {"role": "package", "url": "https://example.org/b"},
        ]
        with self.assertRaises(USER_DOCS.RulesError):
            self.load({**self.VALID, "allowedUrls": entries})


class ParseMarkdownTest(unittest.TestCase):
    def test_見出しとコードブロックを順に取り出す(self) -> None:
        document = USER_DOCS.parse_markdown(
            "# Title\n\ntext\n\n## Section\n\n```swift\nlet a = 1\n\nlet b = 2\n```\n\n### Sub\n\n```\nplain\n```\n"
        )
        self.assertEqual([(h.level, h.title, h.line) for h in document.headings], [(1, "Title", 1), (2, "Section", 5), (3, "Sub", 13)])
        self.assertEqual(
            [(block.language, block.text, block.line) for block in document.code_blocks],
            [("swift", "let a = 1\n\nlet b = 2\n", 7), ("", "plain\n", 15)],
        )
        self.assertIsNone(document.unclosed_fence)

    def test_コードブロックの中の行を見出しに数えない(self) -> None:
        document = USER_DOCS.parse_markdown("# Title\n\n```sh\n# comment\n## also comment\n```\n")
        self.assertEqual([heading.title for heading in document.headings], ["Title"])
        self.assertEqual([number for number, _ in document.prose], [1, 2])

    def test_波線の囲みと長い囲みを読める(self) -> None:
        document = USER_DOCS.parse_markdown("~~~kotlin\nval a = 1\n~~~\n\n````markdown\n```swift\ninner\n```\n````\n")
        self.assertEqual(
            [(block.language, block.text) for block in document.code_blocks],
            [("kotlin", "val a = 1\n"), ("markdown", "```swift\ninner\n```\n")],
        )

    def test_違う記号では囲みが閉じない(self) -> None:
        document = USER_DOCS.parse_markdown("```swift\nlet a = 1\n~~~\n")
        self.assertEqual(document.code_blocks, ())
        self.assertEqual(document.unclosed_fence, 1)

    def test_閉じていない囲みの始まりの行が分かる(self) -> None:
        document = USER_DOCS.parse_markdown("text\n\n```swift\nlet a = 1\n")
        self.assertEqual(document.unclosed_fence, 3)


class FindUrlsTest(unittest.TestCase):
    def test_文とコードの中のURLを取り出す(self) -> None:
        cases = {
            "See [releases](https://example.org/releases).": ["https://example.org/releases"],
            'url: "https://example.org/Package-SPM", exact: "{version}"': ["https://example.org/Package-SPM"],
            "<https://example.org/a>, https://example.org/b.": ["https://example.org/a", "https://example.org/b"],
            "`https://example.org/code`": ["https://example.org/code"],
            'AsyncImage(url: "https://example.com/images/\\(id).png")': ["https://example.com/images/"],
            'load("https://example.com/images/$id.png")': ["https://example.com/images/$id.png"],
            "source: https://example.org/repository": ["https://example.org/repository"],
            "no url here": [],
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(USER_DOCS.find_urls(text), expected)

    def test_日本語の文が続いていてもURLがそこで切れる(self) -> None:
        self.assertEqual(
            USER_DOCS.find_urls("最新の版は https://example.org/releases。で確かめる"),
            ["https://example.org/releases"],
        )
        self.assertEqual(USER_DOCS.find_urls("https://example.org/releasesを開く"), ["https://example.org/releases"])


class RequireRootTest(unittest.TestCase):
    def test_実在するディレクトリを絶対のパスで返す(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(USER_DOCS.require_root(directory), os.path.abspath(directory))

    def test_無いディレクトリとファイルを受け付けない(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            file = support.write(os.path.join(directory, "file.txt"), "")
            for path in (os.path.join(directory, "missing"), file):
                with self.subTest(path=os.path.basename(path)):
                    with self.assertRaises(USER_DOCS.UsageError):
                        USER_DOCS.require_root(path)


if __name__ == "__main__":
    unittest.main()
