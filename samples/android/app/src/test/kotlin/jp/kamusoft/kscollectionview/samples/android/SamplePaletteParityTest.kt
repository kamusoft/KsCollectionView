package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 配色の 2 組が iOS Sample と同じ RGBA であることと、ダークの組が読める組み合わせであることを確かめる。
 *
 * 期待値は iOS Sample の `SamplePalette.swift` (ライト / ダークの 2 組) と `SampleTheme.swift`
 * (色見本) の値をそのまま書き写したもの。プラットフォーム間の一致は言語をまたぐためコンパイラでは
 * 守れず、片側を写した表との突き合わせで守る。
 */
class SamplePaletteParityTest {

    /** iOS Sample のライトの組。名前は宣言順、値は 0xAARRGGBB。 */
    private val iosLight = listOf(
        "accent" to 0xFF2F6FEDL,
        "background" to 0xFFF2F2F7L,
        "cell" to 0xFFFFFFFFL,
        "text" to 0xFF111214L,
        "secondaryText" to 0xFF6E7076L,
        "separator" to 0xFFD9D9DEL,
        "groupHeader" to 0xFFE3E3EAL,
        "onAccent" to 0xFFFFFFFFL,
    )

    /** iOS Sample のダークの組。名前は宣言順、値は 0xAARRGGBB。 */
    private val iosDark = listOf(
        "accent" to 0xFF5B8DF6L,
        "background" to 0xFF0D1321L,
        "cell" to 0xFF182236L,
        "text" to 0xFFE6EBF5L,
        "secondaryText" to 0xFF8E9AB3L,
        "separator" to 0xFF2A3752L,
        "groupHeader" to 0xFF223050L,
        "onAccent" to 0xFF0D1321L,
    )

    /** iOS Sample の色見本 (両外観で同じ値)。 */
    private val iosSwatches = listOf(
        0xFF2F6FEDL, 0xFFE8604CL, 0xFF3BA55DL, 0xFFE5A50AL, 0xFF8E5BD8L,
        0xFF2AA1B3L, 0xFFD3557FL, 0xFF6B7280L, 0xFFB4562EL,
    )

    @Test
    fun `ライトの組が iOS と同じ名前・同じ並び・同じ値である`() {
        assertEquals(iosLight, SamplePalette.Light.namedArgb())
    }

    @Test
    fun `ダークの組が iOS と同じ名前・同じ並び・同じ値である`() {
        assertEquals(iosDark, SamplePalette.Dark.namedArgb())
    }

    @Test
    fun `色見本は iOS と同じ値で外観に関わらない`() {
        assertEquals(iosSwatches, SampleTheme.swatches.map { it.argb() })
    }

    /** 文字とその背景の組は 4.5:1 以上 (WCAG 2.x の AA)。 */
    @Test
    fun `ダークの組の文字と背景はコントラスト比 4_5 以上である`() {
        with(SamplePalette.Dark) {
            listOf(
                "文字 / 下地" to (text to background),
                "文字 / 行" to (text to cell),
                "補助の文字 / 下地" to (secondaryText to background),
                "補助の文字 / 行" to (secondaryText to cell),
                "文字 / 見出しの帯" to (text to groupHeader),
                "補助の文字 / 見出しの帯" to (secondaryText to groupHeader),
                "アクセント / 下地" to (accent to background),
                "アクセント / 行" to (accent to cell),
                "アクセントの上の色 / アクセント" to (onAccent to accent),
            ).forEach { (name, pair) ->
                val ratio = contrastRatio(pair.first, pair.second)
                assertTrue("$name のコントラスト比が $ratio", ratio >= 4.5)
            }
        }
    }

    /** 区切りは飾りの線のため、ライトの今の比 (約 1.4:1) と同程度の 1.3:1 以上。 */
    @Test
    fun `ダークの組の区切りと行はコントラスト比 1_3 以上である`() {
        with(SamplePalette.Dark) {
            val ratio = contrastRatio(separator, cell)
            assertTrue("区切り / 行 のコントラスト比が $ratio", ratio >= 1.3)
        }
    }

    private fun SamplePalette.namedArgb(): List<Pair<String, Long>> = listOf(
        "accent" to accent.argb(),
        "background" to background.argb(),
        "cell" to cell.argb(),
        "text" to text.argb(),
        "secondaryText" to secondaryText.argb(),
        "separator" to separator.argb(),
        "groupHeader" to groupHeader.argb(),
        "onAccent" to onAccent.argb(),
    )

    /** 0xAARRGGBB の値。sRGB の 8 bit 成分に丸めて比べる。 */
    private fun Color.argb(): Long {
        fun Float.channel(): Long = Math.round(this * 255).toLong()
        return (alpha.channel() shl 24) or (red.channel() shl 16) or (green.channel() shl 8) or blue.channel()
    }

    /** WCAG 2.x のコントラスト比。 */
    private fun contrastRatio(a: Color, b: Color): Double {
        val la = a.luminance().toDouble()
        val lb = b.luminance().toDouble()
        return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
    }
}
