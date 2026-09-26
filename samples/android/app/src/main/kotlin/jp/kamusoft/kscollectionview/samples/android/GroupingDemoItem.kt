package jp.kamusoft.kscollectionview.samples.android

/**
 * 「グループ化」画面の項目。行の中身と、属するグループの番号を持つ。
 *
 * @property row 行に出す中身 (「大量件数」と同じ作り方)
 * @property group 属するグループの番号。見出しには「グループ n」と出る
 */
data class GroupingDemoItem(
    val row: DemoItem,
    val group: Int,
) {
    /** 安定 ID。行の中身の ID と同じ。 */
    val id: Int get() = row.id
}
