package jp.kamusoft.kscollectionview.samples.android

/**
 * 「差分更新」画面の項目。
 *
 * @property id 安定 ID
 * @property group 属するグループの番号 (0 から)。見出しには「グループ A」のように英大文字で出る
 * @property revision 「更新」を受けた回数。1 回以上ならタイトルに印が付く
 */
data class DiffUpdateItem(
    val id: Int,
    val group: Int,
    val revision: Int = 0,
) {
    /** 行に出す中身。 */
    val row: DemoItem
        get() = DemoItem(id = id, title = if (revision > 0) "Item $id ★" else "Item $id")
}
