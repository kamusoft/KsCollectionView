package jp.kamusoft.kscollectionview

import androidx.compose.runtime.staticCompositionLocalOf
import coil3.memory.MemoryCache
import coil3.size.Size

/**
 * 画像ローダーへの操作を集めた内部の受け口。本番は [KsCoilImageLoading]、テストは記録用の
 * 実装を [LocalKsImageLoading] から差し込む。
 *
 * 取得単位より上の寿命管理 (アイテムとの対応・参照数) は [KsImagePrefetchWindow] が持ち、
 * この受け口には取得を始めたときの要求が 1 件ずつ届く。
 */
internal interface KsImageLoading {
    /**
     * 到達点を指定して取得を始め、その取得を取り消すための取っ手を返す。
     */
    fun enqueue(request: KsPrefetchRequest, destination: KsPrefetchDestination): KsImageRequestHandle
}

/** 進行中の取得を取り消すための取っ手。完了してキャッシュに入ったものは消さない。 */
internal fun interface KsImageRequestHandle {
    fun dispose()
}

/**
 * 先読みの取得 1 件分の要求。取得を始めたときに作り、取り消しは始めたときの取っ手で行う。
 *
 * @property url 取得に使う URL
 * @property key 画像を見分けるキー。空文字は取り除いた後の値で、null はキーなし
 * @property widthPixels 縮小してメモリへ載せるときの幅 (ピクセル)。幅の正方形を覆う最小の
 *   大きさに縮小する。null は縮小しない (元の大きさのまま、または到達点がディスクまで)
 */
internal data class KsPrefetchRequest(
    val url: String,
    val key: String? = null,
    val widthPixels: Int? = null,
) {
    /** 画像の識別子。 */
    val identifier: String get() = KsImageIdentity.identifier(url, key)

    /** 到達点がメモリまでのとき、この要求が載せる項目の鍵。 */
    val memoryKey: MemoryCache.Key
        get() = if (widthPixels == null) {
            KsImageIdentity.originalKey(identifier)
        } else {
            KsImageIdentity.sizedKey(identifier, Size(widthPixels, widthPixels))
        }
}

/**
 * 画像ローダーの受け口の差し替え口。テストが記録用の実装を提供する。未提供なら Coil の
 * 共有インスタンスを使う実装を組み立てる。
 */
internal val LocalKsImageLoading = staticCompositionLocalOf<KsImageLoading?> { null }
