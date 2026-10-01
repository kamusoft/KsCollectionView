package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle

/**
 * 「並べ替え」画面の 1 行。タイトル「Item n」を出し、動かせない項目には後ろに「(移動不可)」を
 * テキスト副の色で添える。
 *
 * 余白と面は「リスト」画面の行 ([DemoListRow]) と同じ。タイトルと添える文言は 1 つの文として読み上げる。
 * 見た目は iOS Sample の `ReorderDemoRow` とそろえる。
 *
 * @param item 項目
 * @param modifier 行に付ける修飾
 */
@Composable
fun ReorderDemoRow(item: ReorderDemoItem, modifier: Modifier = Modifier) {
    val suffixStyle = SpanStyle(
        color = SampleTheme.secondaryText,
        fontSize = MaterialTheme.typography.bodyMedium.fontSize,
    )
    Text(
        text = reorderRowTitle(item, suffixStyle),
        style = MaterialTheme.typography.bodyLarge,
        color = SampleTheme.text,
        modifier = modifier
            .fillMaxWidth()
            .background(SampleTheme.cell)
            .padding(
                horizontal = SampleTheme.horizontalPadding,
                vertical = SampleTheme.rowVerticalPadding,
            ),
    )
}

/**
 * 行のタイトル。動かせない項目は「Item n (移動不可)」にし、添える文言に [suffixStyle] を付ける。
 *
 * @param item 項目
 * @param suffixStyle 添える文言の見た目
 */
fun reorderRowTitle(item: ReorderDemoItem, suffixStyle: SpanStyle = SpanStyle()): AnnotatedString =
    buildAnnotatedString {
        append(item.title)
        if (!item.isMovable) {
            append(" ")
            withStyle(suffixStyle) { append(ReorderDemoText.Unmovable) }
        }
    }
