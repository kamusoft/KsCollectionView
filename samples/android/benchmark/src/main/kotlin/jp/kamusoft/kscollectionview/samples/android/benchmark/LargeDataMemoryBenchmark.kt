package jp.kamusoft.kscollectionview.samples.android.benchmark

import android.content.Intent
import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.ExperimentalMetricApi
import androidx.benchmark.macro.MemoryUsageMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 全要素を通過する往復を重ねたときのメモリを、件数を変えて測る。
 *
 * 走査と往復ごとの記録は対象アプリ側が自動で行う。ここでは往復の終了時点で計測の枠組みから
 * 見えるメモリを記録し、件数を変えた 2 つの定常値を突き合わせられるようにする。
 */
@OptIn(ExperimentalMetricApi::class)
@RunWith(AndroidJUnit4::class)
class LargeDataMemoryBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun memoryWithOneThousandItems() {
        measureRoundTrips(SmallItemCount)
    }

    @Test
    fun memoryWithTenThousandItems() {
        measureRoundTrips(LargeItemCount)
    }

    /**
     * 自動往復の画面を開き、走査が終わるまで待ってからメモリを記録する。
     *
     * @param count 土俵の件数
     */
    private fun measureRoundTrips(count: Int) {
        benchmarkRule.measureRepeated(
            packageName = MeasurementTarget.PackageName,
            metrics = listOf(MemoryUsageMetric(MemoryUsageMetric.Mode.Last)),
            compilationMode = CompilationMode.Partial(warmupIterations = 1),
            iterations = 1,
            setupBlock = {
                pressHome()
                startActivityAndWait(
                    Intent().apply {
                        setClassName(
                            MeasurementTarget.PackageName,
                            MeasurementTarget.ActivityName,
                        )
                        putExtra(
                            MeasurementTarget.StartRouteExtra,
                            MeasurementTarget.memoryRoundTrip(count, MaxRoundTrips),
                        )
                    },
                )
                // 自動往復の画面が載ったことを確かめてから計測に入る。
                device.awaitMeasurementScreen(
                    MeasurementTarget.memoryRoundTrip(count, MaxRoundTrips),
                )
            },
        ) {
            // 走査の終了は、進捗の印を付けた表示が "running" 以外になったことで判定する。
            // 時間で区切ると、実行機が混んでいるときに走査の途中で測ってしまう。
            val deadline = System.currentTimeMillis() + ScanTimeoutMillis
            var status = "running"
            while (System.currentTimeMillis() < deadline) {
                status = device
                    .wait(Until.findObject(By.desc(MeasurementTarget.StatusDescription)), 5_000)
                    ?.text
                    ?: "running"
                if (status != "running") break
            }
            // 定常化しなかった (notSteady)、到達できなかった (unreached)、間の項目を
            // 飛ばした (missedItems) はいずれも「未判定」であり、緑にしてはならない。
            // 進捗の印にはその時点の実測値が入っているので、失敗の言葉としてそのまま載せる。
            assertTrue(
                "走査が定常に達しませんでした (最後に読めた進捗: $status)",
                status.startsWith("steady:"),
            )
        }
    }

    private companion object {
        /** 件数比の比較に使う小さい方の土俵。 */
        const val SmallItemCount = 1_000

        /** 件数比の比較に使う大きい方の土俵。 */
        const val LargeItemCount = 10_000

        /** 重ねる往復の上限。 */
        const val MaxRoundTrips = 10

        /** 走査の完了を待つ上限。 */
        const val ScanTimeoutMillis = 30 * 60 * 1000L
    }
}
