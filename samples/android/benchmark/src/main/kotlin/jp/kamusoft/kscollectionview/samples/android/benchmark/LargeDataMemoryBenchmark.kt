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
 * 全要素を通過する往復を重ねたときのメモリと、項目単位の保持の解放を測る。
 *
 * 走査と往復ごとの記録は対象アプリ側が自動で行う。ここでは往復の終了時点で計測の枠組みから
 * 見えるメモリを記録し、走査が続けて行う「配列の置換 → 画面離脱」の結果を進捗の印から読んで
 * 判定する。
 */
@OptIn(ExperimentalMetricApi::class)
@RunWith(AndroidJUnit4::class)
class LargeDataMemoryBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

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
            assertReleased(status)
        }
    }

    /**
     * 配列の置換と画面離脱の後に、項目単位の保持が解放されたことを進捗の印から確かめる。
     *
     * 印の形は
     * `steady:<往復> peak:<最大同時生存> visible:<最大可視件数> replaced:<置換後> left:<離脱後>`。
     *
     * 同時生存の上限は、見える範囲の件数 (visible) から独立に決める。同じ走査で観測した同時生存
     * そのものを上限にすると、走査中からすでに多すぎた場合を素通りさせる。係数は固定値であり、
     * 計測結果を見てから動かさない。
     *
     * @param status 結果画面から読んだ進捗の印
     */
    private fun assertReleased(status: String) {
        val fields = status.split(" ")
            .mapNotNull { field ->
                val separator = field.indexOf(':')
                if (separator <= 0) return@mapNotNull null
                val value = field.substring(separator + 1).toLongOrNull()
                    ?: return@mapNotNull null
                field.substring(0, separator) to value
            }
            .toMap()
        val peak = fields["peak"]
        val visible = fields["visible"]
        val replaced = fields["replaced"]
        val left = fields["left"]
        assertTrue(
            "進捗の印から解放の確認に必要な値を読めません (読めた進捗: $status)",
            peak != null && visible != null && replaced != null && left != null,
        )
        assertTrue(
            "見える範囲の件数を観測できていません (読めた進捗: $status)",
            visible!! > 0L,
        )
        val limit = visible * AliveLimitFactor
        assertTrue(
            "走査中の同時生存が上限を超えています (最大: $peak / 上限: $limit = 可視 $visible × " +
                "$AliveLimitFactor)",
            peak!! <= limit,
        )
        assertTrue(
            "置換後の同時生存が上限を超えています (置換後: $replaced / 上限: $limit)",
            replaced!! <= limit,
        )
        assertTrue("画面を離れた後も解放されていない項目があります (残り: $left)", left == 0L)
    }

    private companion object {
        /** 同時生存の上限を、見える範囲の件数の何倍までとするか。 */
        const val AliveLimitFactor = 4L

        /** 土俵の件数。デモ画面と同じ件数。 */
        const val LargeItemCount = 10_000

        /** 重ねる往復の上限。 */
        const val MaxRoundTrips = 10

        /** 走査の完了を待つ上限。 */
        const val ScanTimeoutMillis = 30 * 60 * 1000L
    }
}
