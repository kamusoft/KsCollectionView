package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 「向きで列数変更」画面。縦長と横長で列数が切り替わることを端末を回して見る。
 */
@Composable
fun OrientationGridDemoScreen(modifier: Modifier = Modifier) {
    KsCollectionView(
        items = DemoData.gridItems,
        key = { it.id },
        modifier = modifier,
        layout = KsLayout.Grid(columns = KsColumns.Fixed(portrait = 2, landscape = 4)),
    ) {
        template { item -> DemoGridCell(item) }
    }
}
