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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView

/**
 * 「リスト」画面。区切り線の 3 択とタップ / 長押しのフィードバックを見る。
 *
 * 「既定」はライブラリ既定の色をそのまま見せるため、色の指定自体を行わない。
 */
@Composable
fun ListDemoScreen(modifier: Modifier = Modifier) {
    // 選択と直近の操作は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞いにそろえる。
    var separatorChoice by rememberSaveable { mutableStateOf(ListSeparatorChoice.Standard) }
    var lastInteraction by rememberSaveable { mutableStateOf("") }

    Column(modifier = modifier.fillMaxSize()) {
        SampleControlBar {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(text = "区切り線", color = SampleTheme.text, style = MaterialTheme.typography.bodyMedium)
                SampleSegmentedControl(
                    modifier = Modifier.weight(1f),
                    options = ListSeparatorChoice.entries.map { it.title },
                    selectedIndex = separatorChoice.ordinal,
                    onSelect = { separatorChoice = ListSeparatorChoice.entries[it] },
                )
            }
        }

        KsCollectionView(
            items = DemoData.fruits,
            key = { it.id },
            modifier = Modifier.semantics { stateDescription = lastInteraction },
            listSeparators = separatorChoice != ListSeparatorChoice.Hidden,
            listSeparatorColor = if (separatorChoice == ListSeparatorChoice.Accent) {
                SampleTheme.accent
            } else {
                null
            },
            onItemTap = { lastInteraction = "${it.title} をタップ" },
            onItemLongTap = { lastInteraction = "${it.title} を長押し" },
            touchFeedbackColor = SampleTheme.accent,
        ) {
            template { item -> DemoListRow(item) }
        }
    }
}
