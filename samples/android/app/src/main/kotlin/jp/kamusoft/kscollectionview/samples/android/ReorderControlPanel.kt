package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

/**
 * 「並べ替え」画面の操作のパネル。畳むボタンと表示の形の切り替え、4 つの切り替えのボタン (2×2)、
 * 説明の一行を縦に並べる。並びと文言は iOS Sample の `ReorderControlPanel` とそろえる。
 *
 * @param layoutChoice 選択中の表示の形
 * @param onSelectLayout 表示の形が選ばれたときの処理
 * @param model 切り替えの値を持つモデル。切り替えのボタンはモデルの値を直接書き換える
 * @param onFold 畳むボタンを押したときの処理
 * @param modifier パネルに付ける修飾
 */
@Composable
fun ReorderControlPanel(
    layoutChoice: ReorderLayoutChoice,
    onSelectLayout: (ReorderLayoutChoice) -> Unit,
    model: ReorderDemoModel,
    onFold: () -> Unit,
    modifier: Modifier = Modifier,
) {
    SampleFloatingPanel(modifier = modifier) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SamplePanelMetrics.foldButtonSpacing),
        ) {
            SamplePanelFoldButton(onFold = onFold)
            SampleSegmentedControl(
                modifier = Modifier
                    .weight(1f)
                    .semantics { contentDescription = ReorderDemoText.LayoutPicker },
                options = ReorderLayoutChoice.entries.map { it.title },
                selectedIndex = layoutChoice.ordinal,
                onSelect = { onSelectLayout(ReorderLayoutChoice.entries[it]) },
            )
        }

        ToggleRow(
            leading = ToggleSpec(ReorderDemoText.Reorder, model.isReorderEnabled) { model.isReorderEnabled = it },
            trailing = ToggleSpec(ReorderDemoText.Grouped, model.isGrouped) { model.isGrouped = it },
        )
        ToggleRow(
            leading = ToggleSpec(ReorderDemoText.KeepsGroups, model.keepsGroups) { model.keepsGroups = it },
            trailing = ToggleSpec(ReorderDemoText.RejectsMoves, model.rejectsMoves) { model.rejectsMoves = it },
        )

        Text(
            text = ReorderDemoText.Summary,
            style = MaterialTheme.typography.bodySmall,
            color = SampleTheme.secondaryText,
        )
    }
}

/** 切り替えのボタン 1 つ分の文言・値・切り替えたときの処理。 */
private class ToggleSpec(val text: String, val checked: Boolean, val onCheckedChange: (Boolean) -> Unit)

/**
 * 切り替えのボタン 2 つを同じ幅・同じ高さで横に並べる (片方が 2 行に折り返したら、もう片方も同じ高さにする)。
 */
@Composable
private fun ToggleRow(leading: ToggleSpec, trailing: ToggleSpec) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(SamplePanelMetrics.rowSpacing),
    ) {
        listOf(leading, trailing).forEach { spec ->
            ReorderToggleButton(
                text = spec.text,
                checked = spec.checked,
                onCheckedChange = spec.onCheckedChange,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
            )
        }
    }
}
