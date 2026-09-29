package jp.kamusoft.kscollectionview

import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * コンポーズの根 (ComposeView) を画面の一部に埋め込んだ構成で、項目が 0 件のときのページングの表示が、
 * 実際に重なっている安全領域だけを除いた範囲の真ん中に出ることを確かめる。
 *
 * 根の上に別の View を置き、根はウィンドウの下端に届かない高さにする。ナビゲーションバーの insets は
 * ウィンドウの下端からの長さなので、根の下端がそこまで届いていなければ重なりは無い。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPagingEmbeddedSafeAreaTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    private val tolerance = 1.dp
    private val aboveHeight = 100.dp
    private val navigationBar = 48.dp

    /** 根の上に別の View があり、根がウィンドウの下端に届かないとき、下端の安全領域に重ならないので真ん中はずれない。 */
    @Test
    fun embeddedRootAboveNavigationBarIsNotTreatedAsOverlapping() {
        val composeView = setEmbeddedContent(rootHeight = 400.dp)
        dispatchNavigationBar(composeView)

        assertNear(200.dp, center("empty"), "根の高さ 400dp の真ん中")
    }

    /** 根がウィンドウの下端まで届いて、ナビゲーションバーに重なるときは、その分を除いた範囲の真ん中になる。 */
    @Test
    fun embeddedRootReachingWindowBottomExcludesOnlyTheOverlap() {
        // 上の View 100dp + 根 700dp = ウィンドウの高さ 800dp。下端の 48dp がナビゲーションバーに重なる。
        val composeView = setEmbeddedContent(rootHeight = 700.dp)
        dispatchNavigationBar(composeView)

        assertNear((700.dp - navigationBar) / 2, center("empty"), "重なった 48dp を除いた範囲の真ん中")
    }

    private fun setEmbeddedContent(rootHeight: Dp): ComposeView {
        lateinit var composeView: ComposeView
        composeTestRule.runOnUiThread {
            val activity = composeTestRule.activity
            val density = activity.resources.displayMetrics.density
            val container = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
            container.addView(
                View(activity),
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (aboveHeight.value * density).toInt()),
            )
            composeView = ComposeView(activity).apply {
                setContent {
                    Box(Modifier.fillMaxSize()) {
                        KsCollectionView(
                            items = emptyList<TestItem>(),
                            key = { it.id },
                            modifier = Modifier.fillMaxSize(),
                            paging = KsPaging(
                                state = KsPagingState.EndReached,
                                onLoadMore = {},
                                emptyPlaceholder = { Box(Modifier.fillMaxWidth().height(20.dp).testTag("empty")) },
                            ),
                        ) { template { } }
                    }
                }
            }
            container.addView(
                composeView,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (rootHeight.value * density).toInt()),
            )
            activity.setContentView(container)
        }
        composeTestRule.waitForIdle()
        val location = composeTestRule.runOnUiThread { IntArray(2).also { composeView.getLocationInWindow(it) }[1] }
        val expectedTop = composeTestRule.runOnUiThread {
            (aboveHeight.value * composeTestRule.activity.resources.displayMetrics.density).toInt()
        }
        assertEquals("根は上の View の下にある (前提)", expectedTop, location)
        return composeView
    }

    /** 根のビューへ、下端にナビゲーションバーの insets を配る (ウィンドウの下端からの長さ)。 */
    private fun dispatchNavigationBar(view: View) {
        val bottomPx = with(composeTestRule.density) { navigationBar.roundToPx() }
        composeTestRule.runOnUiThread {
            val insets = android.view.WindowInsets.Builder()
                .setInsets(android.view.WindowInsets.Type.navigationBars(), android.graphics.Insets.of(0, 0, 0, bottomPx))
                .build()
            view.dispatchApplyWindowInsets(insets)
        }
        composeTestRule.waitForIdle()
    }

    private fun center(tag: String): Dp {
        val bounds = composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot()
        return (bounds.top + bounds.bottom) / 2
    }

    private fun assertNear(expected: Dp, actual: Dp, message: String) {
        assertTrue(
            "$message (期待 $expected / 実測 $actual)",
            kotlin.math.abs((expected - actual).value) <= tolerance.value,
        )
    }
}
