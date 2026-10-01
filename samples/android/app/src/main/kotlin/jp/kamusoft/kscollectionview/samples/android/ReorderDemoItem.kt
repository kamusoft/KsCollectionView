package jp.kamusoft.kscollectionview.samples.android

/**
 * 「並べ替え」画面の項目。番号と、属するグループの番号を持つ。
 *
 * @property id 番号 (1 から)。タイトルは「Item n」
 * @property group 属するグループの番号 (1 から)。見出しには「グループ n」と出る。並べ替えで別のグループへ
 *   動かすと書き換わる
 */
data class ReorderDemoItem(val id: Int, val group: Int) {
    /** 行に出すタイトル (「Item n」)。 */
    val title: String get() = "Item $id"

    /** 並べ替えで動かせるか。10 の倍数の項目は動かせない。 */
    val isMovable: Boolean get() = id % 10 != 0
}
