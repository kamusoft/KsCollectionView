package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * デモの 1 行。タイトルと補助テキストを縦に並べる。
 */
@Composable
fun DemoListRow(item: DemoItem, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(SampleTheme.cell)
            .padding(
                horizontal = SampleTheme.horizontalPadding,
                vertical = SampleTheme.rowVerticalPadding,
            ),
    ) {
        Text(
            text = item.title,
            style = MaterialTheme.typography.bodyLarge,
            color = SampleTheme.text,
        )
        item.detail?.let { detail ->
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = SampleTheme.secondaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}
