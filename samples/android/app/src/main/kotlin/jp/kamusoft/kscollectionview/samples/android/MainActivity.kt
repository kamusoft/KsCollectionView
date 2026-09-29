package jp.kamusoft.kscollectionview.samples.android

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

/**
 * Sample の入口。
 *
 * 起動時の追加情報で経路を指定できる。計測は人の操作を挟まずに目的の画面を開く必要があるため、
 * この入口を使う。
 *
 * ルートメニューで選ぶ外観 ([SampleAppearance]) は、この Activity の Configuration の上書きで反映する。
 * 選択が変わったら Activity を作り直し、上書きを [attachBaseContext] からやり直す。作り直しは画面回転と
 * 同じ経路 (保存した状態を引き継ぐ作り直し) を通るため、[onCreate] の計測用の初期化と開始ルートの
 * 扱いも回転時と同じになる。
 */
class MainActivity : ComponentActivity() {
    /**
     * 保存済みの外観に応じて、この Activity の Configuration に夜間モードを上書きする。
     *
     * 上書きは Resources を最初に読む前に済ませる必要があるため、`super` の直後で行う。
     */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(newBase)
        SampleAppearanceStore.nightModeOverride(newBase)?.let { applyOverrideConfiguration(it) }
    }

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
        // 遅延の指定が受け取れないときは、既定の遅延へ黙って戻さずに起動を止める。
        val pagingDelayMilliseconds = PagingDelay.millisecondsOrFail(
            PagingDelay.resolve(readExtra(SampleRoutes.PagingDelayExtra)),
        )
        // 選択が変わるのは作り直しを挟むときだけなので、作るたびに 1 回読めばよい。
        val appearance = SampleAppearanceStore.load(this)
        setContent {
            SampleAppTheme {
                SampleNavHost(
                    startRoute = startRoute,
                    requestedPrefetch = requestedPrefetch,
                    pagingDelayMilliseconds = pagingDelayMilliseconds,
                    appearance = appearance,
                    onSelectAppearance = ::selectAppearance,
                )
            }
        }
    }

    /**
     * 起動の追加情報の値を型によらずに読む。整数 (`--ei`) と文字列 (`-e`) のどちらの指定も受け取るため、
     * 型を決めて読む取り出し方は使わない。
     */
    @Suppress("DEPRECATION")
    private fun readExtra(key: String): Any? = intent?.extras?.get(key)

    /** 外観を選び直す。同じ外観なら何もしない (作り直すと画面の状態を無駄に作り直すため)。 */
    private fun selectAppearance(appearance: SampleAppearance) {
        if (appearance == SampleAppearanceStore.load(this)) return
        SampleAppearanceStore.save(this, appearance)
        // 上書きは attachBaseContext でしか差し替えられないため、Activity を作り直す。
        recreate()
    }
}
