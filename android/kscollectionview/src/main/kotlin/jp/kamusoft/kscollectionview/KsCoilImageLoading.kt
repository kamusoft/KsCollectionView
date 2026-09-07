package jp.kamusoft.kscollectionview

import android.content.Context
import coil3.SingletonImageLoader
import coil3.annotation.ExperimentalCoilApi
import coil3.decode.BlackholeDecoder
import coil3.request.CachePolicy
import coil3.request.ImageRequest
import coil3.request.allowHardware

/**
 * 受け口を Coil の操作へ写像する adapter。取得は共有インスタンス (singleton の ImageLoader) に
 * 出すため、ライブラリ独自のキャッシュ領域は持たない (core/ADR-0012)。
 *
 * 到達点の写像:
 * - [KsPrefetchDestination.Disk] — メモリキャッシュを使わず、デコードもしない要求にする。
 *   元データだけがディスクキャッシュに残る
 * - [KsPrefetchDestination.Memory] — 元データをディスクに残した上で、デコードした画像を
 *   メモリキャッシュにも載せる。載せる画像は表示側 ([KsImageRequestFactory]) がその場で
 *   枠の大きさへ縮小する材料になるため、画素を読み出せる構成でデコードさせる
 *
 * プリフェッチの要求には表示サイズを付けない (元寸のまま取得する)。表示時の制約付きの要求は、
 * この元寸のキャッシュ項目から作られる。
 */
internal class KsCoilImageLoading(private val context: Context) : KsImageLoading {

    // デコードを省くための Decoder は Coil で experimental 扱いだが、使うのはこの 1 箇所だけで、
    // 公開面にも Coil の型は現れない。
    @OptIn(ExperimentalCoilApi::class)
    override fun enqueue(url: String, destination: KsPrefetchDestination): KsImageRequestHandle {
        val builder = ImageRequest.Builder(context).data(url)
        when (destination) {
            KsPrefetchDestination.Disk ->
                builder
                    .memoryCachePolicy(CachePolicy.DISABLED)
                    .decoderFactory(BlackholeDecoder.Factory())

            // 端末のデコードは既定でグラフィックス側に画素を置く構成を選ぶことがあり、その
            // 画像は画素を読み出せないため表示側で枠の大きさへ縮小できない。縮小の材料に
            // するには、読み出せる構成でデコードさせる必要がある。
            KsPrefetchDestination.Memory -> builder.allowHardware(false)
        }
        val disposable = SingletonImageLoader.get(context).enqueue(builder.build())
        return KsImageRequestHandle { disposable.dispose() }
    }
}
