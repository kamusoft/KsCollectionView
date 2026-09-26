package jp.kamusoft.kscollectionview.samples.android

/**
 * 「差分更新」画面の表示の形。並び順と文言は iOS Sample の同名定義とそろえる。
 *
 * @property title 切り替えに出す文言
 */
enum class DiffUpdateLayoutChoice(val title: String) {
    List("リスト"),
    Grid("グリッド"),
}
