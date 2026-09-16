#!/usr/bin/env python3
"""事後検証スクリプトの単体テスト。

判定そのものが計測の合否を決めるため、スクリプトが黙って合格を返す経路が無いことを固定の
結果 JSON で確かめる。実機も計測結果も要らない。

実行 (リポジトリのルートから):
    python3 -m unittest discover -s samples/android/benchmark/scripts -p 'test_*.py'
"""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
_SCRIPT_PATH = _SCRIPT_DIR / "verify-fling-results.py"
_SPEC = importlib.util.spec_from_file_location("verify_fling_results", _SCRIPT_PATH)
assert _SPEC is not None and _SPEC.loader is not None
verifier = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(verifier)

#: 実機で出力された結果 JSON (メモリ計測の実行) をそのまま置いたもの。
REAL_RESULT = _SCRIPT_DIR / "testdata" / "memory-benchmarkData.json"

_SCROLL_CLASS = (
    "jp.kamusoft.kscollectionview.samples.android.benchmark.LargeDataScrollBenchmark"
)
_IMAGE_CLASS = (
    "jp.kamusoft.kscollectionview.samples.android.benchmark.ImageGridBenchmark"
)


def make_context(model: str = "Pixel 4a", sdk: int = 33) -> dict[str, Any]:
    """結果 JSON の環境を、実機の出力と同じ形で作る。

    :param model: 機種名
    :param sdk: OS の API 水準
    """
    return {
        "build": {
            "brand": "google",
            "device": "device",
            "fingerprint": f"google/device/device:{sdk}/build/x:user/release-keys",
            "id": "build",
            "model": model,
            "type": "user",
            "version": {"codename": "REL", "sdk": sdk},
        },
        "cpuCoreCount": 8,
        "cpuLocked": True,
        "compilationMode": "partial",
        "payload": {},
    }


