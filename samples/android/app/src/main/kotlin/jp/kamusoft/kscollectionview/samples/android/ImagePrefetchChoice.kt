package jp.kamusoft.kscollectionview.samples.android

import jp.kamusoft.kscollectionview.KsPrefetchDestination

/**
 * 「画像グリッド」画面で選べるプリフェッチの到達点。
 *
 * 並び順と文言は iOS Sample の同名 enum と一字一句そろえる (cross/ADR-0004)。
 */
enum class ImagePrefetchChoice(val title: String, val destination: KsPrefetchDestination?) {
    /** プリフェッチを宣言しない。 */
    None("なし", null),

    /** 元データをディスクのキャッシュに置くところまで先読みする。 */
    Disk("ディスクまで", KsPrefetchDestination.Disk),

    /** デコードした画像をメモリのキャッシュに載せるところまで先読みする。 */
    Memory("メモリまで", KsPrefetchDestination.Memory),
}
