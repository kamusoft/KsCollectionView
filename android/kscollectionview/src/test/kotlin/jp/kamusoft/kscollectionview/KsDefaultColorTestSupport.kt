package jp.kamusoft.kscollectionview

import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.test.SemanticsNodeInteraction

/**
 * [content] に届く画面の構成の夜間モードだけを差し替える。
 *
 * 端末の表示モードも画面 (Activity) もそのままにして、アプリが画面の構成を上書きした状態を作る。
 * [isNight] を表示中に書き換えると、画面を作り直さずに表示モードだけが切り替わる。
 */
@Composable
internal fun TestNightModeOverride(isNight: Boolean, content: @Composable () -> Unit) {
    val base = LocalConfiguration.current
    val overridden = remember(base, isNight) {
        Configuration(base).apply {
            val night = if (isNight) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
        }
    }
    CompositionLocalProvider(LocalConfiguration provides overridden, content = content)
}

/** 指定した節点の描画結果を画素として読む。 */
internal fun SemanticsNodeInteraction.capturePixels(): PixelMap {
    val node = fetchSemanticsNode()
    val view = (node.root as ViewRootForTest).view
    val whole = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
    view.draw(Canvas(whole))
    val bounds = node.boundsInRoot
    val left = bounds.left.toInt()
    val top = bounds.top.toInt()
    val width = bounds.width.toInt().coerceAtMost(view.width - left)
    val height = bounds.height.toInt().coerceAtMost(view.height - top)
    return Bitmap.createBitmap(whole, left, top, width, height).asImageBitmap().toPixelMap()
}

/** 失敗のメッセージに載せるための、色の 16 進表記 (AARRGGBB)。 */
internal fun Color.hex(): String = "#%08X".format(toArgb())
