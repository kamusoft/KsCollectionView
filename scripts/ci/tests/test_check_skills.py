"""Skill 自身の整合の検査のテスト。

検査は、一時のディレクトリに作った skills/ のひな形 (2 つの Skill の、英語版と日本語版) に
対して流す。許可する URL と内部の言葉は、置いてある一覧のデータの値を使う。今の skills/ には、
検査を流さない。
"""

from __future__ import annotations

import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("check-skills.py")
USER_DOCS = support.load_script("user_docs.py")

RULES = USER_DOCS.load_rules()
PACKAGE_URL = RULES.allowed_urls["package"]
REPOSITORY_URL = RULES.allowed_urls["repository"]
LATEST_VERSION_URL = RULES.allowed_urls["latest-version"]
ISSUE_REPORT_URL = RULES.allowed_urls["issue-report"]
SAMPLE_URL = RULES.sample_url_prefixes[0] + "images/1.png"

IOS = "kscollectionview-ios"
ANDROID = "kscollectionview-android"

INSTALL_EXAMPLE = f"""\
```swift
dependencies: [
    .package(url: "{PACKAGE_URL}", exact: "{{version}}"),
]
```
"""
IMAGE_EXAMPLE = f"""\
```swift
let url = URL(string: "{SAMPLE_URL}")
```
"""


def skill_file(name: str, language: str, description: str, setup: str, latest: str) -> str:
    return f"""\
---
name: {name}
description: {description}
license: MIT
metadata:
  language: {language}
  source: {REPOSITORY_URL}
---

# {name}

{description}

## {setup}

{INSTALL_EXAMPLE}
{latest} [releases]({LATEST_VERSION_URL}) / [issues]({ISSUE_REPORT_URL})

## References

- [basics](references/basics.md)
- [images](references/images.md#loading)
"""


def basics(title: str, section: str, text: str) -> str:
    return f"""\
# {title}

{text} [images](images.md) / [top](../SKILL.md) / [here](#detail)

## {section}

```swift
KsCollectionView(items) {{ item in
    Text(item.title)
}}
```

### Detail

```swift
let count = 100
```
"""


def images(title: str, text: str) -> str:
    return f"""\
# {title}

{text}

## Loading

{IMAGE_EXAMPLE}"""


def skill(name: str, language: str) -> dict[str, str]:
    if language == "en":
        return {
            "SKILL.md": skill_file(name, "en", "Build list screens.", "Setup", "Find the latest version:"),
            "references/basics.md": basics("Basics", "Show a list", "Declare the list. See also"),
            "references/images.md": images("Images", "Load images from a URL."),
        }
    return {
        "SKILL.md": skill_file(name, "ja", "一覧の画面を作る (list screens)。", "導入", "最新の版の確かめ先:"),
        "references/basics.md": basics("基本", "一覧を出す", "一覧を宣言する。あわせて読む:"),
        "references/images.md": images("画像", "URL から画像を読み込む。"),
    }


def file_path(language: str, name: str, file: str) -> str:
    return f"skills/{language}/{name}/{file}"


