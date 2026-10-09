"""Android の利用者の立場のビルドの確認のテスト。

確認のスクリプトは、一時のディレクトリに作った使い捨てのリポジトリの形 (スクリプトの写し・
本体のバージョンカタログ・2 つのビルドルート) の中で、別のプロセスとして流す。2 つのビルドルートの
gradlew は、呼ばれ方を記録して、決めたとおりに振る舞う偽物に差し替えてある。発行も組み立ても、
実際には走らない。スクリプトの出力は、子プロセスの出力を含めて、プロセスの外から読む。

利用者役の実物 (verification/android/) については、ビルドの定義の書き方だけを確かめる。
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

import support

SCRIPT_NAME = "verify-consumer-android.py"
SCRIPT = support.load_script(SCRIPT_NAME)

CATALOG_VERSION = "0.4.0-SNAPSHOT"
CATALOG_TEXT = f"""\
[versions]
agp = "9.4.0"
# ライブラリの版
kscollectionview = "{CATALOG_VERSION}"

[libraries]
kscollectionview = {{ group = "jp.kamusoft", name = "kscollectionview" }}
"""

# gradlew の偽物。呼ばれ方を calls.jsonl に 1 行ずつ足し、behavior.json に従って振る舞う。
#
# behavior.json は、タスクの種類 (publish / assemble / dependencies) ごとに次を持てる。
#   exit            終了コード (既定 0)
#   stdout / stderr 出す文字 (既定は、種類ごとの決まった 1 行)
#   skip_outputs    真なら、成功したときに作るはずのファイル (発行物・対応表) を作らない
FAKE_GRADLEW = r'''#!/usr/bin/env python3
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
root = here
while not os.path.isfile(os.path.join(root, "behavior.json")):
    root = os.path.dirname(root)

arguments = sys.argv[1:]
with open(os.path.join(root, "calls.jsonl"), "a", encoding="utf-8") as f:
    f.write(json.dumps({"build": os.path.relpath(here, root), "cwd": os.path.relpath(os.getcwd(), root), "arguments": arguments}) + "\n")

with open(os.path.join(root, "behavior.json"), encoding="utf-8") as f:
    behavior = json.load(f)


def value(prefix):
    for argument in arguments:
        if argument.startswith(prefix):
            return argument[len(prefix):]
    return None


if any(argument.endswith(":publishToMavenLocal") for argument in arguments):
    kind = "publish"
elif ":app:assembleRelease" in arguments:
    kind = "assemble"
elif ":app:dependencies" in arguments:
    kind = "dependencies"
else:
    sys.stderr.write("知らない呼ばれ方: " + " ".join(arguments) + "\n")
    sys.exit(64)

settings = behavior.get(kind, {})
code = settings.get("exit", 0)
defaults = {
    "publish": "> Task :kscollectionview:publishToMavenLocal\n",
    "assemble": "> Task :app:minifyReleaseWithR8\n",
    "dependencies": "+--- jp.kamusoft:kscollectionview:" + str(value("-PksCollectionViewVersion=")) + "\n",
}
sys.stdout.write(settings.get("stdout", defaults[kind]))
sys.stdout.flush()
sys.stderr.write(settings.get("stderr", ""))
sys.stderr.flush()

if code == 0 and not settings.get("skip_outputs"):
    if kind == "publish":
        version = value("-Pversion=")
        directory = os.path.join(value("-Dmaven.repo" + ".local="), "jp", "kamusoft", "kscollectionview", version)
        os.makedirs(directory, exist_ok=True)
        with open(os.path.join(directory, "kscollectionview-" + version + ".pom"), "w", encoding="utf-8") as f:
            f.write("<project/>\n")
    elif kind == "assemble":
        directory = os.path.join(here, "app", "build", "outputs", "mapping", "release")
        os.makedirs(directory, exist_ok=True)
        with open(os.path.join(directory, "mapping.txt"), "w", encoding="utf-8") as f:
            f.write("# 対応表\n")

sys.exit(code)
'''

LOCAL_REPOSITORY_ARGUMENT = "-D" + SCRIPT.LOCAL_REPOSITORY_PROPERTY + "="
SOURCE_ARGUMENT_PREFIX = "-PksCollectionView"


def task_names(arguments: list[str]) -> list[str]:
    return [argument for argument in arguments if argument.startswith(":")]


def argument_value(arguments: list[str], prefix: str) -> str | None:
    values = [argument[len(prefix) :] for argument in arguments if argument.startswith(prefix)]
    return values[0] if values else None


class ConsumerVerificationTestCase(unittest.TestCase):
    """使い捨てのリポジトリの形を作り、その中の確認のスクリプトを別のプロセスで流す。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = os.path.realpath(directory.name)
        for name in (SCRIPT_NAME, "ci_report.py"):
            os.makedirs(os.path.join(self.root, "scripts", "ci"), exist_ok=True)
            shutil.copy(support.script_path(name), os.path.join(self.root, "scripts", "ci", name))
        support.write(os.path.join(self.root, SCRIPT.VERSION_CATALOG), CATALOG_TEXT)
        for build in (SCRIPT.LIBRARY_BUILD, SCRIPT.CONSUMER_BUILD):
            gradlew = support.write(os.path.join(self.root, build, "gradlew"), FAKE_GRADLEW)
            os.chmod(gradlew, 0o755)
        self.behave({})

    def behave(self, behavior: dict) -> None:
        support.write(os.path.join(self.root, "behavior.json"), json.dumps(behavior))

    def run_script(self, *arguments: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        environment = {
            key: value for key, value in os.environ.items() if not key.startswith(("GITHUB_", "KS_"))
        }
        # 子プロセスの出力の文字コードを、流す環境のロケールに左右させない。
        environment["PYTHONIOENCODING"] = "utf-8"
        environment.update(env or {})
        return subprocess.run(
            [sys.executable, os.path.join(self.root, "scripts", "ci", SCRIPT_NAME), *arguments],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=environment,
            check=False,
        )

    def calls(self) -> list[dict]:
        path = os.path.join(self.root, "calls.jsonl")
        if not os.path.exists(path):
            return []
        with open(path, encoding="utf-8") as f:
            return [json.loads(line) for line in f]

    def mapping_path(self) -> str:
        return os.path.join(self.root, SCRIPT.MAPPING)


class LocalModeTests(ConsumerVerificationTestCase):
    def test_発行と組み立てと依存の確認をこの順に行う(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

        publish, assemble, dependencies = self.calls()
        self.assertEqual(publish["build"], SCRIPT.LIBRARY_BUILD)
        self.assertEqual(task_names(publish["arguments"]), [":kscollectionview:publishToMavenLocal"])
        self.assertEqual(assemble["build"], SCRIPT.CONSUMER_BUILD)
        self.assertEqual(task_names(assemble["arguments"]), [":app:assembleRelease"])
        self.assertEqual(dependencies["build"], SCRIPT.CONSUMER_BUILD)
        self.assertEqual(task_names(dependencies["arguments"]), [":app:dependencies"])
        self.assertIn("releaseRuntimeClasspath", dependencies["arguments"])
        # どの Gradle も、自分のビルドルートを作業ディレクトリにして呼ぶ。
        for call in (publish, assemble, dependencies):
            self.assertEqual(call["cwd"], call["build"])

    def test_版を渡さなければバージョンカタログの版を使う(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        publish, assemble, dependencies = self.calls()
        self.assertEqual(argument_value(publish["arguments"], "-Pversion="), CATALOG_VERSION)
        for call in (assemble, dependencies):
            self.assertEqual(argument_value(call["arguments"], "-PksCollectionViewVersion="), CATALOG_VERSION)
        self.assertIn(f"jp.kamusoft:kscollectionview:{CATALOG_VERSION}", result.stdout)

    def test_版が空ならバージョンカタログの版を使う(self) -> None:
        # workflow は、版の入力が空のときに空の文字列を渡す。
        result = self.run_script("--mode", "local", "--version", "")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(argument_value(self.calls()[0]["arguments"], "-Pversion="), CATALOG_VERSION)

    def test_渡された版をどの手順にも渡す(self) -> None:
        result = self.run_script("--mode", "local", "--version", "1.2.3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        publish, assemble, dependencies = self.calls()
        self.assertEqual(argument_value(publish["arguments"], "-Pversion="), "1.2.3")
        for call in (assemble, dependencies):
            self.assertEqual(argument_value(call["arguments"], "-PksCollectionViewVersion="), "1.2.3")

    def test_利用者役は作業用のリポジトリからだけ本ライブラリを取る(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        publish, assemble, dependencies = self.calls()
        repository = argument_value(publish["arguments"], LOCAL_REPOSITORY_ARGUMENT)
        self.assertTrue(repository and os.path.isabs(repository), repository)
        for call in (assemble, dependencies):
            self.assertEqual(argument_value(call["arguments"], "-PksCollectionViewMode="), "local")
            # 利用者役が取る場所は、発行した場所と同じである。
            self.assertEqual(argument_value(call["arguments"], "-PksCollectionViewRepository="), repository)

    def test_既定の手元のMavenリポジトリに発行しない(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        publish = self.calls()[0]
        repository = argument_value(publish["arguments"], LOCAL_REPOSITORY_ARGUMENT)
        # 発行先の指定が無いと、既定の手元の Maven リポジトリに発行される。
        self.assertIsNotNone(repository)
        default_repository = os.path.realpath(os.path.join(os.path.expanduser("~"), ".m2"))
        self.assertNotEqual(os.path.commonpath([default_repository, repository]), default_repository)
        # 作業用のリポジトリは、確認が終わると残らない。
        self.assertFalse(os.path.exists(repository))

    def test_MavenCentralへ送るタスクを走らせない(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for call in self.calls():
            for task in task_names(call["arguments"]):
                self.assertNotIn("MavenCentral", task)
                self.assertNotEqual(task.rsplit(":", 1)[-1], "publish")

    def test_概要に確かめた内容が出る(self) -> None:
        summary = os.path.join(self.root, "summary.md")
        result = self.run_script("--mode", "local", env={"GITHUB_STEP_SUMMARY": summary})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with open(summary, encoding="utf-8") as f:
            text = f.read()
        self.assertIn("`local`", text)
        self.assertIn(f"`jp.kamusoft:kscollectionview:{CATALOG_VERSION}`", text)


class PublishedModeTests(ConsumerVerificationTestCase):
    def test_publishedでは発行せずに同じ組み立てと依存の確認を始める(self) -> None:
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls()
        self.assertEqual([call["build"] for call in calls], [SCRIPT.CONSUMER_BUILD, SCRIPT.CONSUMER_BUILD])
        assemble, dependencies = calls
        self.assertEqual(task_names(assemble["arguments"]), [":app:assembleRelease"])
        self.assertEqual(task_names(dependencies["arguments"]), [":app:dependencies"])
        for call in calls:
            self.assertEqual(argument_value(call["arguments"], "-PksCollectionViewMode="), "published")
            self.assertEqual(argument_value(call["arguments"], "-PksCollectionViewVersion="), "1.2.3")
            # 取得元のディレクトリは渡さない (利用者役の定義が Maven Central だけにする)。
            self.assertIsNone(argument_value(call["arguments"], "-PksCollectionViewRepository="))

    def test_組み立てと依存の確認は切り替えによって変わらない(self) -> None:
        def without_source(call: dict) -> list[str]:
            return [argument for argument in call["arguments"] if not argument.startswith(SOURCE_ARGUMENT_PREFIX)]

        self.assertEqual(self.run_script("--mode", "local", "--version", "1.2.3").returncode, 0)
        local_calls = self.calls()[1:]
        os.remove(os.path.join(self.root, "calls.jsonl"))
        self.assertEqual(self.run_script("--mode", "published", "--version", "1.2.3").returncode, 0)
        published_calls = self.calls()
        self.assertEqual(
            [without_source(call) for call in local_calls], [without_source(call) for call in published_calls]
        )

    def test_publishedでも成功の条件は同じである(self) -> None:
        self.behave({"dependencies": {"stdout": "+--- androidx.activity:activity-compose:1.11.0\n"}})
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

        self.behave({"assemble": {"skip_outputs": True}})
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("コード縮小の対応表が無い", result.stdout)


class ArgumentTests(ConsumerVerificationTestCase):
    def assert_nothing_started(self, result: subprocess.CompletedProcess, reason: str) -> None:
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn(reason, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [])

    def test_知らない切り替えでは何も始めない(self) -> None:
        for mode in ("dry-run", "LOCAL", "local ", ""):
            with self.subTest(mode=mode):
                self.assert_nothing_started(self.run_script("--mode", mode), "--mode は local か published")

    def test_切り替えが無ければ何も始めない(self) -> None:
        self.assert_nothing_started(self.run_script(), "--mode")

    def test_publishedで版が無ければ何も始めない(self) -> None:
        self.assert_nothing_started(self.run_script("--mode", "published"), "--version が必須")

    def test_publishedで版が空なら何も始めない(self) -> None:
        for version in ("", "  "):
            with self.subTest(version=version):
                self.assert_nothing_started(
                    self.run_script("--mode", "published", "--version", version), "--version が必須"
                )

    def test_版に使えない文字があれば何も始めない(self) -> None:
        for version in ("-Pinjected=1", "1.0 :other:task", "../1.0", "1.0/2"):
            with self.subTest(version=version):
                self.assert_nothing_started(
                    self.run_script("--mode", "local", f"--version={version}"), "使えない文字"
                )


class FailureTests(ConsumerVerificationTestCase):
    def test_発行の失敗は本文が出て組み立ての前に止まる(self) -> None:
        self.behave(
            {
                "publish": {
                    "exit": 1,
                    "stdout": "> Task :kscollectionview:compileReleaseKotlin FAILED\n",
                    "stderr": "e: KsLayout.kt:12:5 Unresolved reference 'broken'\n\nBUILD FAILED in 3s\n",
                }
            }
        )
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        # 準備のコマンドが出した失敗の本文が、そのまま出ている。
        self.assertIn("> Task :kscollectionview:compileReleaseKotlin FAILED\n", result.stdout)
        self.assertIn("e: KsLayout.kt:12:5 Unresolved reference 'broken'\n\nBUILD FAILED in 3s\n", result.stderr)
        self.assertIn("::error::本体の発行が失敗した", result.stdout)
        # 利用者役の組み立ては始まらない。
        self.assertEqual([call["build"] for call in self.calls()], [SCRIPT.LIBRARY_BUILD])

    def test_発行物が残らなければ組み立ての前に止まる(self) -> None:
        self.behave({"publish": {"skip_outputs": True}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("POM が無い", result.stdout)
        self.assertEqual([call["build"] for call in self.calls()], [SCRIPT.LIBRARY_BUILD])

    def test_バージョンカタログから版を読めなければ何も始めない(self) -> None:
        support.write(os.path.join(self.root, SCRIPT.VERSION_CATALOG), "[versions]\nagp = \"9.4.0\"\n")
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("kscollectionview の版が無い", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_組み立ての失敗は本文が出て依存の確認の前に止まる(self) -> None:
        self.behave(
            {
                "assemble": {
                    "exit": 1,
                    "stderr": "ERROR: R8: Missing class jp.kamusoft.kscollectionview.Gone\n",
                }
            }
        )
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("ERROR: R8: Missing class jp.kamusoft.kscollectionview.Gone\n", result.stderr)
        self.assertIn("::error::利用者役の組み立てが失敗した", result.stdout)
        self.assertEqual(
            [task_names(call["arguments"]) for call in self.calls()],
            [[":kscollectionview:publishToMavenLocal"], [":app:assembleRelease"]],
        )

    def test_組み立ての後に対応表が無ければ失敗する(self) -> None:
        self.behave({"assemble": {"skip_outputs": True}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("コード縮小の対応表が無い", result.stdout)
        self.assertEqual(len(self.calls()), 2)

    def test_前の回が残した対応表は数えない(self) -> None:
        support.write(self.mapping_path(), "# 前の回の対応表\n")
        self.behave({"assemble": {"skip_outputs": True}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("コード縮小の対応表が無い", result.stdout)

    def test_依存の一覧に座標が無ければ失敗する(self) -> None:
        self.behave({"dependencies": {"stdout": "+--- org.jetbrains.kotlin:kotlin-stdlib:2.4.10\n"}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("実行時の依存の一覧に jp.kamusoft:kscollectionview が無い", result.stdout)

    def test_依存の一覧が空なら失敗する(self) -> None:
        self.behave({"dependencies": {"stdout": ""}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_座標を解決できていなければ失敗する(self) -> None:
        self.behave({"dependencies": {"stdout": f"+--- jp.kamusoft:kscollectionview:{CATALOG_VERSION} FAILED\n"}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("解決できていない", result.stdout)

    def test_座標が別の版に解決されていれば失敗する(self) -> None:
        for line in (
            "+--- jp.kamusoft:kscollectionview:0.3.0\n",
            f"+--- jp.kamusoft:kscollectionview:{CATALOG_VERSION} -> 0.5.0\n",
        ):
            with self.subTest(line=line):
                self.behave({"dependencies": {"stdout": line}})
                result = self.run_script("--mode", "local")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(f"指定の版 {CATALOG_VERSION} ではなく", result.stdout)

    def test_依存の一覧のコマンドが失敗すれば失敗する(self) -> None:
        self.behave({"dependencies": {"exit": 1, "stderr": "Could not determine the dependencies\n"}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Could not determine the dependencies\n", result.stderr)
        self.assertIn("依存の一覧を取れなかった", result.stdout)

    def test_Gradleのラッパーが無ければ失敗する(self) -> None:
        os.remove(os.path.join(self.root, SCRIPT.CONSUMER_BUILD, "gradlew"))
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Gradle を実行できない", result.stdout)


class OutputTests(ConsumerVerificationTestCase):
    def test_子プロセスの出力をそのままの内容と順序で流す(self) -> None:
        publish = "> Task :kscollectionview:publishToMavenLocal\n\n  字下げと\t空行を含む 発行の出力 \n"
        assemble = "> Task :app:minifyReleaseWithR8\nR8: 警告 0 件\n"
        dependencies = (
            "releaseRuntimeClasspath - Runtime classpath of '/release'.\n"
            f"+--- jp.kamusoft:kscollectionview:{CATALOG_VERSION}\n"
            "|    \\--- androidx.compose.ui:ui -> 1.11.4 (*)\n"
        )
        self.behave(
            {
                "publish": {"stdout": publish},
                "assemble": {"stdout": assemble},
                "dependencies": {"stdout": dependencies},
            }
        )
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        positions = [result.stdout.find(text) for text in (publish, assemble, dependencies)]
        self.assertNotIn(-1, positions, result.stdout)
        self.assertEqual(positions, sorted(positions))
        # 概要は、子プロセスの出力の後に出る。
        self.assertGreater(result.stdout.find("### Android の利用者の立場のビルドの確認"), positions[-1])


class ResolvedVersionsTests(unittest.TestCase):
    def test_指定した版を読む(self) -> None:
        self.assertEqual(SCRIPT.resolved_versions("+--- jp.kamusoft:kscollectionview:1.2.3\n"), ["1.2.3"])

    def test_矢印の後ろの解決された版を読む(self) -> None:
        tree = "+--- jp.kamusoft:kscollectionview:1.2.3 -> 1.3.0 (*)\n"
        self.assertEqual(SCRIPT.resolved_versions(tree), ["1.3.0"])

    def test_版の後ろの印を無視する(self) -> None:
        tree = "|    \\--- jp.kamusoft:kscollectionview:1.2.3 (*)\n+--- jp.kamusoft:kscollectionview:1.2.3 (c)\n"
        self.assertEqual(SCRIPT.resolved_versions(tree), ["1.2.3", "1.2.3"])

    def test_同じgroupの別の成果物を無視する(self) -> None:
        tree = "+--- jp.kamusoft:kscollectionview-extras:9.9.9\n+--- jp.kamusoft:kssettingsview:1.0.0\n"
        self.assertEqual(SCRIPT.resolved_versions(tree), [])

    def test_解決できていない行は例外にする(self) -> None:
        with self.assertRaises(SCRIPT.VerificationError):
            SCRIPT.resolved_versions("+--- jp.kamusoft:kscollectionview:1.2.3 FAILED\n")


class CatalogVersionTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = directory.name

    def write_catalog(self, text: str) -> None:
        support.write(os.path.join(self.root, SCRIPT.VERSION_CATALOG), text)

    def test_versionsの節から版を読む(self) -> None:
        self.write_catalog(CATALOG_TEXT)
        self.assertEqual(SCRIPT.catalog_version(self.root), CATALOG_VERSION)

    def test_別の節の項目は読まない(self) -> None:
        self.write_catalog('[versions]\nagp = "9.4.0"\n\n[libraries]\nkscollectionview = "1.0.0"\n')
        with self.assertRaises(SCRIPT.VerificationError):
            SCRIPT.catalog_version(self.root)

    def test_バージョンカタログが無ければ例外にする(self) -> None:
        with self.assertRaises(SCRIPT.VerificationError):
            SCRIPT.catalog_version(self.root)

    def test_実物のバージョンカタログから版を読める(self) -> None:
        self.assertRegex(SCRIPT.catalog_version(support.REPOSITORY_ROOT), SCRIPT.VERSION_PATTERN)


def read_without_comments(*parts: str) -> str:
    """Gradle のビルドの定義を読み、行のコメントを除いて返す (説明の中の語を拾わないため)。"""
    with open(os.path.join(support.REPOSITORY_ROOT, *parts), encoding="utf-8") as f:
        return "\n".join(line for line in f.read().splitlines() if not line.lstrip().startswith("//"))


class ConsumerDefinitionTests(unittest.TestCase):
    """利用者役の実物のビルドの定義が、利用者と同じ書き方で配布物を参照していること。"""

    def setUp(self) -> None:
        self.settings = read_without_comments(SCRIPT.CONSUMER_BUILD, "settings.gradle.kts")
        self.app = read_without_comments(SCRIPT.CONSUMER_BUILD, "app", "build.gradle.kts")

    def test_本ライブラリへの依存は座標の1行だけである(self) -> None:
        lines = [line.strip() for line in self.app.splitlines() if "kamusoft" in line and "(" in line]
        dependency_lines = [line for line in lines if line.startswith(("implementation", "api", "runtimeOnly"))]
        self.assertEqual(dependency_lines, ['implementation("jp.kamusoft:kscollectionview:$ksCollectionViewVersion")'])
        # 座標を別の書き方 (group と name を分けた形・project への参照) で指す行も無い。
        self.assertEqual(self.app.count("kscollectionview:"), 1)
        self.assertNotIn("project(", self.app)

    def test_groupの取得元はちょうど1つである(self) -> None:
        self.assertEqual(self.settings.count("exclusiveContent"), 1)
        self.assertEqual(self.settings.count('includeGroup("jp.kamusoft")'), 1)
        block = self.settings[self.settings.index("exclusiveContent") : self.settings.index("google()", self.settings.index("exclusiveContent"))]
        self.assertIn('filter { includeGroup("jp.kamusoft") }', block)
        # published は Maven Central、そうでなければ渡したディレクトリ。ほかの枝は無い。
        self.assertRegex(
            block,
            re.compile(
                r'if \(ksCollectionViewMode == "published"\) \{\s*mavenCentral\(\)\s*\} else \{\s*maven \{.*?'
                r"url = uri\(file\(checkNotNull\(ksCollectionViewRepository\)\)\)\s*\}\s*\}",
                re.DOTALL,
            ),
        )

    def test_localはリポジトリのディレクトリを必須にする(self) -> None:
        self.assertRegex(
            self.settings,
            re.compile(r'if \(ksCollectionViewMode == "local"\) \{\s*requireNotNull\(ksCollectionViewRepository\)'),
        )

    def test_既定の手元のMavenリポジトリを取得元にしない(self) -> None:
        self.assertNotIn("mavenLocal", self.settings)
        self.assertNotIn("mavenLocal", self.app)

    def test_本体のビルドを取り込まない(self) -> None:
        for text in (self.settings, self.app):
            self.assertNotIn("includeBuild", text)
            self.assertNotIn("dependencySubstitution", text)
            self.assertNotIn("substitute(", text)
        # 本体のディレクトリを指すのは、バージョンカタログの共有だけである。
        references = re.findall(r'"([^"]*\.\./[^"]*)"', self.settings + self.app)
        self.assertEqual(references, ["../../android/gradle/libs.versions.toml"])

    def test_リリースは既定の規則だけでコード縮小する(self) -> None:
        release = self.app[self.app.index('named("release")') :]
        self.assertIn("isMinifyEnabled = true", release)
        self.assertNotIn("isMinifyEnabled = false", self.app)
        self.assertEqual(
            re.findall(r"proguardFiles?\((.*)\)", self.app),
            ['getDefaultProguardFile("proguard-android-optimize.txt")'],
        )

    def test_利用者役はコード縮小の規則のファイルを持たない(self) -> None:
        consumer = os.path.join(support.REPOSITORY_ROOT, SCRIPT.CONSUMER_BUILD)
        found = []
        for current, directories, files in os.walk(consumer):
            # ビルドの出力には、R8 が書き出した規則のファイルがある。
            directories[:] = [name for name in directories if name not in ("build", ".gradle", ".kotlin")]
            found.extend(
                os.path.relpath(os.path.join(current, name), consumer)
                for name in files
                if name.endswith((".pro", ".pgcfg")) or name in ("proguard-rules.txt", "consumer-rules.txt")
            )
        self.assertEqual(found, [])

    def test_Gradleのラッパーが本体のビルドと同じである(self) -> None:
        def read(*parts: str) -> bytes:
            with open(os.path.join(support.REPOSITORY_ROOT, *parts), "rb") as f:
                return f.read()

        wrapper = ("gradle", "wrapper", "gradle-wrapper.properties")
        self.assertEqual(read(SCRIPT.CONSUMER_BUILD, *wrapper), read(SCRIPT.LIBRARY_BUILD, *wrapper))
        gradlew = os.path.join(support.REPOSITORY_ROOT, SCRIPT.CONSUMER_BUILD, "gradlew")
        self.assertTrue(os.access(gradlew, os.X_OK), "gradlew に実行の権限が無い")

    def test_スクリプトは本体のプロジェクトの名前で発行する(self) -> None:
        library_settings = read_without_comments(SCRIPT.LIBRARY_BUILD, "settings.gradle.kts")
        self.assertIn('include(":kscollectionview")', library_settings)
        self.assertEqual(SCRIPT.PUBLISH_TASK, ":kscollectionview:publishToMavenLocal")


if __name__ == "__main__":
    unittest.main()
