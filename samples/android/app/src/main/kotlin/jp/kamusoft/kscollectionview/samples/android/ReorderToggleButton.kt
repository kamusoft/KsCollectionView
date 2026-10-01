package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * 「並べ替え」画面の操作のパネルに 2×2 で並べる切り替えのボタン。押すたびにオン / オフが入れ替わる。
 *
 * オンはアクセントの面にアクセントの上の色の太字、オフはセル背景の面に区切り線の色の枠とテキスト主の文字。
 * 見た目は iOS Sample の同名の部品とそろえる。文言はボタンの幅で 2 行に折り返してよい。
 *
 * @param text 文言
 * @param checked オンか
 * @param onCheckedChange 押したときの処理 (切り替えた後の値を受け取る)
 * @param modifier ボタンに付ける修飾
 */
@Composable
fun ReorderToggleButton(
    text: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(ReorderToggleButtonMetrics.cornerRadius)
    Box(
        modifier = modifier
            .clip(shape)
            .background(if (checked) SampleTheme.accent else SampleTheme.cell)
            .border(1.dp, if (checked) SampleTheme.accent else SampleTheme.separator, shape)
            .toggleable(value = checked, role = Role.Switch, onValueChange = onCheckedChange)
            .padding(
                vertical = ReorderToggleButtonMetrics.verticalPadding,
                horizontal = ReorderToggleButtonMetrics.horizontalPadding,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = if (checked) FontWeight.SemiBold else null,
            color = if (checked) SampleTheme.onAccent else SampleTheme.text,
            textAlign = TextAlign.Center,
        )
    }
}

/** 切り替えのボタンの寸法。値は iOS Sample の `ReorderToggleButton` とそろえる。 */
object ReorderToggleButtonMetrics {
    /** 文言の上下の余白。 */
    val verticalPadding = 7.dp

    /** 文言の左右の余白。 */
    val horizontalPadding = 4.dp

    /** 面の角丸の半径。 */
    val cornerRadius = 9.dp
}
