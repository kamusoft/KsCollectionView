package jp.kamusoft.kscollectionview.samples.android

/** 「並べ替え」画面に出す文言。iOS Sample の同名の定義と一字一句同じにする。 */
object ReorderDemoText {
    /** 表示の形の切り替えの名前 (読み上げ用)。 */
    const val LayoutPicker = "表示"

    /** 並べ替えのスイッチ。 */
    const val Reorder = "並べ替え"

    /** グループの有無の切り替え。 */
    const val Grouped = "グループ"

    /** 項目を元のグループの外へ置けなくする切り替え。 */
    const val KeepsGroups = "グループをまたがせない"

    /** 置いても受け入れない切り替え。 */
    const val RejectsMoves = "置いても受け入れない"

    /** 操作のパネルの説明の一行。 */
    const val Summary = "全 10,000 件・10 の倍数は移動不可"

    /** 並べ替えを受け入れなかったときの帯。 */
    const val Rejected = "並べ替えを受け入れませんでした"

    /** 動かせない項目のタイトルの後ろに添える文言。 */
    const val Unmovable = "(移動不可)"

    /** 読み上げの 1 つ前へ動かす操作。 */
    const val MoveBackward = "前へ移動"

    /** 読み上げの 1 つ後ろへ動かす操作。 */
    const val MoveForward = "後ろへ移動"

    /** 項目を長押ししたときの帯 (「長押し: Item n」)。 */
    fun longPressed(item: ReorderDemoItem): String = "長押し: ${item.title}"

    /** 見出しのグループ名 (「グループ n」)。 */
    fun groupName(group: Int): String = "グループ $group"
}
