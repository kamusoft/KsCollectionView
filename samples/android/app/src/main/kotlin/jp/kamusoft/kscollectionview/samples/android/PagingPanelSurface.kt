package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp

/**
 * 「ページング」画面の操作のパネルと、畳んだときの丸いボタンに共通の面。
 *
 * セル背景の色に不透明度を掛けた面で一覧を透かし、区切り線の色の枠と薄い影を付ける。ぼかしは
 * 使わない (iOS Sample と同じ透け方にするため)。影は iOS Sample と同じぼかしの半径・下へのずれ・
 * 不透明度の黒で描く。
 *
 * @param shape 面の形
 * @param opacity 面の色 (セル背景) の不透明度。既定はパネルの透け方
 */
@Composable
fun Modifier.pagingPanelSurface(shape: Shape, opacity: Float = PagingPanelMetrics.SurfaceOpacity): Modifier = this
    .dropShadow(
        shape = shape,
        shadow = Shadow(
            radius = PagingPanelMetrics.shadowRadius,
            color = Color.Black,
            offset = DpOffset(0.dp, PagingPanelMetrics.shadowOffset),
            alpha = PagingPanelMetrics.ShadowOpacity,
        ),
    )
    .clip(shape)
    .background(SampleTheme.cell.copy(alpha = opacity))
    .border(width = 1.dp, color = SampleTheme.separator, shape = shape)
