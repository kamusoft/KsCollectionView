package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

/**
 * Sample 全体の配色の土台。外観に応じた [SamplePalette] の組を [SampleTheme] に与え、Material の
 * 部品の既定の配色も同じ組から作る。
 *
 * 外観はルートメニューの選択を Activity の表示モードに上書きして反映するため、
 * [isSystemInDarkTheme] は選んだ外観 (「システム」なら端末の表示モード) を返す。
 *
 * @param content 配色を与える内容
 */
@Composable
fun SampleAppTheme(content: @Composable () -> Unit) {
    val palette = if (isSystemInDarkTheme()) SamplePalette.Dark else SamplePalette.Light
    CompositionLocalProvider(LocalSamplePalette provides palette) {
        MaterialTheme(colorScheme = palette.toMaterialColorScheme(), content = content)
    }
}

/**
 * Material の部品が既定で取る色を、Sample の配色の組に写したもの。
 *
 * Sample が色を渡していない部品 (メニューの一覧・スイッチのオフの状態・スライダーの残りの溝・
 * 文字の既定の色など) も Sample の配色で描かれるようにし、Material の既定の配色がライトのまま
 * ダークに混ざらないようにする。メニューの一覧の面は下地の色 (行の色の操作の帯の上で面が見分けられる)、
 * 溝・オフの面は区切りの色、枠・つまみは補助の文字の色にする。
 */
internal fun SamplePalette.toMaterialColorScheme(): ColorScheme {
    val base = if (this == SamplePalette.Dark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = accent,
        onPrimary = onAccent,
        surfaceTint = accent,
        secondaryContainer = separator,
        onSecondaryContainer = text,
        background = background,
        onBackground = text,
        surface = cell,
        onSurface = text,
        surfaceVariant = background,
        onSurfaceVariant = secondaryText,
        surfaceBright = cell,
        surfaceDim = cell,
        surfaceContainerLowest = cell,
        surfaceContainerLow = cell,
        surfaceContainer = background,
        surfaceContainerHigh = cell,
        surfaceContainerHighest = separator,
        outline = secondaryText,
        outlineVariant = separator,
    )
}
