package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsImage
import jp.kamusoft.kscollectionview.KsLayout
import jp.kamusoft.kscollectionview.KsPrefetchDestination

/** ローダー付属のビューで表示する ID。初期表示の可視範囲より後ろで、先読みの窓に入る位置。 */
private val SharedIds = (13..36).toList()

/** 到達できない取得元。失敗の既定の表示を出すために使う。 */
private const val UnreachableUrl = "https://ks-unreachable.invalid/image.jpg"

/** 読み込みに時間の掛かる取得元。読み込み中の既定の表示を見えるようにするために使う。 */
private const val SlowUrl = "https://picsum.photos/seed/ks-slow/4000/4000"

/**
 * 画像の挙動を確かめる検証画面。
 *
 * 確かめるのは 3 点。
 * - 先読みで取り込んだ画像が、ローダー付属のビュー (`AsyncImage`) を直接使った表示にも効くこと
 * - 読み込み中の既定の表示 (大きな画像を出して読み込み中を見えるようにする)
 * - 失敗の既定の表示 (到達できない取得元を出す)
 */
@Composable
fun ImageBehaviorVerificationScreen(modifier: Modifier = Modifier) {
    var showsLoaderAttachedView by remember { mutableStateOf(false) }
    val items = remember { DemoData.largeItems(200) }

    Column(modifier = modifier.fillMaxSize()) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column {
                KsImage(url = SlowUrl, modifier = Modifier.size(100.dp))
                Text(text = "読み込み中")
            }
            Column {
                KsImage(url = UnreachableUrl, modifier = Modifier.size(100.dp))
                Text(text = "失敗")
            }
            TextButton(onClick = { showsLoaderAttachedView = !showsLoaderAttachedView }) {
                Text(
                    text = if (showsLoaderAttachedView) "先読みへ戻す" else "ローダー付属ビュー",
                )
            }
        }

        if (showsLoaderAttachedView) {
            LoaderAttachedGrid()
        } else {
            PrefetchingCollection(items)
        }
    }
}

/**
 * 先読みを起こす土俵。到達点はメモリまでにして、元寸の画像をメモリに載せる。
 */
@Composable
private fun PrefetchingCollection(items: List<DemoItem>) {
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = Modifier.fillMaxSize(),
        layout = KsLayout.Grid(
            columns = KsColumns.Fixed(ImageGridMetrics.ColumnCount),
            rowSpacing = ImageGridMetrics.spacing,
            columnSpacing = ImageGridMetrics.spacing,
        ),
        contentPadding = PaddingValues(ImageGridMetrics.spacing),
        prefetchResources = { item -> listOf(DemoData.imageUrl(item.id)) },
        prefetchDestination = KsPrefetchDestination.Memory,
    ) {
        template { item -> ImageGridCell(item) }
    }
}

/**
 * ローダー付属のビューだけで組んだ表示。同じ取得元を、ライブラリを通さずに表示する。
 */
@Composable
private fun LoaderAttachedGrid() {
    LazyVerticalGrid(
        columns = GridCells.Fixed(ImageGridMetrics.ColumnCount),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(ImageGridMetrics.spacing),
        verticalArrangement = Arrangement.spacedBy(ImageGridMetrics.spacing),
        horizontalArrangement = Arrangement.spacedBy(ImageGridMetrics.spacing),
    ) {
        items(items = SharedIds, key = { it }) { id ->
            AsyncImage(
                model = DemoData.imageUrl(id),
                contentDescription = null,
                modifier = Modifier.fillMaxWidth().aspectRatio(1f),
                contentScale = ContentScale.Crop,
            )
        }
    }
}
