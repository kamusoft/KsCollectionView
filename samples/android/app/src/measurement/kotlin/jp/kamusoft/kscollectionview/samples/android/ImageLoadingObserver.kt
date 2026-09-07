package jp.kamusoft.kscollectionview.samples.android

import android.util.Log
import coil3.EventListener
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.request.CachePolicy
import coil3.request.ErrorResult
import coil3.request.ImageRequest
import coil3.request.SuccessResult
import jp.kamusoft.kscollectionview.KsImageCache
import jp.kamusoft.kscollectionview.KsImageCacheScope

/** 観測した読み込みを logcat に出すときのタグ。計測側はこのタグの行を数える。 */
const val ImageLoadingObserveTag: String = "KsImageObserve"

/**
 * 画像の読み込みを観測できるようにする。
 *
 * 共有インスタンスの ImageLoader に観測用の EventListener を付けて置き換える。プリフェッチも
 * 表示も同じ共有インスタンスを通るため、開始・取り消し・成功 (どの層に当たったか) を 1 箇所で
 * 数えられる。付けるのは通知だけで、キャッシュや取得の構成は既定のままにする。
 *
 * 配布する構成には入らない。呼ぶのは最初の読み込みより前 (入口の生成時) でなければならない。
 */
fun installImageLoadingObserver() {
    SingletonImageLoader.setSafe { context ->
        ImageLoader.Builder(context)
            .eventListener(LoggingEventListener)
            .build()
    }
}

/**
 * 観測した要求に付ける種別。
 *
 * 要求に付いた指定だけで見分けられる範囲でしか分けない。**区別できない組み合わせは、
 * 区別できないことが分かる名前を出す** (単一の種別を出すと、集計する側が実態と違う数を
 * 確定値として読んでしまう)。
 */
internal object ImageRequestKind {

    /** 到達点をディスクまでにした先読み。メモリキャッシュを使わない指定でこれだけが分かれる。 */
    const val PrefetchDisk: String = "prefetch-disk"

    /**
     * 表示要求か、到達点をメモリまでにした先読みのどちらか。**この 2 つは要求からは区別できない。**
     *
     * 表示要求 (KsImage) は寸法の一致を求める指定 (`Precision.EXACT`) を持つが、これは要求の
     * 既定値でもあるため先読みの要求も同じ値になる。ローダー付属のビュー (`AsyncImage`) を
     * 直接使った表示も同じ形になる。
     */
    const val DisplayOrMemoryPrefetch: String = "display-or-memory-prefetch"

    /**
     * 要求の種別を決める。副作用を持たない純粋な写像で、テストから直接確かめられる。
     *
     * @param request 観測した要求
     */
    fun of(request: ImageRequest): String = when (request.memoryCachePolicy) {
        CachePolicy.DISABLED -> PrefetchDisk
        else -> DisplayOrMemoryPrefetch
    }
}

/**
 * 読み込みの節目を 1 行ずつ logcat へ出す観測者。
 *
 * 要求の種別は [ImageRequestKind] が決める。判定の根拠になった値も同じ行に出すため、
 * 分けきれない分は記録した値から人が読み解ける。
 */
private object LoggingEventListener : EventListener() {

    override fun onStart(request: ImageRequest) {
        log("start", request)
    }

    override fun onCancel(request: ImageRequest) {
        log("cancel", request)
    }

    override fun onSuccess(request: ImageRequest, result: SuccessResult) {
        // どの層に当たったかは、プリフェッチが効いているかの判定にそのまま使える。
        log("success", request, "source=${result.dataSource}")
    }

    override fun onError(request: ImageRequest, result: ErrorResult) {
        log("error", request)
    }

    private fun log(event: String, request: ImageRequest, extra: String = "") {
        val kind = ImageRequestKind.of(request)
        val suffix = if (extra.isEmpty()) "" else " $extra"
        Log.i(
            ImageLoadingObserveTag,
            "$event kind=$kind$suffix prec=${request.precision} " +
                "mem=${request.memoryCachePolicy} data=${request.data}",
        )
    }
}

/**
 * 計測の前処理として画像キャッシュを空にする。
 *
 * 画像の計測は試行ごとにキャッシュの状態を揃えないと、試行が進むほどディスクとメモリが温まり
 * 独立した試行にならない。本ライブラリの計測は**すべての試行を空の状態 (cold) から**始める
 * 取り決めにしており、その状態を作るのがこの処理である (取り決めは計測の証跡に明記する)。
 *
 * 消去はメモリとディスクの両方を対象にする。ディスク上の元データは処理が終わっても残るため、
 * メモリだけを消しても次の試行は温まったままになる。
 *
 * 配布する構成には入らない。呼ぶのは最初の読み込みより前 (入口の生成時) でなければならない。
 *
 * @param requested 消去が要求されたかどうか
 */
fun resetImageCacheForMeasurement(requested: Boolean) {
    if (!requested) return
    KsImageCache.clear(KsImageCacheScope.All)
    Log.i(ImageLoadingObserveTag, "resetImageCache scope=All")
}
