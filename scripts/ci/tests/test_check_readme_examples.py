"""README の例の検査のテスト。

検査は、一時のディレクトリに作ったリポジトリのひな形 (ルートの README の 2 枚・4 つの SKILL.md・
利用者役の画面のファイル・比べる相手の値の出どころ) に対して流す。ひな形の値 (Package URL・
package と product の名前・Maven の座標) は、実物と違う値にしてある。検査が、値を自分で
持たずに、渡したルートの下の利用者役から取っていることを確かめるためである。

実物については、比べる相手の値を今の利用者役から取り出せることだけを確かめる。今の README と
skills/ には、検査を流さない。
"""

from __future__ import annotations

import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("check-readme-examples.py")
USER_DOCS = support.load_script("user_docs.py")

LATEST_VERSION_URL = USER_DOCS.load_rules().allowed_urls["latest-version"]

PACKAGE_URL = "https://github.com/example-org/Example-SPM"
PACKAGE_NAME = "Example-SPM"
PRODUCT_NAME = "ExampleKit"
COORDINATE = "com.example:examplekit"

PACKAGE_LINE = f'.package(url: "{PACKAGE_URL}", exact: "{{version}}"),'
PRODUCT_LINE = f'.product(name: "{PRODUCT_NAME}", package: "{PACKAGE_NAME}"),'
GRADLE_LINE = f'implementation("{COORDINATE}:{{version}}")'

SWIFT_SOURCE = """\
import ExampleKit
import SwiftUI

struct ItemListScreen: View {
    var body: some View {
        ExampleList(items) { item in
            Text(item.title)
        }
    }
}
"""
KOTLIN_SOURCE = """\
import com.example.examplekit.ExampleList

@Composable
fun ItemListScreen() {
    ExampleList(items = items) {
        template { item -> BasicText(item.title) }
    }
}
"""

# 確認のスクリプトの代わり。公開済みの配布物を取るときに差し込む行を、実物と同じ呼び方で返す。
CONSUMER_SCRIPT = f'''\
from __future__ import annotations

import dataclasses


@dataclasses.dataclass(frozen=True)
class Request:
    mode: str
    version: str | None


def dependency_line(request: Request) -> str:
    if request.mode == "published":
        return f'.package(url: "{PACKAGE_URL}", exact: "{{request.version}}"),'
    return '.package(path: "../{PACKAGE_NAME}"),'
'''
MANIFEST_TEMPLATE = f"""\
// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "VerificationApp",
    dependencies: [
        @KSCV_DEPENDENCY@
    ],
    targets: [
        .target(
            name: "VerificationApp",
            dependencies: [
                {PRODUCT_LINE}
            ]
        ),
    ]
)
"""
BUILD_FILE = f"""\
dependencies {{
    implementation("{COORDINATE}:$exampleVersion")
    implementation(libs.compose.foundation)
    implementation("androidx.activity:activity-compose:1.11.0")
}}
"""

SWIFTPM_EXAMPLE = f"""\
```swift
dependencies: [
    {PACKAGE_LINE}
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            {PRODUCT_LINE}
        ]
    ),
]
```
"""
GRADLE_EXAMPLE = f"""\
```kotlin
dependencies {{
    {GRADLE_LINE}
}}
```
"""


def readme(title: str, installation: str, examples: str, latest: str) -> str:
    return f"""\
# Example

## {installation}

{latest} [releases]({LATEST_VERSION_URL})

### Swift Package Manager

{SWIFTPM_EXAMPLE}
### Gradle

{GRADLE_EXAMPLE}
## {examples}

### iOS

```swift
{SWIFT_SOURCE}```

### Android

```kotlin
{KOTLIN_SOURCE}```

## {title}

MIT
"""


def skill(example: str) -> str:
    return f"""\
---
name: example
---

# Example

## Setup

{example}
`{{version}}` is a placeholder. See the [releases]({LATEST_VERSION_URL}) page.
"""


