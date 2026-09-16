#!/usr/bin/env python3
"""Macrobenchmark のフリック計測の結果 JSON を事後検証する。

ライブラリ側と比較対象側の結果をテスト名で対応付け、環境の一致・計測の成立・比較対象に対する
劣化率を判定する。判定を人の突き合わせに委ねると「未判定が緑になる」穴が残るため、合否も
未判定も入力不正もこのスクリプトの終了コードで表す。

判定の規則 (フレーム数の下限・劣化率の上限) は固定値であり、計測結果を見てから動かさない。

使い方 (リポジトリのルートから):
    python3 samples/android/benchmark/scripts/verify-fling-results.py [結果 JSON かディレクトリ]

読むのは 1 実行の結果だけで、指定は 1 つに限る。ディレクトリを渡した場合は、その配下に結果
JSON がちょうど 1 つあることを求める (古い実行の結果が残っていれば入力不正とする)。ライブラリ
側と比較対象側は 1 回の実行で 1 つの結果 JSON に出るため、別々の実行の結果を突き合わせる経路は
持たない。引数を省略すると、計測モジュールの既定の出力先を見る。

終了コード:
    0 合格 / 1 不合格 / 2 未判定 / 3 入力不正
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# ---- 判定の定数 (結果を見て動かさない) ------------------------------------------------

#: 1 試行あたりの描画フレーム数の下限。基準機 60 Hz × 3 秒のフリックの理論上限 180 の 50%。
#: これを割った試行は、フリックが土俵に届いていない可能性があるため合否を付けず未判定とする。
FRAME_COUNT_FLOOR = 90

#: 独立した試行の回数。集計値は 3 試行に対するものであることを求め、増減があれば判定しない。
REQUIRED_TRIAL_COUNT = 3

#: 比較対象に対する劣化率の上限 (%)。
DEGRADATION_LIMIT_PERCENT = 10.0

#: 相対判定に使う指標と百分位。
RELATIVE_METRIC = "frameDurationCpuMs"
RELATIVE_PERCENTILES = ("P90", "P99")

#: 計測の成立を見る指標。
FRAME_COUNT_METRIC = "frameCount"

# ---- 終了コード ------------------------------------------------------------------------

EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_UNDETERMINED = 2
EXIT_INVALID_INPUT = 3

# ---- 対応付けの表 ----------------------------------------------------------------------

_SCROLL_CLASS = (
    "jp.kamusoft.kscollectionview.samples.android.benchmark.LargeDataScrollBenchmark"
)
_IMAGE_CLASS = (
    "jp.kamusoft.kscollectionview.samples.android.benchmark.ImageGridBenchmark"
)

#: 相対判定の対象。(表示名, ライブラリ側のテスト, 比較対象側のテスト)。
#: 計測モジュールは対象アプリのコードを参照できないため、対応付けはテスト名で行う。
RELATIVE_PAIRS = (
    ("2 列グリッド", (_SCROLL_CLASS, "ksCollectionView"), (_SCROLL_CLASS, "baselineLazyVerticalGrid")),
    ("1 列リスト", (_SCROLL_CLASS, "ksCollectionViewList"), (_SCROLL_CLASS, "baselineLazyColumn")),
)

#: 比較対象を持たないため計測の成立だけを見る対象。
MEASUREMENT_ONLY = (
    ("画像グリッド (ディスク)", (_IMAGE_CLASS, "scrollWithDiskPrefetch")),
    ("画像グリッド (メモリ)", (_IMAGE_CLASS, "scrollWithMemoryPrefetch")),
)

#: 結果 JSON のファイル名の末尾。
RESULT_SUFFIX = "benchmarkData.json"

#: 引数を省略したときに見る、計測モジュールの出力先。
DEFAULT_OUTPUT_DIR = (
    Path(__file__).resolve().parent.parent
    / "build"
    / "outputs"
    / "connected_android_test_additional_output"
)


class InvalidInput(Exception):
    """判定の材料が揃っていないことを表す。合格にも不合格にもしない。"""


def collect_result_files(paths: list[Path]) -> list[Path]:
    """渡された指定から、読む結果 JSON を 1 つ決める。

    読むのは 1 実行の結果だけとする。指定が 2 つ以上あれば、別々の実行の結果を突き合わせる
    経路になるため入力不正とする (同じ端末でも、別の日に別のコードで測った結果どうしを比べる
    ことができてしまう)。ディレクトリは配下を再帰的に探し、結果 JSON がちょうど 1 つある
    ことを求める。複数あればどれが最新かを推測せず入力不正として止める。

    :param paths: 結果 JSON かそれを含むディレクトリ (1 つ)
    :return: 読む結果 JSON の一覧 (1 件)
    """
    if len(paths) > 1:
        raise InvalidInput(
            "読むのは 1 実行の結果だけです。指定は 1 つにしてください: "
            + ", ".join(str(path) for path in paths)
        )
    if not paths:
        raise InvalidInput("読む結果 JSON がありません")
    path = paths[0]
    if path.is_dir():
        found = sorted(p for p in path.rglob("*") if p.name.endswith(RESULT_SUFFIX))
        if not found:
            raise InvalidInput(f"結果 JSON が見つかりません: {path}")
        if len(found) > 1:
            names = ", ".join(str(p.relative_to(path)) for p in found)
            raise InvalidInput(
                "複数の実行の結果が混在しています。出力先を空にしてから測り直してください: "
                f"{names}"
            )
        return [found[0]]
    if path.is_file():
        return [path]
    raise InvalidInput(f"指定が見つかりません: {path}")


def load_benchmarks(files: list[Path]) -> dict[tuple[str, str], dict[str, Any]]:
    """結果 JSON を読み、テスト名を鍵にした一覧にする。

    同じテストが 2 度現れた場合は、どちらが最新かを判別できないため入力不正とする。

    :param files: 読む結果 JSON の一覧
    :return: (クラス名, テスト名) を鍵に、環境と計測値を持つ辞書
    """
    collected: dict[tuple[str, str], dict[str, Any]] = {}
    for file in files:
        try:
            document = json.loads(file.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            raise InvalidInput(f"結果 JSON を読めません ({file.name}): {error}") from error
        if not isinstance(document, dict):
            raise InvalidInput(f"結果 JSON の形式が違います: {file.name}")
        context = document.get("context")
        benchmarks = document.get("benchmarks")
        if not isinstance(context, dict) or not isinstance(benchmarks, list):
            raise InvalidInput(f"結果 JSON に context / benchmarks がありません: {file.name}")
        for benchmark in benchmarks:
            if not isinstance(benchmark, dict):
                raise InvalidInput(f"計測結果の形式が違います: {file.name}")
            key = (str(benchmark.get("className", "")), str(benchmark.get("name", "")))
            if key in collected:
                raise InvalidInput(f"同じテストの結果が 2 つあります: {key[1]}")
            collected[key] = {"context": context, "benchmark": benchmark, "file": file}
    return collected


def environment_of(entry: dict[str, Any]) -> dict[str, Any]:
    """環境の照合に使う項目を取り出す。

    機種・OS・ビルド構成が違う結果どうしを比べても、差はラッパーの上乗せを表さない。

    :param entry: 計測結果の 1 件
    :return: 照合に使う項目
    """
    context = entry["context"]
    build = context.get("build")
    if not isinstance(build, dict):
        raise InvalidInput("結果 JSON の環境に build がありません")
    version = build.get("version")
    sdk = version.get("sdk") if isinstance(version, dict) else None
    return {
        "model": build.get("model"),
        "sdk": sdk,
        "fingerprint": build.get("fingerprint"),
        "compilationMode": context.get("compilationMode"),
    }


def metric_of(entry: dict[str, Any], name: str) -> dict[str, Any]:
    """指標を、集計済みの入れ物と標本の入れ物のどちらからでも取り出す。

    :param entry: 計測結果の 1 件
    :param name: 指標の名前
    :return: 指標の中身
    """
    benchmark = entry["benchmark"]
    for container in ("metrics", "sampledMetrics"):
        holder = benchmark.get(container)
        if isinstance(holder, dict) and isinstance(holder.get(name), dict):
            return holder[name]
    raise InvalidInput(f"{benchmark.get('name')} に指標 {name} がありません")


def frame_counts_of(entry: dict[str, Any]) -> list[float]:
    """試行ごとの描画フレーム数を取り出す。

    :param entry: 計測結果の 1 件
    :return: 試行ごとの描画フレーム数
    """
    runs = metric_of(entry, FRAME_COUNT_METRIC).get("runs")
    if not isinstance(runs, list) or not runs:
        raise InvalidInput(f"{entry['benchmark'].get('name')} に試行ごとの描画フレーム数がありません")
    counts: list[float] = []
    for run in runs:
        # 標本の入れ物では試行ごとに標本の並びが入る。並びで来たときはその個数を試行の
        # フレーム数とみなす。
        if isinstance(run, list):
            counts.append(float(len(run)))
        elif isinstance(run, (int, float)):
            counts.append(float(run))
        else:
            raise InvalidInput(f"{entry['benchmark'].get('name')} の描画フレーム数を読めません")
    return counts


def percentile_of(entry: dict[str, Any], name: str, percentile: str) -> float:
    """指標の百分位 (3 試行の集計値) を取り出す。

    :param entry: 計測結果の 1 件
    :param name: 指標の名前
    :param percentile: 百分位の名前
    :return: 集計値
    """
    value = metric_of(entry, name).get(percentile)
    if not isinstance(value, (int, float)):
        raise InvalidInput(
            f"{entry['benchmark'].get('name')} の {name} に {percentile} がありません"
        )
    return float(value)


def check_trial_count(label: str, entry: dict[str, Any], counts: list[float]) -> None:
    """独立した試行の回数が規定どおりかを確かめる。

    判定は 3 試行の集計値に対して行うため、試行が足りない結果を同じ集計値として扱えない。
    結果 JSON が繰り返し回数を持っていればそれも照合する。

    :param label: 報告に出す呼び名
    :param entry: 計測結果の 1 件
    :param counts: 試行ごとの描画フレーム数
    """
    if len(counts) != REQUIRED_TRIAL_COUNT:
        raise InvalidInput(
            f"{label} の試行が {len(counts)} 回です (必要: {REQUIRED_TRIAL_COUNT} 回)"
        )
    repeats = entry["benchmark"].get("repeatIterations")
    if isinstance(repeats, (int, float)) and int(repeats) != REQUIRED_TRIAL_COUNT:
        raise InvalidInput(
            f"{label} の繰り返し回数が {int(repeats)} です (必要: {REQUIRED_TRIAL_COUNT})"
        )


def check_frame_counts(label: str, entry: dict[str, Any], lines: list[str]) -> bool:
    """計測が成立しているかを見る。

    :param label: 報告に出す呼び名
    :param entry: 計測結果の 1 件
    :param lines: 報告の行を足す先
    :return: すべての試行が下限を満たしていれば True
    """
    counts = frame_counts_of(entry)
    check_trial_count(label, entry, counts)
    short = [count for count in counts if count < FRAME_COUNT_FLOOR]
    rendered = " / ".join(f"{count:.0f}" for count in counts)
    if short:
        lines.append(
            f"  未判定: {label} の描画フレーム数が下限 {FRAME_COUNT_FLOOR} を割る試行があります"
            f" (試行ごと: {rendered})"
        )
        return False
    lines.append(f"  計測成立: {label} の描画フレーム数 {rendered} (下限 {FRAME_COUNT_FLOOR})")
    return True


def verify(collected: dict[tuple[str, str], dict[str, Any]]) -> tuple[int, list[str]]:
    """集めた計測結果を判定する。

    :param collected: テスト名を鍵にした計測結果
    :return: 終了コードと報告の行
    """
    lines: list[str] = []
    judged = False
    undetermined = False
    failed = False

    for label, library_key, baseline_key in RELATIVE_PAIRS:
        library = collected.get(library_key)
        baseline = collected.get(baseline_key)
        if library is None and baseline is None:
            continue
        if library is None or baseline is None:
            missing = library_key[1] if library is None else baseline_key[1]
            raise InvalidInput(f"{label} の片側 ({missing}) の結果がありません")
        judged = True
        lines.append(f"[{label}]")

        library_environment = environment_of(library)
        baseline_environment = environment_of(baseline)
        if library_environment != baseline_environment:
            raise InvalidInput(
                f"{label} の両側で環境が一致しません: "
                f"{library_environment} / {baseline_environment}"
            )

        established = check_frame_counts(f"{label} ライブラリ側", library, lines)
        established &= check_frame_counts(f"{label} 比較対象側", baseline, lines)
        if not established:
            undetermined = True

        for percentile in RELATIVE_PERCENTILES:
            library_value = percentile_of(library, RELATIVE_METRIC, percentile)
            baseline_value = percentile_of(baseline, RELATIVE_METRIC, percentile)
            if baseline_value <= 0:
                raise InvalidInput(
                    f"{label} の比較対象側の {RELATIVE_METRIC} {percentile} が正の値ではありません"
                )
            degradation = (library_value - baseline_value) / baseline_value * 100.0
            within = degradation <= DEGRADATION_LIMIT_PERCENT
            if not within:
                failed = True
            verdict = "以内" if within else "超過"
            lines.append(
                f"  {RELATIVE_METRIC} {percentile}: "
                f"ライブラリ {library_value:.3f} ms / 比較対象 {baseline_value:.3f} ms / "
                f"劣化 {degradation:+.1f}% ({DEGRADATION_LIMIT_PERCENT:.0f}% {verdict})"
            )

    for label, key in MEASUREMENT_ONLY:
        entry = collected.get(key)
        if entry is None:
            continue
        judged = True
        lines.append(f"[{label}] 比較対象を持たないため計測の成立だけを見る")
        if not check_frame_counts(label, entry, lines):
            undetermined = True

    if not judged:
        raise InvalidInput("判定の対象になるフリック計測の結果がありません")

    if undetermined:
        lines.append("判定: 未判定 (計測が成立していない試行があります)")
        return EXIT_UNDETERMINED, lines
    if failed:
        lines.append("判定: 不合格 (比較対象に対する劣化が上限を超えています)")
        return EXIT_FAIL, lines
    lines.append("判定: 合格")
    return EXIT_PASS, lines


def run(paths: list[Path]) -> tuple[int, list[str]]:
    """指定された結果を読んで判定する。

    :param paths: 結果 JSON かそれを含むディレクトリ
    :return: 終了コードと報告の行
    """
    try:
        files = collect_result_files(paths)
        collected = load_benchmarks(files)
        return verify(collected)
    except InvalidInput as error:
        return EXIT_INVALID_INPUT, [f"入力不正: {error}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Macrobenchmark のフリック計測の結果を事後検証する",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="結果 JSON かそれを含むディレクトリ (省略時は計測モジュールの既定の出力先)",
    )
    arguments = parser.parse_args(argv)
    paths = arguments.paths or [DEFAULT_OUTPUT_DIR]
    code, lines = run(paths)
    for line in lines:
        print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
