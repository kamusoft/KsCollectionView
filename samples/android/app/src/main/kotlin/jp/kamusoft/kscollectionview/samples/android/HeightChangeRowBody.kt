package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * 展開状態に応じて高さが変わる行の本文。
 *
 * 先頭に見出しを置き、展開時だけ連番の本文行を足すことで、行の上端からのはみ出しを
 * 目視で判別できるようにする。
 *
 * @param item 表示する項目
 * @param isExpanded 展開しているかどうか
 */
@Composable
fun HeightChangeRowBody(
    item: HeightChangeItem,
    isExpanded: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(SampleTheme.cell)
            .padding(
                horizontal = SampleTheme.horizontalPadding,
                vertical = SampleTheme.rowVerticalPadding,
            )
            .testTag("heightChange.row.${item.id}"),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = "行 ${item.id} の先頭",
            style = MaterialTheme.typography.titleMedium,
            color = SampleTheme.text,
            modifier = Modifier.testTag("heightChange.rowHeading.${item.id}"),
        )
        if (isExpanded) {
            (1..4).forEach { line ->
                Text(
                    text = "行 ${item.id} 本文 $line",
                    style = MaterialTheme.typography.bodyMedium,
                    color = SampleTheme.secondaryText,
                    modifier = Modifier.testTag("heightChange.rowBody.${item.id}.$line"),
                )
            }
        }
    }
}
