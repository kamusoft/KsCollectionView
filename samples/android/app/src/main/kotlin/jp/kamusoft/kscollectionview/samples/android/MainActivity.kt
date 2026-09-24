package jp.kamusoft.kscollectionview.samples.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme

/**
 * Sample の入口。
 *
 * 起動時の追加情報で経路を指定できる。計測は人の操作を挟まずに目的の画面を開く必要があるため、
 * この入口を使う。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 画像の読み込みを観測できる構成では、最初の読み込みより前に観測を仕込む。
        // 配布する構成では何も起きない。
        installImageLoadingObserver()
        // 計測の試行ごとに同じキャッシュ状態から始めるための消去。配布する構成では何も起きない。
        resetImageCacheForMeasurement(
            intent?.getBooleanExtra(SampleRoutes.ResetImageCacheExtra, false) == true,
        )
        // 計数は Activity より長く生きるため、入口で必ず初期状態に戻す。前の Activity で
        // 数えた値や切った観測区間が残っていると、印とログの突き合わせに混ざる。
        ImageLoadingSlotCounter.reset()
        // 読み込み中を数えるのは要求された実行だけ。要求が無ければ本体の既定の表示を通す。
        ImageLoadingSlotCounter.setEnabled(
            intent?.getBooleanExtra(SampleRoutes.CountImageLoadingSlotsExtra, false) == true,
        )
        val startRoute = intent?.getStringExtra(SampleRoutes.StartRouteExtra)
        val requestedPrefetch = ImagePrefetchChoice.fromArgument(
            intent?.getStringExtra(SampleRoutes.PrefetchExtra),
        )
        setContent {
            MaterialTheme {
                SampleNavHost(startRoute = startRoute, requestedPrefetch = requestedPrefetch)
            }
        }
    }
}