README_EN = "README.md"
README_JA = "README_ja.md"
IOS_SKILL_EN = "skills/en/kscollectionview-ios/SKILL.md"
IOS_SKILL_JA = "skills/ja/kscollectionview-ios/SKILL.md"
ANDROID_SKILL_EN = "skills/en/kscollectionview-android/SKILL.md"
ANDROID_SKILL_JA = "skills/ja/kscollectionview-android/SKILL.md"
IOS_SOURCE = "verification/ios/Sources/VerificationApp/ItemListScreen.swift"
ANDROID_SOURCE = "verification/android/app/src/main/kotlin/ItemListScreen.kt"
CONSUMER_SCRIPT_PATH = "scripts/ci/verify-consumer-ios.py"
MANIFEST_TEMPLATE_PATH = "verification/ios/Package.swift.template"
BUILD_FILE_PATH = "verification/android/app/build.gradle.kts"

# インストール例を持つファイルと、持つ例の行。
INSTALL_FILES = {
    README_EN: (PACKAGE_LINE, PRODUCT_LINE, GRADLE_LINE),
    README_JA: (PACKAGE_LINE, PRODUCT_LINE, GRADLE_LINE),
    IOS_SKILL_EN: (PACKAGE_LINE, PRODUCT_LINE),
    IOS_SKILL_JA: (PACKAGE_LINE, PRODUCT_LINE),
    ANDROID_SKILL_EN: (GRADLE_LINE,),
    ANDROID_SKILL_JA: (GRADLE_LINE,),
}

FILES = {
    README_EN: readme("License", "Installation", "Minimal code examples", "Find the latest version on the"),
    README_JA: readme("ライセンス", "インストール", "最小コード例", "最新の版は次で確かめる:"),
    IOS_SKILL_EN: skill(SWIFTPM_EXAMPLE),
    IOS_SKILL_JA: skill(SWIFTPM_EXAMPLE),
    ANDROID_SKILL_EN: skill(GRADLE_EXAMPLE),
    ANDROID_SKILL_JA: skill(GRADLE_EXAMPLE),
    IOS_SOURCE: SWIFT_SOURCE,
    ANDROID_SOURCE: KOTLIN_SOURCE,
    CONSUMER_SCRIPT_PATH: CONSUMER_SCRIPT,
    MANIFEST_TEMPLATE_PATH: MANIFEST_TEMPLATE,
    BUILD_FILE_PATH: BUILD_FILE,
}


