package jp.kamusoft.kscollectionview

import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 一覧を上端の安全領域 (ステータスバー) に重ねて置いたときの、固定中のグループの見出しの位置と、
 * 見出しに覆われた範囲を基準にする位置合わせを確かめる。
 *
 * 安全領域はウィンドウの insets としてコンポーズの根のビューへ直接配る。Robolectric のウィンドウには
 * ステータスバーが無いため、配った insets がそのまま安全領域になる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsCollectionViewSafeAreaTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val tolerance = 1.dp
    private val rowHeight = 50.dp
    private val headerHeight = 30.dp
    private val statusBarHeight = 24.dp

    /** 安全領域に重ねて置くと、固定中の見出しは上端ではなく安全領域の境目に止まり、行は境目より上にも見える。 */
    @Test
    fun pinnedHeaderStopsAtSafeAreaBoundary() {
        setContent()
        applyStatusBarInsets()

        scrollToLazyIndex(10)

        assertNear(statusBarHeight, topOf("header-果物"), "見出しは安全領域の境目で止まる")
        val rowsAboveBoundary = (0 until 30).map { "果物-$it" }.filter { tag ->
            composeTestRule.countNodesWithTag(tag) > 0 && topOf(tag) < statusBarHeight - tolerance
        }
        assertTrue("境目より上に始まる行がある (実測 $rowsAboveBoundary)", rowsAboveBoundary.isNotEmpty())
    }

    /** 次の見出しは安全領域の境目から固定中の見出しを押し上げ、境目で入れ替わる。 */
    @Test
    fun nextHeaderPushesFromSafeAreaBoundary() {
        setContent()
        applyStatusBarInsets()

        // 2 つめの見出しの本来の位置を、境目より 10dp 下に置く (押し上げの途中)。
        scrollToLazyIndex(31)
        scrollBy(-(statusBarHeight + 10.dp))
        assertNear(statusBarHeight + 10.dp, topOf("header-野菜"), "2 つめの見出しは境目の少し下")
        assertNear(topOf("header-野菜"), bottomOf("header-果物"), "最初の見出しは 2 つめに押し上げられる")

        // 2 つめの見出しが境目を越えて上端との間に来ても、境目で止まり、最初の見出しはその上に接する。
        scrollBy(statusBarHeight)
        assertNear(statusBarHeight, topOf("header-野菜"), "2 つめの見出しは境目で止まる")
        assertNear(statusBarHeight, bottomOf("header-果物"), "最初の見出しは 2 つめの見出しの上に接する")
    }

    /** 祖先が上端の insets を消費済みなら、安全領域に重ねて置いても見出しは上端に固定される。 */
    @Test
    fun consumedInsetsAreNotTreatedAsSafeArea() {
        setContent(consumesStatusBars = true)
        applyStatusBarInsets()

        scrollToLazyIndex(10)

        assertNear(0.dp, topOf("header-果物"), "見出しは上端に固定される")
    }

    /** 安全領域に重ならない位置に置いた一覧では、見え方は変わらない (見出しは一覧の上端に固定される)。 */
    @Test
    fun collectionBelowSafeAreaIsUnchanged() {
        val offset = 40.dp
        setContent(topSpacer = offset)
        applyStatusBarInsets()

        scrollToLazyIndex(10)

        assertNear(offset, topOf("header-果物"), "見出しは一覧の上端に固定される")
    }

    /** ID で先頭へ送る命令は、項目を安全領域の境目で止まった見出しのすぐ下に置く。 */
    @Test
    fun scrollToItemPlacesItBelowHeaderAtSafeAreaBoundary() {
        val controller = KsScrollController()
        setContent(controller = controller)
        applyStatusBarInsets()

        composeTestRule.runOnUiThread { controller.scrollTo(id = "野菜-10", animated = false) }
        awaitCommands(controller, 1)

        assertNear(statusBarHeight, topOf("header-野菜"), "見出しは安全領域の境目で止まる")
        assertNear(bottomOf("header-野菜"), topOf("野菜-10"), "項目は見出しのすぐ下")
    }

    /** 列数が変わっても、安全領域の境目で止まった見出しのすぐ下に見えていた項目がそこへ戻る。 */
    @Test
    fun columnChangeKeepsLeadingItemBelowHeaderAtSafeAreaBoundary() {
        var width by mutableStateOf(300.dp)
        var height by mutableStateOf(600.dp)
        val controller = KsScrollController()
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = foods("果物" to 80, "野菜" to 80),
                    key = { it.id },
                    layout = KsLayout.Grid(KsColumns.Fixed(portrait = 2, landscape = 4)),
                    scrollController = controller,
                    groups = KsGroups(by = { it.category }) { category, foodsInGroup ->
                        HeaderText(category, "$category ${foodsInGroup.size}")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }
        applyStatusBarInsets()
        composeTestRule.runOnUiThread { controller.scrollTo(id = "果物-42", animated = false) }
        awaitCommands(controller, 1)
        assertNear(bottomOf("header-果物"), topOf("果物-42"), "縦長で見出しのすぐ下に X")

        composeTestRule.runOnUiThread {
            width = 400.dp
            height = 300.dp
        }
        composeTestRule.waitForIdle()

        assertNear(statusBarHeight, topOf("header-果物"), "見出しは安全領域の境目で止まったまま")
        assertNear(bottomOf("header-果物"), topOf("果物-42"), "横長でも見出しのすぐ下の行に X")
    }

    /** 安全領域はコンテンツの先頭に余白を足さない (ルートのヘッダーは安全領域に被って始まる)。 */
    @Test
    fun rootHeaderStartsUnderSafeArea() {
        setContent(rootHeader = true)
        applyStatusBarInsets()

        assertNear(0.dp, topOf("root-header"), "ルートのヘッダーは上端から始まる")
    }

    // ---- 補助 ----

    private data class Food(val id: String, val category: String)

    private fun foods(vararg groups: Pair<String, Int>): List<Food> =
        groups.flatMap { (category, count) -> (0 until count).map { Food("$category-$it", category) } }

    private fun setContent(
        consumesStatusBars: Boolean = false,
        topSpacer: Dp = 0.dp,
        rootHeader: Boolean = false,
        controller: KsScrollController? = null,
    ) {
        composeTestRule.setContent {
            Column {
                if (topSpacer > 0.dp) Spacer(Modifier.height(topSpacer))
                TestContainer(300.dp, 600.dp) {
                    KsCollectionView(
                        items = foods("果物" to 30, "野菜" to 30),
                        key = { it.id },
                        modifier = if (consumesStatusBars) {
                            Modifier.consumeWindowInsets(WindowInsets.statusBars)
                        } else {
                            Modifier
                        },
                        scrollController = controller,
                        header = if (rootHeader) {
                            { Box(Modifier.fillMaxWidth().height(40.dp).testTag("root-header")) }
                        } else {
                            null
                        },
                        groups = KsGroups(by = { it.category }) { category, foodsInGroup ->
                            HeaderText(category, "$category ${foodsInGroup.size}")
                        },
                    ) {
                        template { food -> FoodRow(food) }
                    }
                }
            }
        }
        composeTestRule.waitForIdle()
    }

    @androidx.compose.runtime.Composable
    private fun FoodRow(food: Food) {
        Text(text = food.id, modifier = Modifier.fillMaxWidth().height(rowHeight).testTag(food.id))
    }

    @androidx.compose.runtime.Composable
    private fun HeaderText(category: String, text: String) {
        Text(
            text = text,
            modifier = Modifier
                .fillMaxWidth()
                .height(headerHeight)
                .background(Color(0xFFEEEEEE))
                .testTag("header-$category"),
        )
    }

    /** コンポーズの根のビューへ、上端にステータスバーの insets を配る。 */
    private fun applyStatusBarInsets() {
        val view = composeView()
        val top = with(composeTestRule.density) { statusBarHeight.roundToPx() }
        composeTestRule.runOnUiThread {
            val insets = android.view.WindowInsets.Builder()
                .setInsets(android.view.WindowInsets.Type.statusBars(), android.graphics.Insets.of(0, top, 0, 0))
                .build()
            view.dispatchApplyWindowInsets(insets)
        }
        composeTestRule.waitForIdle()
        val rootTop = composeTestRule.runOnUiThread {
            IntArray(2).also { view.getLocationInWindow(it) }[1]
        }
        assertEquals("コンポーズの根はウィンドウの上端にある (前提)", 0, rootTop)
    }

    private fun composeView(): View =
        (composeTestRule.onRoot().fetchSemanticsNode().root as ViewRootForTest).view

    private fun scrollToLazyIndex(index: Int) {
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(index)
        composeTestRule.waitForIdle()
    }

    private fun scrollBy(distance: Dp) {
        val px = with(composeTestRule.density) { distance.toPx() }
        composeTestRule.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) {
            it(0f, px)
        }
        composeTestRule.waitForIdle()
    }

    private fun awaitCommands(controller: KsScrollController, count: Int) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (controller.processedCommandCount < count) {
            if (System.nanoTime() > deadline) {
                fail("命令が処理されない (期待 $count 件 / 実測 ${controller.processedCommandCount} 件)")
            }
            composeTestRule.waitForIdle()
            composeTestRule.mainClock.advanceTimeByFrame()
        }
        composeTestRule.waitForIdle()
    }

    private fun assertNear(expected: Dp, actual: Dp, message: String) {
        assertTrue(
            "$message (期待 $expected / 実測 $actual)",
            kotlin.math.abs((expected - actual).value) <= tolerance.value,
        )
    }

    private fun bounds(tag: String) = composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun topOf(tag: String): Dp = bounds(tag).top

    private fun bottomOf(tag: String): Dp = bounds(tag).bottom
}
