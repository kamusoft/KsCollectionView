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
 * @param loading 画像の読み込み中の表示。既定は、数えることを要求した実行でだけ数える表示を
 *   差し込み、それ以外は本体の既定の表示に任せる。計測用の画面が観測用の表示を渡すときだけ指定する
 */
@Composable
fun ImageGridCell(
    item: DemoItem,
    modifier: Modifier = Modifier,
    // 読み込み中の表示を差し込むのは、数えることを要求した実行だけにする。このセルは
    // デモ画面・計測用の画面・検証画面が共有しており、常時差し込むと「読み込み中の
    // 既定の表示」を観測点に持つ検証画面が本体の既定を通らなくなる。要求が無ければ
    // null になり、本体の既定の表示に任せる。
    loading: (@Composable () -> Unit)? = ImageLoadingSlotCounter.rememberLoadingSlot(item.id),
) {
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
            loading = loading,
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
