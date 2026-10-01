package jp.kamusoft.kscollectionview.samples.android

/**
 * 「並べ替え」画面の表示の形。並び順と文言は iOS Sample の同名定義とそろえる。
 *
 * @property title 切り替えに出す文言
 */
enum class ReorderLayoutChoice(val title: String) {
    List("リスト"),
    Grid("グリッド"),
}
