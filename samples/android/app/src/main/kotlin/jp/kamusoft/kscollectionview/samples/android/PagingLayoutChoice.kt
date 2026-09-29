package jp.kamusoft.kscollectionview.samples.android

/**
 * 「ページング」画面の表示の形。並び順と文言は iOS Sample の同名定義とそろえる。
 *
 * @property title 切り替えに出す文言
 */
enum class PagingLayoutChoice(val title: String) {
    List("リスト"),
    Grid("グリッド"),
}
