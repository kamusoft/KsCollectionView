package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import jp.kamusoft.kscollectionview.KsImage
import jp.kamusoft.kscollectionview.KsImageContentMode
import jp.kamusoft.kscollectionview.KsImageSource

/**
 * 「画像グリッド」の 1 セル。正方形の画像とその下に ID の文言を置く。
 *
 * @param item 表示する要素
 */
@Composable
fun ImageGridCell(item: DemoItem, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(ImageGridMetrics.cellCornerRadius))
            .background(SampleTheme.cell),
    ) {
        KsImage(
            source = KsImageSource.Remote(DemoData.imageUrl(item.id)),
            modifier = Modifier.fillMaxWidth().aspectRatio(1f),
            // 絵そのものに読み上げる意味はないため、読み上げの対象にしない。
            contentDescription = null,
            contentMode = KsImageContentMode.Fill,
        )
        Text(
            text = item.title,
            style = MaterialTheme.typography.bodySmall,
            color = SampleTheme.secondaryText,
            modifier = Modifier.padding(
                horizontal = ImageGridMetrics.captionHorizontalPadding,
                vertical = ImageGridMetrics.captionVerticalPadding,
            ),
        )
    }
}
