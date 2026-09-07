package jp.kamusoft.kscollectionview

import androidx.annotation.DrawableRes

/** 画像の取得元を表します。 */
public sealed interface KsImageSource {
    /** ネットワーク上の画像を URL で指定します。 */
    public data class Remote(public val url: String) : KsImageSource

    /** 端末内のファイルを指定します。 */
    public data class File(public val file: java.io.File) : KsImageSource

    /** アプリに同梱したドローアブルリソースを ID で指定します。 */
    public data class Resource(@param:DrawableRes public val id: Int) : KsImageSource
}
