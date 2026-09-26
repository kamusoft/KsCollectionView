package jp.kamusoft.kscollectionview.samples.android

/**
 * 「差分更新」画面の操作の対象の位置。配列全体での位置を指す。
 *
 * 並び順と文言は iOS Sample の同名定義とそろえる。
 *
 * @property title 切り替えに出す文言
 */
enum class DiffUpdatePosition(val title: String) {
    Head("先頭"),
    Middle("中ほど"),
    Tail("末尾"),
    ;

    /** 挿入の位置。先頭は 0、中ほどは件数の半分 (切り捨て)、末尾は件数 (最後の項目の後ろ)。 */
    fun insertionIndex(count: Int): Int = when (this) {
        Head -> 0
        Middle -> count / 2
        Tail -> count
    }

    /**
     * 削除・更新・移動の対象の位置。先頭は 0、中ほどは件数の半分 (切り捨て)、末尾は件数 − 1。
     * 空の配列では null。
     */
    fun targetIndex(count: Int): Int? {
        if (count <= 0) return null
        return when (this) {
            Head -> 0
            Middle -> count / 2
            Tail -> count - 1
        }
    }
}
