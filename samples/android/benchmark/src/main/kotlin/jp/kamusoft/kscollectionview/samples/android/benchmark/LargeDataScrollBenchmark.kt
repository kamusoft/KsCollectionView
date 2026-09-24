package jp.kamusoft.kscollectionview.samples.android.benchmark

import android.content.Intent
import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.FrameTimingMetric
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
 * 「大量件数」の土俵のスクロール性能を、ライブラリと素の LazyVerticalGrid で同じ手順で測る。
 *
 * 2 つの結果の差がラッパーの上乗せ分にあたる。候補の実装だけを測ると、値が良いのか悪いのかを
 * 判断する基準がないため、同じ土俵の比較対象を必ず併せて測る。
 */
@RunWith(AndroidJUnit4::class)
class LargeDataScrollBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun ksCollectionView() {
        measureFling(MeasurementTarget.ksLargeData(LargeItemCount))
    }

    @Test
    fun baselineLazyVerticalGrid() {
        measureFling(MeasurementTarget.baselineLargeData(LargeItemCount))
    }

    @Test
    fun ksCollectionViewList() {
        measureFling(MeasurementTarget.ksLargeList(LargeItemCount))
    }

    @Test
    fun baselineLazyColumn() {
        measureFling(MeasurementTarget.baselineLargeList(LargeItemCount))
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
                // 目的の画面が載ったことを確かめてから計測に入る。起動の完了だけでは、
                // メニューや遷移の途中のフレームが計測に混ざる。
                device.awaitMeasurementScreen(route)
            },
        ) {
            device.flingFor(FlingDurationMillis)
            device.assertMeasurementScreenAlive(route, "フリックの後")
        }
    }

    private companion object {
        /** 土俵の件数。 */
        const val LargeItemCount = 10_000

        /** 独立した試行の回数。 */
        const val TrialCount = 3

        /** 1 試行あたりのフリックの継続時間。 */
        const val FlingDurationMillis = 3_000L
    }
}

/**
 * 目的の計測画面が載るまで待つ。
 *
 * 上限は実時間で区切り、超えたらその場で失敗させる。黙って戻ると、目的でない画面の
 * フレームを測った結果が合格として記録される。
 *
 * @param route 開いた経路
 */
internal fun UiDevice.awaitMeasurementScreen(route: String) {
    val found = wait(
        Until.hasObject(By.desc(MeasurementTarget.screenDescription(route))),
        ScreenReadyTimeoutMillis,
    )
    assertTrue("計測画面が $ScreenReadyTimeoutMillis ms 以内に表示されませんでした (経路: $route)", found)
    waitForIdle()
}

/** 目的の画面が載るのを待つ上限。 */
private const val ScreenReadyTimeoutMillis = 30_000L

/**
 * 計測対象の画面がまだ載っていることを確かめる。
 *
 * フリックの計測は、対象アプリが途中で落ちても・別の画面へ移っても、描かれたわずかな
 * フレームを集計して成功で終わる。**描画が成り立たなかったのは未判定であり緑にしてはならない**
 * ため、フリックの後にこの確認を挟む (メモリの計測が持つ「到達できなかったら失敗させる」と
 * 同じ趣旨)。
 *
 * 見ているのは画面の印の有無であり、フレームが何枚描かれたかではない。計測の集計値は
 * 実行後にしか読めないため、frameCount そのものの下限はここでは判定できない。
 *
 * @param route 開いた経路
 * @param phase 確認した時点の呼び名 (失敗したときに読む)
 */
internal fun UiDevice.assertMeasurementScreenAlive(route: String, phase: String) {
    assertTrue(
        "$phase に計測対象の画面が見つかりません (経路: $route)。" +
            "対象アプリが落ちたか、別の画面へ移っています",
        hasObject(By.desc(MeasurementTarget.screenDescription(route))),
    )
}

/**
 * 画面の実座標を上下にフリックし続ける。
 *
 * @param durationMillis 続ける時間
 */
internal fun UiDevice.flingFor(durationMillis: Long) {
    val centerX = displayWidth / 2
    val top = (displayHeight * 0.25).toInt()
    val bottom = (displayHeight * 0.8).toInt()
    val deadline = System.currentTimeMillis() + durationMillis
    var downward = false
    while (System.currentTimeMillis() < deadline) {
        if (downward) {
            swipe(centerX, top, centerX, bottom, FlingSteps)
        } else {
            swipe(centerX, bottom, centerX, top, FlingSteps)
        }
        downward = !downward
    }
    waitForIdle()
}

/** フリックの刻み数。少ないほど速い動きになる。 */
private const val FlingSteps = 5
