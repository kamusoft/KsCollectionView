"""workflow の定義の検査のテスト。"""

from __future__ import annotations

import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("check-workflows.py")

SHA = "3d3c42e5aac5ba805825da76410c181273ba90b1"

# 入口の workflow を模した、決まりを守っている定義。
ENTRY = f"""# 検証の入口
name: CI

on:
  pull_request:
    branches:
      - main
  push:
    branches: [develop]
    paths-ignore:
      - "kasane/**"

permissions:
  contents: read

concurrency:
  group: ci-${{{{ github.workflow }}}}-${{{{ github.event.pull_request.number || github.ref }}}}
  cancel-in-progress: true

jobs:
  ios:
    name: ios
    uses: ./.github/workflows/verify-ios.yml

  lint:
    name: lint
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    env:
      KS_TOOL_VERSION: "1.2.3" # 版
    steps:
      - name: Checkout
        uses: actions/checkout@{SHA} # v7.0.1
      - name: Setup JDK
        uses: actions/setup-java@{SHA}
        with:
          distribution: temurin
          java-version: '21'
      - name: Script
        if: github.event_name == 'pull_request' && github.base_ref == 'main'
        run: |
          set -euo pipefail
          # 複数行の文字列の中は、定義として読まない。
          echo "uses: actions/checkout@v4"
          echo "runs-on: ubuntu-latest"
          echo "permissions: write-all"
      - run: python3 scripts/ci/run-tests.py
"""

REUSABLE = f"""name: verify ios

on:
  workflow_call:

permissions:
  contents: read

jobs:
  verify:
    name: verify
    runs-on: xcode-27
    timeout-minutes: 40
    steps:
    - name: Checkout
      uses: actions/checkout@{SHA}
    - name: Test
      run: >-
        xcodebuild test
"""


class CheckWorkflowsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = self.directory.name

    def add(self, name: str, text: str) -> str:
        return support.write(os.path.join(self.root, ".github", "workflows", name), text)

    def run_check(self, *files: str) -> tuple[int, str]:
        code, stdout, _ = support.run_main(SCRIPT, ["--root", self.root, *files])
        return code, stdout

    def assert_violation(self, text: str, line: int, message: str, name: str = "ci.yml") -> None:
        self.add(name, text)
        code, stdout = self.run_check()
        self.assertEqual(code, 1, stdout)
        self.assertIn(f"{os.path.join('.github', 'workflows', name)}:{line}: ", stdout)
        self.assertIn(message, stdout)

    def test_決まりを守っている定義は通る(self) -> None:
        self.add("ci.yml", ENTRY)
        self.add("verify-ios.yaml", REUSABLE)
        code, stdout = self.run_check()
        self.assertEqual(code, 0, stdout)
        self.assertIn("確かめた workflow: 2 本 (uses 4 箇所 / runs-on 2 箇所 / permissions 2 箇所)", stdout)

    def test_タグで指定した外部のactionがあれば失敗し場所が示される(self) -> None:
        text = ENTRY.replace(f"actions/setup-java@{SHA}", "actions/setup-java@v6")
        line = text.splitlines().index("        uses: actions/setup-java@v6") + 1
        self.assert_violation(text, line, "外部の action を commit の ID で指定していない: actions/setup-java@v6")

    def test_commitのIDに見えるが桁の足りない指定も失敗する(self) -> None:
        for reference in (f"actions/checkout@{SHA[:12]}", "actions/checkout", "actions/checkout@main"):
            with self.subTest(reference=reference):
                self.add("ci.yml", REUSABLE.replace(f"actions/checkout@{SHA}", reference))
                code, stdout = self.run_check()
                self.assertEqual(code, 1)
                self.assertIn("commit の ID で指定していない", stdout)

    def test_外部のイメージはダイジェストで指定する(self) -> None:
        digest = "docker://ghcr.io/owner/image@sha256:" + "a" * 64
        self.add("ci.yml", REUSABLE.replace(f"actions/checkout@{SHA}", digest))
        code, stdout = self.run_check()
        self.assertEqual(code, 0, stdout)
        self.add("ci.yml", REUSABLE.replace(f"actions/checkout@{SHA}", "docker://ghcr.io/owner/image:1.2"))
        code, stdout = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("外部のイメージをダイジェストで指定していない", stdout)

    def test_引用符で囲んだ指定も確かめる(self) -> None:
        self.add("ci.yml", REUSABLE.replace(f"actions/checkout@{SHA}", '"actions/checkout@v7"'))
        code, stdout = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("actions/checkout@v7", stdout)

    def test_タグで指定した外部の再利用workflowがあれば失敗する(self) -> None:
        text = ENTRY.replace("uses: ./.github/workflows/verify-ios.yml", "uses: other/repo/.github/workflows/x.yml@v1")
        line = text.splitlines().index("    uses: other/repo/.github/workflows/x.yml@v1") + 1
        self.assert_violation(text, line, "commit の ID で指定していない")

    def test_最新を指す名前のランナーがあれば失敗しジョブが示される(self) -> None:
        text = ENTRY.replace("runs-on: ubuntu-24.04", "runs-on: ubuntu-latest")
        line = text.splitlines().index("    runs-on: ubuntu-latest") + 1
        self.assert_violation(text, line, "ジョブ lint: 最新を指す名前でランナーを選んでいる: ubuntu-latest")

    def test_並びで書いたランナーの名前も確かめる(self) -> None:
        for runs_on in ("runs-on: [self-hosted, macos-latest]", "runs-on:\n      - self-hosted\n      - macos-latest"):
            with self.subTest(runs_on=runs_on):
                self.add("ci.yml", REUSABLE.replace("runs-on: xcode-27", runs_on))
                code, stdout = self.run_check()
                self.assertEqual(code, 1)
                self.assertIn("ジョブ verify: 最新を指す名前でランナーを選んでいる: macos-latest", stdout)

    def test_版を読み取れないランナーの選び方は失敗する(self) -> None:
        cases = {
            "runs-on: ${{ matrix.os }}": "ランナーを式で選んでいるため、版を確かめられない",
            "runs-on:\n      group: big": "ランナーのグループで選んでいるため、版を確かめられない",
            "runs-on:\n      labels: ubuntu-latest": "最新を指す名前でランナーを選んでいる",
        }
        for runs_on, message in cases.items():
            with self.subTest(runs_on=runs_on):
                self.add("ci.yml", REUSABLE.replace("runs-on: xcode-27", runs_on))
                code, stdout = self.run_check()
                self.assertEqual(code, 1)
                self.assertIn(message, stdout)

    def test_版の番号を持たない名前のランナーがあれば失敗しジョブが示される(self) -> None:
        for label in ("self-hosted", "macos", "linux-arm64", "24.04", "ubuntu-24.04x"):
            with self.subTest(label=label):
                text = ENTRY.replace("runs-on: ubuntu-24.04", f"runs-on: {label}")
                line = text.splitlines().index(f"    runs-on: {label}") + 1
                self.assert_violation(text, line, f"ジョブ lint: 版を読み取れない名前でランナーを選んでいる: {label}")

    def test_並びの中の版の番号を持たない名前も失敗する(self) -> None:
        self.add("ci.yml", REUSABLE.replace("runs-on: xcode-27", "runs-on: [self-hosted, macos-15]"))
        code, stdout = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("ジョブ verify: 版を読み取れない名前でランナーを選んでいる: self-hosted", stdout)
        self.assertNotIn("macos-15", stdout)

    def test_版を指定した名前のランナーは通る(self) -> None:
        for label in ("ubuntu-24.04", "xcode-27", "macos-15-xlarge", "ubuntu-24.04-arm", "'windows-2025'"):
            with self.subTest(label=label):
                self.add("ci.yml", REUSABLE.replace("runs-on: xcode-27", f"runs-on: {label}"))
                code, stdout = self.run_check()
                self.assertEqual(code, 0, stdout)

    def test_読み取り以外の権限があれば失敗し場所が示される(self) -> None:
        text = ENTRY.replace("  contents: read\n", "  contents: read\n  pull-requests: write\n")
        line = text.splitlines().index("  pull-requests: write") + 1
        self.assert_violation(text, line, "workflow: リポジトリの内容の読み取り以外の権限がある: pull-requests: write")

    def test_内容への書き込みの権限があれば失敗する(self) -> None:
        text = ENTRY.replace("  contents: read\n", "  contents: write\n")
        line = text.splitlines().index("  contents: write") + 1
        self.assert_violation(text, line, "contents: write")

    def test_内容以外の読み取りの権限も失敗する(self) -> None:
        self.add("ci.yml", ENTRY.replace("  contents: read\n", "  contents: read\n  actions: read\n"))
        code, stdout = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("actions: read", stdout)

    def test_まとめて与える権限の指定は失敗する(self) -> None:
        for value in ("read-all", "write-all"):
            with self.subTest(value=value):
                self.add("ci.yml", ENTRY.replace("permissions:\n  contents: read\n", f"permissions: {value}\n"))
                code, stdout = self.run_check()
                self.assertEqual(code, 1)
                self.assertIn(f"permissions: {value}", stdout)

    def test_ジョブごとの権限も確かめる(self) -> None:
        text = ENTRY.replace("    timeout-minutes: 10\n", "    timeout-minutes: 10\n    permissions:\n      id-token: write\n")
        line = text.splitlines().index("      id-token: write") + 1
        self.assert_violation(text, line, "ジョブ lint: リポジトリの内容の読み取り以外の権限がある: id-token: write")

    def test_権限の指定が無ければ失敗する(self) -> None:
        self.assert_violation(
            ENTRY.replace("permissions:\n  contents: read\n", ""), 1, "workflow の先頭に permissions の指定が無い"
        )

    def test_権限を与えない指定は通る(self) -> None:
        for permissions in ("permissions: {}\n", "permissions:\n  contents: read\n  packages: none\n"):
            with self.subTest(permissions=permissions):
                self.add("ci.yml", ENTRY.replace("permissions:\n  contents: read\n", permissions))
                code, stdout = self.run_check()
                self.assertEqual(code, 0, stdout)

    def test_時間の上限の無いジョブがあれば失敗しジョブが示される(self) -> None:
        text = ENTRY.replace("    timeout-minutes: 10\n", "")
        line = text.splitlines().index("  lint:") + 1
        self.assert_violation(text, line, "ジョブ lint: 時間の上限 (timeout-minutes) が無い")

    def test_再利用workflowを呼ぶだけのジョブは時間の上限が無くても通る(self) -> None:
        self.assertNotIn("timeout-minutes", ENTRY.split("  lint:")[0])
        self.add("ci.yml", ENTRY)
        code, stdout = self.run_check()
        self.assertEqual(code, 0, stdout)

    def test_時間の上限を持つジョブは値の大小に関わらず通る(self) -> None:
        for minutes in ("1", "40", "360", "100000"):
            with self.subTest(minutes=minutes):
                self.add("ci.yml", REUSABLE.replace("timeout-minutes: 40", f"timeout-minutes: {minutes}"))
                code, stdout = self.run_check()
                self.assertEqual(code, 0, stdout)

    def test_式で書いた時間の上限は失敗する(self) -> None:
        text = REUSABLE.replace("timeout-minutes: 40", "timeout-minutes: ${{ inputs.minutes }}")
        line = text.splitlines().index("    timeout-minutes: ${{ inputs.minutes }}") + 1
        self.assert_violation(text, line, "ジョブ verify: 時間の上限を式で書いているため、上限を確かめられない")

    def test_整数として読み取れない時間の上限は失敗する(self) -> None:
        for value in ("0", "-5", "1.5", "ten", "'40'", "", "\n      minutes: 40"):
            with self.subTest(value=value):
                text = REUSABLE.replace("timeout-minutes: 40", f"timeout-minutes: {value}".rstrip(" "))
                line = [number for number, row in enumerate(text.splitlines(), 1) if "timeout-minutes:" in row][0]
                self.assert_violation(text, line, "ジョブ verify: 時間の上限を 1 以上の整数として読み取れない")

    def test_stepの時間の上限はジョブの上限として扱わない(self) -> None:
        text = REUSABLE.replace("    timeout-minutes: 40\n", "").replace(
            "    - name: Test\n", "    - name: Test\n      timeout-minutes: 5\n"
        )
        self.assert_violation(text, 10, "ジョブ verify: 時間の上限 (timeout-minutes) が無い")

    def test_読み取れない書き方は違反として止める(self) -> None:
        cases = {
            "中身のある波かっこ": ENTRY.replace(
                f"      - name: Checkout\n        uses: actions/checkout@{SHA} # v7.0.1\n",
                "      - {name: Checkout, uses: actions/checkout@v4}\n",
            ),
            "値の波かっこ": ENTRY.replace("permissions:\n  contents: read\n", "permissions: {contents: write}\n"),
            "アンカー": ENTRY.replace("    runs-on: ubuntu-24.04", "    runs-on: &runner ubuntu-latest"),
            "エイリアス": ENTRY.replace("    runs-on: ubuntu-24.04", "    runs-on: *runner"),
            "取り込み": ENTRY.replace("    runs-on: ubuntu-24.04", "    <<: *defaults"),
            "複数行の角かっこ": ENTRY.replace("    runs-on: ubuntu-24.04", "    runs-on: [self-hosted,\n      macos-latest]"),
            "行頭のタブ": ENTRY.replace("    runs-on: ubuntu-24.04", "\truns-on: ubuntu-latest"),
        }
        for name, text in cases.items():
            with self.subTest(name=name):
                self.add("ci.yml", text)
                code, stdout = self.run_check()
                self.assertEqual(code, 1, stdout)
                self.assertIn("読み取れない", stdout)

    def test_ジョブを読み取れない定義は失敗する(self) -> None:
        self.assert_violation("name: CI\non: push\npermissions:\n  contents: read\n", 1, "ジョブを 1 つも読み取れない")

    def test_ランナーも呼び出しも無いジョブは失敗する(self) -> None:
        text = REUSABLE.replace("    runs-on: xcode-27\n", "")
        self.assert_violation(text, 10, "ジョブ verify: runs-on も uses も読み取れない")

    def test_確かめるworkflowが1本も無ければ失敗する(self) -> None:
        code, stdout = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("確かめる workflow が 1 本も無い", stdout)

    def test_ファイルを渡せばそのファイルだけを確かめる(self) -> None:
        good = self.add("verify-ios.yml", REUSABLE)
        self.add("release.yml", ENTRY.replace("  contents: read\n", "  contents: write\n"))
        code, stdout = self.run_check(good)
        self.assertEqual(code, 0, stdout)
        self.assertIn("確かめた workflow: 1 本", stdout)

    def test_渡したファイルが無ければ失敗する(self) -> None:
        code, stdout = self.run_check(os.path.join(self.root, "none.yml"))
        self.assertEqual(code, 1)
        self.assertIn("workflow のファイルを読めない", stdout)

    def test_actionの入力の名前がusesでも外部の指定として扱わない(self) -> None:
        text = REUSABLE.replace(
            "      run: >-\n        xcodebuild test\n", "      run: echo\n      with:\n        uses: something@v1\n"
        )
        self.add("ci.yml", text)
        code, stdout = self.run_check()
        self.assertEqual(code, 0, stdout)


if __name__ == "__main__":
    unittest.main()
