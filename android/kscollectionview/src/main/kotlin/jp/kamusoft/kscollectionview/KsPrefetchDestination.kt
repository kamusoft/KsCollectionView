package jp.kamusoft.kscollectionview

/** プリフェッチした画像をどこまで用意しておくかを表します。 */
public enum class KsPrefetchDestination {
    /** 画像の元データをディスクのキャッシュに保存するところまで行います。表示のためのデコードは行いません。 */
    Disk,

    /** 元データの保存に加えて、デコードした画像をメモリのキャッシュにも載せます。 */
    Memory,
}