class SkillsCase(unittest.TestCase):
    """一時のディレクトリに、検査が通る skills/ のひな形を作る。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = directory.name
        for language in ("en", "ja"):
            for name in (IOS, ANDROID):
                for file, text in skill(name, language).items():
                    self.put(file_path(language, name, file), text)

    def path(self, relative: str) -> str:
        return os.path.join(self.root, *relative.split("/"))

    def put(self, relative: str, text: str) -> None:
        support.write(self.path(relative), text)

    def get(self, relative: str) -> str:
        with open(self.path(relative), encoding="utf-8") as f:
            return f.read()

    def replace(self, relative: str, old: str, new: str) -> None:
        """ファイルの中の文面を置き換える。置き換える文面が無ければ、テストの誤りとして止める。"""
        text = self.get(relative)
        self.assertIn(old, text, f"{relative} に、置き換える文面が無い")
        self.put(relative, text.replace(old, new))

    def append(self, relative: str, text: str) -> None:
        self.put(relative, self.get(relative) + text)

    def check(self) -> tuple[int, str]:
        code, stdout, _ = support.run_main(SCRIPT, [self.root])
        return code, stdout

    def assert_passes(self) -> str:
        code, output = self.check()
        self.assertEqual(code, 0, output)
        self.assertNotIn("::error::", output)
        return output

    def assert_fails(self, *fragments: str, count: int | None = None) -> str:
        """検査が失敗で終わり、どれか 1 件の違反が、渡した文面をすべて含むことを確かめる。

        count を渡すと、違反の件数も確かめる。
        """
        code, output = self.check()
        self.assertEqual(code, 1, output)
        errors = [line for line in output.splitlines() if line.startswith("::error::")]
        self.assertTrue(errors, output)
        self.assertTrue(
            any(all(fragment in line for fragment in fragments) for line in errors),
            f"{fragments} をすべて含む違反が無い:\n{output}",
        )
        if count is not None:
            self.assertEqual(len(errors), count, output)
        return output


class ConsistentSkillsTest(SkillsCase):
    def test_整合していれば成功する(self) -> None:
        output = self.assert_passes()
        # 2 つの Skill × 2 つの言語と、その中の 3 枚ずつを確かめている。
        self.assertIn("Skill 4 つ・Markdown 12 枚", output)


class LanguageParityTest(SkillsCase):
    def test_片方の言語だけ見出しを変えると失敗しその1枚が出る(self) -> None:
        target = file_path("ja", IOS, "references/basics.md")
        self.append(target, "\n## 追加の節\n")
        self.assert_fails(target, "見出しの深さの並びが", count=1)

    def test_見出しの深さだけを変えても失敗する(self) -> None:
        target = file_path("en", ANDROID, "references/basics.md")
        self.replace(target, "### Detail", "## Detail")
        self.assert_fails(file_path("ja", ANDROID, "references/basics.md"), target, "見出しの深さの並びが", count=1)

    def test_見出しの文面は言語で違ってよい(self) -> None:
        self.replace(file_path("ja", IOS, "references/basics.md"), "### Detail", "### 詳しく")
        self.assert_passes()

    def test_片方の言語だけコードを変えると失敗する(self) -> None:
        target = file_path("en", IOS, "references/basics.md")
        self.replace(target, "let count = 100", "let count = 101")
        self.assert_fails(target, "2 つ目のコードブロックが", count=1)

    def test_SKILLのコードを片方だけ変えても失敗する(self) -> None:
        target = file_path("ja", ANDROID, "SKILL.md")
        self.replace(target, "dependencies: [", "dependencies:  [")
        self.assert_fails(target, "1 つ目のコードブロックが", count=1)

    def test_コードブロックの言語の名前だけが違っても失敗する(self) -> None:
        target = file_path("ja", IOS, "references/images.md")
        self.replace(target, "```swift", "```kotlin")
        self.assert_fails(target, "1 つ目のコードブロックが", count=1)

    def test_コードブロックの順番が違うと失敗する(self) -> None:
        target = file_path("ja", IOS, "references/basics.md")
        first = "KsCollectionView(items) { item in\n    Text(item.title)\n}\n"
        second = "let count = 100\n"
        text = self.get(target)
        self.put(target, text.replace(first, "@first@").replace(second, first).replace("@first@", second))
        self.assert_fails(target, "1 つ目のコードブロックが")

    def test_コードブロックの数が違うと失敗する(self) -> None:
        target = file_path("en", IOS, "references/images.md")
        self.append(target, "\n```swift\nlet extra = 1\n```\n")
        self.assert_fails(target, "コードブロックの数が", "英語版 2 つ / 日本語版 1 つ", count=1)

    def test_片方の言語にだけファイルがあると失敗する(self) -> None:
        self.put(file_path("en", IOS, "references/layout.md"), "# Layout\n")
        self.assert_fails(f"skills/en/{IOS}", "英語版にだけあるファイルがある", "references/layout.md", count=1)

    def test_日本語版にだけファイルがあっても失敗する(self) -> None:
        self.put(file_path("ja", ANDROID, "references/paging.md"), "# ページング\n")
        self.assert_fails(f"skills/ja/{ANDROID}", "日本語版にだけあるファイルがある", "references/paging.md", count=1)

    def test_Markdownでないファイルもファイルの集合に数える(self) -> None:
        self.put(file_path("en", IOS, "references/diagram.svg"), "<svg/>\n")
        self.assert_fails(f"skills/en/{IOS}", "英語版にだけあるファイルがある", "references/diagram.svg", count=1)

    def test_OSが作るファイルはファイルの集合に数えない(self) -> None:
        self.put(file_path("en", IOS, ".DS_Store"), "")
        self.put(file_path("ja", ANDROID, "references/.DS_Store"), "")
        self.assert_passes()

    def test_片方の言語にだけSkillがあると失敗する(self) -> None:
        for file, text in skill("kscollectionview-extra", "en").items():
            self.put(file_path("en", "kscollectionview-extra", file), text)
        self.assert_fails("skills/en", "英語版にだけある Skill がある", "kscollectionview-extra", count=1)

    def test_日本語版のSkillが丸ごと無いと失敗する(self) -> None:
        import shutil

        shutil.rmtree(self.path("skills/ja"))
        self.assert_fails("skills/en", "英語版にだけある Skill がある", IOS, ANDROID)


class FrontmatterTest(SkillsCase):
    def test_決めていない項目があると失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.replace(target, "license: MIT\n", "license: MIT\nversion: 1.0.0\n")
        self.assert_fails(target, "決めていない項目がある: version", count=1)

    def test_metadataの下に決めていない項目があっても失敗する(self) -> None:
        target = file_path("ja", ANDROID, "SKILL.md")
        self.replace(target, "  language: ja\n", "  language: ja\n  author: someone\n")
        self.assert_fails(target, "決めていない項目がある: metadata.author", count=1)

    def test_nameがディレクトリの名前と違うと失敗する(self) -> None:
        target = file_path("en", ANDROID, "SKILL.md")
        self.replace(target, f"name: {ANDROID}\n", "name: kscollectionview\n")
        self.assert_fails(target, "name (kscollectionview) が、ディレクトリの名前", count=1)

    def test_languageが置き場の言語と違うと失敗する(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        self.replace(target, "  language: ja\n", "  language: en\n")
        self.assert_fails(target, "metadata.language (en) が、置き場の言語 (ja) と違う", count=1)

    def test_項目が欠けていると失敗する(self) -> None:
        cases = {
            "name": f"name: {IOS}\n",
            "description": "description: Build list screens.\n",
            "license": "license: MIT\n",
            "metadata.language": "  language: en\n",
            "metadata.source": f"  source: {REPOSITORY_URL}\n",
        }
        target = file_path("en", IOS, "SKILL.md")
        for field, line in cases.items():
            with self.subTest(field=field):
                self.setUp()
                self.replace(target, line, "")
                self.assert_fails(target, f"項目 {field} が無い", count=1)

    def test_値が空の項目があると失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.replace(target, "license: MIT\n", "license:\n")
        self.assert_fails(target, "項目 license の値が空である", count=1)

    def test_metadataの下が空だと失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.replace(target, f"metadata:\n  language: en\n  source: {REPOSITORY_URL}\n", "metadata:\n")
        self.assert_fails(target, "決めていない項目がある: metadata")
        self.assert_fails(target, "項目 metadata.language が無い")

    def test_同じ項目を2回書くと失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.replace(target, "license: MIT\n", "license: MIT\nlicense: MIT\n")
        self.assert_fails(target, "項目 license が、2 回書かれている", count=1)

    def test_読み取れない行があると失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.replace(target, "license: MIT\n", "license: MIT\n- list item\n")
        self.assert_fails(target, "frontmatter の 5 行目を読み取れない", count=1)

    def test_frontmatterが無いと失敗する(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        text = self.get(target)
        self.put(target, text[text.index("# ") :])
        self.assert_fails(target, "frontmatter が無い", count=1)

    def test_frontmatterが閉じていないと失敗する(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        self.replace(target, f"  source: {REPOSITORY_URL}\n---\n", f"  source: {REPOSITORY_URL}\n")
        self.assert_fails(target, "frontmatter が閉じていない", count=1)

    def test_引用符で囲んだ値を読める(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, IOS, "SKILL.md")
            self.replace(target, f"name: {IOS}\n", f'name: "{IOS}"\n')
            self.replace(target, "license: MIT\n", "license: 'MIT'\n")
        self.assert_passes()

    def test_SKILLが無いSkillがあると失敗する(self) -> None:
        os.remove(self.path(file_path("en", IOS, "SKILL.md")))
        self.assert_fails(f"skills/en/{IOS}:", "SKILL.md が無い")

    def test_referencesの1枚にはfrontmatterを求めない(self) -> None:
        # ひな形の references/ は frontmatter を持たない。SKILL.md だけを見る。
        self.assertFalse(self.get(file_path("en", IOS, "references/basics.md")).startswith("---"))
        self.assert_passes()


class LinkTest(SkillsCase):
    def test_Skillの外のファイルへのリンクがあると失敗しそのリンクが出る(self) -> None:
        target = file_path("en", IOS, "references/basics.md")
        # 行き先は、どれも実在する。Skill の外にあることだけが違反になる。
        self.put("README.md", "# Example\n")
        self.put("skills/README.md", "# Skills\n")
        links = (
            "../../../../README.md",
            "../../../README.md",
            f"../../{ANDROID}/SKILL.md",
            f"../../../ja/{IOS}/references/basics.md",
        )
        for link in links:
            with self.subTest(link=link):
                self.setUp()
                self.put("README.md", "# Example\n")
                self.put("skills/README.md", "# Skills\n")
                self.assertTrue(os.path.exists(os.path.join(os.path.dirname(self.path(target)), *link.split("/"))))
                self.append(target, f"\nSee [more]({link}).\n")
                self.assert_fails(f"{target}:", "Skill の外のファイルへのリンクがある", link, count=1)

    def test_絶対のパスのリンクは外へのリンクとして失敗する(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        self.append(target, "\n[README](/README.md)\n")
        self.assert_fails(f"{target}:", "Skill の外のファイルへのリンクがある", "/README.md", count=1)

    def test_参照の形で書いた外へのリンクも失敗する(self) -> None:
        target = file_path("en", ANDROID, "references/images.md")
        self.append(target, "\nSee [the index][index].\n\n[index]: ../../../README.md\n")
        self.assert_fails(f"{target}:", "Skill の外のファイルへのリンクがある", "../../../README.md", count=1)

    def test_画像の形で書いた外へのリンクも失敗する(self) -> None:
        target = file_path("en", ANDROID, "references/images.md")
        self.append(target, "\n![screenshot](../../../../assets/list.png)\n")
        self.assert_fails(f"{target}:", "Skill の外のファイルへのリンクがある", "../../../../assets/list.png", count=1)

    def test_HTMLで書いた外へのリンクも失敗する(self) -> None:
        target = file_path("en", IOS, "references/basics.md")
        self.put("README.md", "# Example\n")
        self.append(target, '\n<a href="../../../../README.md">README</a>\n')
        self.assert_fails(f"{target}:", "Skill の外のファイルへのリンクがある", "../../../../README.md", count=1)

    def test_HTMLで書いた外への画像も失敗する(self) -> None:
        target = file_path("ja", ANDROID, "references/images.md")
        images = (
            '<img src="../../../../assets/list.png" width="240">',
            "<img width=240 src='../../../../assets/list.png'>",
            "<img src=../../../../assets/list.png>",
            '<p align="center">\n  <img\n    alt="list"\n    SRC = "../../../../assets/list.png"\n  >\n</p>',
        )
        for image in images:
            with self.subTest(image=image):
                self.setUp()
                self.append(target, f"\n{image}\n")
                self.assert_fails(
                    f"{target}:", "Skill の外のファイルへのリンクがある", "../../../../assets/list.png", count=1
                )

    def test_HTMLで書いた絶対のパスのリンクは外へのリンクとして失敗する(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        self.append(target, '\n<a href="/README.md">README</a>\n')
        self.assert_fails(f"{target}:", "Skill の外のファイルへのリンクがある", "/README.md", count=1)

    def test_HTMLで書いたリンクの先が無いと失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.append(target, '\n<a href="references/paging.md">paging</a>\n')
        self.assert_fails(f"{target}:", "リンクの先が無い", "references/paging.md", count=1)

    def test_HTMLで書いた許可していないURLも失敗する(self) -> None:
        target = file_path("en", IOS, "references/basics.md")
        url = f"{REPOSITORY_URL}/blob/main/README.md"
        self.append(target, f'\n<a href="{url}">README</a>\n')
        self.assert_fails(f"{target}:", "許可した一覧に無い URL がある", f": {url}", count=1)

    def test_HTMLで書いたhttpでもhttpsでもないリンクは失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.append(target, '\n<a href="mailto:someone@example.com">mail</a>\n')
        self.assert_fails(f"{target}:", "http・https でないリンクがある", "mailto:someone@example.com", count=1)

    def test_HTMLで書いたSkillの中のリンクと許可したURLは通る(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, IOS, "references/basics.md")
            self.append(
                target,
                '\n<a href="images.md#loading">images</a> <a href="../SKILL.md">top</a> <a href="#detail">here</a>'
                f' <a href="{ISSUE_REPORT_URL}">issues</a>\n',
            )
        self.assert_passes()

    def test_コードの中のHTMLのリンクの形は確かめない(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, IOS, "references/basics.md")
            self.append(
                target, '\nWrite `<a href="../outside.md">`.\n\n```html\n<img src="../outside.png">\n```\n'
            )
        self.assert_passes()

    def test_リンクの先が無いと失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.append(target, "- [paging](references/paging.md)\n")
        self.assert_fails(f"{target}:", "リンクの先が無い", "references/paging.md", count=1)

    def test_節を指す部分を付けてもリンクの先のファイルを確かめる(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        self.replace(target, "references/images.md#loading", "references/missing.md#loading")
        self.assert_fails(f"{target}:", "リンクの先が無い", "references/missing.md#loading", count=1)

    def test_Skillの中のリンクと同じファイルの中への移動は通る(self) -> None:
        # ひな形は、references/ どうし・SKILL.md への戻り・同じファイルの中への移動を持つ。
        text = self.get(file_path("en", IOS, "references/basics.md"))
        for link in ("(images.md)", "(../SKILL.md)", "(#detail)"):
            self.assertIn(link, text)
        self.assert_passes()

    def test_コードの中のリンクの形は確かめない(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, IOS, "references/basics.md")
            self.append(target, "\nUse `handlers[key](../outside.md)`.\n\n```swift\nlet a = table[key](../outside.md)\n```\n")
        self.assert_passes()

    def test_httpでもhttpsでもないリンクは失敗する(self) -> None:
        target = file_path("en", IOS, "SKILL.md")
        self.append(target, "\n[mail](mailto:someone@example.com)\n")
        self.assert_fails(f"{target}:", "http・https でないリンクがある", "mailto:someone@example.com", count=1)


class UrlTest(SkillsCase):
    def test_許可していないURLがあると失敗しそのURLが出る(self) -> None:
        target = file_path("en", IOS, "references/basics.md")
        urls = (
            # 本リポジトリの中の文書への URL。
            f"{REPOSITORY_URL}/blob/main/README.md",
            f"{REPOSITORY_URL}/blob/main/skills/README.md",
            f"{REPOSITORY_URL}/tree/main/skills/en/{ANDROID}",
            # 許可した URL に、続きを足したもの。
            f"{LATEST_VERSION_URL}/latest",
            f"{PACKAGE_URL}.git",
            f"{REPOSITORY_URL}/",
            "https://developer.apple.com/documentation/swiftui",
            "http://example.com/images/1.png",
        )
        for url in urls:
            with self.subTest(url=url):
                self.setUp()
                self.append(target, f"\nSee [the page]({url}).\n")
                self.assert_fails(f"{target}:", "許可した一覧に無い URL がある", f": {url}", count=1)

    def test_コードブロックの中の許可していないURLも失敗する(self) -> None:
        for language in ("en", "ja"):
            self.replace(file_path(language, IOS, "references/images.md"), SAMPLE_URL, "https://images.example.org/1.png")
        self.assert_fails(
            f"{file_path('en', IOS, 'references/images.md')}:", "許可した一覧に無い URL がある", "https://images.example.org/1.png"
        )

    def test_frontmatterの中の許可していないURLも失敗する(self) -> None:
        target = file_path("ja", ANDROID, "SKILL.md")
        self.replace(target, f"  source: {REPOSITORY_URL}\n", f"  source: {REPOSITORY_URL}/tree/main/skills\n")
        self.assert_fails(f"{target}:", "許可した一覧に無い URL がある", f"{REPOSITORY_URL}/tree/main/skills", count=1)

    def test_許可したURLと見本のURLは通る(self) -> None:
        # ひな形は、Package URL を書いたインストール例と、見本の URL の前置きで始まる画像の URL を
        # 書いたコード例を持つ。
        self.assertIn(f'.package(url: "{PACKAGE_URL}"', self.get(file_path("en", IOS, "SKILL.md")))
        self.assertIn(f'URL(string: "{SAMPLE_URL}")', self.get(file_path("en", IOS, "references/images.md")))
        self.assert_passes()

    def test_許可した4つのURLはどれも通る(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, IOS, "references/basics.md")
            for url in RULES.allowed_urls.values():
                self.append(target, f"\n- <{url}>\n- {url}.\n")
        self.assert_passes()

    def test_見本のURLの前置きで始まるURLはどれも通る(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, ANDROID, "references/images.md")
            self.append(target, '\n```kotlin\nval a = "https://example.com/a/$id.png"\nval b = "https://example.com/"\n```\n')
        self.assert_passes()


class InternalTermTest(SkillsCase):
    def test_内部の言葉があると失敗しその言葉と場所が出る(self) -> None:
        target = file_path("ja", IOS, "references/basics.md")
        lines = len(self.get(target).splitlines())
        self.append(target, "\nこの動きは ADR-0011 で決めた。\n")
        self.assert_fails(f"{target}: {lines + 2} 行目:", "内部の言葉がある: ADR", count=1)

    def test_一覧の言葉はどれも見つける(self) -> None:
        target = file_path("en", ANDROID, "references/basics.md")
        for term in RULES.internal_terms:
            with self.subTest(term=term):
                self.setUp()
                self.append(target, f"\nSee {term}0001 for details.\n" if term.endswith("-") else f"\nSee the {term} note.\n")
                self.assert_fails(f"{target}:", f"内部の言葉がある: {term}", count=1)

    def test_コードブロックの中の内部の言葉も失敗する(self) -> None:
        for language in ("en", "ja"):
            self.replace(file_path(language, IOS, "references/basics.md"), "let count = 100", "let count = 100 // cross/ADR-0005")
        self.assert_fails(f"{file_path('en', IOS, 'references/basics.md')}:", "内部の言葉がある: ADR")
        self.assert_fails(f"{file_path('ja', IOS, 'references/basics.md')}:", "内部の言葉がある: ADR")

    def test_frontmatterの中の内部の言葉も失敗する(self) -> None:
        target = file_path("ja", IOS, "SKILL.md")
        self.replace(target, "一覧の画面を作る (list screens)。", "利用者役の画面を作る (list screens)。")
        self.assert_fails(f"{target}:", "内部の言葉がある: 利用者役")

    def test_大文字と小文字を区別せずに探す(self) -> None:
        target = file_path("en", IOS, "references/images.md")
        self.append(target, "\nWritten with the kasane harness.\n")
        self.assert_fails(f"{target}:", "内部の言葉がある: Kasane", count=1)

    def test_ほかの単語の一部は内部の言葉に数えない(self) -> None:
        for language in ("en", "ja"):
            target = file_path(language, IOS, "references/basics.md")
            self.append(target, "\nA quadratic layout in Madrid uses the padrAdr2 helper and the backsn-1 mode.\n")
        self.assert_passes()


class MissingSkillsTest(SkillsCase):
    def test_skillsが無いと失敗する(self) -> None:
        import shutil

        shutil.rmtree(self.path("skills"))
        self.assert_fails("skills/ が無い", count=1)

    def test_Skillが1つも無いと失敗する(self) -> None:
        import shutil

        cases = {
            "skills/ が空": lambda: shutil.rmtree(self.path("skills/en")) or shutil.rmtree(self.path("skills/ja")),
            "言語のディレクトリが空": lambda: [
                shutil.rmtree(self.path(f"skills/{language}/{name}")) for language in ("en", "ja") for name in (IOS, ANDROID)
            ],
        }
        for title, empty in cases.items():
            with self.subTest(case=title):
                self.setUp()
                empty()
                # 索引だけがあっても、Skill があることにはならない。
                self.put("skills/README.md", "# Skills\n")
                self.assert_fails("Skill が 1 つも無い", count=1)

    def test_言語のディレクトリの直下のファイルはSkillに数えない(self) -> None:
        import shutil

        for language in ("en", "ja"):
            for name in (IOS, ANDROID):
                shutil.rmtree(self.path(f"skills/{language}/{name}"))
            self.put(f"skills/{language}/README.md", "# Skills\n")
        self.assert_fails("Skill が 1 つも無い", count=1)


class BrokenMarkdownTest(SkillsCase):
    def test_コードブロックが閉じていないと失敗する(self) -> None:
        target = file_path("en", IOS, "references/images.md")
        lines = len(self.get(target).splitlines())
        self.append(target, "\n```swift\nlet a = 1\n")
        self.assert_fails(f"{target}: {lines + 2} 行目: コードブロックが閉じていない", count=1)


class ArgumentTest(SkillsCase):
    def test_無いルートでは始めない(self) -> None:
        code, output = support.run_main(SCRIPT, [os.path.join(self.root, "missing")])[:2]
        self.assertEqual(code, 2)
        self.assertIn("::error::リポジトリのルートが、実在するディレクトリではない", output)
        # 何も確かめていない (違反の件数も、成功の報告も出ない)。
        self.assertNotIn("Skill 自身の整合の検査", output)

    def test_ファイルをルートとして渡しても始めない(self) -> None:
        code, output = support.run_main(SCRIPT, [self.path(file_path("en", IOS, "SKILL.md"))])[:2]
        self.assertEqual(code, 2)
        self.assertNotIn("Skill 自身の整合の検査", output)

    def test_ルートを渡さないと引数の誤りで終わる(self) -> None:
        code, _, _ = support.run_main(SCRIPT, [])
        self.assertEqual(code, 2)

    def test_skillsの下ではなくルートを渡す(self) -> None:
        # skills/ そのものを渡すと、その下に skills/ が無いので失敗する。
        code, output = support.run_main(SCRIPT, [self.path("skills")])[:2]
        self.assertEqual(code, 1, output)
        self.assertIn("skills/ が無い", output)


if __name__ == "__main__":
    unittest.main()
