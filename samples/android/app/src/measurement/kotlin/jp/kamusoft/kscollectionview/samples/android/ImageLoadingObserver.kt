package jp.kamusoft.kscollectionview.samples.android

import android.os.SystemClock
import android.util.Log
import java.util.concurrent.atomic.AtomicInteger
import coil3.EventListener
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.decode.DecodeResult
import coil3.decode.Decoder
import coil3.fetch.FetchResult
import coil3.fetch.Fetcher
import coil3.fetch.SourceFetchResult
import coil3.request.CachePolicy
import coil3.request.ErrorResult
import coil3.request.ImageRequest
import coil3.request.Options
import coil3.request.SuccessResult
import coil3.size.Precision
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
 *
 * 共有インスタンスは最初の読み込みの時点で作られる。それまでに [ImageLoadingNetworkOverride] へ
 * 同一ホストの同時取得数が指定されていれば、その値の取得経路で作る (取得の並行度の対照計測用)。
 */
fun installImageLoadingObserver() {
    SingletonImageLoader.setSafe { context ->
        val builder = ImageLoader.Builder(context).eventListener(LoggingEventListener)
        ImageLoadingNetworkOverride.maxRequestsPerHost?.let { limit ->
            builder.components { add(ImageLoadingNetworkOverride.fetcherFactory(limit)) }
            Log.i(ImageLoadingObserveTag, "network maxRequestsPerHost=$limit")
        }
        builder.build()
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
     * 表示幅を宣言した、到達点がメモリまでの先読み。寸法つきの鍵 (`coil#size`) を持ち、寸法の一致を
     * 求めない指定 (`Precision.INEXACT`) で出る。寸法つきの鍵は表示要求 (KsImage) も持つが、表示要求は
     * 寸法の一致を求める指定 (`Precision.EXACT`) なので、この組み合わせで見分けられる。
     */
    const val WidthPrefetch: String = "width-prefetch"

    /**
     * 表示要求か、表示幅の無い到達点メモリまでの先読みのどちらか。**この 2 つは要求からは
     * 区別できないものとして扱う。**
     *
     * 表示要求 (KsImage) は寸法の一致を求める指定 (`Precision.EXACT`) を持つが、これは要求の
     * 既定値でもあるため先読みの要求も同じ値になる。ローダー付属のビュー (`AsyncImage`) を
     * 直接使った表示も同じ形になる。メモリの項目を引き当てた KsImage は要求を出さないため、
     * ここには現れない。
     */
    const val DisplayOrMemoryPrefetch: String = "display-or-memory-prefetch"

    /** 寸法つきの鍵に付く付随情報の名前。本体が表示と幅つきの先読みの鍵に付ける。 */
    private const val SizeExtra: String = "coil#size"

    /**
     * 要求の種別を決める。副作用を持たない純粋な写像で、テストから直接確かめられる。
     *
     * @param request 観測した要求
     */
    fun of(request: ImageRequest): String = when {
        request.memoryCachePolicy == CachePolicy.DISABLED -> PrefetchDisk
        request.memoryCacheKeyExtras.containsKey(SizeExtra) &&
            request.precision == Precision.INEXACT -> WidthPrefetch
        else -> DisplayOrMemoryPrefetch
    }
}

/**
 * 読み込みの節目を 1 行ずつ logcat へ出す観測者。
 *
 * 要求の種別は [ImageRequestKind] が決める。判定の根拠になった値も同じ行に出すため、
 * 分けきれない分は記録した値から人が読み解ける。
 *
 * 取得 (fetch) とデコード (decode) の開始・終了も出す。要求の開始から取得の開始までは
 * ローダーの中の待ち、取得の開始から終了までは取得経路の待ち (同時取得数の上限による待ちと
 * 通信) にあたるため、表示が揃うまでの時間の内訳をこの時刻から読める。各行の `t=` は
 * 起動からの経過 (ミリ秒、[SystemClock.uptimeMillis]) で、画面側の観測 ([ImageObserveScreen]) の
 * 行と同じ時計で突き合わせられる。`keyExtras=` はメモリの鍵に付いた付随情報の名前で、表示要求
 * (当てはめ方の付随情報を持つ) と幅の無い先読み (付随情報を持たない) をここで見分けられる。
 */
private object LoggingEventListener : EventListener() {

    override fun onStart(request: ImageRequest) {
        ImageLoadingInFlight.started()
        log("start", request)
    }

    override fun onCancel(request: ImageRequest) {
        ImageLoadingInFlight.finished()
        log("cancel", request)
    }

    override fun fetchStart(request: ImageRequest, fetcher: Fetcher, options: Options) {
        log("fetchStart", request)
    }

    override fun fetchEnd(
        request: ImageRequest,
        fetcher: Fetcher,
        options: Options,
        result: FetchResult?,
    ) {
        val source = (result as? SourceFetchResult)?.dataSource
        log("fetchEnd", request, "source=$source")
    }

    override fun decodeStart(request: ImageRequest, decoder: Decoder, options: Options) {
        log("decodeStart", request)
    }

    override fun decodeEnd(
        request: ImageRequest,
        decoder: Decoder,
        options: Options,
        result: DecodeResult?,
    ) {
        val image = result?.image
        log("decodeEnd", request, "px=${image?.width}x${image?.height}")
    }

    override fun onSuccess(request: ImageRequest, result: SuccessResult) {
        ImageLoadingInFlight.finished()
        // どの層に当たったかは、プリフェッチが効いているかの判定にそのまま使える。
        log("success", request, "source=${result.dataSource}")
    }

    override fun onError(request: ImageRequest, result: ErrorResult) {
        ImageLoadingInFlight.finished()
        log("error", request)
    }

    private fun log(event: String, request: ImageRequest, extra: String = "") {
        val kind = ImageRequestKind.of(request)
        val suffix = if (extra.isEmpty()) "" else " $extra"
        val keyExtras = request.memoryCacheKeyExtras.keys.sorted().joinToString(",")
        Log.i(
            ImageLoadingObserveTag,
            "$event t=${SystemClock.uptimeMillis()} kind=$kind$suffix keyExtras=[$keyExtras] " +
                "prec=${request.precision} mem=${request.memoryCachePolicy} data=${request.data}",
        )
    }
}

/**
 * 進行中の読み込みの数。開始で増え、成功・失敗・取り消しで減る。
 *
 * メモリの往復を「表示と先読みの読み込みが落ち着いてから次へ進む」形で走らせるときに、
 * 落ち着いたことの判定に使う。
 */
object ImageLoadingInFlight {
    private val count = AtomicInteger()

    /** いま進行中の読み込みの数。 */
    val current: Int get() = count.get()

    /** 読み込みが 1 つ始まった。 */
    fun started() {
        count.incrementAndGet()
    }

    /** 読み込みが 1 つ終わった。 */
    fun finished() {
        count.decrementAndGet()
    }
}

/**
 * 取得経路の同一ホストの同時取得数を、計測のために既定から変える指定。
 *
 * 既定の取得経路 (OkHttp) は同一ホストへの同時取得を 5 件に制限する。表示が揃うまでの時間が
 * この上限で決まっているかを対照計測で確かめるため、上限だけを変えた取得経路を作れるようにする。
 * 取得経路の型は本体の実装の依存で、この構成のコンパイル対象には現れないため、実行時に名前で
 * 組み立てる。指定が無い (null) ときは既定の取得経路のままにする。
 *
 * 共有インスタンスは最初の読み込みで作られるため、指定はそれより前に行う必要がある。
 */
object ImageLoadingNetworkOverride {
    /** 同一ホストの同時取得数の上限。null なら既定のまま。 */
    @Volatile
    var maxRequestsPerHost: Int? = null

    /**
     * 同時取得数の上限だけを変えた取得経路を作る。
     *
     * @param limit 同一ホストの同時取得数の上限
     */
    fun fetcherFactory(limit: Int): Fetcher.Factory<coil3.Uri> {
        val dispatcherClass = Class.forName("okhttp3.Dispatcher")
        val dispatcher = dispatcherClass.getConstructor().newInstance()
        dispatcherClass.getMethod("setMaxRequestsPerHost", Int::class.javaPrimitiveType)
            .invoke(dispatcher, limit)
        // 全体の上限 (既定 64) が同一ホストの上限より小さいと、そちらで頭打ちになる。
        dispatcherClass.getMethod("setMaxRequests", Int::class.javaPrimitiveType)
            .invoke(dispatcher, maxOf(limit, 64))
        val builderClass = Class.forName("okhttp3.OkHttpClient\$Builder")
        val builder = builderClass.getConstructor().newInstance()
        builderClass.getMethod("dispatcher", dispatcherClass).invoke(builder, dispatcher)
        val client = builderClass.getMethod("build").invoke(builder)
        val callFactory: () -> Any = { client!! }
        val factory = Class.forName("coil3.network.okhttp.OkHttpNetworkFetcher")
            .getMethod("factory", Function0::class.java)
            .invoke(null, callFactory)
        @Suppress("UNCHECKED_CAST")
        return factory as Fetcher.Factory<coil3.Uri>
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
