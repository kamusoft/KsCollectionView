package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 「グリッド (固定列)」画面。3 列のグリッドと 1 列のリストを同じデータのまま切り替える。
 */
@Composable
fun FixedGridDemoScreen(modifier: Modifier = Modifier) {
    // 選択は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞いにそろえる。
    var choice by rememberSaveable { mutableStateOf(FixedGridLayoutChoice.Grid) }

    Column(modifier = modifier.fillMaxSize()) {
        SampleControlBar {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(text = "レイアウト", color = SampleTheme.text, style = MaterialTheme.typography.bodyMedium)
                SampleSegmentedControl(
                    modifier = Modifier.weight(1f),
                    options = FixedGridLayoutChoice.entries.map { it.title },
                    selectedIndex = choice.ordinal,
                    onSelect = { choice = FixedGridLayoutChoice.entries[it] },
                )
            }
        }

        KsCollectionView(
            items = DemoData.fixedGridItems,
            key = { it.id },
            layout = if (choice == FixedGridLayoutChoice.Grid) {
                KsLayout.Grid(columns = KsColumns.Fixed(3))
            } else {
                KsLayout.List
            },
        ) {
            template { item ->
                if (choice == FixedGridLayoutChoice.Grid) {
                    DemoGridCell(item)
                } else {
                    DemoListRow(item)
                }
            }
        }
    }
}
