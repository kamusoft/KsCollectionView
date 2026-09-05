package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 「スペーシングと余白」画面。行間 / 列間と内側余白を動かして見え方の変化を見る。
 */
@Composable
fun SpacingPaddingDemoScreen(modifier: Modifier = Modifier) {
    // 滑り操作の値は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞いにそろえる。
    var spacing by rememberSaveable { mutableFloatStateOf(4f) }
    var padding by rememberSaveable { mutableFloatStateOf(8f) }

    Column(modifier = modifier.fillMaxSize()) {
        SampleControlBar {
            SliderRow(
                label = "スペーシング",
                value = spacing,
                range = 0f..16f,
                onValueChange = { spacing = it },
            )
            SliderRow(
                label = "余白",
                value = padding,
                range = 0f..24f,
                onValueChange = { padding = it },
            )
        }

        KsCollectionView(
            items = DemoData.gridItems,
            key = { it.id },
            layout = KsLayout.Grid(
                columns = KsColumns.Fixed(2),
                rowSpacing = spacing.dp,
                columnSpacing = spacing.dp,
            ),
            contentPadding = PaddingValues(padding.dp),
        ) {
            template { item -> DemoGridCell(item) }
        }
    }
}

/** 見出しと滑り操作を 1 行に並べる。 */
@Composable
private fun SliderRow(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    onValueChange: (Float) -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(text = label, color = SampleTheme.text, style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.weight(1f))
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = range,
            modifier = Modifier.width(180.dp),
            colors = SliderDefaults.colors(
                thumbColor = SampleTheme.accent,
                activeTrackColor = SampleTheme.accent,
            ),
        )
    }
}
