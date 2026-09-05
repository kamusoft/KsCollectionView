package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Sample 共通の配色と寸法。
 *
 * 実値がプラットフォーム間でずれる OS の semantic color は使わず、iOS Sample の同名定義と
 * 同じ RGBA・同じ寸法をここに置く (cross/ADR-0004)。
 */
object SampleTheme {
    val accent = Color(0xFF2F6FED)
    val background = Color(0xFFF2F2F7)
    val cell = Color(0xFFFFFFFF)
    val text = Color(0xFF111214)
    val secondaryText = Color(0xFF6E7076)
    val separator = Color(0xFFD9D9DE)

    val horizontalPadding = 16.dp
    val rowVerticalPadding = 12.dp
    val controlVerticalPadding = 10.dp
    val swatchSize = 44.dp
    val gridMinimumHeight = 106.dp

    val swatches = listOf(
        accent,
        Color(0xFFE8604C),
        Color(0xFF3BA55D),
        Color(0xFFE5A50A),
        Color(0xFF8E5BD8),
        Color(0xFF2AA1B3),
        Color(0xFFD3557F),
        Color(0xFF6B7280),
        Color(0xFFB4562E),
    )
}
