package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp

/**
 * グリッドの 1 セル。色見本とタイトルを縦に並べる。
 *
 * 色見本は ID から決まる 9 色の循環で選ぶため、同じ位置には常に同じ色が出る。
 */
@Composable
fun DemoGridCell(item: DemoItem, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = SampleTheme.gridMinimumHeight)
            .background(SampleTheme.cell),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
    ) {
        Column(
            modifier = Modifier
                .size(SampleTheme.swatchSize)
                // 色そのものに読み上げる意味はないため、読み上げの対象から外す。
                .clearAndSetSemantics { }
                .background(
                    color = SampleTheme.swatches[(item.id - 1).mod(SampleTheme.swatches.size)],
                    shape = RoundedCornerShape(8.dp),
                ),
            content = {},
        )
        Text(
            text = item.title,
            style = MaterialTheme.typography.bodySmall,
            color = SampleTheme.text,
        )
    }
}