def make_benchmark(
    name: str,
    p90: float,
    p99: float,
    frame_counts: list[int],
    class_name: str = _SCROLL_CLASS,
    with_frame_count: bool = True,
    repeat_iterations: int | None = None,
) -> dict[str, Any]:
    """1 件分の計測結果を、実機の出力と同じ形で作る。

    :param name: テスト名
    :param p90: フレーム時間の P90
    :param p99: フレーム時間の P99
    :param frame_counts: 試行ごとの描画フレーム数
    :param class_name: テストクラスの名前
    :param with_frame_count: 描画フレーム数の指標を含めるか
    :param repeat_iterations: 結果 JSON が持つ繰り返し回数。省略すると試行数に合わせる
    """
    metrics: dict[str, Any] = {}
    if with_frame_count:
        runs = [float(count) for count in frame_counts]
        metrics["frameCount"] = {
            "minimum": min(runs),
            "maximum": max(runs),
            "median": sorted(runs)[len(runs) // 2],
            "runs": runs,
        }
    return {
        "name": name,
        "params": {},
        "className": class_name,
        "totalRunTimeNs": 1_000_000_000,
        "metrics": metrics,
        "sampledMetrics": {
            "frameDurationCpuMs": {
                "P50": p90 - 1,
                "P90": p90,
                "P95": p90,
                "P99": p99,
                "runs": [[p90] for _ in frame_counts],
            },
        },
        "warmupIterations": 1,
        "repeatIterations": (
            repeat_iterations if repeat_iterations is not None else len(frame_counts)
        ),
        "thermalThrottleSleepSeconds": 0,
        "profilerOutputs": [],
    }


def real_shaped_benchmark(
    name: str,
    p90: float,
    p99: float,
    frame_counts: list[int],
    class_name: str = _SCROLL_CLASS,
) -> dict[str, Any]:
    """実機が出力した結果の入れ物をそのまま使い、指標だけフリック計測のものに差し替える。

    手書きの見本は「どの入れ物にどの指標が入るか」を仮定した形でしかない。実機が出力した
    1 件をひな型にすることで、少なくとも入れ物の形 (キーの構成) は実物に合わせられる。

    :param name: テスト名
    :param p90: フレーム時間の P90
    :param p99: フレーム時間の P99
    :param frame_counts: 試行ごとの描画フレーム数
    :param class_name: テストクラスの名前
    """
    document = json.loads(REAL_RESULT.read_text(encoding="utf-8"))
    benchmark = copy.deepcopy(document["benchmarks"][0])
    template = next(iter(benchmark["metrics"].values()))
    runs = [float(count) for count in frame_counts]
    frame_count = dict.fromkeys(template.keys())
    frame_count.update(
        {
            "minimum": min(runs),
            "maximum": max(runs),
            "median": sorted(runs)[len(runs) // 2],
            "coefficientOfVariation": 0.0,
            "runs": runs,
        }
    )
    benchmark["name"] = name
    benchmark["className"] = class_name
    benchmark["metrics"] = {"frameCount": frame_count}
    benchmark["sampledMetrics"] = {
        "frameDurationCpuMs": {
            "P50": p90 - 1,
            "P90": p90,
            "P95": p90,
            "P99": p99,
            "runs": [[p90] for _ in frame_counts],
        },
    }
    benchmark["warmupIterations"] = 1
    benchmark["repeatIterations"] = len(frame_counts)
    return benchmark


def real_context() -> dict[str, Any]:
    """実機が出力した結果の環境をそのまま返す。"""
    return json.loads(REAL_RESULT.read_text(encoding="utf-8"))["context"]


class VerifyFlingResultsTest(unittest.TestCase):
    """事後検証スクリプトの判定。"""

    def setUp(self) -> None:
        self._temporary = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary.name)
        self.addCleanup(self._temporary.cleanup)

    def write_result(
        self,
        benchmarks: list[dict[str, Any]],
        context: dict[str, Any] | None = None,
        directory: str = "run",
        raw: str | None = None,
    ) -> Path:
        """結果 JSON を書き出す。

        :param benchmarks: 収める計測結果
        :param context: 環境。省略すると基準機のもの
        :param directory: 書き出す先のディレクトリ名
        :param raw: JSON の代わりに書き出す文字列
        :return: 書き出したファイル
        """
        target = self.root / directory
        target.mkdir(parents=True, exist_ok=True)
        file = target / "jp.kamusoft.sample-benchmarkData.json"
        if raw is not None:
            file.write_text(raw, encoding="utf-8")
            return file
        document = {
            "context": context or make_context(),
            "benchmarks": benchmarks,
        }
        file.write_text(json.dumps(document), encoding="utf-8")
        return file

    def scroll_pair(
        self,
        library_p90: float = 6.0,
        library_p99: float = 8.0,
        baseline_p90: float = 6.0,
        baseline_p99: float = 8.0,
        frame_counts: list[int] | None = None,
    ) -> list[dict[str, Any]]:
        """2 列グリッドの両側の計測結果を作る。"""
        counts = frame_counts or [120, 118, 121]
        return [
            make_benchmark("ksCollectionView", library_p90, library_p99, counts),
            make_benchmark("baselineLazyVerticalGrid", baseline_p90, baseline_p99, counts),
        ]

    def test_合格(self) -> None:
        self.write_result(self.scroll_pair(library_p90=6.3, library_p99=8.5))
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_PASS, code, "\n".join(lines))
        self.assertIn("判定: 合格", lines[-1])

    def test_劣化が上限を超えると不合格(self) -> None:
        # P99 が比較対象の +12.5% で、上限 10% を超える。
        self.write_result(self.scroll_pair(library_p99=9.0, baseline_p99=8.0))
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_FAIL, code, "\n".join(lines))
        self.assertIn("判定: 不合格", lines[-1])

    def test_描画フレーム数が下限を割ると未判定(self) -> None:
        self.write_result(self.scroll_pair(frame_counts=[120, 42, 118]))
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_UNDETERMINED, code, "\n".join(lines))
        self.assertIn("判定: 未判定", lines[-1])

    def test_下限割れは劣化が上限内でも合格にならない(self) -> None:
        self.write_result(
            self.scroll_pair(library_p99=9.0, baseline_p99=8.0, frame_counts=[10, 10, 10])
        )
        code, _ = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_UNDETERMINED, code)

    def test_試行が_1_回だけなら判定しない(self) -> None:
        self.write_result(self.scroll_pair(frame_counts=[120]))
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("試行が 1 回", lines[0])

    def test_試行が_2_回なら判定しない(self) -> None:
        self.write_result(self.scroll_pair(frame_counts=[120, 118]))
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("試行が 2 回", lines[0])

    def test_試行が_4_回なら判定しない(self) -> None:
        self.write_result(self.scroll_pair(frame_counts=[120, 118, 121, 119]))
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("試行が 4 回", lines[0])

    def test_繰り返し回数が試行数と食い違うと判定しない(self) -> None:
        benchmarks = [
            make_benchmark(
                "ksCollectionView", 6.0, 8.0, [120, 118, 121], repeat_iterations=1
            ),
            make_benchmark("baselineLazyVerticalGrid", 6.0, 8.0, [120, 118, 121]),
        ]
        self.write_result(benchmarks)
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("繰り返し回数", lines[0])

    def test_片側だけの結果は入力不正(self) -> None:
        self.write_result([make_benchmark("ksCollectionView", 6.0, 8.0, [120, 120, 120])])
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("片側", lines[0])

    def test_環境が一致しないと入力不正(self) -> None:
        # 実行を分けて測る経路は持たないため、環境が食い違う入力は結果 JSON を直接組んで確かめる。
        collected = {
            (_SCROLL_CLASS, "ksCollectionView"): {
                "context": make_context(),
                "benchmark": make_benchmark("ksCollectionView", 6.0, 8.0, [120, 120, 120]),
            },
            (_SCROLL_CLASS, "baselineLazyVerticalGrid"): {
                "context": make_context(model="Pixel 6a", sdk=34),
                "benchmark": make_benchmark(
                    "baselineLazyVerticalGrid", 6.0, 8.0, [120, 120, 120]
                ),
            },
        }
        with self.assertRaises(verifier.InvalidInput) as raised:
            verifier.verify(collected)
        self.assertIn("環境が一致しません", str(raised.exception))

    def test_指定を_2_つ渡すと入力不正(self) -> None:
        first = self.write_result(self.scroll_pair(), directory="first")
        second = self.write_result(self.scroll_pair(), directory="second")
        code, lines = verifier.run([first, second])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("1 実行の結果だけ", lines[0])

    def test_複数実行の混在は入力不正(self) -> None:
        self.write_result(self.scroll_pair(), directory="run-1")
        self.write_result(self.scroll_pair(), directory="run-2")
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("混在", lines[0])

    def test_同じテストが重複すると入力不正(self) -> None:
        benchmarks = self.scroll_pair() + [
            make_benchmark("ksCollectionView", 6.0, 8.0, [120, 118, 121])
        ]
        self.write_result(benchmarks)
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("2 つ", lines[0])

    def test_指標が欠けていると入力不正(self) -> None:
        self.write_result(
            [
                make_benchmark(
                    "ksCollectionView", 6.0, 8.0, [120, 120, 120], with_frame_count=False
                ),
                make_benchmark("baselineLazyVerticalGrid", 6.0, 8.0, [120, 120, 120]),
            ]
        )
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("frameCount", lines[0])

    def test_壊れた_JSON_は入力不正(self) -> None:
        self.write_result([], raw="{ これは JSON ではない")
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("読めません", lines[0])

    def test_結果が無いディレクトリは入力不正(self) -> None:
        (self.root / "empty").mkdir()
        code, lines = verifier.run([self.root / "empty"])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("見つかりません", lines[0])

    def test_判定対象のテストが無ければ入力不正(self) -> None:
        self.write_result(
            [
                make_benchmark(
                    "memoryWithTenThousandItems",
                    6.0,
                    8.0,
                    [120, 120, 120],
                    class_name=(
                        "jp.kamusoft.kscollectionview.samples.android.benchmark"
                        ".LargeDataMemoryBenchmark"
                    ),
                )
            ]
        )
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("判定の対象", lines[0])

    def test_実機の結果_JSON_をそのまま読める(self) -> None:
        # 実機が出力した結果 (メモリ計測の実行) は、フリック計測の指標を持たない。手書きの
        # 見本だけで確かめていると、実物の形と食い違っても緑のままになる。
        self.assertTrue(REAL_RESULT.is_file(), f"見本が見つかりません: {REAL_RESULT}")
        code, lines = verifier.run([REAL_RESULT])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code, "\n".join(lines))
        self.assertIn("判定の対象", lines[0])

    def test_実機の結果_JSON_から環境を読める(self) -> None:
        document = json.loads(REAL_RESULT.read_text(encoding="utf-8"))
        entry = {"context": document["context"], "benchmark": document["benchmarks"][0]}
        environment = verifier.environment_of(entry)
        # 照合に使う項目がすべて実物から読めることを固定する (どれかが None のままだと、
        # 両側とも None で一致して照合が無音で素通りする)。
        for key, value in environment.items():
            self.assertIsNotNone(value, f"{key} を実物から読めません")

    def test_実機の入れ物にフリックの指標を入れた結果を判定できる(self) -> None:
        # 実機が出力した入れ物 (context と benchmarks[].metrics の形) に、フリック計測の指標
        # だけを入れた結果。合格の経路がこの形を通ることを固定する。
        counts = [120, 118, 121]
        self.write_result(
            [
                real_shaped_benchmark("ksCollectionView", 6.3, 8.5, counts),
                real_shaped_benchmark("baselineLazyVerticalGrid", 6.0, 8.0, counts),
            ],
            context=real_context(),
        )
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_PASS, code, "\n".join(lines))
        self.assertIn("判定: 合格", lines[-1])

    def test_実機の入れ物でも劣化が上限を超えれば不合格(self) -> None:
        counts = [120, 118, 121]
        self.write_result(
            [
                real_shaped_benchmark("ksCollectionView", 6.0, 9.0, counts),
                real_shaped_benchmark("baselineLazyVerticalGrid", 6.0, 8.0, counts),
            ],
            context=real_context(),
        )
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_FAIL, code, "\n".join(lines))

    def test_実機の入れ物でも下限を割れば未判定(self) -> None:
        counts = [120, 30, 121]
        self.write_result(
            [
                real_shaped_benchmark("ksCollectionView", 6.0, 8.0, counts),
                real_shaped_benchmark("baselineLazyVerticalGrid", 6.0, 8.0, counts),
            ],
            context=real_context(),
        )
        code, _ = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_UNDETERMINED, code)

    def test_画像グリッドは計測成立だけを見る(self) -> None:
        self.write_result(
            [
                make_benchmark(
                    "scrollWithDiskPrefetch",
                    99.0,
                    199.0,
                    [120, 120, 120],
                    class_name=_IMAGE_CLASS,
                )
            ]
        )
        code, lines = verifier.run([self.root])
        # 比較対象を持たないため、フレーム時間がどれだけ大きくても不合格にはしない。
        self.assertEqual(verifier.EXIT_PASS, code, "\n".join(lines))

    def test_画像グリッドでも下限を割れば未判定(self) -> None:
        self.write_result(
            [
                make_benchmark(
                    "scrollWithMemoryPrefetch",
                    6.0,
                    8.0,
                    [120, 20, 120],
                    class_name=_IMAGE_CLASS,
                )
            ]
        )
        code, _ = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_UNDETERMINED, code)

    def test_画像グリッドでも試行数は照合する(self) -> None:
        self.write_result(
            [
                make_benchmark(
                    "scrollWithDiskPrefetch",
                    6.0,
                    8.0,
                    [120, 120],
                    class_name=_IMAGE_CLASS,
                )
            ]
        )
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_INVALID_INPUT, code)
        self.assertIn("試行が 2 回", lines[0])

    def test_標本の並びからも描画フレーム数を読む(self) -> None:
        # 標本の入れ物に試行ごとの並びが入る形の結果でも、並びの個数を試行のフレーム数とみなす。
        benchmarks = self.scroll_pair()
        for benchmark in benchmarks:
            benchmark["metrics"] = {}
            benchmark["sampledMetrics"]["frameCount"] = {
                "runs": [[1.0] * 120, [1.0] * 118, [1.0] * 121]
            }
        self.write_result(benchmarks)
        code, lines = verifier.run([self.root])
        self.assertEqual(verifier.EXIT_PASS, code, "\n".join(lines))


if __name__ == "__main__":
    unittest.main()
