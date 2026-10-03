package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * 描かれる場所で使う配色の組。[SampleAppTheme] が外観に応じた組を与える。
 *
 * 与えられていない場所 (画面単体の Composable を直接描くテスト等) ではライトの組になる。
 */
val LocalSamplePalette = staticCompositionLocalOf { SamplePalette.Light }

/**
 * Sample 共通の配色と寸法。
 *
 * 色は [SamplePalette] のライト / ダークの 2 組から、描かれる場所の外観 (ルートメニューで選んだ
 * 外観を Activity の表示モードに上書きしたもの。「システム」なら端末の表示モード) に応じた組の
 * 値を取る。寸法は外観に関わらず同じで、iOS Sample の同名定義と同じ値を置く。
 */
object SampleTheme {
    /** 選択の印・戻る・操作の文言など、強調に使う色。 */
    val accent: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.accent

    /** 画面の下地。 */
    val background: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.background

    /** 行・セル・操作の帯の面。 */
    val cell: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.cell

    /** 主な文字。 */
    val text: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.text

    /** 補助の文字。 */
    val secondaryText: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.secondaryText

    /** 区切りの線。 */
    val separator: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.separator

    /** グループの見出しの帯の面。 */
    val groupHeader: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.groupHeader

    /** アクセントで塗った面の上に載せる文字・印・つまみ。 */
    val onAccent: Color
        @Composable @ReadOnlyComposable get() = LocalSamplePalette.current.onAccent

    val horizontalPadding = 16.dp
    val rowVerticalPadding = 12.dp
    val controlVerticalPadding = 10.dp
    val swatchSize = 44.dp
    val gridMinimumHeight = 106.dp

    /** 色見本。項目の内容を表す色のため、ライト / ダークで同じ値を使う (先頭はライトのアクセントと同じ値)。 */
    val swatches = listOf(
        SamplePalette.Light.accent,
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
