package jp.kamusoft.kscollectionview

import androidx.compose.runtime.staticCompositionLocalOf

/**
 * 画像ローダーへの操作を集めた内部の受け口。本番は [KsCoilImageLoading]、テストは記録用の
 * 実装を [LocalKsImageLoading] から差し込む。
 *
 * URL 単位より上の寿命管理 (アイテムとの対応・参照数) は [KsImagePrefetchWindow] が持ち、
 * この受け口には解決済みの URL が 1 件ずつ届く。
 */
internal interface KsImageLoading {
    /**
     * 到達点を指定して URL の取得を始め、その取得を取り消すための取っ手を返す。
     */
    fun enqueue(url: String, destination: KsPrefetchDestination): KsImageRequestHandle
}

/** 進行中の取得を取り消すための取っ手。完了してキャッシュに入ったものは消さない。 */
internal fun interface KsImageRequestHandle {
    fun dispose()
}

/**
 * 画像ローダーの受け口の差し替え口。テストが記録用の実装を提供する。未提供なら Coil の
 * 共有インスタンスを使う実装を組み立てる。
 */
internal val LocalKsImageLoading = staticCompositionLocalOf<KsImageLoading?> { null }
