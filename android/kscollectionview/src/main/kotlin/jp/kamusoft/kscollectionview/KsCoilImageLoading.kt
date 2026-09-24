package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import coil3.SingletonImageLoader
import coil3.annotation.ExperimentalCoilApi
import coil3.decode.BlackholeDecoder
import coil3.request.CachePolicy
import coil3.request.ImageRequest
import coil3.size.Precision
import coil3.size.Scale

/**
 * 受け口を Coil の操作へ写像する adapter。取得は共有インスタンス (singleton の ImageLoader) に
 * 出すため、ライブラリ独自のキャッシュ領域は持たない (core/ADR-0012)。
 *
 * 到達点の写像:
 * - [KsPrefetchDestination.Disk] — メモリキャッシュを使わず、デコードもしない要求にする。
 *   元データだけがディスクキャッシュに残る。幅は使わない
 * - [KsPrefetchDestination.Memory] — 元データをディスクに残した上で、デコードした画像を
 *   メモリキャッシュにも載せる。幅があればその幅の正方形を覆う最小の大きさに縮小してデコードし
 *   (元が小さければ拡大しない)、幅が無ければ元の大きさのまま載せる
 *
 * メモリまで載せる要求は、表示のときに引き当てられるよう出した時点で鍵を索引
 * ([KsImageMemoryIndex]) に覚えさせる。完了は待たない。あわせて取得中であることを索引に数えさせ、
 * 完了・失敗・取り消しの時点で外す。表示は取得中の先読みがある画像に限って要求を遅らせる。
 *
 * 画素の置き場はローダーと端末の判断に委ね、こちらからは指定しない。実機では通常グラフィックス側
 * ([Bitmap.Config.HARDWARE]) に置かれて画素を読み出せないが、表示側の引き当ては画素を読まないため
 * そのまま使える。ハードウェア支援を切って挙動を揃えることはしない — 切ると描画のたびに画素の
 * 転送費用が乗り、スクロールの滑らかさを損なうため。
 */
internal class KsCoilImageLoading(
    private val context: Context,
    private val index: KsImageMemoryIndex = KsImageMemoryIndex.shared,
) : KsImageLoading {

    // デコードを省くための Decoder は Coil で experimental 扱いだが、使うのはこの 1 箇所だけで、
    // 公開面にも Coil の型は現れない。
    @OptIn(ExperimentalCoilApi::class)
    override fun enqueue(
        request: KsPrefetchRequest,
        destination: KsPrefetchDestination,
    ): KsImageRequestHandle {
        val builder = ImageRequest.Builder(context).data(request.url)
        var endFetch: () -> Unit = {}
        // キーのある画像は、ディスクの項目もキーで見分ける。
        if (request.key != null) builder.diskCacheKey(request.identifier)
        when (destination) {
            KsPrefetchDestination.Disk ->
                builder
                    .memoryCachePolicy(CachePolicy.DISABLED)
                    .decoderFactory(BlackholeDecoder.Factory())

            KsPrefetchDestination.Memory -> {
                val widthPixels = request.widthPixels
                if (widthPixels != null) {
                    // 幅の正方形を覆う最小の大きさにする。寸法の一致を求めない指定にすると、
                    // 元が小さいときに拡大しない。
                    builder
                        .size(widthPixels, widthPixels)
                        .scale(Scale.FILL)
                        .precision(Precision.INEXACT)
                }
                // 幅もキーも無い要求は鍵をローダーの既定 (URL) のままにして、ローダー付属のビューと
                // 同じ項目を共有する。どちらかがあれば、識別子と幅で決まる鍵を付けて索引から
                // 引き当てられるようにする (表示の要求の鍵とは当てはめ方の有無で重ならない)。
                if (widthPixels != null || request.key != null) {
                    builder.memoryCacheKey(request.memoryKey)
                }
                index.register(request.memoryKey)
                val end = index.beginFetch(request.memoryKey)
                endFetch = end
                // 取得の終わりはどの形でも外す。始まる前に取り消された要求には通知が来ないため、
                // 取り消しの取っ手でも外す (2 度目は何もしない)。
                builder.listener(
                    onCancel = { end() },
                    onError = { _, _ -> end() },
                    onSuccess = { _, _ -> end() },
                )
            }
        }
        val disposable = SingletonImageLoader.get(context).enqueue(builder.build())
        return KsImageRequestHandle {
            disposable.dispose()
            endFetch()
        }
    }
}
