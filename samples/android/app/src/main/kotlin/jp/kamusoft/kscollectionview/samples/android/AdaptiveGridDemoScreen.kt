package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 「グリッド (adaptive)」画面。項目の最小幅だけを決めて列数を自動で決めさせる。
 */
@Composable
fun AdaptiveGridDemoScreen(modifier: Modifier = Modifier) {
    KsCollectionView(
        items = DemoData.gridItems,
        key = { it.id },
        modifier = modifier,
        layout = KsLayout.Grid(columns = KsColumns.Adaptive(minItemWidth = 120.dp)),
    ) {
        template { item -> DemoGridCell(item) }
    }
}
