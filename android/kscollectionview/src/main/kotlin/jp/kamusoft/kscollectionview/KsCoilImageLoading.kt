package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import coil3.SingletonImageLoader
import coil3.annotation.ExperimentalCoilApi
import coil3.decode.BlackholeDecoder
import coil3.request.CachePolicy
import coil3.request.ImageRequest

/**
 * 受け口を Coil の操作へ写像する adapter。取得は共有インスタンス (singleton の ImageLoader) に
 * 出すため、ライブラリ独自のキャッシュ領域は持たない (core/ADR-0012)。
 *
 * 到達点の写像:
 * - [KsPrefetchDestination.Disk] — メモリキャッシュを使わず、デコードもしない要求にする。
 *   元データだけがディスクキャッシュに残る
 * - [KsPrefetchDestination.Memory] — 元データをディスクに残した上で、デコードした画像を
 *   メモリキャッシュにも載せる。画素の置き場はローダーと端末の判断に委ね、こちらからは
 *   指定しない
 *
 * 到達点メモリで載る画像の画素は、実機では通常グラフィックス側 ([Bitmap.Config.HARDWARE]) に
 * 置かれ、その画像は読み出せない。表示側 ([KsImageRequestFactory]) は読み出せない元寸を初回の
 * 描画に使わず、ローダーの縮小デコードを待つ (読み込み中の表示を一瞬経由する)。画素が
 * ソフトウェア側に置かれる環境 (エミュレータ・JVM 上のテスト) では、表示側がその場で縮小して
 * 即座に描く。実機でも、ローダーは端末の資源が逼迫するとグラフィックス側への配置を自ら止めるため、
 * どちらになるかは端末とローダーの判断による。ハードウェア支援を切って挙動を揃えることはしない — 切ると描画のたびに
 * 画素の転送費用が乗り、スクロールの滑らかさを損なうため。
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

            // 到達点メモリは既定のまま取得する。デコード済みの画像は既定でメモリキャッシュへ
            // 載るため、足す指定は無い。
            KsPrefetchDestination.Memory -> Unit
        }
        val disposable = SingletonImageLoader.get(context).enqueue(builder.build())
        return KsImageRequestHandle { disposable.dispose() }
    }
}
