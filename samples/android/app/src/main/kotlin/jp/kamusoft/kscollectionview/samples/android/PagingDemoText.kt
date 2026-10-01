package jp.kamusoft.kscollectionview.samples.android

/** 「ページング」画面に出す文言。iOS Sample の同名の定義と一字一句同じにする。 */
object PagingDemoText {
    /** 表示の形の切り替えの名前 (読み上げ用)。 */
    const val LayoutPicker = "表示"

    /** 失敗させる切り替え。 */
    const val FailsNextLoad = "次の読み込みを失敗させる"

    /** 0 件にする切り替え。 */
    const val IsEmpty = "中身を 0 件にする"

    /** 引っ張らずに取り直す操作。 */
    const val Reload = "再読み込み"

    /** 操作のパネルの説明の一行 (通常)。 */
    const val Summary = "全 10,000 件・1 ページ 50 件"

    /** 操作のパネルの説明の一行 (項目があるときの取り直しに失敗したとき)。 */
    const val RefreshFailed = "更新できませんでした"

    /** 読み込みの失敗の表示 (最後の項目の後ろ / 0 件のとき)。 */
    const val LoadFailed = "読み込めませんでした"

    /** 失敗の表示の中の再試行の操作。 */
    const val Retry = "再試行"

    /** 終端の表示。 */
    const val EndReached = "これ以上ありません"

    /** 空の表示。 */
    const val Empty = "項目がありません"
}
