package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

/**
 * 一覧の上に浮かせる操作のパネルの面。中身を縦に並べ、背景の透ける角丸の面に載せる。
 *
 * 中身の並べ方 (1 行目に畳むボタンと表示の形の切り替え、最後に説明の一行) は各画面が決める。
 * 見た目は iOS Sample の `SampleFloatingPanel` とそろえる。
 *
 * @param modifier パネルに付ける修飾
 * @param content パネルの中身
 */
@Composable
fun SampleFloatingPanel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = modifier
            .samplePanelSurface(RoundedCornerShape(SamplePanelMetrics.cornerRadius))
            .padding(
                horizontal = SamplePanelMetrics.horizontalPadding,
                vertical = SamplePanelMetrics.verticalPadding,
            ),
        verticalArrangement = Arrangement.spacedBy(SamplePanelMetrics.rowSpacing),
        horizontalAlignment = Alignment.CenterHorizontally,
        content = content,
    )
}
