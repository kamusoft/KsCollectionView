package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * 択一のメニュー。いまの選択を 1 行で出し、触れると選択肢の一覧が開く。
 *
 * 選択肢の文言が長く、横に並べる切り替えでは収まらない操作に使う。iOS Sample のメニュー形式の
 * Picker と同じ操作を Material の見た目で出す。
 *
 * @param options 選択肢の表示文言。並び順のまま上から並べる
 * @param selectedIndex いま選ばれている選択肢の位置
 * @param onSelect 選択肢が選ばれたときの処理
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SampleMenuPicker(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
        modifier = modifier,
    ) {
        Row(
            modifier = Modifier
                .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable)
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = options[selectedIndex],
                style = MaterialTheme.typography.bodyMedium,
                color = SampleTheme.accent,
            )
            ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
        }
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            options.forEachIndexed { index, label ->
                DropdownMenuItem(
                    text = { Text(text = label, style = MaterialTheme.typography.bodyMedium) },
                    onClick = {
                        expanded = false
                        onSelect(index)
                    },
                )
            }
        }
    }
}
