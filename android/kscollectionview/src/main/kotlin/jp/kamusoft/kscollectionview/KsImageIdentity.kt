package jp.kamusoft.kscollectionview

import coil3.memory.MemoryCache
import coil3.size.Size

/**
 * 画像の識別子と、識別子から作るローダーの鍵を扱う。
 *
 * 識別子は「キーがあればキー、無ければ URL」から 1 か所で求め、先読み・表示・索引・台帳・
 * キャッシュ操作のすべてがこれを使う (core/ADR-0014)。どこか 1 か所でも URL が残ると、
 * 取得のたびに URL が変わる画像ではそこだけ毎回食い違うためである。
 *
 * 識別子の形は次の 2 つで、互いに衝突しない。
 * - キーなし: URL の文字列そのもの。URL の文字列は空白を含まない (含む場合は符号化される)。
 * - キーあり: [KeyPrefix] + キー。接頭辞に空白を含むので、URL の識別子と重ならない。
 *
 * 識別子はメモリの鍵の本体にもなる。キーありの画像はディスクの鍵も識別子にする。キーなしの画像は
 * ディスクの鍵をローダーの既定 (URL) のままにして、ローダー付属のビューと同じ項目を共有する。
 *
 * ソース単位の削除の世代は鍵に入れない。削除前に始まった要求は、先読みの停止と、世代による
 * [KsImage] の作り直しで捨てる。
 */
internal object KsImageIdentity {
    /** キーありの識別子に付ける接頭辞。iOS と同じ形にする。 */
    private const val KeyPrefix = "ks-key "

    /** 鍵に表示サイズを載せる付随情報の名前。ローダーが寸法の一致を見るのと同じ名前にする。 */
    private const val SizeExtra = "coil#size"

    /** 表示の鍵に当てはめ方を載せる付随情報の名前。ローダーはこの名前を解釈しない。 */
    private const val ScaleExtra = "ks#scale"

    /**
     * URL とキーから識別子を求める。空文字のキーは誤りだが、ここでは報告せずキーなしとみなす
     * (報告は入口ごとに [emptyKeyMessage] で行う)。
     */
    fun identifier(url: String, key: String?): String =
        if (key.isNullOrEmpty()) url else KeyPrefix + key

    /** 空文字のキーを受け取ったときの警告の文面。 */
    fun emptyKeyMessage(url: String): String =
        "画像のキーに空文字が指定されました。URL で見分けます: $url"

    /** 寸法を付けない鍵。先読みが元の大きさのまま載せる項目を指す。 */
    fun originalKey(identifier: String): MemoryCache.Key = MemoryCache.Key(identifier)

    /**
     * 寸法を付けた鍵。幅を宣言した先読みの要求が使う。
     *
     * 当てはめ方は鍵に含めない。先読みの項目は、表示の要求の鍵とは重ならず、索引を経由した
     * 引き当てでだけ使えるか判定される。
     */
    fun sizedKey(identifier: String, size: Size): MemoryCache.Key =
        MemoryCache.Key(identifier, mapOf(SizeExtra to size.toString()))

    /**
     * 表示の要求の鍵。寸法に加えて当てはめ方を載せる。
     *
     * ローダーは寸法の付随情報が一致するだけで項目を有効とみなす。当てはめ方が無いと、引き当てで
     * 許容範囲の外と退けた項目 (同じ寸法で載せた先読みの項目や、別の当てはめ方で載せた項目) を、
     * 続けて出す表示の要求がメモリからそのまま受け取ってしまう。当てはめ方を載せることで、表示の
     * 要求は同じ枠・同じ当てはめ方で載せた項目にだけ当たる。
     */
    fun displayKey(identifier: String, size: Size, contentMode: KsImageContentMode): MemoryCache.Key =
        MemoryCache.Key(
            identifier,
            mapOf(SizeExtra to size.toString(), ScaleExtra to contentMode.scaleExtraValue),
        )

    private val KsImageContentMode.scaleExtraValue: String
        get() = when (this) {
            KsImageContentMode.Fit -> "fit"
            KsImageContentMode.Fill -> "fill"
        }
}

/**
 * ローダーを通すソースの識別子。ローダーを通らないソース (同梱リソース) では null になる。
 */
internal val KsImageSource.identifier: String?
    get() = when (this) {
        is KsImageSource.Remote -> KsImageIdentity.identifier(url, key)
        is KsImageSource.File -> "file://${file.absolutePath}"
        is KsImageSource.Resource -> null
    }

/** キーを持つソースか。空文字のキーはキーなしとみなす。 */
internal val KsImageSource.hasKey: Boolean
    get() = this is KsImageSource.Remote && !key.isNullOrEmpty()

/** 空文字のキーを持つソースなら、その警告の文面。 */
internal val KsImageSource.emptyKeyMessage: String?
    get() = if (this is KsImageSource.Remote && key?.isEmpty() == true) {
        KsImageIdentity.emptyKeyMessage(url)
    } else {
        null
    }
