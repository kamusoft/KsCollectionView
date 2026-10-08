#!/usr/bin/env python3
"""Android のテストの実行件数を、Gradle が作る結果のファイルから確かめる。

テストが 1 件も実行されなくても Gradle は成功で終わり、件数はコンソールに出ない。
このスクリプトは、渡された「モジュールとタスクの組」ごとに結果のファイル (TEST-*.xml) を集計し、
スキップを除いた実行が 1 件以上あることと、テストのソースにあるテストのクラスが
すべて結果に現れていることを確かめる (cross/ADR-0013)。

使い方:
  python3 scripts/ci/check-android-test-count.py \\
      --target "<対象の名前>=<モジュールのディレクトリ>:<タスクの名前>" [--target ...] \\
      [--stale-before <目印のファイル>]

  --target        確かめる組。1 つ以上を明示して渡す (自動では導かない)。
                  モジュールのディレクトリは、作業ディレクトリからの相対パス。例:
                    --target "Android 本体=android/kscollectionview:testDebugUnitTest"
                    --target "Android Sample=samples/android/app:testDebugUnitTest"
  --stale-before  このファイルより更新の時刻が古い結果のファイルを、前の実行の残りとして数えない。
                  テストを始める直前に作った目印のファイルを渡す。省くと、置き場にある結果をすべて数える
                  (その場合は、テストの前に置き場を空にしておく)

  読む場所 (モジュールのディレクトリを基準にする):
    結果      build/test-results/<タスクの名前>/TEST-*.xml
              (ディレクトリの名前は、ビルドの種類の名前ではなくタスクの名前)
    ソース    src/test と、タスクの名前から決まる src/test<種類> (testDebugUnitTest なら src/testDebug)

終了コード:
  0  すべての組が通った
  1  どれかの組で次のいずれかに当たった:
     結果のファイルが無い / 結果のファイルを読めない / 実行が 0 件 / 全件がスキップ /
     テストのクラスを 1 つも導けない / 属するクラスを導けない @Test がある /
     結果に現れないテストのクラスがある
  2  引数の誤り

テストのクラスの導き方:
  ソース (*.kt / *.java) のうち、行頭から始まるクラスの宣言で、その中に @Test の印を持つものを
  テストのクラスとする。abstract なクラスは結果に現れないので数えない。
  宣言の前に同じ行で注釈や修飾子が付く形と、バッククォートで囲んだ名前も宣言として読む。
  クラスの中に入れ子で書いたテストのクラスは、外側のクラスのものとして扱う
  (本リポジトリには無い書き方。使うと、外側のクラスが結果に現れないとして失敗する)。

  @Test の印は、行のどこにあっても拾う (ほかの注釈の後ろ、クラスの宣言と同じ行、行頭)。
  印の属するクラスは、同じ行で印より前に宣言があればそのクラス、無ければ直前に読んだ
  行頭の宣言のクラスとする。

  Kotlin の構文を解析しているわけではない。属するクラスを決められない印は、黙って捨てずに
  「属するクラスを導けない @Test」として失敗にする。決められないのは次の形:
    - クラスの宣言として読めない行頭の行 (行頭の関数・プロパティなど) の後ろにある印。
      クラスの中身を字下げしない書き方では、クラスの 2 つ目より後ろの印がこれに当たる
  コメントや文字列の中の @Test も印として拾う。そのため、テストを持たないクラスが
  テストのクラスに数えられたり、属するクラスを導けないとして失敗したりすることがある
  (黙って通る側には倒れない)。

  拾えない形 (そのクラスが結果に無くても失敗にならない):
    - @Test・@ParameterizedTest 以外の印 (@TestFactory など) だけを持つクラス
    - 印を自分では持たず、親のクラスから受け継いだテストだけを持つクラス

  テストの失敗の有無はここでは合否にしない (Gradle の終了コードが決める)。
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ci_report  # noqa: E402

TASK_VARIANT = re.compile(r"^test(.+)UnitTest$")
PACKAGE = re.compile(r"^package\s+([\w.]+)")
# 行頭から始まる行のうち、宣言・注釈になりうるもの (閉じかっこ・コメント・空行は当たらない)。
TOP_LEVEL_LINE = re.compile(r"^[A-Za-z_@`]")
# 宣言のキーワードと名前。`X::class` や Java の `@interface` はキーワードとして読まない。
DECLARATION = re.compile(r"(?<![\w:.@])(?P<kind>class|object|interface)\s+(?P<name>`[^`]+`|\w+)")
# キーワードの直前に並ぶ修飾子 (注釈のかっこの中の語は含めない)。
TRAILING_MODIFIERS = re.compile(r"((?:\w+\s+)*)$")
# テストの印。行のどこにあっても拾う (@TestFactory のように名前が続くものは当たらない)。
TEST_ANNOTATION = re.compile(r"@(?:[\w.]+\.)?(?:Test|ParameterizedTest)\b")


@dataclass
class ClassResult:
    """結果のファイル 1 つ分 (テストのクラス 1 つ分) の件数。"""

    name: str
    tests: int
    skipped: int
    failed: int

    @property
    def executed(self) -> int:
        return self.tests - self.skipped


@dataclass
class TargetReport:
    """組 1 つ分の集計。"""

    label: str
    result_dir: str
    classes: list[ClassResult] = field(default_factory=list)
    stale: list[str] = field(default_factory=list)
    expected: set[str] = field(default_factory=set)
    reasons: list[str] = field(default_factory=list)

    @property
    def tests(self) -> int:
        return sum(result.tests for result in self.classes)

    @property
    def skipped(self) -> int:
        return sum(result.skipped for result in self.classes)

    @property
    def executed(self) -> int:
        return self.tests - self.skipped

    @property
    def failed(self) -> int:
        return sum(result.failed for result in self.classes)


def parse_target(value: str) -> tuple[str, str, str]:
    """`名前=ディレクトリ:タスク` を (名前, ディレクトリ, タスク) に分ける。"""
    label, separator, rest = value.partition("=")
    module_dir, colon, task = rest.rpartition(":")
    if not separator or not colon or not label.strip() or not module_dir or not task:
        raise argparse.ArgumentTypeError(
            f"--target は「名前=モジュールのディレクトリ:タスクの名前」の形で渡す: {value}"
        )
    return label.strip(), module_dir, task


def source_dirs(module_dir: str, task: str) -> list[str]:
    """タスクが対象にするテストのソースの置き場のうち、実在するものを返す。"""
    names = ["test"]
    matched = TASK_VARIANT.match(task)
    if matched:
        names.append("test" + matched.group(1))
    found = []
    for name in names:
        path = os.path.join(module_dir, "src", name)
        if os.path.isdir(path):
            found.append(path)
    return found


# 結果に現れない宣言 (abstract なクラス・interface・object) の中にいることを表す印。
NOT_RUNNABLE = object()


def declared_owner(line: str, declaration: re.Match[str]) -> object:
    """宣言 1 つから、その中の @Test が属する先 (クラスの名前 / NOT_RUNNABLE) を決める。"""
    modifiers = TRAILING_MODIFIERS.search(line[: declaration.start()]).group(1).split()
    runnable = declaration.group("kind") == "class" and "abstract" not in modifiers
    return declaration.group("name").strip("`") if runnable else NOT_RUNNABLE


def test_classes_in_source(text: str) -> tuple[set[str], list[int]]:
    """ソース 1 ファイルから、テストのクラスの完全な名前の集合を導く。

    属するクラスを導けなかった @Test の行番号も返す。
    """
    package = ""
    # 直前に読んだ行頭の行が表す宣言。
    # クラスの名前 / NOT_RUNNABLE / None (宣言の外、または宣言として読めない行頭の行の後ろ)。
    current: object = None
    found: set[str] = set()
    orphans: list[int] = []
    for number, line in enumerate(text.splitlines(), start=1):
        package_match = PACKAGE.match(line)
        if package_match:
            package = package_match.group(1)
            continue
        top_level = TOP_LEVEL_LINE.match(line) is not None
        # 宣言を読むのは行頭から始まる行だけ (字下げした行の宣言は、外側のクラスのものとして扱う)。
        declared = [(m.start(), declared_owner(line, m)) for m in DECLARATION.finditer(line)] if top_level else []
        for annotation in TEST_ANNOTATION.finditer(line):
            # 同じ行で印より前に宣言があればそのクラス、無ければ直前の行頭の宣言のクラス。
            owner = current
            for start, candidate in declared:
                if start < annotation.start():
                    owner = candidate
            if owner is None:
                if number not in orphans:
                    orphans.append(number)
            elif owner is not NOT_RUNNABLE:
                found.add(f"{package}.{owner}" if package else str(owner))
        if top_level:
            # 宣言として読めない行は、直前のクラスを引き継がない
            # (読み落とした宣言の中の @Test を、直前のクラスのものとして数えない)。
            current = declared[-1][1] if declared else None
    return found, orphans


def expected_classes(directories: list[str]) -> tuple[set[str], list[str]]:
    """テストのソースの置き場から、テストのクラスの集合を導く。

    属するクラスを導けなかった @Test の場所 (`ファイル:行`) も返す。
    """
    expected: set[str] = set()
    orphans: list[str] = []
    for directory in directories:
        for root, _, files in sorted(os.walk(directory)):
            for name in sorted(files):
                if not name.endswith((".kt", ".java")):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding="utf-8", errors="replace") as f:
                    found, lines = test_classes_in_source(f.read())
                expected |= found
                orphans += [f"{path}:{line}" for line in lines]
    return expected, orphans


def read_result(path: str) -> list[ClassResult]:
    """結果のファイル 1 つを読む。読めないときは ValueError を投げる。"""
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as error:
        raise ValueError(str(error)) from error
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
    if not suites:
        raise ValueError("testsuite の要素が無い")
    results = []
    for suite in suites:
        try:
            results.append(
                ClassResult(
                    name=suite.get("name", ""),
                    tests=int(suite.get("tests", "")),
                    skipped=int(suite.get("skipped", "0")),
                    failed=int(suite.get("failures", "0")) + int(suite.get("errors", "0")),
                )
            )
        except ValueError as error:
            raise ValueError(f"件数の属性を数として読めない: {error}") from error
    return results


def inspect(label: str, module_dir: str, task: str, stale_before: float | None) -> TargetReport:
    """組 1 つを集計して、失敗の理由を付ける。"""
    result_dir = os.path.join(module_dir, "build", "test-results", task)
    report = TargetReport(label=label, result_dir=result_dir)

    for path in sorted(glob.glob(os.path.join(glob.escape(result_dir), "TEST-*.xml"))):
        if stale_before is not None and os.path.getmtime(path) < stale_before:
            report.stale.append(os.path.basename(path))
            continue
        try:
            report.classes.extend(read_result(path))
        except ValueError as error:
            report.reasons.append(f"{label}: 結果のファイルを読めない ({path}: {error})")

    directories = source_dirs(module_dir, task)
    report.expected, orphans = expected_classes(directories)
    if orphans:
        # 期待の集合が、読み落としたクラスの分だけ黙って縮むのを防ぐ。
        report.reasons.append(
            f"{label}: テストのソースに、属するクラスを導けない @Test がある"
            f" (クラスの宣言の書き方を読み取れていない): {', '.join(orphans)}"
        )

    if not report.classes and not report.reasons:
        note = f" (前の実行の残りとして数えなかったファイル: {len(report.stale)} 件)" if report.stale else ""
        report.reasons.append(f"{label}: {result_dir} にテストの結果のファイルが無い{note}")
    elif report.classes:
        if report.tests == 0:
            report.reasons.append(f"{label}: テストが 1 件も実行されていない (実行 0 件)")
        elif report.executed <= 0:
            report.reasons.append(
                f"{label}: スキップを除くと実行が 0 件である"
                f" (集計 {report.tests} 件のうちスキップ {report.skipped} 件)"
            )

    if not report.expected:
        where = ", ".join(directories) if directories else f"{os.path.join(module_dir, 'src')} の下にテストのソースの置き場が無い"
        report.reasons.append(f"{label}: テストのソースからテストのクラスを 1 つも導けなかった ({where})")
    elif report.classes:
        # 結果が 1 つも無いときは、その理由だけを示す (全クラスを並べても情報が増えない)。
        present = {result.name for result in report.classes}
        missing = sorted(report.expected - present)
        if missing:
            report.reasons.append(
                f"{label}: テストのソースにあるのに結果に現れないクラスがある: {', '.join(missing)}"
            )
    return report


def build_summary(reports: list[TargetReport]) -> list[str]:
    lines = ["## Android のテストの実行件数", ""]
    lines += [
        "| 対象 | 集計の件数 | スキップ | スキップを除く実行 | 失敗 | 結果のクラス | ソースのテストのクラス |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for report in reports:
        lines.append(
            f"| {report.label} | {report.tests} | {report.skipped} | {report.executed} | {report.failed}"
            f" | {len(report.classes)} | {len(report.expected)} |"
        )
    for report in reports:
        lines += ["", f"### {report.label} のクラスごとの内訳", ""]
        if report.classes:
            lines += ["| クラス | 集計の件数 | スキップ | 失敗 |", "|---|---:|---:|---:|"]
            lines += [
                f"| {result.name} | {result.tests} | {result.skipped} | {result.failed} |"
                for result in sorted(report.classes, key=lambda result: result.name)
            ]
        else:
            lines.append("結果が無い。")
        if report.stale:
            lines += ["", f"前の実行の残りとして数えなかった結果のファイル: {len(report.stale)} 件"]
    reasons = [reason for report in reports for reason in report.reasons]
    if reasons:
        lines += ["", "### 件数の検査の失敗", ""]
        lines += [f"- {reason}" for reason in reasons]
    return lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Android のテストの実行件数を確かめる")
    parser.add_argument(
        "--target",
        action="append",
        required=True,
        type=parse_target,
        metavar="名前=モジュールのディレクトリ:タスクの名前",
        help="確かめる組 (複数指定できる)",
    )
    parser.add_argument("--stale-before", help="これより古い結果のファイルを数えない、目印のファイル")
    args = parser.parse_args(argv)

    stale_before: float | None = None
    if args.stale_before is not None:
        if not os.path.exists(args.stale_before):
            parser.error(f"--stale-before のファイルが無い: {args.stale_before}")
        stale_before = os.path.getmtime(args.stale_before)

    reports = [inspect(label, module_dir, task, stale_before) for label, module_dir, task in args.target]
    reasons = [reason for report in reports for reason in report.reasons]
    ci_report.emit_summary(build_summary(reports))
    ci_report.emit_errors(reasons)
    return 1 if reasons else 0


if __name__ == "__main__":
    sys.exit(main())
