package jp.kamusoft.kscollectionview

import androidx.annotation.DrawableRes

/** 画像の取得元を表します。 */
public sealed interface KsImageSource {
    /**
     * ネットワーク上の画像を URL で指定します。
     *
     * [key] を指定すると、取得には URL を使い、キャッシュの項目はキーで見分けます。署名付きの
     * URL のように取得のたびに URL が変わる画像でも、同じキーなら先読みした画像や保存済みの画像が
     * 使われます。先読みの宣言 ([KsResource]) にも同じキーを指定してください。キーは画像の
     * 中身を一意に特定する値にし、空文字は使わないでください (空文字は誤りとして扱い、デバッグ
     * ビルドでは停止し、リリースビルドでは警告を記録してキーを指定しなかったものとして扱います)。
     *
     * キーを指定した画像は、ローダー付属のビューに同じ URL を直接渡して表示した画像とは
     * キャッシュを共有しません。
     *
     * @param url 画像を取得する URL
     * @param key 画像を見分けるキー。省略すると URL で見分けます
     */
    public data class Remote(
        public val url: String,
        public val key: String? = null,
    ) : KsImageSource

    /** 端末内のファイルを指定します。 */
    public data class File(public val file: java.io.File) : KsImageSource

    /** アプリに同梱したドローアブルリソースを ID で指定します。 */
    public data class Resource(@param:DrawableRes public val id: Int) : KsImageSource
}
