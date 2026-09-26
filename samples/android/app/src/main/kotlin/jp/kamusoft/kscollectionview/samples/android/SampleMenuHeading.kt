package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/**
 * ルートメニューの項目群の見出し。下地の色の帯に補助の文字で置き、選べない。
 *
 * 上下の余白は iOS Sample の `SampleMenuHeadingRow` と同じ値にする。
 *
 * @param title 見出しの文言
 */
@Composable
fun SampleMenuHeading(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.bodySmall,
        color = SampleTheme.secondaryText,
        modifier = Modifier
            .fillMaxWidth()
            .background(SampleTheme.background)
            .semantics { heading() }
            .padding(
                start = SampleTheme.horizontalPadding,
                end = SampleTheme.horizontalPadding,
                top = 16.dp,
                bottom = 6.dp,
            ),
    )
}
