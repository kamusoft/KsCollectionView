package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 「大量件数」の土俵の配置。
 *
 * デモ画面と計測用の画面が同じ土俵を描くための単一の宣言元。ここを 2 か所に書くと、
 * 計測結果がデモ画面と違う土俵の値になっても気づけない。
 */
val LargeDataLayout: KsLayout = KsLayout.Grid(
    columns = KsColumns.Fixed(2),
    rowSpacing = 1.dp,
    columnSpacing = 1.dp,
)

/**
 * 「大量件数」画面。10,000 件を 2 列グリッドで並べ、固定高と可変行高を混ぜて表示する。
 *
 * 件数・列数・行間 / 列間・データの作り方は iOS Sample の同名画面とそろえる。
 */
@Composable
fun LargeDataDemoScreen(modifier: Modifier = Modifier) {
    val items = remember { DemoData.largeItems(DemoData.LargeItemCount) }
    KsLargeDataGrid(items = items, modifier = modifier)
}

/**
 * 「大量件数」の土俵をライブラリで描く。件数だけを変えて計測にも使う。
 *
 * @param items 表示する要素
 */
@Composable
fun KsLargeDataGrid(
    items: List<DemoItem>,
    modifier: Modifier = Modifier,
) {
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier,
        layout = LargeDataLayout,
    ) {
        template { item ->
            // テンプレートが呼ばれた回数と、同時に生きているテンプレートの数を数える。
            // 可視範囲 + 先読み分しか同時に生きないことを実機で確かめるための計数で、
            // 配布する構成では何もしない実装に差し替わる。
            TemplateInvocationCounter.record(SampleScreen.LargeData.name)
            TemplateInvocationCounter.TrackLifetime(SampleScreen.LargeData.name, item.id)
            DemoListRow(item)
        }
    }
}

/**
 * 同じ土俵を 1 列のリストとして描く。多列と 1 列で上乗せの傾向が変わらないかを見るために使う。
 *
 * @param items 表示する要素
 */
@Composable
fun KsLargeDataList(items: List<DemoItem>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier,
        layout = KsLayout.List(rowSpacing = 1.dp),
    ) {
        template { item ->
            TemplateInvocationCounter.record(SampleScreen.LargeData.name)
            TemplateInvocationCounter.TrackLifetime(SampleScreen.LargeData.name, item.id)
            DemoListRow(item)
        }
    }
}
