package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * コレクションの上に置く操作列のはこ。
 *
 * 余白と背景をここで揃え、画面ごとに操作の中身だけを渡す。
 *
 * @param verticalArrangement 操作を縦に複数並べるときの並べ方
 * @param content 操作の中身
 */
@Composable
fun SampleControlBar(
    modifier: Modifier = Modifier,
    verticalArrangement: Arrangement.Vertical = Arrangement.Top,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(SampleTheme.cell)
            .padding(
                horizontal = SampleTheme.horizontalPadding,
                vertical = SampleTheme.controlVerticalPadding,
            ),
        verticalArrangement = verticalArrangement,
        content = content,
    )
}
