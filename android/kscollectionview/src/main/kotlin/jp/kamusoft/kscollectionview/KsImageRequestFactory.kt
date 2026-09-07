package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import coil3.BitmapImage
import coil3.Image
import coil3.SingletonImageLoader
import coil3.asImage
import coil3.decode.DecodeUtils
import coil3.memory.MemoryCache
import coil3.request.ImageRequest
import coil3.size.Precision
import coil3.size.Scale
import coil3.size.Size
import coil3.toBitmap
import kotlin.math.roundToInt

/** 表示に使う要求と、組み立ての時点でメモリから同期で取り出せた画像の組。 */
internal data class KsPreparedImageRequest(
    /** ローダーへ出す要求。 */
    val request: ImageRequest,
    /**
     * ローダーの応答を待たずにそのまま描ける画像。メモリに何も無ければ null で、
     * その場合だけ読み込み中の表示から始まる。
     */
    val cachedImage: Image?,
)

/**
 * 表示側の要求を組み立てる。
 *
 * 表示枠の実サイズが確定してから、その大きさへ縮小してデコードする要求を作る。要求には
 * 表示サイズを含む鍵を付けるため、同じ取得元でも表示サイズごとに別のキャッシュ項目になる。
 *
 * 先読みは寸法を付けない要求で元寸をメモリへ載せるので、表示に使う鍵とは一致しない。
 * そのままでは元寸をそのまま描くか、取得しなおすかのどちらかになるため、[prepare] は
 * 元寸の項目をその場で枠の大きさへ縮小し、表示に使う鍵へ載せ直す。取得もデコードも
 * やり直さず、以後の表示は表示サイズ付きの鍵で当たる。
 */
internal object KsImageRequestFactory {

    /**
     * 鍵に表示サイズを載せるための付随情報の名前。
     *
     * ローダーは鍵に載った表示サイズと要求の表示サイズが食い違う項目を捨てるため、
     * ローダーが見るのと同じ名前でなければ、載せた項目が使われないまま捨てられる。
     */
    private const val SizeExtra: String = "coil#size"

    /**
     * 鍵に当てはめ方を載せるための付随情報の名前。同じ枠でも fit と fill では縮小後の寸法が
     * 違うため、これが無いと先に作られた側の画像がもう一方でも使われてしまう。
     */
    private const val ScaleExtra: String = "ks#scale"

    /**
     * 表示枠の大きさと当てはめ方から要求を組み立て、初回の描画に使える画像を同期で用意する。
     *
     * ローダーを通さないソースと、大きさが未確定 (0 以下) の間は null を返す。
     */
    fun prepare(
        context: Context,
        source: KsImageSource,
        width: Int,
        height: Int,
        contentMode: KsImageContentMode,
    ): KsPreparedImageRequest? {
        val cacheKey = source.cacheKey ?: return null
        if (width <= 0 || height <= 0) return null

        val size = Size(width, height)
        val scale = contentMode.toCoilScale()
        val displayKey = MemoryCache.Key(
            cacheKey,
            mapOf(SizeExtra to size.toString(), ScaleExtra to scale.name),
        )
        val request = ImageRequest.Builder(context)
            .data(source.loaderModel())
            .size(size)
            .scale(scale)
            // 枠の大きさへ確実に収めるため、寸法の一致を求める。緩めると縮小されていない
            // 項目が表示サイズと無関係に使われる。
            .precision(Precision.EXACT)
            .memoryCacheKey(displayKey)
            .build()

        val memory = SingletonImageLoader.get(context).memoryCache
            ?: return KsPreparedImageRequest(request, null)

        // この大きさで縮小済みの画像が既にあるなら、それをそのまま初回の描画に使う。
        memory.get(displayKey)?.image?.let { return KsPreparedImageRequest(request, it) }

        // 先読みが載せた元寸の項目。寸法を付けない要求なので鍵は取得元の文字列そのものになる。
        val original = memory.get(MemoryCache.Key(cacheKey))?.image
            ?: return KsPreparedImageRequest(request, null)

        return when (val result = downscale(original, width, height, scale)) {
            is KsDownscaleResult.Done -> {
                memory.set(displayKey, MemoryCache.Value(result.image))
                KsPreparedImageRequest(request, result.image)
            }

            // 枠より小さい画像は縮小しない。ローダーが読み直しを決めるまでの間は元の大きさで描く。
            KsDownscaleResult.NotNeeded -> KsPreparedImageRequest(request, original)

            // 画素を読み出せない画像はその場で縮小できない。元の大きさのまま描くと表示に使う
            // 画像が枠を超えてしまうため、初回の描画には使わずローダーの縮小デコードを待つ。
            KsDownscaleResult.Unreadable -> KsPreparedImageRequest(request, null)
        }
    }

    /**
     * 元寸の画像から、当てはめ方に応じた寸法の画像をその場で作る。
     * fit は枠に収まる最大、fill は枠を覆う最小になる。
     */
    private fun downscale(
        image: Image,
        width: Int,
        height: Int,
        scale: Scale,
    ): KsDownscaleResult {
        val sourceWidth = image.width
        val sourceHeight = image.height
        if (sourceWidth <= 0 || sourceHeight <= 0) return KsDownscaleResult.NotNeeded

        val multiplier = DecodeUtils.computeSizeMultiplier(
            srcWidth = sourceWidth,
            srcHeight = sourceHeight,
            dstWidth = width,
            dstHeight = height,
            scale = scale,
            maxSize = Size.ORIGINAL,
        )
        if (multiplier >= 1.0) return KsDownscaleResult.NotNeeded
        if (!image.isPixelReadable()) return KsDownscaleResult.Unreadable

        val targetWidth = (sourceWidth * multiplier).roundToInt().coerceAtLeast(1)
        val targetHeight = (sourceHeight * multiplier).roundToInt().coerceAtLeast(1)
        return KsDownscaleResult.Done(image.toBitmap(targetWidth, targetHeight).asImage())
    }
}

/** 元寸の画像をその場で縮小しようとした結果。 */
private sealed interface KsDownscaleResult {

    /** 縮小した画像ができた。 */
    data class Done(val image: Image) : KsDownscaleResult

    /** 枠より小さいため縮小する必要が無い。 */
    data object NotNeeded : KsDownscaleResult

    /** 画素を読み出せないため縮小できない。 */
    data object Unreadable : KsDownscaleResult
}

/**
 * その場での縮小に使えるよう画素を読み出せる画像かどうか。
 *
 * 端末のデコードはグラフィックス側に置く構成 ([Bitmap.Config.HARDWARE]) を選ぶことがあり、
 * その画像は画素を読み出せないため、縮小しようとすると実行時に落ちる。読み出せるのは
 * ソフトウェア側の構成の画像と、ビットマップを持たない画像 (図形など) に限られる。
 */
private fun Image.isPixelReadable(): Boolean =
    this !is BitmapImage || bitmap.config != Bitmap.Config.HARDWARE

/** 当てはめ方をローダーの縮小の基準へ対応させる。 */
internal fun KsImageContentMode.toCoilScale(): Scale = when (this) {
    KsImageContentMode.Fit -> Scale.FIT
    KsImageContentMode.Fill -> Scale.FILL
}
