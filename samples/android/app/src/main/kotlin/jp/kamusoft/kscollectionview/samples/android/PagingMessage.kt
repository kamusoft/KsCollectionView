package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
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

/**
 * 「ページング」画面の失敗・終端・空の表示。文言と、失敗のときは「再試行」を縦に並べる。
 *
 * 最後の項目の後ろ (失敗・終端) と、項目が 0 件のときの一覧の真ん中 (失敗・空) の両方に使う。
 * 並べ方と色は iOS Sample の `PagingMessageView` とそろえる。
 *
 * @param message 文言
 * @param modifier 表示全体に付ける修飾
 * @param retry 再試行の操作。失敗の表示だけが持つ
 */
@Composable
fun PagingMessage(
    message: String,
    modifier: Modifier = Modifier,
    retry: (() -> Unit)? = null,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(PagingMessageMetrics.messageSpacing),
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = SampleTheme.secondaryText,
            textAlign = TextAlign.Center,
        )
        if (retry != null) {
            val shape = RoundedCornerShape(PagingMessageMetrics.retryCornerRadius)
            Text(
                text = PagingDemoText.Retry,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = SampleTheme.accent,
                modifier = Modifier
                    .clip(shape)
                    .background(SampleTheme.cell)
                    .clickable(role = Role.Button, onClick = retry)
                    .padding(
                        horizontal = PagingMessageMetrics.retryHorizontalPadding,
                        vertical = PagingMessageMetrics.retryVerticalPadding,
                    ),
            )
        }
    }
}
