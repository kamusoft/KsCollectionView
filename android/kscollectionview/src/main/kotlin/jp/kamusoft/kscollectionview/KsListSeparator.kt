package jp.kamusoft.kscollectionview

import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * list の区切り線の既定値 (core/ADR-0010)。
 *
 * 既定の色はライト用とダーク用の 2 つの固定値で持ち、iOS 版と同じ値にする (core/ADR-0036)。
 * 利用者アプリの Material のテーマの配色には依存しない。
 */
internal object KsListSeparatorDefaults {
    /** ライトの表示モードの既定の色。 */
    val lightColor: Color = Color(0xFFD9D9DE)

    /** ダークの表示モードの既定の色。 */
    val darkColor: Color = Color(0xFF38383A)

    /**
     * 表示モードに応じた既定の色。
     *
     * @param isDarkTheme 一覧が置かれた画面の構成の夜間モードかどうか
     */
    fun color(isDarkTheme: Boolean): Color = if (isDarkTheme) darkColor else lightColor

    /** 線の太さ。 */
    val thickness = 1.dp
}

/**
 * list の区切り線を項目の content の前面に描く。
 *
 * 先頭の項目だけ上端にも線を引き、すべての項目の下端に線を引くことで、
 * 先頭行の上端・行間・最終行の下端に線が並ぶ。content の前面に描くのは、
 * 不透明な背景を持つテンプレートでも線が隠れないようにするため
 * (iOS 側も区切り線を content の前面に置いている)。
 *
 * @param isVisible 区切り線を描くかどうか
 * @param isFirst 先頭の項目かどうか (上端の線を描く条件)
 * @param color 線の色
 */
internal fun Modifier.ksListSeparator(
    isVisible: Boolean,
    isFirst: Boolean,
    color: Color,
): Modifier = if (!isVisible) {
    this
} else {
    drawWithContent {
        drawContent()
        val thickness = KsListSeparatorDefaults.thickness.toPx()
        if (isFirst) {
            drawRect(color = color, topLeft = Offset.Zero, size = Size(size.width, thickness))
        }
        drawRect(
            color = color,
            topLeft = Offset(0f, size.height - thickness),
            size = Size(size.width, thickness),
        )
    }
}
