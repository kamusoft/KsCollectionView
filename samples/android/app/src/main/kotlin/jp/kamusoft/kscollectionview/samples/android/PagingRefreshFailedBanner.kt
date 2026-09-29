package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign

/**
 * 「ページング」画面で、項目があるときの取り直しに失敗したことを知らせる帯。
 *
 * セル背景の不透明な面に区切り線の色の枠を付け、操作のパネルと同じ影を落とす。文言はテキスト主の太字。
 * 見た目は iOS Sample の `PagingRefreshFailedBanner` とそろえる。出たことは読み上げにも知らせる
 * (読み上げの対象が変わったときに読み上げる領域にする)。
 *
 * @param modifier 帯に付ける修飾
 */
@Composable
fun PagingRefreshFailedBanner(modifier: Modifier = Modifier) {
    Text(
        text = PagingDemoText.RefreshFailed,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.SemiBold,
        color = SampleTheme.text,
        textAlign = TextAlign.Center,
        modifier = modifier
            .fillMaxWidth()
            .pagingPanelSurface(RoundedCornerShape(PagingPanelMetrics.bannerCornerRadius), opacity = 1f)
            .padding(vertical = PagingPanelMetrics.bannerVerticalPadding)
            .semantics { liveRegion = LiveRegionMode.Polite },
    )
}
