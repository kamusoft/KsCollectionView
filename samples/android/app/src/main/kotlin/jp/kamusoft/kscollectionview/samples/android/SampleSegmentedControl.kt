package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * 択一の切り替え。iOS Sample の同じ操作を Material の見た目で出す。
 *
 * @param options 選択肢の表示文言。並び順のまま左から並べる
 * @param selectedIndex いま選ばれている選択肢の位置
 * @param onSelect 選択肢が選ばれたときの処理
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SampleSegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    SingleChoiceSegmentedButtonRow(modifier = modifier) {
        options.forEachIndexed { index, label ->
            SegmentedButton(
                selected = index == selectedIndex,
                onClick = { onSelect(index) },
                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
                colors = SegmentedButtonDefaults.colors(
                    activeContainerColor = SampleTheme.accent,
                    activeContentColor = SampleTheme.onAccent,
                    activeBorderColor = SampleTheme.accent,
                    inactiveContainerColor = SampleTheme.cell,
                    inactiveContentColor = SampleTheme.accent,
                    inactiveBorderColor = SampleTheme.accent,
                ),
                // 選択済みの印は塗り分けで足りるため、確認の図案は出さない。
                icon = {},
            ) {
                Text(text = label, style = MaterialTheme.typography.labelMedium)
            }
        }
    }
}
