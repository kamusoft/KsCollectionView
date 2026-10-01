package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role

/**
 * 操作のパネル左上の畳むボタン。押すとパネルを左端の丸いボタン ([SamplePanelHandle]) に畳む。
 *
 * @param onFold 押したときの処理
 * @param modifier ボタンに付ける修飾
 */
@Composable
fun SamplePanelFoldButton(onFold: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(SamplePanelMetrics.foldButtonSize)
            .clip(CircleShape)
            .background(SampleTheme.background)
            .clickable(onClick = onFold)
            // 図案の文字ではなく、操作の名前を読み上げる。
            .clearAndSetSemantics {
                contentDescription = SamplePanelText.Fold
                role = Role.Button
                onClick { onFold(); true }
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "‹",
            style = MaterialTheme.typography.titleMedium,
            color = SampleTheme.accent,
        )
    }
}
