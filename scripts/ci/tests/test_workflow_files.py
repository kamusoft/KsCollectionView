"""検証 CI の workflow が、決めた形を保っているかのテスト。

確かめるのは、崩れても平時の緑では気付けない形だけにする: 起動の条件、検査の名前、
検証が走らせる範囲、件数の検査が必ず走る条件。
道具の固定と権限、ジョブの時間の上限は check-workflows.py が確かめるので、ここでは確かめない。
"""

from __future__ import annotations

import os
import re
import unittest

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
    steps: dict[str, list[str]] = {}
    current: list[str] | None = None
    for line in read(name).splitlines():
        matched = STEP_START.match(line)
        if matched:
            current = steps.setdefault(matched.group(1), [])
        if current is not None and not line.strip().startswith("#"):
            current.append(line)
    return {step: "\n".join(lines) for step, lines in steps.items()}


def condition_of(step: str) -> str | None:
    matched = re.search(r"(?m)^\s+if:\s*(.+?)\s*$", step)
    return matched.group(1) if matched else None


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

    def test_検査の名前がlintとiosとandroidである(self) -> None:
        jobs = {node.path[1] for node in self.nodes if len(node.path) >= 2 and node.path[0] == "jobs"}
        self.assertEqual(jobs, {"lint", "ios", "android"})
        for job in sorted(jobs):
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "name"), job)

    def test_2本の検証を入力なしで呼び条件を付けない(self) -> None:
        for job, workflow in (("ios", "verify-ios.yml"), ("android", "verify-android.yml")):
            with self.subTest(job=job):
                self.assertEqual(value_at(self.nodes, "jobs", job, "uses"), f"./.github/workflows/{workflow}")
                keys = {node.path[2] for node in self.nodes if node.path[:2] == ("jobs", job) and len(node.path) >= 3}
                self.assertEqual(keys, {"name", "uses"})

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


class IosWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.nodes = nodes_of("verify-ios.yml")
        self.steps = steps_of("verify-ios.yml")

    def test_決めた版のXcodeが無ければテストの前に止まる(self) -> None:
        self.assertRegex(value_at(self.nodes, "env", "KS_XCODE_VERSION") or "", r"^\d+\.\d+$")
        names = list(self.steps)
        self.assertLess(names.index("Select Xcode"), names.index("Test library"))
        step = self.steps["Select Xcode"]
        self.assertIn("Xcode_${KS_XCODE_VERSION}*.app", step)
        self.assertIn("exit 1", step)
        self.assertIsNone(condition_of(step))

    def test_本体のテストをSimulatorで絞り込みなしに流す(self) -> None:
        step = self.steps["Test library"]
        self.assertIn("run-logged.py", step)
        self.assertIn("xcodebuild test", step)
        self.assertIn("-scheme KsCollectionView\n", step.replace(" \\", ""))
        self.assertIn("platform=iOS Simulator,id=${KS_SIMULATOR_UDID}", step)
        self.assertNotIn("-only-testing", step)
        self.assertNotIn("-skip-testing", step)

    def test_Sampleはユニットテストのターゲットだけを流す(self) -> None:
        step = self.steps["Build sample and test sample units"]
        self.assertIn("run-logged.py", step)
        self.assertIn("-scheme KsCollectionViewSamples ", step)
        self.assertEqual(re.findall(r"-only-testing:(\S+)", step), ["KsCollectionViewSamplesTests"])
        self.assertNotIn("UITests", step)
        self.assertNotIn("Performance", step)

    def test_本体のテストが落ちてもSampleの検証は走る(self) -> None:
        condition = condition_of(self.steps["Build sample and test sample units"])
        self.assertEqual(condition, "${{ !cancelled() && steps.simulator.outcome == 'success' }}")

    def test_件数の検査はテストが失敗しても走り同じ記録を読む(self) -> None:
        pairs = (
            ("Test library", "library", "Check library test count", "iOS 本体", "ios-library.log"),
            ("Build sample and test sample units", "sample", "Check sample test count", "iOS Sample", "ios-sample.log"),
        )
        for test_step, step_id, check_step, label, log in pairs:
            with self.subTest(check=check_step):
                self.assertRegex(self.steps[test_step], rf"(?m)^\s+id: {step_id}$")
                self.assertIn(f'--log "${{RUNNER_TEMP}}/{log}"', self.steps[test_step])
                check = self.steps[check_step]
                self.assertEqual(
                    condition_of(check), f"${{{{ !cancelled() && steps.{step_id}.outcome != 'skipped' }}}}"
                )
                self.assertIn(f'check-ios-test-count.py --label "{label}" --log "${{RUNNER_TEMP}}/{log}"', check)


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


if __name__ == "__main__":
    unittest.main()
