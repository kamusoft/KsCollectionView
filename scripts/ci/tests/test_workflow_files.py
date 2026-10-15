"""検証 CI の workflow が、決めた形を保っているかのテスト。

確かめるのは、崩れても平時の緑では気付けない形だけにする: 起動の条件、検査の名前、
検証が走らせる範囲、iOS がテストを実行しないこと、Android の件数の検査が必ず走る条件、
利用者の立場のビルドの確認が走る条件と受け取る入力、リリースの workflow の起動・同時実行・
secret を置いた環境・公開の step の順。
道具の固定と権限、ジョブの時間の上限は check-workflows.py が確かめるので、ここでは確かめない。
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from xml.etree import ElementTree

import support

PARSER = support.load_script("check-workflows.py")

WORKFLOWS = (".github", "workflows")
STEP_START = re.compile(r"^\s+- name:\s*(.+?)\s*$")


def read(name: str) -> str:
    with open(os.path.join(support.REPOSITORY_ROOT, *WORKFLOWS, name), encoding="utf-8") as f:
        return f.read()


def nodes_of(name: str) -> list:
    nodes, problems = PARSER.parse(name, read(name))
    if problems:
        raise AssertionError(f"{name} を読み取れない: {[problem.render() for problem in problems]}")
    return nodes


def find(nodes: list, *path: str):
    """キーの位置が path に一致する行を返す。無ければ None。"""
    for node in nodes:
        if node.key is not None and node.path == path:
            return node
    return None


def value_at(nodes: list, *path: str) -> str | None:
    node = find(nodes, *path)
    return None if node is None or node.value is None else PARSER.unquote(node.value)


def list_at(nodes: list, *path: str) -> list[str]:
    node = find(nodes, *path)
    return [] if node is None else [value for _, value in PARSER.values_of(nodes, node)]


def steps_of(name: str) -> dict[str, str]:
    """step の名前 → その step の本文 (コメントの行を除く) の対応を返す。"""
    return steps_in(read(name))


def steps_in(text: str) -> dict[str, str]:
    """workflow の本文 (またはその一部) の、step の名前 → step の本文 (コメントの行を除く) の対応を返す。"""
    steps: dict[str, list[str]] = {}
    current: list[str] | None = None
    for line in text.splitlines():
        matched = STEP_START.match(line)
        if matched:
            current = steps.setdefault(matched.group(1), [])
        if current is not None and not line.strip().startswith("#"):
            current.append(line)
    return {step: "\n".join(lines) for step, lines in steps.items()}


def condition_of(step: str) -> str | None:
    matched = re.search(r"(?m)^\s+if:\s*(.+?)\s*$", step)
    return matched.group(1) if matched else None


def keys_under(nodes: list, *path: str) -> set[str]:
    """path の直下にあるキーの集合を返す。"""
    depth = len(path)
    return {node.path[depth] for node in nodes if node.path[:depth] == path and len(node.path) > depth}


def without_comments(name: str) -> str:
    """workflow のうち、コメントの行を除いた本文を返す。"""
    return "\n".join(line for line in read(name).splitlines() if not line.strip().startswith("#"))


class EntryWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.nodes = nodes_of("ci.yml")

    def test_developへのpushとmain宛てのPullRequestで起動する(self) -> None:
        self.assertEqual(list_at(self.nodes, "on", "push", "branches"), ["develop"])
        self.assertEqual(list_at(self.nodes, "on", "pull_request", "branches"), ["main"])
        triggers = {node.path[1] for node in self.nodes if len(node.path) >= 2 and node.path[0] == "on"}
        self.assertEqual(triggers, {"push", "pull_request"})

    def test_developへのpushは開発の記録とIssueのフォームと貢献の案内だけなら起動しない(self) -> None:
        self.assertEqual(
            list_at(self.nodes, "on", "push", "paths-ignore"),
            ["kasane/**", ".github/ISSUE_TEMPLATE/**", ".github/CONTRIBUTING.md", ".github/CONTRIBUTING_ja.md"],
        )
        self.assertIsNone(find(self.nodes, "on", "push", "paths"))

    def test_main宛てのPullRequestは変更したパスで絞り込まない(self) -> None:
        keys = {node.path[2] for node in self.nodes if node.path[:2] == ("on", "pull_request") and len(node.path) >= 3}
        self.assertEqual(keys, {"branches"})

    def test_同じブランチまたは同じPullRequestの古い実行を打ち切る(self) -> None:
        group = value_at(self.nodes, "concurrency", "group") or ""
        self.assertIn("github.event.pull_request.number || github.ref", group)
        self.assertEqual(value_at(self.nodes, "concurrency", "cancel-in-progress"), "true")

    # Pull Request で起動したときだけ走る、利用者の立場のビルドの確認のジョブと、呼ぶ workflow。
    CONSUMER_JOBS = (
        ("consumer-ios", "verify-consumer-ios.yml"),
        ("consumer-android", "verify-consumer-android.yml"),
    )

    def test_ジョブは決めた5つで検査の名前がジョブの名前と同じである(self) -> None:
        jobs = keys_under(self.nodes, "jobs")
        self.assertEqual(jobs, {"lint", "ios", "android", "consumer-ios", "consumer-android"})
        for job in sorted(jobs):
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "name"), job)

    def test_2本の検証を入力なしで呼び条件を付けない(self) -> None:
        for job, workflow in (("ios", "verify-ios.yml"), ("android", "verify-android.yml")):
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "uses"), f"./.github/workflows/{workflow}")
                keys = {node.path[2] for node in self.nodes if node.path[:2] == ("jobs", job) and len(node.path) >= 3}
                self.assertEqual(keys, {"name", "uses"})

    def test_lintは条件なしで走る(self) -> None:
        self.assertIsNone(find(self.nodes, "jobs", "lint", "if"))

    def test_利用者の立場のビルドの確認はPullRequestで起動したときだけ走る(self) -> None:
        for job, workflow in self.CONSUMER_JOBS:
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "uses"), f"./.github/workflows/{workflow}")
                self.assertEqual(
                    value_at(self.nodes, "jobs", job, "if"), "${{ github.event_name == 'pull_request' }}"
                )
                self.assertEqual(keys_under(self.nodes, "jobs", job), {"name", "if", "uses", "with"})

    def test_利用者の立場のビルドの確認にlocalを渡し版もartifactの名前も渡さない(self) -> None:
        for job, _ in self.CONSUMER_JOBS:
            with self.subTest(job=job):
                self.assertEqual(keys_under(self.nodes, "jobs", job, "with"), {"mode"})
                self.assertEqual(value_at(self.nodes, "jobs", job, "with", "mode"), "local")

    def test_利用者の立場のビルドの確認の検査の名前が決めたとおりになる(self) -> None:
        # 検査の名前は「呼ぶ側のジョブの名前 / 呼ばれる側のジョブの名前」になる。
        reported = set()
        for job, workflow in self.CONSUMER_JOBS:
            called = nodes_of(workflow)
            for called_job in keys_under(called, "jobs"):
                caller = value_at(self.nodes, "jobs", job, "name")
                reported.add(f"{caller} / {value_at(called, 'jobs', called_job, 'name')}")
        self.assertEqual(reported, {"consumer-ios / verify", "consumer-android / verify"})

    def test_lintが決めた検査をすべて走らせる(self) -> None:
        steps = steps_of("ci.yml")
        expected = {
            "Pull request head restriction": "python3 scripts/ci/check-pr-head.py",
            "Secret scan (gitleaks)": "gitleaks dir ",
            "Local absolute path lint": "python3 scripts/local-path-lint.py",
            "Identity lint": "python3 scripts/identity-lint.py",
            "Comment policy lint": "python3 scripts/comment-policy-lint.py",
            "CI script tests": "python3 scripts/ci/run-tests.py",
            "Workflow definition check": "python3 scripts/ci/check-workflows.py",
        }
        for name, command in expected.items():
            with self.subTest(step=name):
                self.assertIn(name, steps)
                self.assertIn(command, steps[name])
                # 条件や失敗の見逃しで、検査が黙って外れないこと。
                self.assertIsNone(condition_of(steps[name]))
                self.assertNotIn("continue-on-error", steps[name])

    def test_出どころの確認にPullRequestの出どころのリポジトリを渡す(self) -> None:
        step = steps_of("ci.yml")["Pull request head restriction"]
        self.assertIn("KS_PR_HEAD_REPOSITORY: ${{ github.event.pull_request.head.repo.full_name }}", step)

    def test_gitleaksはチェックサムを確かめてから展開する(self) -> None:
        step = steps_of("ci.yml")["Install gitleaks"]
        self.assertIn("set -euo pipefail", step)
        check = step.index("sha256sum --check --strict")
        self.assertLess(check, step.index("tar -xzf"))
        self.assertRegex(value_at(self.nodes, "jobs", "lint", "env", "KS_GITLEAKS_VERSION") or "", r"^\d+\.\d+\.\d+$")
        self.assertRegex(value_at(self.nodes, "jobs", "lint", "env", "KS_GITLEAKS_SHA256") or "", r"^[0-9a-f]{64}$")

    def test_secretの検査は取り出した数を確かめてから走査する(self) -> None:
        step = steps_of("ci.yml")["Secret scan (gitleaks)"]
        self.assertIn("set -euo pipefail", step)
        self.assertIn("git archive --format=tar HEAD | tar -x", step)
        self.assertLess(step.index('"$extracted" -lt "$tracked"'), step.index("gitleaks dir "))


class PlatformWorkflowTest(unittest.TestCase):
    FILES = ("verify-ios.yml", "verify-android.yml")

    def test_入力なしで他のworkflowから呼べる(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                nodes = nodes_of(name)
                on_keys = [node.path for node in nodes if node.path[0] == "on"]
                self.assertEqual(on_keys, [("on",), ("on", "workflow_call")])

    def test_ジョブの名前がverifyである(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                nodes = nodes_of(name)
                jobs = {node.path[1] for node in nodes if len(node.path) >= 2 and node.path[0] == "jobs"}
                self.assertEqual(jobs, {"verify"})
                self.assertEqual(value_at(nodes, "jobs", "verify", "name"), "verify")


class ConsumerWorkflowTest(unittest.TestCase):
    """利用者の立場のビルドの確認の 2 本に共通する形。"""

    # workflow → (確認のスクリプト, 道具と権限の決まりを合わせる相手の workflow)
    FILES = {
        "verify-consumer-ios.yml": ("verify-consumer-ios.py", "verify-ios.yml"),
        "verify-consumer-android.yml": ("verify-consumer-android.py", "verify-android.yml"),
    }
    # workflow → (取り込んだ artifact をスクリプトに渡す引数, その環境変数, 取り込む先の末尾の名前)
    ARTIFACT_ARGUMENTS = {
        "verify-consumer-ios.yml": ("--snapshot", "KS_SNAPSHOT", "KsCollectionView-SPM"),
        "verify-consumer-android.yml": ("--repository", "KS_REPOSITORY", "maven"),
    }
    VERIFY = "Verify consumer"
    CHECK = "Check inputs"
    DOWNLOAD = "Download artifact"

    def test_他のworkflowから呼ばれる形だけを持つ(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                nodes = nodes_of(name)
                self.assertEqual(keys_under(nodes, "on"), {"workflow_call"})
                self.assertEqual(keys_under(nodes, "on", "workflow_call"), {"inputs"})

    def test_切り替えを必須で版とartifactの名前を任意で受け取る(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                nodes = nodes_of(name)
                inputs = ("on", "workflow_call", "inputs")
                self.assertEqual(keys_under(nodes, *inputs), {"mode", "version", "artifact"})
                self.assertEqual(value_at(nodes, *inputs, "artifact", "type"), "string")
                self.assertEqual(value_at(nodes, *inputs, "artifact", "required"), "false")
                self.assertEqual(value_at(nodes, *inputs, "artifact", "default"), "")
                self.assertEqual(value_at(nodes, *inputs, "mode", "type"), "string")
                self.assertEqual(value_at(nodes, *inputs, "mode", "required"), "true")
                # 必須の入力に既定の値があると、渡し忘れが黙って通る。
                self.assertIsNone(find(nodes, *inputs, "mode", "default"))
                self.assertEqual(value_at(nodes, *inputs, "version", "type"), "string")
                self.assertEqual(value_at(nodes, *inputs, "version", "required"), "false")
                self.assertEqual(value_at(nodes, *inputs, "version", "default"), "")

    def test_ジョブの名前がverifyである(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                nodes = nodes_of(name)
                self.assertEqual(keys_under(nodes, "jobs"), {"verify"})
                self.assertEqual(value_at(nodes, "jobs", "verify", "name"), "verify")

    def test_ランナーが既存の検証と同じである(self) -> None:
        for name, (_, counterpart) in self.FILES.items():
            with self.subTest(workflow=name):
                runner = value_at(nodes_of(name), "jobs", "verify", "runs-on")
                self.assertIsNotNone(runner)
                self.assertEqual(runner, value_at(nodes_of(counterpart), "jobs", "verify", "runs-on"))

    def test_失敗を見逃す指定が無い(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                self.assertNotIn("continue-on-error", without_comments(name))

    def test_workflowの定義の検査に違反が無い(self) -> None:
        # 道具の固定・権限・時間の上限の決まりは、定義の検査が確かめる。確かめた箇所が 0 のまま
        # 違反なしになっていないことも見る。
        for name in self.FILES:
            with self.subTest(workflow=name):
                problems, counts = PARSER.check_text(name, read(name))
                self.assertEqual([problem.render() for problem in problems], [])
                self.assertEqual(counts["runs-on"], 1)
                self.assertEqual(counts["permissions"], 1)
                self.assertGreaterEqual(counts["uses"], 1)

    def test_確認のスクリプトに切り替えと版と取り込んだ場所をそのまま渡す(self) -> None:
        for name, (script, _) in self.FILES.items():
            with self.subTest(workflow=name):
                option, variable, directory = self.ARTIFACT_ARGUMENTS[name]
                self.assertTrue(os.path.isfile(support.script_path(script)))
                step = steps_of(name)[self.VERIFY]
                self.assertIn("KS_MODE: ${{ inputs.mode }}\n", step)
                self.assertIn("KS_VERSION: ${{ inputs.version }}\n", step)
                # 取り込んだ場所は artifact のときだけ渡し、ほかの切り替えでは空にする。
                self.assertIn(
                    f"{variable}: ${{{{ inputs.mode == 'artifact' && "
                    f"format('{{0}}/consumer-artifact/{directory}', runner.temp) || '' }}}}\n",
                    step,
                )
                # 入力は環境変数を通して渡す。本文に式を直に埋めると、値がシェルの構文として読まれる。
                command = re.search(r"(?m)^\s+run:\s*(.+)$", step)
                self.assertIsNotNone(command)
                self.assertEqual(
                    command.group(1),
                    f'python3 scripts/ci/{script} --mode "${{KS_MODE}}" --version "${{KS_VERSION}}"'
                    f' {option} "${{{variable}}}"',
                )

    def test_artifactのときだけ渡した名前のartifactを取り込む(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                _, _, directory = self.ARTIFACT_ARGUMENTS[name]
                steps = steps_of(name)
                step = steps[self.DOWNLOAD]
                self.assertEqual(condition_of(step), "${{ inputs.mode == 'artifact' }}")
                self.assertRegex(step, r"(?m)^\s+uses: actions/download-artifact@[0-9a-f]{40} # v\d+\.\d+\.\d+$")
                self.assertIn("name: ${{ inputs.artifact }}\n", step)
                # 取り込む先は、確認のスクリプトに渡す場所と同じである。
                self.assertRegex(step, rf"(?m)^\s+path: \$\{{\{{ runner.temp \}}\}}/consumer-artifact/{re.escape(directory)}$")
                # 名前を渡さずにすべての artifact を取り込む指定や、展開を飛ばす指定を持たない。
                for word in ("pattern:", "merge-multiple:", "artifact-ids:", "skip-decompress:", "github-token:"):
                    self.assertNotIn(word, step)
                # 取り込みは確認の直前に置く。
                names = list(steps)
                self.assertEqual(names.index(self.DOWNLOAD) + 1, names.index(self.VERIFY))

    def test_artifactの名前の過不足を最初に確かめる(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                steps = steps_of(name)
                self.assertEqual(list(steps)[0], self.CHECK)
                step = steps[self.CHECK]
                self.assertIsNone(condition_of(step))
                self.assertIn("KS_MODE: ${{ inputs.mode }}\n", step)
                self.assertIn("KS_ARTIFACT: ${{ inputs.artifact }}\n", step)
                self.assertIn("set -euo pipefail", step)
                # 名前が無い artifact と、artifact 以外での名前の指定を、どちらも止める。
                missing = step.index('if [ "${KS_MODE}" = "artifact" ] && [ -z "${KS_ARTIFACT}" ]; then')
                self.assertLess(missing, step.index("exit 1", missing))
                extra = step.index('if [ "${KS_MODE}" != "artifact" ] && [ -n "${KS_ARTIFACT}" ]; then')
                self.assertLess(extra, step.index("exit 1", extra))

    def test_確認のstepは最後に条件なしで走る(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                steps = steps_of(name)
                self.assertEqual(list(steps)[-1], self.VERIFY)
                # 条件を付けるのは、artifact の取り込みだけである。前の step が失敗したら、確認は始まらない。
                for step_name, step in steps.items():
                    if step_name == self.DOWNLOAD:
                        continue
                    with self.subTest(step=step_name):
                        self.assertIsNone(condition_of(step))

    def test_確認のスクリプトを呼ぶのは1箇所だけである(self) -> None:
        for name, (script, _) in self.FILES.items():
            with self.subTest(workflow=name):
                self.assertEqual(without_comments(name).count(script), 1)

    def test_認証の情報を受け取らない(self) -> None:
        for name in self.FILES:
            with self.subTest(workflow=name):
                self.assertNotIn("secrets", without_comments(name))


class ConsumerIosWorkflowTest(unittest.TestCase):
    NAME = "verify-consumer-ios.yml"

    def setUp(self) -> None:
        self.nodes = nodes_of(self.NAME)
        self.steps = steps_of(self.NAME)

    def test_stepは決めた6つだけである(self) -> None:
        self.assertEqual(
            list(self.steps),
            ["Check inputs", "Checkout", "Select Xcode", "Show toolchain", "Download artifact", "Verify consumer"],
        )

    def test_Xcodeの版が既存の検証と同じである(self) -> None:
        version = value_at(self.nodes, "env", "KS_XCODE_VERSION")
        self.assertRegex(version or "", r"^\d+\.\d+$")
        self.assertEqual(version, value_at(nodes_of("verify-ios.yml"), "env", "KS_XCODE_VERSION"))

    def test_決めた版のXcodeが無ければビルドの前に止まる(self) -> None:
        names = list(self.steps)
        self.assertLess(names.index("Select Xcode"), names.index("Verify consumer"))
        step = self.steps["Select Xcode"]
        self.assertIn("set -euo pipefail", step)
        self.assertIn("Xcode_${KS_XCODE_VERSION}*.app", step)
        self.assertLess(step.index('if [ -z "$app" ]'), step.index("exit 1"))
        self.assertLess(step.index("exit 1"), step.index("DEVELOPER_DIR="))

    def test_Xcodeを選ぶ手順が既存の検証と同じである(self) -> None:
        self.assertEqual(self.steps["Select Xcode"], steps_of("verify-ios.yml")["Select Xcode"])

    def test_選んだXcodeの版が違えばビルドの前に止まる(self) -> None:
        names = list(self.steps)
        self.assertLess(names.index("Show toolchain"), names.index("Verify consumer"))
        step = self.steps["Show toolchain"]
        self.assertIn("set -euo pipefail", step)
        self.assertIn('"${KS_XCODE_VERSION}" | "${KS_XCODE_VERSION}".*) ;;', step)
        self.assertIn("exit 1", step)

    def test_Simulatorを選ばない(self) -> None:
        commands = without_comments(self.NAME)
        for word in ("simctl", "SIMULATOR_UDID", "boot"):
            with self.subTest(word=word):
                self.assertNotIn(word, commands)


class ConsumerAndroidWorkflowTest(unittest.TestCase):
    NAME = "verify-consumer-android.yml"

    def setUp(self) -> None:
        self.steps = steps_of(self.NAME)

    def test_stepは決めた8つだけである(self) -> None:
        self.assertEqual(
            list(self.steps),
            [
                "Check inputs",
                "Checkout",
                "Setup JDK",
                "Cache Gradle dependencies",
                "Show toolchain",
                "Ensure Android SDK platform",
                "Download artifact",
                "Verify consumer",
            ],
        )

    def test_JDKの版が既存の検証と同じである(self) -> None:
        pattern = r'(?m)^\s+java-version: "(\d+)"$'
        version = re.search(pattern, self.steps["Setup JDK"])
        self.assertIsNotNone(version)
        existing = re.search(pattern, steps_of("verify-android.yml")["Setup JDK"])
        self.assertEqual(version.group(1), existing.group(1))

    def test_ビルドの出力と手元のMavenリポジトリをキャッシュしない(self) -> None:
        step = self.steps["Cache Gradle dependencies"]
        paths = step.split("path: |", 1)[1].split("key:", 1)[0].split()
        self.assertEqual(paths, ["~/.gradle/caches/modules-2", "~/.gradle/wrapper"])

    def test_キャッシュのキーに利用者役のビルドの定義が入る(self) -> None:
        key = re.search(r"(?m)^\s+key:\s*(.+)$", self.steps["Cache Gradle dependencies"]).group(1)
        for path in (
            "android/gradle/libs.versions.toml",
            "verification/android/gradle/wrapper/gradle-wrapper.properties",
            "verification/android/**/*.gradle.kts",
        ):
            with self.subTest(path=path):
                self.assertIn(f"'{path}'", key)
        # 既存の検証のキャッシュとは、キーの頭を分ける (取得する依存の集合が違う)。
        self.assertTrue(key.startswith("gradle-consumer-"))

    def test_コンパイル対象のSDKを確かめる手順が既存の検証と同じである(self) -> None:
        def body(step: str) -> str:
            return step.split("run: |", 1)[1]

        existing = steps_of("verify-android.yml")["Ensure Android SDK platform"]
        self.assertEqual(body(self.steps["Ensure Android SDK platform"]), body(existing))


class IosWorkflowTest(unittest.TestCase):
    LIBRARY = "Build library and library tests"
    SAMPLE = "Build sample and sample tests"
    SAMPLE_SCHEME = (
        "samples",
        "ios",
        "KsCollectionViewSamples.xcodeproj",
        "xcshareddata",
        "xcschemes",
        "KsCollectionViewSamples.xcscheme",
    )

    def setUp(self) -> None:
        self.nodes = nodes_of("verify-ios.yml")
        self.steps = steps_of("verify-ios.yml")

    def commands(self) -> str:
        """workflow のうち、コメントの行を除いた本文を返す。"""
        lines = read("verify-ios.yml").splitlines()
        return "\n".join(line for line in lines if not line.strip().startswith("#"))

    def test_決めた版のXcodeが無ければビルドの前に止まる(self) -> None:
        self.assertRegex(value_at(self.nodes, "env", "KS_XCODE_VERSION") or "", r"^\d+\.\d+$")
        names = list(self.steps)
        self.assertLess(names.index("Select Xcode"), names.index(self.LIBRARY))
        step = self.steps["Select Xcode"]
        self.assertIn("Xcode_${KS_XCODE_VERSION}*.app", step)
        self.assertIn("exit 1", step)
        self.assertIsNone(condition_of(step))

    def test_stepは決めた5つだけである(self) -> None:
        self.assertEqual(
            list(self.steps), ["Checkout", "Select Xcode", "Show toolchain", self.LIBRARY, self.SAMPLE]
        )

    def test_テストを実行しない(self) -> None:
        commands = self.commands()
        # xcodebuild の呼び出しは、テストのコードまでをビルドして止まる形の 2 つだけ。
        self.assertEqual(re.findall(r"xcodebuild (?!-version)(\S+)", commands), ["build-for-testing"] * 2)
        self.assertNotIn("test-without-building", commands)
        self.assertNotIn("swift test", commands)

    def test_Simulatorを選ばず総称の行き先でビルドする(self) -> None:
        commands = self.commands()
        self.assertEqual(
            re.findall(r"-destination (.+?)(?: \\)?$", commands, flags=re.MULTILINE),
            ['"generic/platform=iOS Simulator"'] * 2,
        )
        for word in ("simctl", "SIMULATOR_UDID", "boot"):
            with self.subTest(word=word):
                self.assertNotIn(word, commands)

    def test_本体と本体のテストのコードをビルドする(self) -> None:
        step = self.steps[self.LIBRARY]
        self.assertIn("working-directory: ios\n", step)
        self.assertIn("xcodebuild build-for-testing", step)
        self.assertIn("-scheme KsCollectionView\n", step.replace(" \\", ""))
        self.assertIsNone(condition_of(step))
        # パッケージのスキームは、パッケージが宣言するテストのターゲットをビルドの対象に持つ。
        with open(os.path.join(support.REPOSITORY_ROOT, "ios", "Package.swift"), encoding="utf-8") as f:
            package = f.read()
        self.assertRegex(package, r'\.testTarget\(\s*name: "KsCollectionViewTests"')

    def test_SampleのアプリとユニットテストとUIテストのコードをビルドする(self) -> None:
        step = self.steps[self.SAMPLE]
        self.assertIn("working-directory: samples/ios\n", step)
        self.assertIn("xcodebuild build-for-testing", step)
        self.assertIn("-project KsCollectionViewSamples.xcodeproj ", step)
        self.assertIn("-scheme KsCollectionViewSamples ", step)
        # スキームが、アプリと 2 つのテストのターゲットをビルドの対象に持つこと。
        scheme = ElementTree.parse(os.path.join(support.REPOSITORY_ROOT, *self.SAMPLE_SCHEME)).getroot()
        built = {
            entry.find("BuildableReference").get("BuildableName")
            for entry in scheme.iter("BuildActionEntry")
            if entry.get("buildForTesting") == "YES"
        }
        self.assertEqual(built, {"KsCollectionViewSamples.app"})
        testables = {
            testable.find("BuildableReference").get("BuildableName"): testable.get("skipped")
            for testable in scheme.iter("TestableReference")
        }
        self.assertEqual(
            testables,
            {"KsCollectionViewSamplesTests.xctest": "NO", "KsCollectionViewSamplesUITests.xctest": "NO"},
        )

    def test_本体のビルドが落ちてもSampleのビルドは走る(self) -> None:
        self.assertRegex(self.steps[self.LIBRARY], r"(?m)^\s+id: library$")
        condition = condition_of(self.steps[self.SAMPLE])
        self.assertEqual(condition, "${{ !cancelled() && steps.library.outcome != 'skipped' }}")

    def test_ビルドの失敗を見逃さない(self) -> None:
        self.assertNotIn("continue-on-error", self.commands())
        for name in (self.LIBRARY, self.SAMPLE):
            with self.subTest(step=name):
                command = self.steps[name].split("run: |", 1)[1]
                # 合否は xcodebuild の終了コードで決まる。後ろに別のコマンドをつなぐと、
                # つないだ側の終了コードが step の合否になる。
                for token in ("|", ";", "&&"):
                    self.assertNotIn(token, command)


class AndroidWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.steps = steps_of("verify-android.yml")

    def test_決めた版のJDKを使う(self) -> None:
        self.assertRegex(self.steps["Setup JDK"], r'(?m)^\s+java-version: "21"$')

    def test_ビルドの出力をキャッシュしない(self) -> None:
        self.assertNotIn("build", re.sub(r"(?m)^\s+key:.*$", "", self.steps["Cache Gradle dependencies"]))

    def test_テストの前に結果の置き場を空にする(self) -> None:
        names = list(self.steps)
        self.assertLess(names.index("Clear test results"), names.index("Test library"))
        step = self.steps["Clear test results"]
        self.assertIn("android/kscollectionview/build/test-results/testDebugUnitTest", step)
        self.assertIn("samples/android/app/build/test-results/testDebugUnitTest", step)

    def test_本体とSampleのデバッグのユニットテストだけを流す(self) -> None:
        library = self.steps["Test library"]
        self.assertIn("working-directory: android\n", library)
        self.assertRegex(library, r"gradlew .*:kscollectionview:testDebugUnitTest$")
        sample = self.steps["Assemble sample and test sample units"]
        self.assertIn("working-directory: samples/android\n", sample)
        self.assertRegex(sample, r"gradlew .*:app:assembleDebug :app:testDebugUnitTest$")
        for step in (library, sample):
            self.assertNotIn("Release", step)
            self.assertNotIn("benchmark", step)
            self.assertNotIn("--tests", step)

    def test_本体のテストが落ちてもSampleの検証は走る(self) -> None:
        condition = condition_of(self.steps["Assemble sample and test sample units"])
        self.assertEqual(condition, "${{ !cancelled() && steps.sdk.outcome == 'success' }}")

    def test_件数の検査はテストが失敗しても走り2つの組を明示して渡す(self) -> None:
        self.assertRegex(self.steps["Test library"], r"(?m)^\s+id: library$")
        step = self.steps["Check test count"]
        self.assertEqual(condition_of(step), "${{ !cancelled() && steps.library.outcome != 'skipped' }}")
        self.assertEqual(
            re.findall(r'--target "([^"]+)"', step),
            [
                "Android 本体=android/kscollectionview:testDebugUnitTest",
                "Android Sample=samples/android/app:testDebugUnitTest",
            ],
        )
        self.assertNotIn("--stale-before", step)


# ---- リリースの workflow ----

RELEASE = "release.yml"

# 公開のジョブの step のうち、取り消せる順に並んでいなければならないもの (cross/ADR-0022)。
# 写しの push → 保留の送信 → 決着の待ち → 公開 → 配信用リポジトリの tag → 本リポジトリの tag → Release。
PUBLISH_ORDER = (
    "Push SPM snapshot",
    "Upload to Maven Central",
    "Wait for validation",
    "Publish deployment",
    "Tag SPM repository",
    "Tag main repository",
    "Create release",
)

# secret → それを受け取ってよい、公開のジョブの step。
SECRET_STEPS = {
    "SIGNING_KEY": {"Build signed publication", "Upload to Maven Central"},
    "SIGNING_KEY_ID": {"Build signed publication", "Upload to Maven Central"},
    "SIGNING_PASSWORD": {"Build signed publication", "Upload to Maven Central"},
    "MAVEN_CENTRAL_USERNAME": {
        "Check published deployment",
        "Inspect previous deployment",
        "Upload to Maven Central",
        "Wait for validation",
        "Publish deployment",
        "Wait for publication",
        "Drop pending deployment",
    },
    "MAVEN_CENTRAL_PASSWORD": {
        "Check published deployment",
        "Inspect previous deployment",
        "Upload to Maven Central",
        "Wait for validation",
        "Publish deployment",
        "Wait for publication",
        "Drop pending deployment",
    },
    "SPM_DEPLOY_KEY": {"Push SPM snapshot", "Tag SPM repository"},
}
SECRET_REFERENCE = re.compile(r"\$\{\{\s*secrets\.([A-Za-z0-9_]+)\s*\}\}")


def job_text(text: str, job: str) -> str:
    """workflow の本文から、1 つのジョブの行だけを返す。無ければ空の文字列。"""
    lines = text.splitlines()
    try:
        start = lines.index(f"  {job}:")
    except ValueError:
        return ""
    end = len(lines)
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if re.match(r"^ {0,2}\S", line) and not line.lstrip().startswith("#"):
            end = index
            break
    return "\n".join(lines[start:end])


def release_problems(text: str) -> list[str]:
    """リリースの workflow の定義が、決めた形から外れている点を返す。外れていなければ空。"""
    nodes, parse_problems = PARSER.parse(RELEASE, text)
    if parse_problems:
        return [problem.render() for problem in parse_problems]
    problems = []

    # 起動は手動だけで、入力は版と dry-run の 2 つ。
    triggers = keys_under(nodes, "on")
    if triggers != {"workflow_dispatch"}:
        problems.append(f"起動の条件が手動だけでない: {sorted(triggers)}")
    inputs = ("on", "workflow_dispatch", "inputs")
    if keys_under(nodes, *inputs) != {"version", "dry-run"}:
        problems.append(f"入力が版と dry-run の 2 つでない: {sorted(keys_under(nodes, *inputs))}")
    if (value_at(nodes, *inputs, "version", "type"), value_at(nodes, *inputs, "version", "required")) != (
        "string",
        "true",
    ) or find(nodes, *inputs, "version", "default") is not None:
        problems.append("版の入力が、既定の値を持たない必須の文字列でない")
    if (value_at(nodes, *inputs, "dry-run", "type"), value_at(nodes, *inputs, "dry-run", "default")) != (
        "boolean",
        "false",
    ):
        problems.append("dry-run の入力が、既定が偽の真偽でない")

    # 同時に 1 本だけ流し、走っているものを打ち切らない。まとまりは式を含まない 1 つの名前に固定する。
    group = value_at(nodes, "concurrency", "group") or ""
    if not group or "${{" in group:
        problems.append(f"同時実行のまとまりが 1 つに固定されていない: {group or '(無し)'}")
    if value_at(nodes, "concurrency", "cancel-in-progress") != "false":
        problems.append("同時実行で、走っているものを打ち切らない指定 (cancel-in-progress: false) が無い")

    # secret を置いた環境を指定するのは、公開のジョブだけ。
    for job in sorted(keys_under(nodes, "jobs")):
        environment = find(nodes, "jobs", job, "environment")
        expected = "release" if job == "publish" else None
        actual = None if environment is None else (PARSER.unquote(environment.value or "") or "(入れ子の指定)")
        if actual != expected:
            problems.append(f"ジョブ {job} の環境が {expected or '無し'} でない: {actual or '無し'}")

    # 公開のジョブの step が、取り消せる順に並ぶ。
    names = list(steps_in(job_text(text, "publish")))
    missing = [name for name in PUBLISH_ORDER if name not in names]
    if missing:
        problems.append(f"公開のジョブに、次の step が無い: {missing}")
    else:
        positions = [names.index(name) for name in PUBLISH_ORDER]
        if positions != sorted(positions):
            actual_order = sorted(PUBLISH_ORDER, key=names.index)
            problems.append(f"公開の step の順が違う: {actual_order} (決めた順: {list(PUBLISH_ORDER)})")
    return problems


class ReleaseWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.text = read(RELEASE)
        self.nodes = nodes_of(RELEASE)
        self.publish = steps_in(job_text(self.text, "publish"))

    def job_steps(self, job: str) -> dict[str, str]:
        return steps_in(job_text(self.text, job))

    def test_決めた形を守っている(self) -> None:
        self.assertEqual(release_problems(self.text), [])

    def test_tagのpushでの起動を足すと落ちる(self) -> None:
        text = self.text.replace("on:\n  workflow_dispatch:\n", "on:\n  push:\n    tags:\n      - \"*\"\n  workflow_dispatch:\n")
        self.assertNotEqual(text, self.text)
        problems = release_problems(text)
        self.assertTrue(any("起動の条件が手動だけでない" in problem for problem in problems), problems)

    def test_入力を足すと落ちる(self) -> None:
        text = self.text.replace(
            "      dry-run:\n", "      skip-tests:\n        type: boolean\n        default: false\n      dry-run:\n"
        )
        self.assertNotEqual(text, self.text)
        self.assertTrue(any("入力が版と dry-run の 2 つでない" in problem for problem in release_problems(text)))

    def test_走っているものを打ち切る指定にすると落ちる(self) -> None:
        text = self.text.replace("  cancel-in-progress: false\n", "  cancel-in-progress: true\n")
        self.assertNotEqual(text, self.text)
        self.assertTrue(any("cancel-in-progress" in problem for problem in release_problems(text)))

    def test_同時実行のまとまりを式で分けると落ちる(self) -> None:
        text = self.text.replace("  group: release\n", "  group: release-${{ github.ref }}\n")
        self.assertNotEqual(text, self.text)
        self.assertTrue(any("同時実行のまとまり" in problem for problem in release_problems(text)))

    def test_公開以外のジョブに環境を指定すると落ちる(self) -> None:
        text = self.text.replace(
            "  package-android:\n    name: package-android\n",
            "  package-android:\n    name: package-android\n    environment: release\n",
        )
        self.assertNotEqual(text, self.text)
        problems = release_problems(text)
        self.assertTrue(any("ジョブ package-android の環境" in problem for problem in problems), problems)

    def test_公開のstepの順を入れ替えると落ちる(self) -> None:
        # 本リポジトリの tag の step を、Maven Central の公開の step より前に移す。
        tag_step = steps_in(job_text(self.text, "publish"))["Tag main repository"]
        start = self.text.index("      - name: Tag main repository\n")
        end = self.text.index("      - name: Create release\n")
        moved_block = self.text[start:end]
        text = self.text[:start] + self.text[end:]
        anchor = text.index("      - name: Publish deployment\n")
        text = text[:anchor] + moved_block + text[anchor:]
        self.assertIn("gh api --method POST", tag_step)
        problems = release_problems(text)
        self.assertTrue(any("公開の step の順が違う" in problem for problem in problems), problems)

    def test_workflowの定義の検査に違反が無い(self) -> None:
        problems, counts = PARSER.check_text(RELEASE, self.text)
        self.assertEqual([problem.render() for problem in problems], [])
        # 確かめた箇所が 0 のまま違反なしになっていないこと。
        self.assertEqual(counts["permissions"], 2)
        self.assertGreaterEqual(counts["runs-on"], 5)
        self.assertGreaterEqual(counts["uses"], 10)

    def test_内容の書き込みを持つのは公開のジョブだけである(self) -> None:
        self.assertEqual(keys_under(self.nodes, "permissions"), {"contents"})
        self.assertEqual(value_at(self.nodes, "permissions", "contents"), "read")
        for job in keys_under(self.nodes, "jobs"):
            with self.subTest(job=job):
                if job == "publish":
                    self.assertEqual(keys_under(self.nodes, "jobs", job, "permissions"), {"contents"})
                    self.assertEqual(value_at(self.nodes, "jobs", job, "permissions", "contents"), "write")
                else:
                    self.assertIsNone(find(self.nodes, "jobs", job, "permissions"))

    def test_ジョブの並びが決めたとおりである(self) -> None:
        expected = {
            "validate": None,
            "verify-ios": ["validate"],
            "verify-android": ["validate"],
            "package-ios": ["validate"],
            "package-android": ["validate"],
            "consumer-ios": ["package-ios"],
            "consumer-android": ["package-android"],
            "publish": ["validate", "verify-ios", "verify-android", "consumer-ios", "consumer-android"],
            "wait-for-registries": ["publish"],
            "smoke-ios": ["wait-for-registries"],
            "smoke-android": ["wait-for-registries"],
            "check-release": ["wait-for-registries"],
        }
        self.assertEqual(keys_under(self.nodes, "jobs"), set(expected))
        for job, needs in expected.items():
            with self.subTest(job=job):
                node = find(self.nodes, "jobs", job, "needs")
                actual = None if node is None else [value for _, value in PARSER.values_of(self.nodes, node)]
                self.assertEqual(actual, needs)
                self.assertEqual(value_at(self.nodes, "jobs", job, "name"), job)

    def test_公開は本番だけ走りdryrunでは飛ばす(self) -> None:
        self.assertEqual(
            value_at(self.nodes, "jobs", "publish", "if"), "${{ needs.validate.outputs.production == 'true' }}"
        )
        self.assertEqual(
            value_at(self.nodes, "jobs", "validate", "outputs", "production"), "${{ steps.inputs.outputs.production }}"
        )
        # 公開の後の工程は、公開のジョブに続けてだけ走る (自分の条件で公開を飛び越えない)。
        for job in ("wait-for-registries", "smoke-ios", "smoke-android", "check-release"):
            with self.subTest(job=job):
                self.assertIsNone(find(self.nodes, "jobs", job, "if"))

    def test_最初のジョブが入力と状態を確かめてノートを組み立てる(self) -> None:
        steps = self.job_steps("validate")
        self.assertEqual(
            list(steps),
            ["Checkout", "Check inputs", "Check tags", "Check published version", "Build release notes", "Upload release notes"],
        )
        self.assertIn("fetch-depth: 0", steps["Checkout"])
        self.assertIn(
            'check-release-state.py inputs --version "${KS_VERSION}" --dry-run "${KS_DRY_RUN}"', steps["Check inputs"]
        )
        self.assertIn("KS_DRY_RUN: ${{ inputs.dry-run }}\n", steps["Check inputs"])
        self.assertIn('check-release-state.py tags --version "${KS_VERSION}"', steps["Check tags"])
        self.assertIn('check-release-state.py published --version "${KS_VERSION}"', steps["Check published version"])
        self.assertIn("build-release-notes.py --version", steps["Build release notes"])
        self.assertEqual(condition_of(steps["Upload release notes"]), "${{ steps.notes.outputs.built == 'true' }}")
        # 入力と状態の確かめは、条件なしで走る (dry-run でも確かめる)。
        for name in ("Check inputs", "Check tags", "Check published version", "Build release notes"):
            with self.subTest(step=name):
                self.assertIsNone(condition_of(steps[name]))

    def test_検証は検証CIと同じworkflowを入力なしで呼ぶ(self) -> None:
        for job, workflow in (("verify-ios", "verify-ios.yml"), ("verify-android", "verify-android.yml")):
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "uses"), f"./.github/workflows/{workflow}")
                self.assertEqual(keys_under(self.nodes, "jobs", job), {"name", "needs", "uses"})

    def test_公開の前の利用者役は組み立てたartifactを使う(self) -> None:
        uploads = {
            "package-ios": ("Upload SPM snapshot", "consumer-ios", "verify-consumer-ios.yml"),
            "package-android": ("Upload publication", "consumer-android", "verify-consumer-android.yml"),
        }
        for package, (upload, consumer, workflow) in uploads.items():
            with self.subTest(job=consumer):
                name = re.search(r"(?m)^\s+name: (\S+)$", self.job_steps(package)[upload].split("with:", 1)[1])
                self.assertIsNotNone(name)
                self.assertEqual(value_at(self.nodes, "jobs", consumer, "uses"), f"./.github/workflows/{workflow}")
                self.assertEqual(value_at(self.nodes, "jobs", consumer, "with", "mode"), "artifact")
                self.assertEqual(value_at(self.nodes, "jobs", consumer, "with", "artifact"), name.group(1))
        self.assertEqual(keys_under(self.nodes, "jobs", "consumer-ios", "with"), {"mode", "artifact"})
        self.assertEqual(
            value_at(self.nodes, "jobs", "consumer-android", "with", "version"), "${{ inputs.version }}"
        )

    def test_公開の後の利用者役は公開物を取る(self) -> None:
        for job, workflow in (("smoke-ios", "verify-consumer-ios.yml"), ("smoke-android", "verify-consumer-android.yml")):
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "uses"), f"./.github/workflows/{workflow}")
                self.assertEqual(keys_under(self.nodes, "jobs", job, "with"), {"mode", "version"})
                self.assertEqual(value_at(self.nodes, "jobs", job, "with", "mode"), "published")
                self.assertEqual(value_at(self.nodes, "jobs", job, "with", "version"), "${{ inputs.version }}")

    def test_組み立ての段の発行物に版と元のcommitを入れて確かめる(self) -> None:
        steps = self.job_steps("package-android")
        publish = steps["Publish to working repository"]
        self.assertIn('"-Pversion=${KS_VERSION}"', publish)
        self.assertIn('"-PksCollectionViewSourceCommit=${GITHUB_SHA}"', publish)
        self.assertIn(":kscollectionview:publishToMavenLocal", publish)
        self.assertIn('--commit "${GITHUB_SHA}"', steps["Check publication"])
        names = list(steps)
        self.assertLess(names.index("Check publication"), names.index("Upload publication"))

    def test_secretは公開のジョブの使うstepにだけ渡す(self) -> None:
        for job in keys_under(self.nodes, "jobs"):
            if job == "publish":
                continue
            with self.subTest(job=job):
                self.assertNotIn("secrets", job_text(self.text, job))
        # ジョブ全体の環境変数には渡さない。
        publish_env = job_text(self.text, "publish").split("    steps:", 1)[0]
        self.assertNotIn("secrets.", publish_env)
        received: dict[str, set[str]] = {}
        for name, step in self.publish.items():
            for secret in SECRET_REFERENCE.findall(step):
                received.setdefault(secret, set()).add(name)
        self.assertEqual(received, SECRET_STEPS)

    def test_secretをファイルに書き出さない(self) -> None:
        for name in SECRET_STEPS["SPM_DEPLOY_KEY"]:
            with self.subTest(step=name):
                step = self.publish[name]
                self.assertIn('printf \'%s\\n\' "${SPM_DEPLOY_KEY}" | ssh-add -', step)
                self.assertIn("trap 'ssh-agent -k > /dev/null' EXIT", step)
                self.assertNotRegex(step, r"SPM_DEPLOY_KEY[^\n]*>")
        for name in ("Build signed publication", "Upload to Maven Central"):
            with self.subTest(step=name):
                self.assertIn("ORG_GRADLE_PROJECT_signingInMemoryKey: ${{ secrets.SIGNING_KEY }}\n", self.publish[name])

    def test_自動で公開する設定を渡さない(self) -> None:
        commands = without_comments(RELEASE)
        self.assertNotIn("mavenCentralAutomaticPublishing", commands)
        self.assertNotIn("publishAndReleaseToMavenCentral", commands)
        self.assertIn(":kscollectionview:publishToMavenCentral", self.publish["Upload to Maven Central"])

    def test_署名して組み立て直した発行物を確かめてから送る(self) -> None:
        names = list(self.publish)
        self.assertLess(names.index("Build signed publication"), names.index("Check signed publication"))
        self.assertLess(names.index("Check signed publication"), names.index("Upload to Maven Central"))
        check = self.publish["Check signed publication"]
        self.assertIn('--reference "${RUNNER_TEMP}/reference-maven" --signed "${RUNNER_TEMP}/signed-maven"', check)
        self.assertIn('--commit "${GITHUB_SHA}"', check)
        for name in ("Build signed publication", "Upload to Maven Central"):
            with self.subTest(step=name):
                self.assertIn('"-PksCollectionViewSourceCommit=${GITHUB_SHA}"', self.publish[name])
                self.assertIn('"-Pversion=${KS_VERSION}"', self.publish[name])

    def test_公開済みの検査と元のcommitの照合は写しのpushより前である(self) -> None:
        names = list(self.publish)
        push = names.index("Push SPM snapshot")
        for name in ("Check published deployment", "Check published commit", "Inspect previous deployment"):
            with self.subTest(step=name):
                self.assertLess(names.index(name), push)
        self.assertIn("central-portal.py published", self.publish["Check published deployment"])
        commit_check = self.publish["Check published commit"]
        self.assertEqual(condition_of(commit_check), "${{ steps.published.outputs.published == 'true' }}")
        self.assertIn('wait-for-maven-central.py --version "${KS_VERSION}" --commit "${GITHUB_SHA}"', commit_check)

    def test_送信の操作は状態に応じて飛ばす(self) -> None:
        not_published = "steps.published.outputs.published != 'true'"
        upload_only = f"${{{{ {not_published} && steps.inspect.outputs.action == 'upload' }}}}"
        for name in ("Build signed publication", "Check signed publication", "Upload to Maven Central"):
            with self.subTest(step=name):
                self.assertEqual(condition_of(self.publish[name]), upload_only)
        upload_or_reuse = (
            f"${{{{ {not_published} && (steps.inspect.outputs.action == 'upload' || "
            "steps.inspect.outputs.action == 'reuse') }}"
        )
        for name in ("Wait for validation", "Publish deployment"):
            with self.subTest(step=name):
                self.assertEqual(condition_of(self.publish[name]), upload_or_reuse)
        self.assertEqual(
            condition_of(self.publish["Wait for publication"]),
            f"${{{{ {not_published} && steps.inspect.outputs.action != 'published' }}}}",
        )
        self.assertEqual(
            condition_of(self.publish["Inspect previous deployment"]), f"${{{{ {not_published} }}}}"
        )

    def test_待ちの上限を渡しジョブの上限はその合計より長い(self) -> None:
        self.assertIn("settle --deployment-id", self.publish["Wait for validation"])
        self.assertIn("--timeout-minutes 60", self.publish["Wait for validation"])
        self.assertIn("--timeout-minutes 120", self.publish["Wait for publication"])
        self.assertIn("--timeout-minutes 120", self.publish["Check published commit"])
        self.assertIn("--timeout-minutes 10", self.publish["Drop pending deployment"])
        self.assertGreater(int(value_at(self.nodes, "jobs", "publish", "timeout-minutes")), 60 + 120 + 120 + 10)
        wait = self.job_steps("wait-for-registries")["Wait for Maven Central"]
        self.assertIn('--commit "${GITHUB_SHA}" --timeout-minutes 120', wait)
        self.assertGreater(int(value_at(self.nodes, "jobs", "wait-for-registries", "timeout-minutes")), 120)

    def test_送信のIDをログから読み試行の番号を入れた名前で控えを置く(self) -> None:
        upload = self.publish["Upload to Maven Central"]
        # ログをファイルに受け、Gradle の終了コードを控えてそのまま返す。パイプでつながない。
        # 失敗したときの動きは、下の UploadStepShellTest が実際にシェルで流して確かめる。
        self.assertIn('publishToMavenCentral > "$log" 2>&1 || status=$?\n', upload)
        self.assertIn('exit "$status"', upload)
        self.assertNotIn("| tee", without_comments(RELEASE))
        extract = self.publish["Extract deployment id"]
        self.assertEqual(
            condition_of(extract),
            "${{ !cancelled() && (steps.upload.outcome == 'success' || steps.upload.outcome == 'failure') }}",
        )
        self.assertIn('extract-id --log "${RUNNER_TEMP}/maven-central-upload.log"', extract)
        receipt = self.publish["Upload deployment receipt"]
        self.assertIn("name: central-portal-receipt-${{ github.run_attempt }}\n", receipt)
        self.assertEqual(condition_of(receipt), "${{ !cancelled() && steps.extract.outcome == 'success' }}")
        receipts = self.publish["Download deployment receipts"]
        self.assertIn("pattern: central-portal-receipt-*\n", receipts)
        self.assertIn('inspect --version "${KS_VERSION}" --receipts "${RUNNER_TEMP}/receipts"', self.publish["Inspect previous deployment"])

    def test_取り下げは公開の指示の前に失敗したときだけ試みる(self) -> None:
        names = list(self.publish)
        self.assertEqual(names[-1], "Drop pending deployment")
        condition = condition_of(self.publish["Drop pending deployment"]) or ""
        self.assertTrue(condition.startswith("${{ failure() && steps.publish.outcome == 'skipped' && "), condition)
        self.assertIn("drop --deployment-id", self.publish["Drop pending deployment"])

    def test_tagとReleaseは今の状態を確かめてから作る(self) -> None:
        names = list(self.publish)
        self.assertLess(names.index("Wait for publication"), names.index("Check tags before tagging"))
        self.assertLess(names.index("Check tags before tagging"), names.index("Tag SPM repository"))
        self.assertIn('check-release-state.py tags --version "${KS_VERSION}"', self.publish["Check tags before tagging"])
        self.assertEqual(condition_of(self.publish["Tag SPM repository"]), "${{ steps.tags.outputs.spm-tag == 'absent' }}")
        self.assertEqual(condition_of(self.publish["Tag main repository"]), "${{ steps.tags.outputs.main-tag == 'absent' }}")
        self.assertIn('-f "sha=${GITHUB_SHA}"', self.publish["Tag main repository"])
        self.assertIn("KS_SPM_COMMIT: ${{ steps.spm.outputs.commit }}\n", self.publish["Tag SPM repository"])

    def test_Releaseの属性(self) -> None:
        release = self.publish["Create release"]
        self.assertIsNone(condition_of(release))
        self.assertLess(release.index("gh release view"), release.index("gh release create"))
        create = release[release.index("gh release create") :]
        for option in ("--verify-tag", '--title "${KS_VERSION}"', "--latest", "--notes-file"):
            with self.subTest(option=option):
                self.assertIn(option, create)
        for option in ("--prerelease", "--draft", "--latest=false", "--generate-notes", "--target"):
            with self.subTest(option=option):
                self.assertNotIn(option, create)
        # 本文は validate が組み立てたノートで、Pull Request の本文を読み直さない。
        self.assertIn("name: release-notes\n", self.publish["Download release notes"])
        self.assertNotIn("build-release-notes.py", job_text(self.text, "publish"))

    def test_本リポジトリにcommitを作らない(self) -> None:
        # commit を作るのは配信用リポジトリの作業コピーだけで、本リポジトリへ git で push しない。
        commands = without_comments(RELEASE).replace("\\\n", " ")
        touched = []
        for line in commands.splitlines():
            if re.search(r"\bgit\b.*\b(commit|push)\b", line):
                touched.append(line)
                with self.subTest(line=line.strip()):
                    self.assertIn('-C "$spm_dir"', line)
        # 写しの commit・写しの push・配信用リポジトリの tag の push の 3 か所。
        self.assertEqual(len(touched), 3, touched)

    def test_写しは利用者役で確かめたartifactをそのまま置いてpushする(self) -> None:
        names = list(self.publish)
        self.assertLess(names.index("Download SPM snapshot"), names.index("Push SPM snapshot"))
        # 取り込むのは、package-ios が置き、consumer-ios が確かめたのと同じ名前の artifact。
        verified = value_at(self.nodes, "jobs", "consumer-ios", "with", "artifact")
        self.assertEqual(verified, "spm-snapshot")
        download = self.publish["Download SPM snapshot"]
        self.assertIn(f"name: {verified}\n", download)
        self.assertIn("path: ${{ runner.temp }}/spm-snapshot\n", download)
        self.assertIsNone(condition_of(download))
        push = self.publish["Push SPM snapshot"]
        self.assertIn(
            'place-spm-snapshot.py --snapshot "${RUNNER_TEMP}/spm-snapshot" --destination "$spm_dir"', push
        )
        self.assertLess(push.index("git clone"), push.index("place-spm-snapshot.py"))
        self.assertLess(push.index("place-spm-snapshot.py"), push.index("diff --cached --quiet"))
        # 作業コピーに写しを作り直さない。index に載せるのは place-spm-snapshot.py だけが行う
        # (載せた後に、index の中身が確かめた写しと同じことを確かめている)。
        self.assertNotIn("sync-spm-snapshot.py", job_text(self.text, "publish"))
        self.assertNotIn(" add ", push)

    def test_写しは差分が無ければcommitを作らない(self) -> None:
        push = self.publish["Push SPM snapshot"]
        self.assertIn('if git -C "$spm_dir" diff --cached --quiet; then', push)
        self.assertLess(push.index("diff --cached --quiet"), push.index("commit --quiet"))
        self.assertIn('git -C "$spm_dir" push --quiet origin HEAD:refs/heads/main', push)
        self.assertIn("StrictHostKeyChecking=yes", push)

    def test_最新のReleaseが今回の版を指すことを確かめる(self) -> None:
        step = self.job_steps("check-release")["Check latest release"]
        self.assertIn("releases/latest", step)
        self.assertIn('"$latest" != "${KS_VERSION}"', step)
        self.assertIn("/releases/tag/${KS_VERSION}", step)

    def test_SDKを確かめる手順が既存の検証と同じである(self) -> None:
        def body(step: str) -> str:
            return step.split("run: |", 1)[1]

        existing = body(steps_of("verify-android.yml")["Ensure Android SDK platform"])
        for job in ("package-android", "publish"):
            with self.subTest(job=job):
                self.assertEqual(body(self.job_steps(job)["Ensure Android SDK platform"]), existing)

    def test_JDKの版が既存の検証と同じである(self) -> None:
        pattern = r'(?m)^\s+java-version: "(\d+)"$'
        existing = re.search(pattern, steps_of("verify-android.yml")["Setup JDK"]).group(1)
        for job in ("package-android", "publish"):
            with self.subTest(job=job):
                self.assertEqual(re.search(pattern, self.job_steps(job)["Setup JDK"]).group(1), existing)

    def test_ほかのworkflowと共有するキャッシュを使わない(self) -> None:
        self.assertNotIn("actions/cache@", without_comments(RELEASE))

    def test_失敗を見逃す指定が無い(self) -> None:
        self.assertNotIn("continue-on-error", without_comments(RELEASE))


def run_block(step: str) -> str:
    """step の `run: |` の本文を、インデントを外して返す。"""
    lines = step.split("run: |\n", 1)[1].splitlines()
    indent = min(len(line) - len(line.lstrip()) for line in lines if line.strip())
    return "\n".join(line[indent:] for line in lines) + "\n"


# GitHub Actions が、Linux のランナーで run の本文を流すときのシェル。shell を指定しない step は
# 1 つ目、shell: bash を指定した step は 2 つ目で流れる。どちらも失敗したコマンドで即座に終わる (-e)。
# https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell
ACTIONS_SHELLS = (("bash", "-e"), ("bash", "--noprofile", "--norc", "-eo", "pipefail"))


class UploadStepShellTest(unittest.TestCase):
    """Maven Central へ送る step の本文を、Actions と同じシェルのオプションで、偽の Gradle を置いて流す。"""

    def setUp(self) -> None:
        step = steps_in(job_text(read(RELEASE), "publish"))["Upload to Maven Central"]
        self.assertIsNone(re.search(r"(?m)^\s+shell:", step), "シェルの指定が変わったら ACTIONS_SHELLS を見直す")
        self.body = run_block(step)
        self.directory = tempfile.mkdtemp(prefix="release-upload-step-")
        self.addCleanup(shutil.rmtree, self.directory)
        self.android = os.path.join(self.directory, "android")
        self.runner_temp = os.path.join(self.directory, "runner-temp")
        os.makedirs(self.android)
        os.makedirs(self.runner_temp)
        self.script = os.path.join(self.directory, "step.sh")
        with open(self.script, "w", encoding="utf-8") as f:
            f.write(self.body)

    def write_gradle(self, output: str, status: int) -> None:
        gradlew = os.path.join(self.android, "gradlew")
        with open(gradlew, "w", encoding="utf-8") as f:
            f.write(f"#!/bin/sh\nprintf '%s\\n' '{output}'\necho 'to stderr' >&2\nexit {status}\n")
        os.chmod(gradlew, 0o755)

    def run_step(self, shell: tuple[str, ...]) -> subprocess.CompletedProcess:
        environment = {key: value for key, value in os.environ.items() if not key.startswith(("GITHUB_", "KS_"))}
        environment.update({"RUNNER_TEMP": self.runner_temp, "KS_VERSION": "0.1.0-beta.1", "GITHUB_SHA": "a" * 40})
        return subprocess.run(
            [*shell, self.script], cwd=self.android, capture_output=True, text=True, env=environment, timeout=60
        )

    def test_失敗してもログを表示し元の終了コードで終わる(self) -> None:
        self.write_gradle("Central Portal rejected the upload: 401 Unauthorized", 3)
        for shell in ACTIONS_SHELLS:
            with self.subTest(shell=" ".join(shell)):
                result = self.run_step(shell)
                self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
                self.assertIn("Central Portal rejected the upload: 401 Unauthorized", result.stdout)
                self.assertIn("to stderr", result.stdout)
                with open(os.path.join(self.runner_temp, "maven-central-upload.log"), encoding="utf-8") as f:
                    self.assertIn("401 Unauthorized", f.read())

    def test_成功したらログを表示して成功で終わる(self) -> None:
        line = "Uploaded bundle to Central Portal as USER_MANAGED, deployment id: 0000"
        self.write_gradle(line, 0)
        for shell in ACTIONS_SHELLS:
            with self.subTest(shell=" ".join(shell)):
                result = self.run_step(shell)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(line, result.stdout)


if __name__ == "__main__":
    unittest.main()