class RepositoryCase(unittest.TestCase):
    """一時のディレクトリに、検査が通るリポジトリのひな形を作る。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = directory.name
        for relative, text in FILES.items():
            self.put(relative, text)

    def path(self, relative: str) -> str:
        return os.path.join(self.root, *relative.split("/"))

    def put(self, relative: str, text: str) -> None:
        support.write(self.path(relative), text)

    def get(self, relative: str) -> str:
        with open(self.path(relative), encoding="utf-8") as f:
            return f.read()

    def replace(self, relative: str, old: str, new: str, count: int = -1) -> None:
        """ファイルの中の文面を置き換える。置き換える文面が無ければ、テストの誤りとして止める。"""
        text = self.get(relative)
        self.assertIn(old, text, f"{relative} に、置き換える文面が無い")
        self.put(relative, text.replace(old, new, count))

    def remove(self, relative: str) -> None:
        os.remove(self.path(relative))

    def check(self) -> tuple[int, str]:
        code, stdout, _ = support.run_main(SCRIPT, [self.root])
        return code, stdout

    def assert_passes(self) -> str:
        code, output = self.check()
        self.assertEqual(code, 0, output)
        self.assertNotIn("::error::", output)
        return output

    def assert_fails(self, *fragments: str) -> str:
        """検査が失敗で終わり、どれか 1 件の違反が、渡した文面をすべて含むことを確かめる。"""
        code, output = self.check()
        self.assertEqual(code, 1, output)
        errors = [line for line in output.splitlines() if line.startswith("::error::")]
        self.assertTrue(errors, output)
        self.assertTrue(
            any(all(fragment in line for fragment in fragments) for line in errors),
            f"{fragments} をすべて含む違反が無い:\n{output}",
        )
        return output


class MinimalExampleTest(RepositoryCase):
    def test_一致していれば成功する(self) -> None:
        output = self.assert_passes()
        # README の 2 枚 × 2 つのプラットフォームを比べている。
        self.assertIn("一致した最小コード例 4 つ", output)

    def test_READMEの例だけを変えると失敗しどのREADMEのどのプラットフォームかが出る(self) -> None:
        cases = {
            (README_EN, "iOS"): ("ExampleList(items) {", "ExampleList(itemz) {"),
            (README_EN, "Android"): ("BasicText(item.title)", "BasicText(item.titlf)"),
            (README_JA, "iOS"): ("ExampleList(items) {", "ExampleList(itemz) {"),
            (README_JA, "Android"): ("BasicText(item.title)", "BasicText(item.titlf)"),
        }
        for (path, platform), (old, new) in cases.items():
            with self.subTest(readme=path, platform=platform):
                self.setUp()
                self.replace(path, old, new)
                output = self.assert_fails(f"{path}:", f"{platform} の最小コード例")
                # 違反は、変えた 1 か所だけである。
                self.assertEqual(output.count("::error::"), 1, output)

    def test_利用者役のファイルだけを変えると失敗する(self) -> None:
        cases = {"iOS": (IOS_SOURCE, SWIFT_SOURCE), "Android": (ANDROID_SOURCE, KOTLIN_SOURCE)}
        for platform, (path, source) in cases.items():
            with self.subTest(platform=platform):
                self.setUp()
                self.put(path, source + "\n// changed\n")
                # README の 2 枚の、どちらの例も違うと出る。
                self.assert_fails(f"{README_EN}:", f"{platform} の最小コード例", path)
                self.assert_fails(f"{README_JA}:", f"{platform} の最小コード例", path)

    def test_日本語版のREADMEも確かめる(self) -> None:
        self.replace(README_JA, "ExampleList(items) {", "ExampleList(itemz) {")
        output = self.assert_fails(f"{README_JA}:", "iOS の最小コード例")
        self.assertNotIn(f"{README_EN}:", output)

    def test_節が見つからないと失敗する(self) -> None:
        cases = {README_EN: "## Minimal code examples\n", README_JA: "## 最小コード例\n"}
        for path, heading in cases.items():
            with self.subTest(readme=path):
                self.setUp()
                self.replace(path, heading, "")
                self.assert_fails(f"{path}:", "最小コード例の節の見出し")

    def test_節の見出しの文面が違うと失敗する(self) -> None:
        self.replace(README_EN, "## Minimal code examples\n", "## Quick start\n")
        self.assert_fails(f"{README_EN}:", "最小コード例の節の見出し")

    def test_節の見出しが2つあると失敗する(self) -> None:
        self.put(README_EN, self.get(README_EN) + "\n## Minimal code examples\n")
        self.assert_fails(f"{README_EN}:", "最小コード例の節の見出し")

    def test_節にコードブロックが無いと失敗する(self) -> None:
        self.replace(README_JA, f"```kotlin\n{KOTLIN_SOURCE}```\n", "")
        self.assert_fails(f"{README_JA}:", "Android の例", "0 つ")

    def test_節に同じ言語のコードブロックが2つあると失敗する(self) -> None:
        block = f"```swift\n{SWIFT_SOURCE}```\n"
        self.replace(README_EN, f"### iOS\n\n{block}", f"### iOS\n\n{block}\n{block}")
        self.assert_fails(f"{README_EN}:", "iOS の例", "2 つ")

    def test_節の外のコードブロックは最小コード例に数えない(self) -> None:
        # 節の後ろに、同じ言語の別のコードを足しても、節の中の 1 つだけを比べる。
        self.put(README_EN, self.get(README_EN) + "\n## Notes\n\n```swift\nlet other = 1\n```\n")
        self.put(README_JA, self.get(README_JA) + "\n## 補足\n\n```swift\nlet other = 1\n```\n")
        self.assert_passes()

    def test_節の中の小見出しの深さは問わない(self) -> None:
        for path in (README_EN, README_JA):
            self.replace(path, "### iOS\n", "#### iOS\n")
        self.assert_passes()

    def test_末尾の改行だけが違っても失敗する(self) -> None:
        self.put(IOS_SOURCE, SWIFT_SOURCE + "\n")
        self.assert_fails(f"{README_EN}:", "iOS の最小コード例", "行の数が違う")

    def test_利用者役のファイルが無いと失敗する(self) -> None:
        for platform, path in (("iOS", IOS_SOURCE), ("Android", ANDROID_SOURCE)):
            with self.subTest(platform=platform):
                self.setUp()
                self.remove(path)
                self.assert_fails(f"{path}:", "利用者役の画面のファイルが無い")

    def test_READMEが無いと失敗する(self) -> None:
        for path in (README_EN, README_JA):
            with self.subTest(readme=path):
                self.setUp()
                self.remove(path)
                self.assert_fails(f"{path}:", "ファイルが無い")

    def test_READMEのコードブロックが閉じていないと失敗する(self) -> None:
        self.put(README_EN, self.get(README_EN) + "\n```swift\nlet a = 1\n")
        self.assert_fails(f"{README_EN}:", "コードブロックが閉じていない")


class InstallExampleTest(RepositoryCase):
    def test_決めた形なら成功する(self) -> None:
        output = self.assert_passes()
        # README の 2 枚に 3 行ずつ、iOS の SKILL.md の 2 枚に 2 行ずつ、Android の 2 枚に 1 行ずつ。
        self.assertIn("確かめた依存の宣言の行 12 行", output)

    def test_具体の版が書かれていると失敗しそのファイルが出る(self) -> None:
        for path, lines in INSTALL_FILES.items():
            for line in lines:
                if "{version}" not in line:
                    continue
                with self.subTest(file=path, line=line):
                    self.setUp()
                    self.replace(path, line, line.replace("{version}", "1.2.3"))
                    self.assert_fails(f"{path}:", "具体の版を書かない")

    def test_版の指定の書き方が違うと失敗する(self) -> None:
        self.replace(README_EN, 'exact: "{version}"', 'from: "{version}"')
        self.assert_fails(f"{README_EN}:", "SwiftPM の Package URL の行", "版の指定が")

    def test_値が利用者役と違うと失敗する(self) -> None:
        cases = {
            "Package URL": (PACKAGE_URL, "https://github.com/example-org/Other-SPM", "Package URL が"),
            "product の名前": (f'name: "{PRODUCT_NAME}"', 'name: "OtherKit"', "product の名前が"),
            "package の名前": (f'package: "{PACKAGE_NAME}"', 'package: "Other-SPM"', "package の名前が"),
            "Maven の座標": (COORDINATE, "com.example:otherkit", "Maven の座標が"),
        }
        for title, (old, new, message) in cases.items():
            with self.subTest(value=title):
                self.setUp()
                self.replace(README_EN, old, new)
                output = self.assert_fails(f"{README_EN}:", message)
                # ほかのファイルは、違反にならない。
                self.assertEqual(output.count("::error::"), 1, output)

    def test_SKILLの値が利用者役と違っても失敗する(self) -> None:
        self.replace(IOS_SKILL_JA, PACKAGE_URL, "https://github.com/example-org/Other-SPM")
        self.assert_fails(f"{IOS_SKILL_JA}:", "Package URL が")
        self.setUp()
        self.replace(ANDROID_SKILL_EN, COORDINATE, "com.example:otherkit")
        self.assert_fails(f"{ANDROID_SKILL_EN}:", "Maven の座標が")

    def test_比べる相手の値は渡したルートの利用者役から取る(self) -> None:
        # README を変えずに、利用者役の側の値を変えると、6 つのファイルの例が違うことになる。
        self.replace(BUILD_FILE_PATH, COORDINATE, "com.example:renamed")
        output = self.assert_fails(f"{README_EN}:", "Maven の座標が", "com.example:renamed")
        self.assertEqual(output.count("Maven の座標が"), 4, output)

        self.setUp()
        self.replace(CONSUMER_SCRIPT_PATH, PACKAGE_URL, "https://github.com/example-org/Renamed-SPM")
        output = self.assert_fails(f"{IOS_SKILL_EN}:", "Package URL が", "Renamed-SPM")
        self.assertEqual(output.count("Package URL が"), 4, output)

        self.setUp()
        self.replace(MANIFEST_TEMPLATE_PATH, f'name: "{PRODUCT_NAME}"', 'name: "RenamedKit"')
        output = self.assert_fails(f"{README_JA}:", "product の名前が", "RenamedKit")
        self.assertEqual(output.count("product の名前が"), 4, output)

    def assert_off_form_fails(self, path: str, old: str, new: str, title: str, count: int | None = 1) -> None:
        """例の 1 行を置き換えると、決めた形でない行が違反として出ることを確かめる。

        count は、違反の件数。None を渡すと、件数を確かめない。
        """
        self.replace(path, old, new)
        output = self.assert_fails(f"{path}:", f"本ライブラリの {title}", "決めた形", "具体の版を書かない")
        if count is not None:
            self.assertEqual(output.count("::error::"), count, output)

    def test_行末にコメントを足した行の具体の版も失敗する(self) -> None:
        self.assert_off_form_fails(
            README_EN, GRADLE_LINE, f'{GRADLE_LINE}\n    implementation("{COORDINATE}:1.2.3") // pinned', "Maven の座標"
        )

    def test_Groovyの書き方の具体の版も失敗する(self) -> None:
        self.assert_off_form_fails(
            README_JA, GRADLE_LINE, f"{GRADLE_LINE}\n    implementation '{COORDINATE}:1.2.3'", "Maven の座標"
        )

    def test_apiで書いた具体の版も失敗する(self) -> None:
        self.assert_off_form_fails(
            ANDROID_SKILL_EN, GRADLE_LINE, f'{GRADLE_LINE}\n    api("{COORDINATE}:1.2.3")', "Maven の座標"
        )

    def test_複数行に分けた宣言の具体の版も失敗する(self) -> None:
        split = f'.package(\n        url: "{PACKAGE_URL}",\n        exact: "1.2.3"\n    ),'
        self.assert_off_form_fails(IOS_SKILL_JA, PACKAGE_LINE, f"{PACKAGE_LINE}\n    {split}", "Package URL")

    def test_決めた形の行を持たずに別の書き方だけで書いても失敗する(self) -> None:
        # 例が無い違反も一緒に出るので、件数は確かめない。
        self.assert_off_form_fails(
            ANDROID_SKILL_JA, GRADLE_LINE, f"implementation '{COORDINATE}:1.2.3'", "Maven の座標", count=None
        )

    def test_ほかのライブラリの依存の行は確かめない(self) -> None:
        # 本ライブラリの値に触れていない行は、どの書き方でも、具体の版を持っていてもよい。
        for path in (README_EN, README_JA):
            self.replace(
                path,
                GRADLE_LINE,
                f'{GRADLE_LINE}\n    implementation("androidx.activity:activity-compose:1.11.0") // other',
            )
        self.assert_passes()

    def test_最新の版の確かめ先が無いと失敗しそのファイルが出る(self) -> None:
        for path in INSTALL_FILES:
            with self.subTest(file=path):
                self.setUp()
                self.replace(path, f"({LATEST_VERSION_URL})", "")
                output = self.assert_fails(f"{path}:", "最新の版の確かめ先の URL が無い")
                self.assertEqual(output.count("::error::"), 1, output)

    def test_最新の版の確かめ先に続きを足したURLでは代わりにならない(self) -> None:
        self.replace(README_EN, f"({LATEST_VERSION_URL})", f"({LATEST_VERSION_URL}/latest)")
        self.assert_fails(f"{README_EN}:", "最新の版の確かめ先の URL が無い")

    def test_例が無いファイルがあると失敗する(self) -> None:
        cases = {
            "iOS の SKILL.md の SwiftPM": ((IOS_SKILL_EN, IOS_SKILL_JA), SWIFTPM_EXAMPLE, "SwiftPM の Package URL の行が無い"),
            "Android の SKILL.md の Gradle": ((ANDROID_SKILL_EN, ANDROID_SKILL_JA), GRADLE_EXAMPLE, "Gradle の依存の行が無い"),
            "README の SwiftPM": ((README_EN, README_JA), SWIFTPM_EXAMPLE, "SwiftPM の product の行が無い"),
            "README の Gradle": ((README_EN, README_JA), GRADLE_EXAMPLE, "Gradle の依存の行が無い"),
        }
        for title, (paths, example, message) in cases.items():
            with self.subTest(case=title):
                # 英語版と日本語版の両方から消す。数は揃っているので、例が無いことだけが違反になる。
                self.setUp()
                for path in paths:
                    self.replace(path, example, "")
                output = self.assert_fails(f"{paths[0]}:", message)
                self.assert_fails(f"{paths[1]}:", message)
                self.assertNotIn("種類と数が違う", output)

    def test_片方の言語のSKILLからだけ例を消しても失敗する(self) -> None:
        self.replace(IOS_SKILL_EN, SWIFTPM_EXAMPLE, "")
        self.assert_fails(f"{IOS_SKILL_EN}:", "SwiftPM の Package URL の行が無い")

    def test_productの行だけが無くても失敗する(self) -> None:
        for path in (IOS_SKILL_EN, IOS_SKILL_JA):
            self.replace(path, f"            {PRODUCT_LINE}\n", "")
        self.assert_fails(f"{IOS_SKILL_EN}:", "SwiftPM の product の行が無い")

    def test_英語版と日本語版で例の数が違うと失敗する(self) -> None:
        self.replace(README_JA, GRADLE_EXAMPLE, "")
        self.assert_fails(README_EN, README_JA, "種類と数が違う", "Gradle の依存の行 1 つ / 0 つ")

    def test_例がどちらにもあっても数が違うと失敗する(self) -> None:
        # 英語版にだけ、正しい例をもう 1 つ足す。値の違反も、例が無い違反も出ない。
        self.put(ANDROID_SKILL_EN, self.get(ANDROID_SKILL_EN) + "\n" + GRADLE_EXAMPLE)
        output = self.assert_fails(ANDROID_SKILL_EN, ANDROID_SKILL_JA, "種類と数が違う", "Gradle の依存の行 2 つ / 1 つ")
        self.assertEqual(output.count("::error::"), 1, output)

    def test_文の中に書いた依存の宣言は例に数えない(self) -> None:
        # コードブロックの外の同じ字面は、例の代わりにならない。
        for path in (ANDROID_SKILL_EN, ANDROID_SKILL_JA):
            self.replace(path, GRADLE_EXAMPLE, f"Add `{GRADLE_LINE}` to your dependencies.\n\n{GRADLE_LINE}\n")
        self.assert_fails(f"{ANDROID_SKILL_EN}:", "Gradle の依存の行が無い")

    def test_文の中に書いた具体の版は違反に数えない(self) -> None:
        for path in (README_EN, README_JA):
            self.put(path, self.get(path) + '\nFor example, write `implementation("com.example:examplekit:1.2.3")`.\n')
        self.assert_passes()

    def test_対象のファイルが無いと失敗する(self) -> None:
        for path in INSTALL_FILES:
            with self.subTest(file=path):
                self.setUp()
                self.remove(path)
                self.assert_fails(f"{path}:", "ファイルが無い")

    def test_比べる相手の値の出どころが無いと失敗する(self) -> None:
        for path in (CONSUMER_SCRIPT_PATH, MANIFEST_TEMPLATE_PATH, BUILD_FILE_PATH):
            with self.subTest(source=path):
                self.setUp()
                self.remove(path)
                self.assert_fails(f"{path}:", "無い")

    def test_比べる相手の値を読み取れないと失敗する(self) -> None:
        cases = {
            "差し込む行を返す関数が無い": (CONSUMER_SCRIPT_PATH, "def dependency_line", "def other_line", "差し込む行を取れない"),
            "差し込む行が URL の形でない": (CONSUMER_SCRIPT_PATH, ".package(url:", ".package(path:", "版の指定の形でない"),
            "差し込む行に版の位置が無い": (CONSUMER_SCRIPT_PATH, "{request.version}", "1.0.0", "版の指定の形でない"),
            "product の行が無い": (MANIFEST_TEMPLATE_PATH, PRODUCT_LINE, "", "product の行が、ちょうど 1 つ無い"),
            "版を変数で書いた依存の行が無い": (BUILD_FILE_PATH, "$exampleVersion", "1.0.0", "ちょうど 1 つ無い"),
        }
        for title, (path, old, new, message) in cases.items():
            with self.subTest(case=title):
                self.setUp()
                self.replace(path, old, new)
                self.assert_fails(f"{path}:", message)

    def test_確認のスクリプトの読み込みが残らない(self) -> None:
        import sys

        before_path = list(sys.path)
        self.assert_passes()
        self.assertEqual([name for name in sys.modules if name.startswith("_user_docs_consumer_ios_")], [])
        self.assertEqual(sys.path, before_path)
        # 読み込んだ先に、バイトコードのキャッシュを作らない。
        self.assertFalse(os.path.exists(os.path.join(os.path.dirname(self.path(CONSUMER_SCRIPT_PATH)), "__pycache__")))


class ArgumentTest(RepositoryCase):
    def test_無いルートでは始めない(self) -> None:
        code, output = support.run_main(SCRIPT, [os.path.join(self.root, "missing")])[:2]
        self.assertEqual(code, 2)
        self.assertIn("::error::リポジトリのルートが、実在するディレクトリではない", output)
        # 何も比べていない (違反の件数も、成功の報告も出ない)。
        self.assertNotIn("README の例の検査", output)

    def test_ファイルをルートとして渡しても始めない(self) -> None:
        code, output = support.run_main(SCRIPT, [self.path(README_EN)])[:2]
        self.assertEqual(code, 2)
        self.assertNotIn("README の例の検査", output)

    def test_ルートを渡さないと引数の誤りで終わる(self) -> None:
        code, _, _ = support.run_main(SCRIPT, [])
        self.assertEqual(code, 2)

    def test_どの作業ディレクトリから呼んでも渡したルートを見る(self) -> None:
        current = os.getcwd()
        self.addCleanup(os.chdir, current)
        with tempfile.TemporaryDirectory() as elsewhere:
            os.chdir(elsewhere)
            code, output = self.check()
            os.chdir(current)
        self.assertEqual(code, 0, output)


class RealConsumerTest(unittest.TestCase):
    def test_実物の利用者役から比べる相手の値を取れる(self) -> None:
        expected = SCRIPT.load_expected(support.REPOSITORY_ROOT)
        self.assertEqual(expected.package_url, "https://github.com/kamusoft/KsCollectionView-SPM")
        self.assertEqual(expected.requirement, 'exact: "{version}"')
        self.assertEqual(expected.product, "KsCollectionView")
        self.assertEqual(expected.package, "KsCollectionView-SPM")
        self.assertEqual(expected.coordinate, "jp.kamusoft:kscollectionview")

    def test_実物の利用者役の画面のファイルがある(self) -> None:
        for platform in SCRIPT.PLATFORMS:
            with self.subTest(platform=platform.title):
                self.assertTrue(os.path.isfile(os.path.join(support.REPOSITORY_ROOT, *platform.source.split("/"))))


if __name__ == "__main__":
    unittest.main()
