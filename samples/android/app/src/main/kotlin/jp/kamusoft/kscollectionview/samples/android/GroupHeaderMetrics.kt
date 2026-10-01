package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.unit.dp

/**
 * 「グループ化」「差分更新」「並べ替え」の画面が使う、グループまわりの寸法。
 *
 * 値は iOS Sample の同名定義とそろえる。これらの画面だけの値のため [SampleTheme] には置かない。
 */
object GroupHeaderMetrics {
    /** 見出しの帯の高さ。 */
    val height = 40.dp

    /** グループとグループの間の間隔。 */
    val groupSpacing = 16.dp

    /** グリッドの行と行・列と列の間隔。グリッドの見出しと先頭行の間も同じ間隔にする。 */
    val gridSpacing = 1.dp
}
