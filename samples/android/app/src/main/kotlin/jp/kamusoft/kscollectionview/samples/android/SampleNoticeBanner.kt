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
 * 画面の上 (上部バーのすぐ下) に一覧の上へ浮かせて出す知らせの帯。
 *
 * セル背景の不透明な面に区切り線の色の枠を付け、操作のパネルと同じ影を落とす。文言はテキスト主の太字。
 * 見た目は iOS Sample の `SampleNoticeBanner` とそろえる。出たことは読み上げにも知らせる
 * (読み上げの対象が変わったときに読み上げる領域にする)。出す位置と消すまでの時間は [SamplePanelMetrics] の
 * 帯の値を使う。
 *
 * @param text 知らせの文言
 * @param modifier 帯に付ける修飾
 */
@Composable
fun SampleNoticeBanner(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.SemiBold,
        color = SampleTheme.text,
        textAlign = TextAlign.Center,
        modifier = modifier
            .fillMaxWidth()
            .samplePanelSurface(RoundedCornerShape(SamplePanelMetrics.bannerCornerRadius), opacity = 1f)
            .padding(vertical = SamplePanelMetrics.bannerVerticalPadding)
            .semantics { liveRegion = LiveRegionMode.Polite },
    )
}
