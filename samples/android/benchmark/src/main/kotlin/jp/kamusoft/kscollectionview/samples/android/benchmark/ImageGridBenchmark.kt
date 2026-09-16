package jp.kamusoft.kscollectionview.samples.android.benchmark

import android.content.Intent
import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.ExperimentalMetricApi
import androidx.benchmark.macro.FrameTimingMetric
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
 * 「画像グリッド」の土俵のスクロール性能とメモリを、プリフェッチの到達点ごとに測る。
 *
 * この土俵には同等機能を持つ比較対象が無いため、スクロール性能については計測が成立したか
 * どうかだけを事後検証で見る (フレーム時間そのものの良し悪しはオーナーの体感が判定する)。
 * メモリは往復の定常化で見る。取得はネットワークに依存するので、結果は実行時の回線状態を含む。
 */
@OptIn(ExperimentalMetricApi::class)
@RunWith(AndroidJUnit4::class)
class ImageGridBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun scrollWithDiskPrefetch() {
        measureFling(MeasurementTarget.imageGrid(LargeItemCount, "disk"))
    }

    @Test
    fun scrollWithMemoryPrefetch() {
        measureFling(MeasurementTarget.imageGrid(LargeItemCount, "memory"))
    }

    @Test
    fun memoryWithDiskPrefetchAndTenThousandItems() {
        measureRoundTrips(destination = "disk", count = LargeItemCount)
    }

    @Test
    fun memoryWithMemoryPrefetchAndTenThousandItems() {
        measureRoundTrips(destination = "memory", count = LargeItemCount)
    }

    /**
     * 指定した画面を開き、実座標のフリックを 3 秒続ける試行を独立に 3 回行う。
     *
     * 試行の前処理で画像キャッシュを空にするため、3 回とも取得が最初から走る状態 (cold) で
     * 測る。空にしないと 2 回目以降はディスクとメモリが温まり、同じ負荷の独立した試行に
     * ならない。取得はネットワークに依存するので、cold の試行は回線状態の影響を強く受ける。
     *
     * @param route 開く経路
     */
    private fun measureFling(route: String) {
        benchmarkRule.measureRepeated(
            packageName = MeasurementTarget.PackageName,
            metrics = listOf(FrameTimingMetric()),
            compilationMode = CompilationMode.Partial(warmupIterations = 1),
            iterations = TrialCount,
            setupBlock = {
                pressHome()
                startActivityAndWait(measurementIntent(route))
                device.awaitMeasurementScreen(route)
            },
        ) {
            device.flingFor(FlingDurationMillis)
            // 対象アプリが落ちても計測は「描かれたわずかなフレーム」を集計して成功で終わる。
            // 描画が成り立たなかったのは未判定であり、緑にしてはならない。
            device.assertMeasurementScreenAlive(route, "フリックの後")
        }
    }

    /**
     * 自動往復の画面を開き、走査が終わるまで待ってからメモリを記録する。
     *
     * スクロール性能と同じく、開始時のキャッシュを空にしてから測る。件数は経路で渡し、
     * 対象アプリ側はその件数分だけを作って保持する。
     *
     * @param destination プリフェッチの到達点
     * @param count 土俵の件数
     */
    private fun measureRoundTrips(destination: String, count: Int) {
        val route = MeasurementTarget.imageMemoryRoundTrip(count, MaxRoundTrips, destination)
        benchmarkRule.measureRepeated(
            packageName = MeasurementTarget.PackageName,
            metrics = listOf(MemoryUsageMetric(MemoryUsageMetric.Mode.Last)),
            compilationMode = CompilationMode.Partial(warmupIterations = 1),
            iterations = 1,
            setupBlock = {
                pressHome()
                startActivityAndWait(measurementIntent(route))
                device.awaitMeasurementScreen(route)
            },
        ) {
            // 走査の終了は、進捗の印を付けた表示が "running" 以外になったことで判定する。
            val deadline = System.currentTimeMillis() + ScanTimeoutMillis
            var status = "running"
            while (System.currentTimeMillis() < deadline) {
                status = device
                    .wait(Until.findObject(By.desc(MeasurementTarget.StatusDescription)), 5_000)
                    ?.text
                    ?: "running"
                if (status != "running") break
            }
            // 定常化しなかった・到達できなかった・間の項目を飛ばしたはいずれも未判定であり、
            // 緑にしてはならない。進捗の印にはその時点の実測値が入っている。
            assertTrue(
                "走査が定常に達しませんでした (最後に読めた進捗: $status)",
                status.startsWith("steady:"),
            )
        }
    }

    /**
     * 計測用の画面を、キャッシュを空にした状態で開く起動指定を作る。
     *
     * @param route 開く経路
     */
    private fun measurementIntent(route: String): Intent = Intent().apply {
        setClassName(MeasurementTarget.PackageName, MeasurementTarget.ActivityName)
        putExtra(MeasurementTarget.StartRouteExtra, route)
        putExtra(MeasurementTarget.ResetImageCacheExtra, true)
    }

    private companion object {
        /** 土俵の件数。デモ画面と同じ件数。 */
        const val LargeItemCount = 10_000

        /** 独立した試行の回数。 */
        const val TrialCount = 3

        /** 1 試行あたりのフリックの継続時間。 */
        const val FlingDurationMillis = 3_000L

        /** 重ねる往復の上限。 */
        const val MaxRoundTrips = 10

        /** 走査の完了を待つ上限。 */
        const val ScanTimeoutMillis = 30 * 60 * 1000L
    }
}
