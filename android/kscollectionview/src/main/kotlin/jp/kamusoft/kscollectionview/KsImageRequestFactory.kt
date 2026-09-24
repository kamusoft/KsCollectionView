package jp.kamusoft.kscollectionview

import android.content.Context
import coil3.Image
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.memory.MemoryCache
import coil3.request.ImageRequest
import coil3.size.Precision
import coil3.size.Scale
import coil3.size.Size

/** 表示に使う要求と、メモリから引き当てた画像の組。 */
internal data class KsPreparedImageRequest(
    /** 引き当てに失敗したときにローダーへ出す、枠の実サイズへ縮小してデコードする要求。 */
    val request: ImageRequest,
    /** [request] がローダーのメモリへ載せる項目の鍵。要求を出す時点で索引に覚えさせる。 */
    val displayKey: MemoryCache.Key,
    /**
     * メモリから引き当てた、枠にそのまま使える画像。あれば表示はこれで完了し、ローダーへは
     * 要求を出さない。無ければ null で、[request] を出して読み込み中の表示から始まる。
     */
    val matchedImage: Image?,
    /**
     * 引き当てに失敗し、同じ識別子の先読みがまだ取得中で、その項目がまだメモリに無いか。少し待てば
     * 引き当てられる見込みがあることを表す。完了・失敗・取り消し・追い出し済みの先読みは含まない。
     * 引き当てたときと、ローダーのメモリキャッシュが無いときは false。
     */
    val prefetchPending: Boolean = false,
)

/**
 * 表示側の要求を組み立てる。
 *
 * 表示枠の実サイズが確定してから、まずライブラリが把握しているメモリの項目を引き当て、使えるものが
 * 無いときだけ枠の実サイズへ縮小してデコードする要求を作る。縮小はデコード時に行うため、元寸の
 * 画像はメモリに展開されない。
 *
 * 引き当ては、索引 ([KsImageMemoryIndex]) が覚えている同じ識別子の鍵をローダーのメモリキャッシュへ
 * 問い合わせ、返った画像の実物の寸法が枠に対して許容範囲の内側にあるものを選ぶ ([KsImageMatching])。
 * 画素を読んで縮小し直すことはしないので、画素がグラフィックス側に置かれた (読み出せない) 画像でも
 * 成立する。
 */
internal object KsImageRequestFactory {

    /**
     * 表示枠の大きさと当てはめ方から要求を組み立て、あわせてメモリから枠にそのまま使える画像を
     * 引き当てる。ローダーを通さないソースと、大きさが未確定 (0 以下) の間は null を返す。
     *
     * 引き当てに失敗したときは、返す要求の鍵を索引に覚えさせる (呼び出し側がその要求をすぐに出す
     * 前提)。要求をすぐには出さない呼び出し側は [lookup] で組み立て、出す時点で [markRequested] を呼ぶ。
     */
    fun prepare(
        context: Context,
        source: KsImageSource,
        width: Int,
        height: Int,
        contentMode: KsImageContentMode,
        loader: ImageLoader = SingletonImageLoader.get(context),
        index: KsImageMemoryIndex = KsImageMemoryIndex.shared,
    ): KsPreparedImageRequest? {
        val prepared = lookup(context, source, width, height, contentMode, loader, index)
        if (prepared != null && prepared.matchedImage == null) markRequested(prepared, index)
        return prepared
    }

    /**
     * [prepare] と同じく要求を組み立てて引き当てるが、索引には何も覚えさせない。
     *
     * 画面に出る前に組み立てられた表示は、ここで引き当てを試すだけにして要求を出さない。要求を
     * 出すのは画面に出る時点で、そのときに [markRequested] を呼ぶ。完了前の鍵は問い合わせで
     * 空になるだけで候補にならない。
     */
    fun lookup(
        context: Context,
        source: KsImageSource,
        width: Int,
        height: Int,
        contentMode: KsImageContentMode,
        loader: ImageLoader = SingletonImageLoader.get(context),
        index: KsImageMemoryIndex = KsImageMemoryIndex.shared,
    ): KsPreparedImageRequest? {
        val identifier = source.identifier ?: return null
        if (width <= 0 || height <= 0) return null

        val size = Size(width, height)
        val displayKey = KsImageIdentity.displayKey(identifier, size, contentMode)
        val builder = ImageRequest.Builder(context)
            .data(source.loaderModel())
            .size(size)
            .scale(contentMode.toCoilScale())
            // 枠の大きさへ確実に収めるため、寸法の一致を求める。緩めると縮小されていない
            // 項目が表示サイズと無関係に使われる。
            .precision(Precision.EXACT)
            .memoryCacheKey(displayKey)
        // キーのある画像は、ディスクの項目もキーで見分ける。キーの無い画像はローダーの既定
        // (URL) のままにして、ローダー付属のビューと同じ項目を共有する。
        if (source.hasKey) builder.diskCacheKey(identifier)
        val request = builder.build()

        val memory = loader.memoryCache
        if (memory != null) {
            val entries = index.cachedEntries(identifier, memory)
            val best = KsImageMatching.bestMatch(
                imageSizes = entries.map { (_, image) -> image.width to image.height },
                frameWidth = width,
                frameHeight = height,
                contentMode = contentMode,
            )
            if (best != null) {
                val (key, image) = entries[best]
                index.markUsed(key)
                return KsPreparedImageRequest(request, displayKey, image)
            }
            val prefetchPending = index.hasFetchInFlight(identifier, memory)
            return KsPreparedImageRequest(request, displayKey, null, prefetchPending)
        }
        return KsPreparedImageRequest(request, displayKey, null)
    }

    /** 要求をローダーへ出す時点で、その要求が載せる項目の鍵を索引に覚えさせる。 */
    fun markRequested(
        prepared: KsPreparedImageRequest,
        index: KsImageMemoryIndex = KsImageMemoryIndex.shared,
    ) {
        index.register(prepared.displayKey)
    }
}

/** 当てはめ方をローダーの縮小の基準へ対応させる。 */
internal fun KsImageContentMode.toCoilScale(): Scale = when (this) {
    KsImageContentMode.Fit -> Scale.FIT
    KsImageContentMode.Fill -> Scale.FILL
}
