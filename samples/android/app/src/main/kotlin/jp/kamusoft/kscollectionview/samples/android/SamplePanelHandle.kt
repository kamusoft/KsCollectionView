package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.font.FontWeight

/**
 * 操作のパネルを畳んだときに残る丸いボタン。押すとパネルを広げる。
 *
 * @param onUnfold 押したときの処理
 * @param modifier ボタンに付ける修飾
 */
@Composable
fun SamplePanelHandle(onUnfold: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(SamplePanelMetrics.handleSize)
            .samplePanelSurface(CircleShape)
            .clickable(onClick = onUnfold)
            // 図案の文字ではなく、操作の名前を読み上げる。
            .clearAndSetSemantics {
                contentDescription = SamplePanelText.Unfold
                role = Role.Button
                onClick { onUnfold(); true }
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "›",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = SampleTheme.accent,
        )
    }
}
