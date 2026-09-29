package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
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
 * ページングを付けた一覧の表示範囲の置き方 (差し替えの直前の状態で決める) を、list とグリッドで確かめる。
 *
 * 一覧は幅 300dp・高さ 600dp、行の高さ 60dp。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPagingPositionTest {

    @get:Rule
    val composeTestRule = androidx.compose.ui.test.junit4.v2.createComposeRule()

    private val rowHeight = 60.dp
    private val width = 300.dp
    private val height = 600.dp
    private val tolerance = 1.dp
    private val grid = KsLayout.Grid(KsColumns.Fixed(2))

    // ---- 端を表示中の端への挿入 (ページングの例外) ----

    /** 末尾まで送って追加読み込み中のとき、次のページを足して同じ回に待機にしても、末尾へ送らず今の位置の下に現れる (list)。 */
    @Test
    fun appendedPageAppearsBelowCurrentPositionInList() {
        assertAppendedPageAppearsBelow(KsLayout.List, finalState = KsPagingState.Idle)
    }

    /** 同じくグリッドでも、届いたページは今の位置の下に現れる。 */
    @Test
    fun appendedPageAppearsBelowCurrentPositionInGrid() {
        assertAppendedPageAppearsBelow(grid, finalState = KsPagingState.Idle)
    }

    /** 最後のページが届くのと同時に終端になっても、直前の状態は追加読み込み中なので末尾へ送らない。 */
    @Test
    fun lastPageWithEndReachedDoesNotFollowEnd() {
        assertAppendedPageAppearsBelow(KsLayout.List, finalState = KsPagingState.EndReached)
        assertAppendedPageAppearsBelow(grid, finalState = KsPagingState.EndReached, reuseContent = true)
    }

    /** 状態が終端のまま末尾へ 1 件足すと、表示範囲は末尾に留まり、足した項目が末尾に現れる。 */
    @Test
    fun appendAfterEndReachedStaysAtEnd() {
        for (layout in listOf(KsLayout.List, grid)) {
            val vm = KsPagingProbeVm(testItems(41), state = KsPagingState.EndReached)
            setContent(vm, layout)
            val controller = currentController
            composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
            awaitCommands(controller, 1)

            composeTestRule.runOnUiThread { vm.items = vm.items + TestItem("new", "new") }
            composeTestRule.awaitCondition("足した項目が末尾に出る", observed = { bottomOrNull("new") }) {
                bottomOrNull("new")?.let { kotlin.math.abs((it - height).value) <= tolerance.value } == true
            }
            composeTestRule.waitForIdle()
            resetContent()
        }
    }

    // ---- 取り直しの結果は先頭から表示する ----

    /** 500 件を途中までスクロールして取り直すと、差し替えと同時に先頭を表示し、次ページ要求はすぐ呼ばれない。 */
    @Test
    fun refreshInTheMiddleShowsTopAndDoesNotRequestImmediately() {
        for (layout in listOf(KsLayout.List, grid)) {
            assertRefreshShowsTop(layout, count = 500)
            resetContent()
        }
    }

    /** 10,000 件を途中までスクロールして取り直しても、先頭を表示する。 */
    @Test
    fun refreshOfLargeListShowsTop() {
        assertRefreshShowsTop(KsLayout.List, count = 10_000)
    }

    /** 先頭で取り直し中に、新しい項目を先頭に含む配列へ差し替えて待機にすると、先頭のまま新しい項目が見える。 */
    @Test
    fun pullRefreshAtTopKeepsTopAndShowsNewItems() {
        for (layout in listOf(KsLayout.List, grid)) {
            val vm = KsPagingProbeVm(testItems(40))
            setContent(vm, layout)
            composeTestRule.runOnUiThread { vm.state = KsPagingState.Refreshing }
            composeTestRule.waitForIdle()
            composeTestRule.runOnUiThread {
                vm.items = listOf(TestItem("fresh", "fresh")) + vm.items
                vm.state = KsPagingState.Idle
            }
            composeTestRule.waitForIdle()
            assertNear(0.dp, composeTestRule.topOfTag("fresh"), "新しい項目が先頭に見える")
            resetContent()
        }
    }

    /**
     * 0 件で開いて最初のページが届くと、コンテンツの先頭 (最初の項目) から並べ、次ページ要求は続かない
     * (list / グリッド、ルートのフッターの有無)。フッターの枠を保って末尾に着地してはいけない。
     */
    @Test
    fun firstPageFromEmptyShowsTop() {
        for (layout in listOf(KsLayout.List, grid)) {
            val vm = KsPagingProbeVm(emptyList())
            val gate = kotlinx.coroutines.CompletableDeferred<Unit>()
            vm.onLoadMore = { state = KsPagingState.Appending }
            vm.loadMoreGate = gate
            setContent(vm, layout)
            composeTestRule.awaitCondition("最初の読み込み", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
            composeTestRule.runOnUiThread {
                vm.items = testItems(50)
                vm.state = KsPagingState.Idle
                gate.complete(Unit)
            }
            composeTestRule.waitForIdle()
            assertNear(0.dp, composeTestRule.topOfTag("item-0"), "$layout: 最初の項目から並ぶ")
            composeTestRule.assertStaysFor("$layout: 2 ページ目は続けて読み込まれない") { vm.loadMoreCount }
            assertEquals(1, vm.loadMoreCount)
            resetContent()
        }
    }

    /** 0 件の失敗から再試行で最初のページが届いたときも、最初の項目から並べる。 */
    @Test
    fun firstPageAfterRetryFromEmptyFailureShowsTop() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.Failed)
        setContent(vm, KsLayout.List)
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Appending }
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread {
            vm.items = testItems(50)
            vm.state = KsPagingState.Idle
        }
        composeTestRule.waitForIdle()
        assertNear(0.dp, composeTestRule.topOfTag("item-0"), "最初の項目から並ぶ")
        composeTestRule.assertStaysFor("2 ページ目は続けて読み込まれない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
    }

    /** 待機のまま配列だけを差し替えると、先頭に戻さず既定の位置の保ち方になる。 */
    @Test
    fun replacementWithoutRefreshingDoesNotReturnToTop() {
        for (layout in listOf(KsLayout.List, grid)) {
            val vm = KsPagingProbeVm(testItems(500))
            setContent(vm, layout)
            composeTestRule.scrollListToIndex(200)
            val before = composeTestRule.topOfTag("item-200")

            // 同じ ID のまま中身を書き換えた配列に差し替える。
            composeTestRule.runOnUiThread { vm.items = vm.items.map { it.copy(text = "${it.text}!") } }
            composeTestRule.waitForIdle()
            assertEquals("先頭に戻らない", 0, composeTestRule.countNodesWithTag("item-0"))
            assertNear(before, composeTestRule.topOfTag("item-200"), "見ていた項目の位置を保つ")
            resetContent()
        }
    }

    /** ページングを付けていない一覧では、取り直しの規則は働かない (配列を差し替えても先頭へ送らない)。 */
    @Test
    fun collectionWithoutPagingKeepsDefaultPositioning() {
        var items by androidx.compose.runtime.mutableStateOf(testItems(500))
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(items = items, key = { it.id }, listSeparators = false) {
                    template { item -> PagingRow(item) }
                }
            }
        }
        composeTestRule.scrollListToIndex(200)
        composeTestRule.runOnUiThread { items = items.map { it.copy(text = "${it.text}!") } }
        composeTestRule.waitForIdle()
        assertEquals(0, composeTestRule.countNodesWithTag("item-0"))
    }

    // ---- 補助 ----

    private fun assertAppendedPageAppearsBelow(layout: KsLayout, finalState: KsPagingState, reuseContent: Boolean = false) {
        if (reuseContent) resetContent()
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        setContent(vm, layout)
        val controller = currentController
        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        awaitCommands(controller, 1)
        assertEquals("末尾に次のページの読み込み中が見えている", 1, composeTestRule.countIndeterminateProgress())
        val before = composeTestRule.bottomOfTag("item-39")

        composeTestRule.runOnUiThread {
            vm.items = vm.items + testItems(40, prefix = "next")
            vm.state = finalState
        }
        composeTestRule.assertStaysFor("表示範囲は末尾へ送られない", frames = 40) {
            composeTestRule.bottomOfTag("item-39").value.toInt()
        }
        assertNear(before, composeTestRule.bottomOfTag("item-39"), "見ていた項目は動かない")
        assertTrue(
            "届いた項目は今の位置の下",
            composeTestRule.countNodesWithTag("next-0") == 0 ||
                composeTestRule.topOfTag("next-0") >= composeTestRule.bottomOfTag("item-39") - tolerance,
        )
        assertEquals("残りがしきい値を超えるので次ページ要求は続かない", 0, vm.loadMoreCount)
    }

    private fun assertRefreshShowsTop(layout: KsLayout, count: Int) {
        val vm = KsPagingProbeVm(testItems(count))
        setContent(vm, layout)
        composeTestRule.scrollListToIndex(count / 2)
        assertEquals(0, composeTestRule.countNodesWithTag("item-0"))

        composeTestRule.runOnUiThread { vm.state = KsPagingState.Refreshing }
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread {
            vm.items = testItems(50, prefix = "first")
            vm.state = KsPagingState.Idle
        }
        composeTestRule.waitForIdle()
        assertNear(0.dp, composeTestRule.topOfTag("first-0"), "$layout: 差し替えと同時に先頭を表示する")
        composeTestRule.assertStaysFor("$layout: 次ページ要求はすぐ呼ばれない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
    }

    private var contentHolder = androidx.compose.runtime.mutableStateOf<(@Composable () -> Unit)?>(null)
    private var contentSet = false
    private lateinit var currentController: KsScrollController

    /** 1 つの試験の中で一覧を作り直せるよう、中身を差し替えられる入れ物に置く。 */
    private fun setContent(vm: KsPagingProbeVm, layout: KsLayout) {
        val controller = KsScrollController()
        currentController = controller
        val content: @Composable () -> Unit = {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    layout = layout,
                    listSeparators = false,
                    scrollController = controller,
                    paging = KsPaging(state = vm.state, onLoadMore = vm.loadMore),
                ) { template { item -> PagingRow(item) } }
            }
        }
        if (!contentSet) {
            contentSet = true
            composeTestRule.setContent { contentHolder.value?.invoke() }
        }
        composeTestRule.runOnUiThread { contentHolder.value = content }
        composeTestRule.waitForIdle()
    }

    private fun resetContent() {
        composeTestRule.runOnUiThread { contentHolder.value = null }
        composeTestRule.waitForIdle()
    }

    private fun bottomOrNull(tag: String): Dp? =
        if (composeTestRule.countNodesWithTag(tag) == 0) null else composeTestRule.bottomOfTag(tag)

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

    @Composable
    private fun PagingRow(item: TestItem) {
        Text(item.text, Modifier.fillMaxWidth().height(rowHeight).testTag(item.id))
    }
}
