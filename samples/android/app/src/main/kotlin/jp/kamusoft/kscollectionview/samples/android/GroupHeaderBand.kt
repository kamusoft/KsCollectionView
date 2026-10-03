package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import java.text.NumberFormat
import java.util.Locale

/**
 * グループの見出しの帯。グループ名を左、件数を右に置く。
 *
 * 背景は画面の背景とも行の面とも違う専用の色で、上端に固定されている間もこの帯のまま表示される。
 *
 * @param name グループ名
 * @param itemCount グループの項目の件数
 */
@Composable
fun GroupHeaderBand(name: String, itemCount: Int, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = GroupHeaderMetrics.height)
            .background(SampleTheme.groupHeader)
            .padding(horizontal = SampleTheme.horizontalPadding)
            // 名前と件数をひとまとまりで読み上げる。
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = SampleTheme.text,
        )
        Text(
            text = groupItemCountText(itemCount),
            style = MaterialTheme.typography.bodySmall,
            color = SampleTheme.secondaryText,
        )
    }
}

/**
 * 見出しの件数の文言。端末の言語設定によらず 3 桁区切りの「1,200 件」の形にする
 * (iOS Sample と同じ文言)。
 *
 * @param count 件数
 */
fun groupItemCountText(count: Int): String =
    "${NumberFormat.getIntegerInstance(Locale.US).format(count)} 件"
