package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.unit.dp

/**
 * 「画像グリッド」画面だけが使う寸法。
 *
 * 値は iOS Sample の同名定義とそろえる (cross/ADR-0004)。Sample 全体で使い回す値では
 * ないため [SampleTheme] には置かない。
 */
object ImageGridMetrics {
    /** グリッドの列数。 */
    const val ColumnCount: Int = 3

    /** セルとセルの間隔と、グリッドの内側余白。 */
    val spacing = 8.dp

    /** セルの角丸の半径。 */
    val cellCornerRadius = 8.dp

    /** ID の文言の左右の余白。 */
    val captionHorizontalPadding = 8.dp

    /** ID の文言の上下の余白。 */
    val captionVerticalPadding = 6.dp
}
