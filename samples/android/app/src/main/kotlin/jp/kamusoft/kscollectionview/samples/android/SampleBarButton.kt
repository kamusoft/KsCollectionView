package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

/**
 * 下部バーに並べる操作ボタン。角丸の面に、アクセント色の太字の文言を置く。
 *
 * 見た目は iOS Sample の `SampleBarButtonStyle` とそろえる (面の色は画面の背景色、角丸の半径と
 * 文言の上下の余白は同じ値)。幅は呼び出し側が決める。
 *
 * @param text ボタンの文言
 * @param onClick 押したときの処理
 */
@Composable
fun SampleBarButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(CornerRadius),
        colors = ButtonDefaults.buttonColors(
            containerColor = SampleTheme.background,
            contentColor = SampleTheme.accent,
        ),
        contentPadding = PaddingValues(horizontal = HorizontalPadding, vertical = VerticalPadding),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** 面の角丸の半径。 */
private val CornerRadius = 10.dp

/** 文言の上下の余白。 */
private val VerticalPadding = 10.dp

/** 文言の左右の余白。幅の狭いボタンでも文言が収まるよう、Material の既定より詰める。 */
private val HorizontalPadding = 8.dp
