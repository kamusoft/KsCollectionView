package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

// 2 組の同じ名前の色は iOS Sample の `SamplePalette.swift` と同じ RGBA にそろえる (cross/ADR-0007)。

/**
 * Sample の配色の 1 組。ライトとダークの 2 組を持ち、画面側は [SampleTheme] の同じ名前の色から、
 * 選んだ外観に応じた組の値を受け取る。
 *
 * OS や Material の semantic color は実値がプラットフォーム間でずれるため使わない。
 *
 * @property accent 選択の印・戻る・操作の文言など、強調に使う色
 * @property background 画面の下地
 * @property cell 行・セル・操作の帯の面
 * @property text 主な文字
 * @property secondaryText 補助の文字
 * @property separator 区切りの線
 * @property onAccent アクセントで塗った面の上に載せる文字・印・つまみ
 */
@Immutable
data class SamplePalette(
    val accent: Color,
    val background: Color,
    val cell: Color,
    val text: Color,
    val secondaryText: Color,
    val separator: Color,
    val onAccent: Color,
) {
    companion object {
        /** ライトの組。 */
        val Light = SamplePalette(
            accent = Color(0xFF2F6FED),
            background = Color(0xFFF2F2F7),
            cell = Color(0xFFFFFFFF),
            text = Color(0xFF111214),
            secondaryText = Color(0xFF6E7076),
            separator = Color(0xFFD9D9DE),
            onAccent = Color(0xFFFFFFFF),
        )

        /**
         * ダークの組。下地と行をアクセントの青の色相に寄せた紺にし、ライブラリの既定の色と
         * 見分けられるようにする。アクセントの上の色は、明るめの青のアクセントの上で白では
         * 読みにくいため、下地の紺にする。
         */
        val Dark = SamplePalette(
            accent = Color(0xFF5B8DF6),
            background = Color(0xFF0D1321),
            cell = Color(0xFF182236),
            text = Color(0xFFE6EBF5),
            secondaryText = Color(0xFF8E9AB3),
            separator = Color(0xFF2A3752),
            onAccent = Color(0xFF0D1321),
        )
    }
}
