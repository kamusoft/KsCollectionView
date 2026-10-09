"""iOS の利用者の立場のビルドの確認のテスト。

確認のスクリプトは、一時のディレクトリに作った使い捨てのリポジトリの形 (スクリプトの写し・
利用者役のひな形とソース・写しを作る道具) の中で、別のプロセスとして流す。写しを作る道具と
xcodebuild は、呼ばれ方を記録して、決めたとおりに振る舞う偽物に差し替えてある。写しの作成も
ビルドも、実際には走らない。スクリプトの出力は、子プロセスの出力を含めて、プロセスの外から読む。

利用者役の実物 (verification/ios/) については、ひな形とソースの書き方だけを確かめる。
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

SCRIPT_NAME = "verify-consumer-ios.py"
SCRIPT = support.load_script(SCRIPT_NAME)

TARGET_DEPENDENCY = '.product(name: "KsCollectionView", package: "KsCollectionView-SPM")'
LOCAL_DEPENDENCY = '.package(path: "../KsCollectionView-SPM"),'
DISTRIBUTION_URL = "https://github.com/kamusoft/KsCollectionView-SPM"

SIMULATOR = "generic/platform=iOS Simulator"
DEVICE = "generic/platform=iOS"

TEMPLATE_TEXT = f"""\
// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "VerificationApp",
    dependencies: [
        {SCRIPT.DEPENDENCY_PLACEHOLDER}
    ],
    targets: [
        .target(name: "VerificationApp", dependencies: [{TARGET_DEPENDENCY}]),
    ]
)
"""
SOURCE_PATH = os.path.join("Sources", "VerificationApp", "Screen.swift")
SOURCE_TEXT = "import KsCollectionView\n"

# 偽物が共有する前置き。呼ばれ方を calls.jsonl に 1 行ずつ足し、behavior.json に従って振る舞う。
#
# behavior.json は、種類 (snapshot / simulator / device) ごとに次を持てる。
#   exit            終了コード (既定 0)
#   stdout / stderr 出す文字 (既定は、種類ごとの決まった 1 行)
#   skip_outputs    真なら、成功したときに作るはずのファイル (写しのマニフェスト) を作らない
FAKE_PREAMBLE = r'''#!/usr/bin/env python3
import json
import os
import sys

root = os.path.dirname(os.path.abspath(__file__))
while not os.path.isfile(os.path.join(root, "behavior.json")):
    root = os.path.dirname(root)

arguments = sys.argv[1:]
with open(os.path.join(root, "behavior.json"), encoding="utf-8") as f:
    behavior = json.load(f)


def record(call):
    with open(os.path.join(root, "calls.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps(call) + "\n")


def finish(kind, default_stdout):
    settings = behavior.get(kind, {})
    sys.stdout.write(settings.get("stdout", default_stdout))
    sys.stdout.flush()
    sys.stderr.write(settings.get("stderr", ""))
    sys.stderr.flush()
    return settings.get("exit", 0), bool(settings.get("skip_outputs"))
'''

# 写しを作る道具の偽物。成功したら、行き先に写しのマニフェストを置く。
FAKE_SNAPSHOT_TOOL = FAKE_PREAMBLE + r'''
destination = arguments[0]
record({"tool": "snapshot", "cwd": os.getcwd(), "arguments": arguments, "existed": os.path.lexists(destination)})
code, skip_outputs = finish("snapshot", "写しを作った: " + destination + "\n")
if code == 0 and not skip_outputs:
    os.makedirs(destination)
    with open(os.path.join(destination, "Package.swift"), "w", encoding="utf-8") as f:
        f.write("// swift-tools-version: 6.4\n")
sys.exit(code)
'''

# xcodebuild の偽物。呼ばれた時点の作業ディレクトリの中身 (マニフェスト・ソース・隣の写し) も記録する。
FAKE_XCODEBUILD = FAKE_PREAMBLE + r'''
cwd = os.getcwd()
manifest = None
if os.path.isfile("Package.swift"):
    with open("Package.swift", encoding="utf-8") as f:
        manifest = f.read()
files = sorted(
    os.path.relpath(os.path.join(current, name), cwd) for current, _, names in os.walk(cwd) for name in names
)
record(
    {
        "tool": "xcodebuild",
        "cwd": cwd,
        "arguments": arguments,
        "manifest": manifest,
        "files": files,
        "siblings": sorted(os.listdir(os.path.dirname(cwd))),
        "snapshot_manifest": os.path.isfile(os.path.join(cwd, "..", "KsCollectionView-SPM", "Package.swift")),
    }
)
destination = arguments[arguments.index("-destination") + 1] if "-destination" in arguments else ""
kind = "simulator" if "Simulator" in destination else "device"
code, _ = finish(kind, "** BUILD SUCCEEDED ** (" + destination + ")\n")
sys.exit(code)
'''


def option_value(arguments: list[str], name: str) -> str | None:
    return arguments[arguments.index(name) + 1] if name in arguments else None


def without_comments(text: str) -> str:
    """Swift の行のコメントを除いて返す (説明の中の語を拾わないため)。"""
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("//"))


def tree(directory: str, skip: tuple[str, ...] = ()) -> dict[str, bytes]:
    """directory の下のファイルを、相対パス → 内容 の対応で返す。"""
    entries: dict[str, bytes] = {}
    for current, _, names in os.walk(directory):
        for name in names:
            path = os.path.join(current, name)
            relative = os.path.relpath(path, directory)
            if relative in skip:
                continue
            with open(path, "rb") as f:
                entries[relative] = f.read()
    return entries


class ConsumerVerificationTestCase(unittest.TestCase):
    """使い捨てのリポジトリの形を作り、その中の確認のスクリプトを別のプロセスで流す。"""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = os.path.realpath(directory.name)
        for name in (SCRIPT_NAME, "ci_report.py"):
            os.makedirs(os.path.join(self.root, "scripts", "ci"), exist_ok=True)
            shutil.copy(support.script_path(name), os.path.join(self.root, "scripts", "ci", name))
        support.write(os.path.join(self.root, SCRIPT.MANIFEST_TEMPLATE), TEMPLATE_TEXT)
        support.write(os.path.join(self.root, SCRIPT.CONSUMER, SOURCE_PATH), SOURCE_TEXT)
        support.write(os.path.join(self.root, SCRIPT.SNAPSHOT_TOOL), FAKE_SNAPSHOT_TOOL)
        self.bin = os.path.join(self.root, "bin")
        os.chmod(support.write(os.path.join(self.bin, "xcodebuild"), FAKE_XCODEBUILD), 0o755)
        self.behave({})

    def behave(self, behavior: dict) -> None:
        support.write(os.path.join(self.root, "behavior.json"), json.dumps(behavior))

    def run_script(self, *arguments: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        environment = {
            key: value for key, value in os.environ.items() if not key.startswith(("GITHUB_", "KS_"))
        }
        # 子プロセスの出力の文字コードを、流す環境のロケールに左右させない。
        environment["PYTHONIOENCODING"] = "utf-8"
        # xcodebuild は、偽物が先に見つかるようにする。本物は呼ばれない。
        environment["PATH"] = self.bin + os.pathsep + environment.get("PATH", "")
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

    def tools(self) -> list[str]:
        """呼ばれた順の、道具の種類 (写しは snapshot、ビルドは行き先の指定)。"""
        return [
            "snapshot" if call["tool"] == "snapshot" else option_value(call["arguments"], "-destination")
            for call in self.calls()
        ]

    def builds(self) -> list[dict]:
        return [call for call in self.calls() if call["tool"] == "xcodebuild"]


class LocalModeTests(ConsumerVerificationTestCase):
    def test_写しを作ってからSimulator向けと実機向けの順にビルドする(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.tools(), ["snapshot", SIMULATOR, DEVICE])

    def test_写しはpackageの名前のまだ無いディレクトリに作る(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        snapshot = self.calls()[0]
        self.assertEqual(len(snapshot["arguments"]), 1)
        destination = snapshot["arguments"][0]
        self.assertTrue(os.path.isabs(destination), destination)
        # SwiftPM は、参照先の末尾の名前を package の名前として扱う。
        self.assertEqual(os.path.basename(destination), "KsCollectionView-SPM")
        # 写しを作る道具は、中身のある行き先を拒む。毎回、まだ無いパスを渡す。
        self.assertFalse(snapshot["existed"])
        # 行き先は、リポジトリの外にある。
        self.assertNotEqual(os.path.commonpath([self.root, destination]), self.root)
        # 写しを作る道具は、リポジトリの中のものを呼ぶ。
        self.assertEqual(os.path.realpath(snapshot["cwd"]), self.root)

    def test_利用者役は写しをパスで参照する(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        snapshot_directory = self.calls()[0]["arguments"][0]
        for build in self.builds():
            self.assertIn(LOCAL_DEPENDENCY, build["manifest"])
            self.assertNotIn(SCRIPT.DEPENDENCY_PLACEHOLDER, build["manifest"])
            self.assertNotIn(".package(url:", build["manifest"])
            # 相対のパスの指す先が、作った写しである。
            self.assertEqual(
                os.path.realpath(os.path.join(build["cwd"], "..", "KsCollectionView-SPM")), snapshot_directory
            )
            self.assertTrue(build["snapshot_manifest"])

    def test_targetの依存はpackageの名前とproductを指す(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for build in self.builds():
            self.assertIn(TARGET_DEPENDENCY, build["manifest"])

    def test_利用者役の写しをリポジトリの外でビルドする(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for build in self.builds():
            self.assertNotEqual(os.path.commonpath([self.root, build["cwd"]]), self.root)
            self.assertEqual(build["files"], ["Package.swift", SOURCE_PATH])
            # ひな形は、写した先に持ち込まない (SwiftPM が読むのは Package.swift だけである)。
            self.assertEqual(build["siblings"], ["KsCollectionView-SPM", "consumer"])

    def test_どちらの行き先もリリースの構成でビルドする(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        simulator, device = self.builds()
        for build in (simulator, device):
            arguments = build["arguments"]
            self.assertEqual(arguments[0], "build")
            self.assertEqual(option_value(arguments, "-scheme"), "VerificationApp")
            self.assertEqual(option_value(arguments, "-configuration"), "Release")
            # ビルドの出力は、利用者役の写しの隣 (一時のディレクトリの中) に置く。
            self.assertEqual(
                option_value(arguments, "-derivedDataPath"),
                os.path.join(os.path.dirname(build["cwd"]), "DerivedData"),
            )
        self.assertEqual(option_value(simulator["arguments"], "-destination"), SIMULATOR)
        self.assertEqual(option_value(device["arguments"], "-destination"), DEVICE)
        # 実機向けは、署名なしでビルドする。
        self.assertIn("CODE_SIGNING_ALLOWED=NO", device["arguments"])
        self.assertNotIn("CODE_SIGNING_ALLOWED=NO", simulator["arguments"])

    def test_Simulatorを選ばずテストも走らせない(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for build in self.builds():
            words = " ".join(build["arguments"])
            for word in ("name=", "id=", "OS=", "simctl", "test"):
                with self.subTest(word=word):
                    self.assertNotIn(word, words)

    def test_リポジトリの中を何も変えない(self) -> None:
        # 偽物が書く呼ばれ方の記録だけは、確認の外のものとして除く。
        before = tree(self.root, skip=("calls.jsonl",))
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(tree(self.root, skip=("calls.jsonl",)), before)

    def test_作業用のディレクトリを残さない(self) -> None:
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        work = os.path.dirname(self.builds()[0]["cwd"])
        self.assertFalse(os.path.exists(work))

    def test_失敗しても作業用のディレクトリを残さない(self) -> None:
        self.behave({"device": {"exit": 65}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertFalse(os.path.exists(os.path.dirname(self.builds()[0]["cwd"])))

    def test_localでは渡された版を使わない(self) -> None:
        for version in ("1.2.3", ""):
            with self.subTest(version=version):
                result = self.run_script("--mode", "local", "--version", version)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                for build in self.builds():
                    self.assertIn(LOCAL_DEPENDENCY, build["manifest"])
                    self.assertNotIn("exact:", build["manifest"])

    def test_概要に確かめた内容が出る(self) -> None:
        summary = os.path.join(self.root, "summary.md")
        result = self.run_script("--mode", "local", env={"GITHUB_STEP_SUMMARY": summary})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with open(summary, encoding="utf-8") as f:
            text = f.read()
        self.assertIn("`local`", text)
        self.assertIn(f"`{LOCAL_DEPENDENCY}`", text)
        self.assertIn(f"`{SIMULATOR}`", text)
        self.assertIn(f"`{DEVICE}`", text)


class PublishedModeTests(ConsumerVerificationTestCase):
    def test_publishedでは写しを作らずに同じ2つのビルドを始める(self) -> None:
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.tools(), [SIMULATOR, DEVICE])
        for build in self.builds():
            # 写しのディレクトリは、作られていない。
            self.assertEqual(build["siblings"], ["consumer"])
            self.assertFalse(build["snapshot_manifest"])

    def test_利用者役は配信用リポジトリを版の完全一致で参照する(self) -> None:
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for build in self.builds():
            self.assertIn(f'.package(url: "{DISTRIBUTION_URL}", exact: "1.2.3"),', build["manifest"])
            self.assertNotIn(".package(path:", build["manifest"])
            self.assertNotIn(SCRIPT.DEPENDENCY_PLACEHOLDER, build["manifest"])
            self.assertIn(TARGET_DEPENDENCY, build["manifest"])

    def test_ビルドは切り替えによって変わらない(self) -> None:
        def normalized(build: dict) -> list[str]:
            # 一時のディレクトリの名前だけが、流すたびに変わる。
            return [argument.replace(os.path.dirname(build["cwd"]), "<work>") for argument in build["arguments"]]

        self.assertEqual(self.run_script("--mode", "local").returncode, 0)
        local_builds = [normalized(build) for build in self.builds()]
        os.remove(os.path.join(self.root, "calls.jsonl"))
        self.assertEqual(self.run_script("--mode", "published", "--version", "1.2.3").returncode, 0)
        self.assertEqual([normalized(build) for build in self.builds()], local_builds)

    def test_publishedでも成功の条件は同じである(self) -> None:
        for kind in ("simulator", "device"):
            with self.subTest(kind=kind):
                self.behave({kind: {"exit": 65}})
                result = self.run_script("--mode", "published", "--version", "1.2.3")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_概要に版が出る(self) -> None:
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("`published`", result.stdout)
        self.assertIn('exact: "1.2.3"', result.stdout)


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
        for version in ('1.0", branch: "main', "1.0\\", "-1.0", "../1.0", "1.0 2"):
            for mode in SCRIPT.MODES:
                with self.subTest(version=version, mode=mode):
                    self.assert_nothing_started(
                        self.run_script("--mode", mode, f"--version={version}"), "使えない文字"
                    )

    def test_引数の誤りは注釈として出る(self) -> None:
        result = self.run_script("--mode", "dry-run")
        self.assertIn("::error::--mode は local か published", result.stdout)


class FailureTests(ConsumerVerificationTestCase):
    def test_写しの作成の失敗は本文が出てビルドの前に止まる(self) -> None:
        self.behave(
            {
                "snapshot": {
                    "exit": 1,
                    "stdout": "",
                    "stderr": "エラー: 写しの元が欠けている: ios/Sources/ (git が追跡しているファイルが 1 つも無い)\n",
                }
            }
        )
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        # 準備のコマンドが出した失敗の本文が、そのまま出ている。
        self.assertIn(
            "エラー: 写しの元が欠けている: ios/Sources/ (git が追跡しているファイルが 1 つも無い)\n", result.stderr
        )
        self.assertIn("::error::写しの作成が失敗した", result.stdout)
        # 利用者役のビルドは始まらない。
        self.assertEqual(self.tools(), ["snapshot"])

    def test_写しにマニフェストが無ければビルドの前に止まる(self) -> None:
        self.behave({"snapshot": {"skip_outputs": True}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("写しにマニフェスト (Package.swift) が無い", result.stdout)
        self.assertEqual(self.tools(), ["snapshot"])

    def test_写しを作る道具が無ければビルドの前に止まる(self) -> None:
        os.remove(os.path.join(self.root, SCRIPT.SNAPSHOT_TOOL))
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::写しの作成が失敗した", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_Simulator向けのビルドの失敗は本文が出て実機向けの前に止まる(self) -> None:
        self.behave(
            {
                "simulator": {
                    "exit": 65,
                    "stdout": "VerificationListScreen.swift:1:8: error: no such module 'KsCollectionView'\n",
                    "stderr": "** BUILD FAILED **\n",
                }
            }
        )
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("VerificationListScreen.swift:1:8: error: no such module 'KsCollectionView'\n", result.stdout)
        self.assertIn("** BUILD FAILED **\n", result.stderr)
        self.assertIn("::error::利用者役のビルドが失敗した: Simulator 向け (xcodebuild の終了コード 65)", result.stdout)
        self.assertEqual(self.tools(), ["snapshot", SIMULATOR])

    def test_実機向けのビルドだけが失敗しても失敗する(self) -> None:
        self.behave({"device": {"exit": 65, "stderr": "** BUILD FAILED **\n"}})
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        # Simulator 向けは成功している。
        self.assertIn(f"** BUILD SUCCEEDED ** ({SIMULATOR})\n", result.stdout)
        self.assertIn("::error::利用者役のビルドが失敗した: 実機向け (xcodebuild の終了コード 65)", result.stdout)
        self.assertEqual(self.tools(), ["snapshot", SIMULATOR, DEVICE])
        # 成功の概要は出ない。
        self.assertNotIn("### iOS の利用者の立場のビルドの確認", result.stdout)

    def test_xcodebuildが無ければ失敗する(self) -> None:
        empty = os.path.join(self.root, "empty-bin")
        os.makedirs(empty)
        result = self.run_script("--mode", "published", "--version", "1.2.3", env={"PATH": empty})
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("xcodebuild を実行できない", result.stdout)

    def test_ひな形の差し込み口がちょうど1つでなければビルドの前に止まる(self) -> None:
        placeholder = SCRIPT.DEPENDENCY_PLACEHOLDER
        for text in (TEMPLATE_TEXT.replace(placeholder, ""), TEMPLATE_TEXT + f"// {placeholder}\n"):
            with self.subTest(count=text.count(placeholder)):
                support.write(os.path.join(self.root, SCRIPT.MANIFEST_TEMPLATE), text)
                result = self.run_script("--mode", "published", "--version", "1.2.3")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("ちょうど 1 つ無い", result.stdout)
                self.assertEqual(self.calls(), [])

    def test_利用者役のファイルが無ければビルドの前に止まる(self) -> None:
        for path in (SCRIPT.MANIFEST_TEMPLATE, SCRIPT.CONSUMER_SOURCES):
            with self.subTest(path=path):
                target = os.path.join(self.root, path)
                os.rename(target, target + ".moved")
                try:
                    result = self.run_script("--mode", "published", "--version", "1.2.3")
                finally:
                    os.rename(target + ".moved", target)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("利用者役を作業用のディレクトリに写せない", result.stdout)
                self.assertEqual(self.calls(), [])


class OutputTests(ConsumerVerificationTestCase):
    def test_子プロセスの出力をそのままの内容と順序で流す(self) -> None:
        snapshot = "写しを作った: <行き先> (Sources 93 ファイル / Tests 45 ファイル)\n\n  字下げと\t空行を含む 出力 \n"
        simulator = "CompileSwift normal arm64 (in target 'KsCollectionView')\n** BUILD SUCCEEDED ** [Simulator]\n"
        device = "note: 署名なし\n** BUILD SUCCEEDED ** [実機]\n"
        self.behave(
            {"snapshot": {"stdout": snapshot}, "simulator": {"stdout": simulator}, "device": {"stdout": device}}
        )
        result = self.run_script("--mode", "local")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        positions = [result.stdout.find(text) for text in (snapshot, simulator, device)]
        self.assertNotIn(-1, positions, result.stdout)
        self.assertEqual(positions, sorted(positions))
        # 概要は、子プロセスの出力の後に出る。
        self.assertGreater(result.stdout.find("### iOS の利用者の立場のビルドの確認"), positions[-1])

    def test_配布物への参照をビルドの前に出す(self) -> None:
        result = self.run_script("--mode", "published", "--version", "1.2.3")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        reference = result.stdout.find(f'配布物への参照: .package(url: "{DISTRIBUTION_URL}", exact: "1.2.3"),')
        self.assertNotEqual(reference, -1, result.stdout)
        self.assertLess(reference, result.stdout.find("** BUILD SUCCEEDED **"))


class ManifestTests(unittest.TestCase):
    def test_localは写しのディレクトリをパスで参照する(self) -> None:
        self.assertEqual(SCRIPT.dependency_line(SCRIPT.Request(mode="local", version=None)), LOCAL_DEPENDENCY)
        # local では、版を渡しても参照は変わらない。
        self.assertEqual(SCRIPT.dependency_line(SCRIPT.Request(mode="local", version="1.2.3")), LOCAL_DEPENDENCY)

    def test_publishedは配信用リポジトリを版の完全一致で参照する(self) -> None:
        self.assertEqual(
            SCRIPT.dependency_line(SCRIPT.Request(mode="published", version="2.0.0-rc.1")),
            f'.package(url: "{DISTRIBUTION_URL}", exact: "2.0.0-rc.1"),',
        )

    def test_差し込み口だけを置き換える(self) -> None:
        rendered = SCRIPT.render_manifest(TEMPLATE_TEXT, LOCAL_DEPENDENCY)
        self.assertEqual(rendered, TEMPLATE_TEXT.replace(SCRIPT.DEPENDENCY_PLACEHOLDER, LOCAL_DEPENDENCY))

    def test_差し込み口がちょうど1つでないひな形を拒否する(self) -> None:
        for text in ("let package = Package()\n", TEMPLATE_TEXT * 2):
            with self.subTest(count=text.count(SCRIPT.DEPENDENCY_PLACEHOLDER)):
                with self.assertRaises(SCRIPT.VerificationError):
                    SCRIPT.render_manifest(text, LOCAL_DEPENDENCY)

    def test_行き先は端末を決めないSimulator向けと実機向けである(self) -> None:
        self.assertEqual([destination.specifier for destination in SCRIPT.DESTINATIONS], [SIMULATOR, DEVICE])


class ConsumerDefinitionTests(unittest.TestCase):
    """利用者役の実物が、利用者と同じ書き方で配布物を参照していること。"""

    def setUp(self) -> None:
        with open(os.path.join(support.REPOSITORY_ROOT, SCRIPT.MANIFEST_TEMPLATE), encoding="utf-8") as f:
            self.template = f.read()
        self.manifests = {
            "local": SCRIPT.render_manifest(
                self.template, SCRIPT.dependency_line(SCRIPT.Request(mode="local", version=None))
            ),
            "published": SCRIPT.render_manifest(
                self.template, SCRIPT.dependency_line(SCRIPT.Request(mode="published", version="1.2.3"))
            ),
        }

    def target_dependencies(self, manifest: str) -> list[str]:
        """マニフェストの target の依存の宣言を、1 つずつ取り出す。"""
        pattern = r"\.target\(\s*name: \"[^\"]+\",\s*dependencies: \[(.*?)\]\s*\)"
        found = re.findall(pattern, without_comments(manifest), re.DOTALL)
        self.assertEqual(len(found), 1, manifest)
        return [line.strip().rstrip(",") for line in found[0].splitlines() if line.strip()]

    def test_差し込み口は依存の宣言の中にありコメントの中に無い(self) -> None:
        self.assertEqual(self.template.count(SCRIPT.DEPENDENCY_PLACEHOLDER), 1)
        self.assertRegex(
            without_comments(self.template),
            r"dependencies: \[\s*" + re.escape(SCRIPT.DEPENDENCY_PLACEHOLDER) + r"\s*\],\s*targets: \[",
        )

    def test_targetはpackageの名前でproductに依存する(self) -> None:
        for mode, manifest in self.manifests.items():
            with self.subTest(mode=mode):
                # 本ライブラリへの依存は、利用者が書くのと同じ 1 行だけである。
                self.assertEqual(self.target_dependencies(manifest), [TARGET_DEPENDENCY])

    def test_localはpackageの名前のディレクトリをパスで参照する(self) -> None:
        packages = re.findall(r"\.package\(.*\)", without_comments(self.manifests["local"]))
        self.assertEqual(packages, ['.package(path: "../KsCollectionView-SPM")'])

    def test_publishedは配信用リポジトリを版の完全一致で参照する(self) -> None:
        packages = re.findall(r"\.package\(.*\)", without_comments(self.manifests["published"]))
        self.assertEqual(packages, [f'.package(url: "{DISTRIBUTION_URL}", exact: "1.2.3")'])

    def test_本体のソースを参照しない(self) -> None:
        for mode, manifest in self.manifests.items():
            with self.subTest(mode=mode):
                body = without_comments(manifest)
                # 本体のビルドルート (ios/) を指す書き方が無い。
                self.assertIsNone(re.search(r'path:\s*"[^"]*\bios\b', body))
                self.assertNotIn("../..", body)
                # ソースの場所は既定のまま (利用者役の Sources/ の下だけ) である。
                for word in ("sources:", "exclude:", "unsafeFlags", "binaryTarget"):
                    self.assertNotIn(word, body)

    def test_packageの名前が写しを作る道具の配信用リポジトリと合う(self) -> None:
        tool = support.load_script(
            os.path.basename(SCRIPT.SNAPSHOT_TOOL),
            os.path.join(support.REPOSITORY_ROOT, os.path.dirname(SCRIPT.SNAPSHOT_TOOL)),
        )
        self.assertEqual(tool.DISTRIBUTION_REPOSITORY, f"kamusoft/{SCRIPT.PACKAGE_NAME}")
        self.assertEqual(SCRIPT.DISTRIBUTION_URL, f"https://github.com/{tool.DISTRIBUTION_REPOSITORY}")

    def test_利用者役が指すproductを本体が宣言している(self) -> None:
        with open(os.path.join(support.REPOSITORY_ROOT, "ios", "Package.swift"), encoding="utf-8") as f:
            library = f.read()
        self.assertIn(f'.library(name: "{SCRIPT.PRODUCT_NAME}"', library)

    def test_スクリプトがビルドするschemeを利用者役が宣言している(self) -> None:
        body = without_comments(self.template)
        self.assertIn(f'name: "{SCRIPT.SCHEME}"', body)
        self.assertIn(f'.library(name: "{SCRIPT.SCHEME}", targets: ["{SCRIPT.SCHEME}"])', body)
        self.assertTrue(
            os.path.isdir(os.path.join(support.REPOSITORY_ROOT, SCRIPT.CONSUMER_SOURCES, SCRIPT.SCHEME))
        )

    def test_利用者役のソースは本ライブラリをモジュールとして使う(self) -> None:
        sources = os.path.join(support.REPOSITORY_ROOT, SCRIPT.CONSUMER_SOURCES)
        imports: set[str] = set()
        swift_files = []
        for current, _, names in os.walk(sources):
            for name in names:
                if not name.endswith(".swift"):
                    continue
                swift_files.append(name)
                with open(os.path.join(current, name), encoding="utf-8") as f:
                    text = without_comments(f.read())
                imports.update(re.findall(r"(?m)^(?:@testable )?import (\S+)$", text))
                self.assertNotIn("@testable", text)
        self.assertTrue(swift_files)
        # 一覧を表示する利用例が、本ライブラリのモジュールを使っている。
        self.assertEqual(imports, {"KsCollectionView", "SwiftUI"})

    def test_利用者役のディレクトリはそのままではpackageではない(self) -> None:
        # マニフェストは、作業用のディレクトリにだけ書く。ここに置くと、確認が追跡しているファイルを変える形になる。
        consumer = os.path.join(support.REPOSITORY_ROOT, SCRIPT.CONSUMER)
        self.assertFalse(os.path.exists(os.path.join(consumer, "Package.swift")))
        entries = sorted(name for name in os.listdir(consumer) if not name.startswith("."))
        self.assertEqual(entries, ["Package.swift.template", "Sources"])


if __name__ == "__main__":
    unittest.main()
