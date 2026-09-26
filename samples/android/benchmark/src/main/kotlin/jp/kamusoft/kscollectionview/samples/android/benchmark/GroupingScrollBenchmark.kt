package jp.kamusoft.kscollectionview.samples.android.benchmark

import android.content.Intent
import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 「グループ化」の土俵 (大小のグループに分けた 10,000 件を、固定される見出しつきで縦長 2 列 /
 * 横長 4 列に並べたグリッド) のスクロール性能を、ライブラリと素の LazyVerticalGrid で同じ手順で測る。
 *
 * 2 つの結果の差が、グループの見出しを持つときのラッパーの上乗せ分にあたる。比較対象はライブラリの
 * 既定機能 (高さ変化のアニメーション・配置のアニメーション・縦スクロールインジケータ) を同じ位置に
 * 持つ。
 */
@RunWith(AndroidJUnit4::class)
class GroupingScrollBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun ksCollectionView() {
        measureFling(MeasurementTarget.ksGrouping())
    }

    @Test
    fun baselineLazyVerticalGrid() {
        measureFling(MeasurementTarget.baselineGrouping())
    }

    /**
     * 指定した画面を開き、実座標のフリックを 3 秒続ける試行を独立に 3 回行う。
     *
     * @param route 開く経路
     */
    private fun measureFling(route: String) {
        benchmarkRule.measureRepeated(
            packageName = MeasurementTarget.PackageName,
            metrics = listOf(FrameTimingMetric()),
            // 実行時コンパイルの状態を試行間でそろえる。1 回の暖機の後にコンパイルする。
            compilationMode = CompilationMode.Partial(warmupIterations = 1),
            iterations = TrialCount,
            setupBlock = {
                pressHome()
                startActivityAndWait(
                    Intent().apply {
                        setClassName(
                            MeasurementTarget.PackageName,
                            MeasurementTarget.ActivityName,
                        )
                        putExtra(MeasurementTarget.StartRouteExtra, route)
                    },
                )
                // 目的の画面が載ったことを確かめてから計測に入る。
                device.awaitMeasurementScreen(route)
            },
        ) {
            device.flingFor(FlingDurationMillis)
            device.assertMeasurementScreenAlive(route, "フリックの後")
        }
    }

    private companion object {
        /** 独立した試行の回数。 */
        const val TrialCount = 3

        /** 1 試行あたりのフリックの継続時間。 */
        const val FlingDurationMillis = 3_000L
    }
}
