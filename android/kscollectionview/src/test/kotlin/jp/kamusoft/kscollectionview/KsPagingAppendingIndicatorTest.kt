package jp.kamusoft.kscollectionview

import android.view.View
import androidx.compose.foundation.LocalOverscrollFactory
import androidx.compose.foundation.OverscrollEffect
import androidx.compose.foundation.OverscrollFactory
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.node.DelegatableNode
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 項目があるときの次のページの読み込み中の表示が、一覧の見えている範囲の下端に止まって重なること
 * (置き場・スクロールしても動かないこと・消えること・フッターの枠に影響しないこと・タッチの通し方・
 * 差し替えた表示の置き場) を確かめる。
 *
 * 表示の下端は、見えている範囲の下端から「下端のシステムバーとの重なり + 8dp」だけ上に来る。下の余白
 * (contentPadding) では位置は変わらない。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPagingAppendingIndicatorTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val width = 300.dp
    private val height = 600.dp
    private val rowHeight = 60.dp
    private val margin = 8.dp
    private val tolerance = 1.dp

    /**
     * list で、見えている範囲の下端から 8dp 上・横の中央に、下地の無い標準の読み込み中の表示 (直径 24dp) が
     * 出て、スクロールしても動かない。
     */
    @Test
    fun defaultIndicatorStaysAtViewportBottomInList() {
        assertIndicatorStaysAt(KsLayout.List, bottomPadding = 0.dp, expectedBottom = height - margin)
    }

    /** グリッドでも、下の余白によらず同じ位置 (見えている範囲の下端から 8dp 上) に出る。 */
    @Test
    fun defaultIndicatorIgnoresBottomPaddingInGrid() {
        val grid = KsLayout.Grid(KsColumns.Fixed(2))
        assertIndicatorStaysAt(grid, bottomPadding = 0.dp, expectedBottom = height - margin)
        assertIndicatorStaysAt(grid, bottomPadding = 100.dp, expectedBottom = height - margin, reuse = true)
    }

    /** list で下の余白があっても、表示の位置は変わらない。 */
    @Test
    fun defaultIndicatorIgnoresBottomPaddingInList() {
        assertIndicatorStaysAt(KsLayout.List, bottomPadding = 100.dp, expectedBottom = height - margin)
    }

    /** 全画面の一覧が下端のナビゲーションバーに重なるときは、重なりの分だけ上に出る。 */
    @Test
    fun defaultIndicatorStaysAboveNavigationBarOverlap() {
        val fullHeight = 800.dp
        val navigationBar = 48.dp
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        // 下の余白があっても、上がるのはシステムバーとの重なりの分だけ。
        setContent(vm, containerWidth = 400.dp, containerHeight = fullHeight, bottomPadding = 100.dp)
        applyNavigationBarInsets(navigationBar)
        settle()
        val bounds = indicatorBounds()
        assertNear(fullHeight - navigationBar - margin, bounds.bottom, "表示の下端")
        assertNear(200.dp, (bounds.left + bounds.right) / 2, "横の中央")
        scrollBy(600.dp)
        assertNear(bounds.top, indicatorBounds().top, "スクロールしても動かない")
    }

    /** 状態が待機に戻ったら消える。 */
    @Test
    fun indicatorDisappearsWhenIdle() {
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        setContent(vm)
        settle()
        assertEquals(1, composeTestRule.countIndeterminateProgress())

        composeTestRule.runOnUiThread { vm.state = KsPagingState.EndReached }
        composeTestRule.awaitCondition("表示が消える", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 0
        }
    }

    /** 追加読み込み中の間も、フッターの枠の高さは変わらない (最後の項目のすぐ下に利用者のフッターが続く)。 */
    @Test
    fun footerSlotHeightDoesNotChangeWhileAppending() {
        val vm = KsPagingProbeVm(testItems(5), state = KsPagingState.Idle)
        vm.loadMoreGate = kotlinx.coroutines.CompletableDeferred()
        setContent(vm, footer = { Box(Modifier.fillMaxWidth().height(40.dp).testTag("root-footer")) })
        val gapBefore = composeTestRule.topOfTag("root-footer") - composeTestRule.bottomOfTag("item-4")
        val footerHeightBefore = composeTestRule.bottomOfTag("root-footer") - composeTestRule.topOfTag("root-footer")

        composeTestRule.runOnUiThread { vm.state = KsPagingState.Appending }
        settle()
        assertEquals(1, composeTestRule.countIndeterminateProgress())
        assertNear(gapBefore, composeTestRule.topOfTag("root-footer") - composeTestRule.bottomOfTag("item-4"), "枠のページングの部分は高さを持たない")
        assertNear(
            footerHeightBefore,
            composeTestRule.bottomOfTag("root-footer") - composeTestRule.topOfTag("root-footer"),
            "利用者のフッターの高さも変わらない",
        )
        composeTestRule.runOnUiThread { vm.loadMoreGate?.complete(Unit) }
    }

    /** 既定の表示はタッチを受けず、その下の項目のタップが届く。 */
    @Test
    fun tapOnDefaultIndicatorReachesItemBelow() {
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        val tapped = mutableListOf<String>()
        setContent(vm, onItemTap = { tapped += it.id })
        settle()
        val bounds = indicatorBounds()
        tapAt((bounds.left + bounds.right) / 2, (bounds.top + bounds.bottom) / 2)
        // 表示の真ん中 (上端から 572dp) の下には 9 番目 (540〜600dp) の項目がある。
        assertEquals(listOf("item-9"), tapped)
    }

    /** 差し替えた表示は下地なしで同じ置き場に出て、その範囲のタッチだけを受け、外は下の項目へ通す。 */
    @Test
    fun substitutedIndicatorUsesSamePlacementAndOnlyItsOwnTouches() {
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        val tapped = mutableListOf<String>()
        var customTaps = 0
        setContent(
            vm,
            onItemTap = { tapped += it.id },
            appendingIndicator = {
                Text("読み込み中", Modifier.size(120.dp, 30.dp).clickable { customTaps += 1 }.testTag("custom"))
            },
        )
        settle()
        assertEquals("既定の表示は出ない", 0, composeTestRule.countIndeterminateProgress())
        val bounds = composeTestRule.onNodeWithTag("custom").getUnclippedBoundsInRoot()
        assertNear(height - margin, bounds.bottom, "同じ置き場 (下端)")
        assertNear(width / 2, (bounds.left + bounds.right) / 2, "同じ置き場 (横の中央)")

        tapAt((bounds.left + bounds.right) / 2, (bounds.top + bounds.bottom) / 2)
        assertEquals("表示の範囲のタッチは表示が受ける", 1, customTaps)
        assertEquals(emptyList<String>(), tapped)

        tapAt(10.dp, (bounds.top + bounds.bottom) / 2)
        assertEquals("表示の外のタッチは下の項目へ通る", listOf("item-9"), tapped)
    }

    /** 押せる部品を持たない差し替えた表示でも、その範囲のタップは止め (下の項目へ通さない)、範囲の外は下へ通す。 */
    @Test
    fun substitutedIndicatorWithoutButtonBlocksTouchesInsideItsBounds() {
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        val tapped = mutableListOf<String>()
        setContent(
            vm,
            onItemTap = { tapped += it.id },
            appendingIndicator = { Text("読み込み中", Modifier.size(120.dp, 30.dp).testTag("custom")) },
        )
        settle()
        val bounds = composeTestRule.onNodeWithTag("custom").getUnclippedBoundsInRoot()

        tapAt((bounds.left + bounds.right) / 2, (bounds.top + bounds.bottom) / 2)
        assertEquals("表示の範囲のタップは下の項目へ届かない", emptyList<String>(), tapped)

        tapAt(10.dp, (bounds.top + bounds.bottom) / 2)
        assertEquals("表示の外のタッチは下の項目へ通る", listOf("item-9"), tapped)
    }

    /** 差し替えた表示の範囲から縦にドラッグすると、一覧がスクロールする (list)。 */
    @Test
    fun dragFromSubstitutedIndicatorScrollsListInList() {
        assertDragFromSubstitutedIndicatorScrolls(KsLayout.List)
    }

    /** 同じくグリッドでも、差し替えた表示の範囲から始めたドラッグで一覧がスクロールする。 */
    @Test
    fun dragFromSubstitutedIndicatorScrollsListInGrid() {
        assertDragFromSubstitutedIndicatorScrolls(KsLayout.Grid(KsColumns.Fixed(2)))
    }

    private fun assertDragFromSubstitutedIndicatorScrolls(layout: KsLayout) {
        val vm = KsPagingProbeVm(testItems(100), state = KsPagingState.Appending)
        setContent(
            vm,
            layout = layout,
            appendingIndicator = { Text("読み込み中", Modifier.size(120.dp, 30.dp).testTag("custom")) },
        )
        settle()
        val before = composeTestRule.topOfTag("item-0")
        val bounds = composeTestRule.onNodeWithTag("custom").getUnclippedBoundsInRoot()
        val start = with(composeTestRule.density) {
            Offset(((bounds.left + bounds.right) / 2).toPx(), ((bounds.top + bounds.bottom) / 2).toPx())
        }
        val distance = with(composeTestRule.density) { 300.dp.toPx() }
        composeTestRule.onRoot().performTouchInput {
            swipe(start, Offset(start.x, start.y - distance), durationMillis = 500)
        }
        composeTestRule.waitForIdle()
        val after = if (composeTestRule.countNodesWithTag("item-0") == 0) null else composeTestRule.topOfTag("item-0")
        assertTrue(
            "$layout: 差し替えた表示の範囲から始めたドラッグで一覧がスクロールする (前 $before / 後 $after)",
            after == null || after < before - 100.dp,
        )
    }

    /**
     * 差し替えた表示の範囲から始めたドラッグも、一覧と同じ端で伸びる効果 (オーバースクロール) を通る。
     * 効果の実体を記録するものに差し替え、一覧の範囲から始めたドラッグと同じ実体にスクロールが渡ることを確かめる。
     */
    @Test
    fun dragFromSubstitutedIndicatorUsesListOverscrollEffect() {
        val recorder = RecordingOverscrollFactory()
        val vm = KsPagingProbeVm(testItems(100), state = KsPagingState.Appending)
        composeTestRule.setContent {
            CompositionLocalProvider(LocalOverscrollFactory provides recorder) {
                TestContainer(width, height) {
                    KsCollectionView(
                        items = vm.items,
                        key = { it.id },
                        listSeparators = false,
                        paging = KsPaging(
                            state = vm.state,
                            onLoadMore = vm.loadMore,
                            appendingIndicator = { Text("読み込み中", Modifier.size(120.dp, 30.dp).testTag("custom")) },
                        ),
                    ) { template { item -> Text(item.text, Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) } }
                }
            }
        }
        settle()
        val bounds = composeTestRule.onNodeWithTag("custom").getUnclippedBoundsInRoot()
        val start = with(composeTestRule.density) {
            Offset(((bounds.left + bounds.right) / 2).toPx(), ((bounds.top + bounds.bottom) / 2).toPx())
        }
        val distance = with(composeTestRule.density) { 300.dp.toPx() }
        composeTestRule.onRoot().performTouchInput {
            swipe(start, Offset(start.x, start.y - distance), durationMillis = 500)
        }
        composeTestRule.waitForIdle()

        assertEquals("効果の実体は一覧で 1 つだけ", 1, recorder.created.size)
        assertTrue(
            "差し替えた表示の範囲から始めたドラッグが、一覧の効果を通る (実測 ${recorder.created.single().scrollCount} 回)",
            recorder.created.single().scrollCount > 0,
        )
    }

    /** 作った効果を覚え、スクロールが通った回数を数える。 */
    private class RecordingOverscrollFactory : OverscrollFactory {
        val created = mutableListOf<RecordingOverscroll>()

        override fun createOverscrollEffect(): OverscrollEffect = RecordingOverscroll().also { created += it }

        override fun hashCode(): Int = System.identityHashCode(this)

        override fun equals(other: Any?): Boolean = other === this
    }

    private class RecordingOverscroll : OverscrollEffect {
        var scrollCount = 0

        override fun applyToScroll(
            delta: Offset,
            source: NestedScrollSource,
            performScroll: (Offset) -> Offset,
        ): Offset {
            scrollCount += 1
            return performScroll(delta)
        }

        override suspend fun applyToFling(velocity: Velocity, performFling: suspend (Velocity) -> Velocity) {
            performFling(velocity)
        }

        override val isInProgress: Boolean = false

        override val node: DelegatableNode = object : Modifier.Node() {}
    }

    // ---- 補助 ----

    /** [reuse] が true なら、同じ試験の中で一覧を置き直す (前の一覧を取り除いてから置く)。 */
    private fun assertIndicatorStaysAt(layout: KsLayout, bottomPadding: Dp, expectedBottom: Dp, reuse: Boolean = false) {
        val vm = KsPagingProbeVm(testItems(100), state = KsPagingState.Appending)
        if (reuse) {
            composeTestRule.runOnUiThread { contentHolder.value = null }
            composeTestRule.waitForIdle()
        }
        setContent(vm, layout = layout, bottomPadding = bottomPadding)
        settle()
        val first = indicatorBounds()
        assertNear(expectedBottom, first.bottom, "$layout: 表示の下端")
        // 下地が無いので、読み込み中の表示そのものの下端が置き場の下端になる。
        assertNear(24.dp, first.bottom - first.top, "$layout: 読み込み中の表示の直径")
        assertNear(width / 2, (first.left + first.right) / 2, "$layout: 横の中央")

        for (distance in listOf(300.dp, 900.dp)) {
            scrollBy(distance)
            val moved = indicatorBounds()
            assertNear(first.top, moved.top, "$layout: ${distance} スクロールしても動かない")
        }
        composeTestRule.scrollListToIndex(99)
        assertNear(first.top, indicatorBounds().top, "$layout: 末尾まで送っても動かない")
    }

    private fun setContent(
        vm: KsPagingProbeVm,
        layout: KsLayout = KsLayout.List,
        bottomPadding: Dp = 0.dp,
        containerWidth: Dp = width,
        containerHeight: Dp = height,
        footer: (@Composable () -> Unit)? = null,
        onItemTap: ((TestItem) -> Unit)? = null,
        appendingIndicator: (@Composable () -> Unit)? = null,
    ) {
        val content: @Composable () -> Unit = {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    layout = layout,
                    contentPadding = PaddingValues(bottom = bottomPadding),
                    footer = footer,
                    onItemTap = onItemTap,
                    listSeparators = false,
                    paging = KsPaging(
                        state = vm.state,
                        onLoadMore = vm.loadMore,
                        appendingIndicator = appendingIndicator,
                    ),
                ) { template { item -> Text(item.text, Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) } }
            }
        }
        if (!contentSet) {
            contentSet = true
            composeTestRule.setContent { contentHolder.value?.invoke() }
        }
        composeTestRule.runOnUiThread { contentHolder.value = content }
        composeTestRule.waitForIdle()
    }

    private var contentSet = false
    private val contentHolder = androidx.compose.runtime.mutableStateOf<(@Composable () -> Unit)?>(null)

    /** 出るフェードが終わるまで進める。 */
    private fun settle() {
        composeTestRule.mainClock.advanceTimeBy(500)
        composeTestRule.waitForIdle()
    }

    private fun indicatorBounds(): DpRect {
        // 既定の表示は下地を持たず、標準の読み込み中の表示だけでできている。
        return composeTestRule.onNode(isIndeterminateProgress).getUnclippedBoundsInRoot()
    }

    private fun scrollBy(distance: Dp) {
        val px = with(composeTestRule.density) { distance.toPx() }
        composeTestRule.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, px) }
        composeTestRule.waitForIdle()
    }

    private fun tapAt(x: Dp, y: Dp) {
        val offset = with(composeTestRule.density) { Offset(x.toPx(), y.toPx()) }
        composeTestRule.onRoot().performTouchInput { click(offset) }
        composeTestRule.waitForIdle()
    }

    private fun applyNavigationBarInsets(bottom: Dp) {
        val view = composeView()
        val bottomPx = with(composeTestRule.density) { bottom.roundToPx() }
        composeTestRule.runOnUiThread {
            val insets = android.view.WindowInsets.Builder()
                .setInsets(android.view.WindowInsets.Type.navigationBars(), android.graphics.Insets.of(0, 0, 0, bottomPx))
                .build()
            view.dispatchApplyWindowInsets(insets)
        }
        composeTestRule.waitForIdle()
    }

    private fun composeView(): View =
        (composeTestRule.onRoot().fetchSemanticsNode().root as ViewRootForTest).view

    private fun assertNear(expected: Dp, actual: Dp, message: String) {
        assertTrue(
            "$message (期待 $expected / 実測 $actual)",
            kotlin.math.abs((expected - actual).value) <= tolerance.value,
        )
    }
}
