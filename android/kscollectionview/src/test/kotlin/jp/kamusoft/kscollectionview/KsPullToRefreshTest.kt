package jp.kamusoft.kscollectionview

import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Pull to Refresh の接続・インジケータの規則・追加読み込みの間の引っ張りの抑止・全画面の一覧での
 * インジケータの位置と、取り直し中の固定中の見出しと先頭の判定を確かめる。
 *
 * 引っ張りは、一覧の上端から下へ指を滑らせる操作として与える。インジケータは標準の部品が取り直し中に
 * 出す不定の読み込み中の表示で数える (項目がある一覧ではページングの表示は読み込み中を出さない)。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPullToRefreshTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val rowHeight = 60.dp
    private val width = 300.dp
    private val height = 600.dp
    private val tolerance = 1.dp

    // ---- 接続 ----

    /** 取り直しの処理を渡した一覧は、ページングの有無によらず、先頭で引っ張ると取り直しの処理が呼ばれる。 */
    @Test
    fun pullCallsRefreshWithAndWithoutPaging() {
        val vm = KsPagingProbeVm(testItems(40))
        var withPaging by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    paging = if (withPaging) KsPaging(state = vm.state, onLoadMore = vm.loadMore) else null,
                    onRefresh = vm.refresh,
                ) { template { item -> PagingRow(item) } }
            }
        }
        pull()
        composeTestRule.awaitCondition("ページングなしの取り直し", observed = { vm.refreshCount }) { vm.refreshCount == 1 }

        composeTestRule.runOnUiThread { withPaging = true }
        composeTestRule.waitForIdle()
        pull()
        composeTestRule.awaitCondition("ページングありの取り直し", observed = { vm.refreshCount }) { vm.refreshCount == 2 }
    }

    /** 取り直しの処理を渡さない一覧は引っ張れない (引っ張ってもインジケータは出ない)。 */
    @Test
    fun collectionWithoutRefreshCannotBePulled() {
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(items = testItems(40), key = { it.id }) { template { item -> PagingRow(item) } }
            }
        }
        pull(release = false)
        assertEquals(0, composeTestRule.countIndeterminateProgress())
        assertNear(0.dp, composeTestRule.topOfTag("item-0"), "一覧は動かない")
    }

    /** 項目が 0 件の一覧でも引っ張れる。 */
    @Test
    fun emptyCollectionCanBePulled() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.EndReached)
        setPagingContent(vm)
        pull()
        composeTestRule.awaitCondition("取り直しの処理", observed = { vm.refreshCount }) { vm.refreshCount == 1 }
    }

    // ---- インジケータの規則 ----

    /** 取り直しの処理の中で待つ VM では、処理が終わるまでインジケータが出て、終わったら消える。 */
    @Test
    fun indicatorShowsUntilWaitingRefreshFinishes() {
        val vm = KsPagingProbeVm(testItems(40))
        vm.refreshGate = CompletableDeferred()
        setPagingContent(vm)
        pull()
        composeTestRule.awaitCondition("取り直しの処理", observed = { vm.refreshCount }) { vm.refreshCount == 1 }
        composeTestRule.assertStaysFor("処理の間はインジケータが出続ける") { composeTestRule.countIndeterminateProgress() }
        assertEquals(1, composeTestRule.countIndeterminateProgress())

        composeTestRule.runOnUiThread { vm.refreshGate?.complete(Unit) }
        composeTestRule.awaitCondition("インジケータが消える", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 0
        }
    }

    /** 処理の中で状態を取り直し中にしてすぐ戻る VM では、状態が待機に戻るまでインジケータが出続ける。 */
    @Test
    fun indicatorStaysWhileStateIsRefreshingAfterQuickReturn() {
        val vm = KsPagingProbeVm(testItems(40))
        vm.onRefresh = { state = KsPagingState.Refreshing }
        setPagingContent(vm)
        pull()
        composeTestRule.awaitCondition("取り直しの処理", observed = { vm.refreshCount }) { vm.refreshCount == 1 }
        composeTestRule.assertStaysFor("処理が戻っても取り直し中の間は出続ける") { composeTestRule.countIndeterminateProgress() }
        assertEquals(1, composeTestRule.countIndeterminateProgress())

        composeTestRule.runOnUiThread {
            vm.items = testItems(10, prefix = "fresh")
            vm.state = KsPagingState.Idle
        }
        composeTestRule.awaitCondition("インジケータが消える", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 0
        }
    }

    /** 引っ張らずに状態を取り直し中にしても、インジケータは出ない。取り直しの処理も呼ばれない。 */
    @Test
    fun vmStartedRefreshDoesNotShowIndicator() {
        val vm = KsPagingProbeVm(testItems(40))
        setPagingContent(vm)
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Refreshing }
        composeTestRule.assertStaysFor("インジケータは出ない") { composeTestRule.countIndeterminateProgress() }
        assertEquals(0, composeTestRule.countIndeterminateProgress())
        assertEquals(0, vm.refreshCount)
    }

    /** 引っ張って始めた取り直しの処理が終わった後に VM が取り直し中にしても、インジケータは出し直さない。 */
    @Test
    fun indicatorIsNotShownAgainAfterPullRefreshFinished() {
        val vm = KsPagingProbeVm(testItems(40))
        setPagingContent(vm)
        pull()
        composeTestRule.awaitCondition("インジケータが消える", observed = { composeTestRule.countIndeterminateProgress() }) {
            vm.refreshCount == 1 && composeTestRule.countIndeterminateProgress() == 0
        }
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Refreshing }
        composeTestRule.assertStaysFor("VM が始めた取り直しでは出ない") { composeTestRule.countIndeterminateProgress() }
        assertEquals(0, composeTestRule.countIndeterminateProgress())
    }

    // ---- 追加読み込みの間は引っ張れない ----

    /** 状態が追加読み込み中の間は引っ張っても取り直しは始まらず、待機に戻ると引っ張れる。 */
    @Test
    fun cannotPullWhileAppending() {
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        setPagingContent(vm)
        pull()
        composeTestRule.assertStaysFor("取り直しは呼ばれない") { vm.refreshCount }
        assertEquals(0, vm.refreshCount)

        composeTestRule.runOnUiThread { vm.state = KsPagingState.Idle }
        composeTestRule.waitForIdle()
        pull()
        composeTestRule.awaitCondition("追加読み込みが終わった後の取り直し", observed = { vm.refreshCount }) { vm.refreshCount == 1 }
    }

    /**
     * ライブラリが次ページ要求の処理を呼んだ直後 (VM がまだ状態を追加読み込み中にしていない間) に引っ張っても
     * 取り直しは始まらない。処理が終わると、また引っ張れる。
     */
    @Test
    fun cannotPullWhileLoadMoreActionIsRunning() {
        val vm = KsPagingProbeVm(emptyList())
        vm.loadMoreGate = CompletableDeferred()
        setPagingContent(vm)
        composeTestRule.awaitCondition("最初の読み込み", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals(KsPagingState.Idle, vm.state)
        pull()
        composeTestRule.assertStaysFor("取り直しは呼ばれない") { vm.refreshCount }
        assertEquals(0, vm.refreshCount)

        composeTestRule.runOnUiThread { vm.loadMoreGate?.complete(Unit) }
        composeTestRule.waitForIdle()
        pull()
        composeTestRule.awaitCondition("処理の後の取り直し", observed = { vm.refreshCount }) { vm.refreshCount == 1 }
    }

    /** 引っ張って始めた取り直しの間に状態が追加読み込み中になっても、出しているインジケータは消さない。 */
    @Test
    fun indicatorStaysWhenStateBecomesAppendingDuringPullRefresh() {
        val vm = KsPagingProbeVm(testItems(40))
        vm.refreshGate = CompletableDeferred()
        setPagingContent(vm)
        pull()
        composeTestRule.awaitCondition("インジケータ", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 1
        }
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Appending }
        composeTestRule.waitForIdle()
        // 末尾の追加読み込み中の表示は画面の外。上端のインジケータは出たまま。
        assertEquals(1, composeTestRule.countIndeterminateProgressInTopArea())
        composeTestRule.runOnUiThread { vm.refreshGate?.complete(Unit) }
    }

    // ---- 安全領域 ----

    /** 行をステータスバーの裏に流す全画面の一覧でも、取り直し中のインジケータは安全領域の境目より下に出る。 */
    @Test
    fun indicatorAppearsBelowTopSafeArea() {
        val vm = KsPagingProbeVm(testItems(40))
        vm.refreshGate = CompletableDeferred()
        setPagingContent(vm, containerHeight = 800.dp)
        pull()
        composeTestRule.awaitCondition("インジケータ", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 1
        }
        composeTestRule.mainClock.advanceTimeBy(1_000)
        composeTestRule.waitForIdle()
        val withoutSafeArea = composeTestRule.onNode(isIndeterminateProgress).getUnclippedBoundsInRoot().top

        // 取り直し中のまま、上端にステータスバーの安全領域が入る (全画面に広げた一覧)。
        val statusBar = 24.dp
        applyStatusBarInsets(statusBar)
        val indicator = composeTestRule.onNode(isIndeterminateProgress).getUnclippedBoundsInRoot()
        assertNear(withoutSafeArea + statusBar, indicator.top, "インジケータは安全領域の分だけ下がる")
        assertTrue("インジケータは境目より下 (上端 ${indicator.top})", indicator.top >= statusBar)
        assertNear(0.dp, composeTestRule.topOfTag("item-0"), "行はバーの裏から始まったまま")
        composeTestRule.runOnUiThread { vm.refreshGate?.complete(Unit) }
    }

    /**
     * 取り直し中も、安全領域に重ねた一覧の固定中の見出しは境目で止まり、先頭を表示中の先頭への挿入は
     * 先頭に留まる (インジケータは表示範囲や先頭の判定を変えない)。
     */
    @Test
    fun pinnedHeaderAndTopDetectionHoldDuringPullRefresh() {
        var items by mutableStateOf(
            (0 until 30).map { TestItem("m-$it", "m $it", TestKind.Message) } +
                (0 until 30).map { TestItem("a-$it", "a $it", TestKind.Ad) },
        )
        val gate = CompletableDeferred<Unit>()
        var refreshCount = 0
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    groups = KsGroups(by = { it.kind }) { kind, _ ->
                        Text(
                            kind.name,
                            Modifier.fillMaxWidth().height(30.dp).background(Color.LightGray).testTag("header-${kind.name}"),
                        )
                    },
                    onRefresh = {
                        refreshCount += 1
                        gate.await()
                    },
                ) { template { item -> PagingRow(item) } }
            }
        }
        val statusBar = 24.dp
        applyStatusBarInsets(statusBar)
        pull()
        composeTestRule.awaitCondition("取り直し中", observed = { refreshCount }) {
            refreshCount == 1 && composeTestRule.countIndeterminateProgress() == 1
        }

        composeTestRule.scrollListToIndex(10)
        assertNear(statusBar, composeTestRule.topOfTag("header-Message"), "固定中の見出しは安全領域の境目で止まる")

        composeTestRule.scrollListToIndex(0)
        composeTestRule.runOnUiThread { items = listOf(TestItem("m-new", "m new", TestKind.Message)) + items }
        composeTestRule.waitForIdle()
        // 先頭では見出しの本来の位置 (上端) の直後が先頭の項目の位置 (見出しの高さ 30dp の下)。
        assertNear(30.dp, composeTestRule.topOfTag("m-new"), "先頭への挿入は先頭に留まり、挿入した項目が先頭に出る")
        assertTrue("元の先頭は後ろへずれる", composeTestRule.topOfTag("m-0") >= 30.dp + rowHeight - tolerance)
        composeTestRule.runOnUiThread { gate.complete(Unit) }
    }

    // ---- Pull to Refresh の取り直しの結果は先頭から表示する ----

    /**
     * 引っ張って始めた取り直しの間に、VM が「取り直し中」と「1 ページ目への差し替えと待機」を同じフレームで
     * 行っても (取得がすぐ終わる)、差し替えと同時に先頭を表示し、次ページ要求はすぐには走らない (list)。
     * インジケータを出している間に途中までスクロールしていても先頭になる。
     */
    @Test
    fun pullRefreshReplacementShowsTopEvenWhenStatesCoalesceInList() {
        assertPullRefreshReplacementShowsTop(KsLayout.List, withPaging = true)
    }

    /** 同じくグリッドでも先頭を表示する。 */
    @Test
    fun pullRefreshReplacementShowsTopEvenWhenStatesCoalesceInGrid() {
        assertPullRefreshReplacementShowsTop(KsLayout.Grid(KsColumns.Fixed(2)), withPaging = true)
    }

    /** ページングを付けない一覧でも、取り直しの処理の中で差し替えた配列は先頭から表示する。 */
    @Test
    fun pullRefreshReplacementShowsTopWithoutPaging() {
        assertPullRefreshReplacementShowsTop(KsLayout.List, withPaging = false)
    }

    private fun assertPullRefreshReplacementShowsTop(layout: KsLayout, withPaging: Boolean) {
        val vm = KsPagingProbeVm(testItems(500))
        val gate = CompletableDeferred<Unit>()
        var refreshCount = 0
        val refresh: suspend () -> Unit = {
            refreshCount += 1
            gate.await()
            // 取得がすぐ終わる VM: 3 つの書き換えが 1 回の描画にまとまる。
            vm.state = KsPagingState.Refreshing
            vm.items = testItems(50, prefix = "fresh")
            vm.state = KsPagingState.Idle
        }
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    layout = layout,
                    listSeparators = false,
                    paging = if (withPaging) KsPaging(state = vm.state, onLoadMore = vm.loadMore) else null,
                    onRefresh = refresh,
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
        pull()
        composeTestRule.awaitCondition("取り直しの処理", observed = { refreshCount }) { refreshCount == 1 }
        // インジケータを出している間に途中までスクロールする。
        composeTestRule.scrollListToIndex(200)
        assertEquals(0, composeTestRule.countNodesWithTag("item-0"))

        composeTestRule.runOnUiThread { gate.complete(Unit) }
        composeTestRule.awaitCondition("インジケータが消える", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 0
        }
        assertNear(0.dp, composeTestRule.topOfTag("fresh-0"), "$layout: 差し替えと同時に先頭を表示する")
        composeTestRule.assertStaysFor("$layout: 次ページ要求はすぐには走らない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)

        // インジケータを出し終えた後の差し替えには効かない (既定の位置の保ち方のまま)。
        composeTestRule.scrollListToIndex(20)
        composeTestRule.runOnUiThread { vm.items = vm.items.map { it.copy(text = "${it.text}!") } }
        composeTestRule.waitForIdle()
        assertEquals("$layout: 先頭に戻さない", 0, composeTestRule.countNodesWithTag("fresh-0"))
    }

    // ---- 補助 ----

    private fun setPagingContent(vm: KsPagingProbeVm, containerHeight: Dp = height) {
        composeTestRule.setContent {
            TestContainer(width, containerHeight) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    paging = KsPaging(state = vm.state, onLoadMore = vm.loadMore),
                    onRefresh = vm.refresh,
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
    }

    /** 一覧の上端から下へ指を滑らせる。[release] が false なら離さずに確かめられるよう短く引く。 */
    private fun pull(release: Boolean = true) {
        composeTestRule.onNode(hasScrollAction(), useUnmergedTree = true).performTouchInput {
            if (release) {
                swipeDown(startY = top + 10f, endY = bottom - 10f, durationMillis = 300)
            } else {
                swipeDown(startY = top + 10f, endY = top + 200f, durationMillis = 300)
            }
        }
        composeTestRule.waitForIdle()
    }

    /** 上端 200dp の範囲にある不定の読み込み中の表示の数。 */
    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.countIndeterminateProgressInTopArea(): Int =
        onAllNodes(isIndeterminateProgress).fetchSemanticsNodes().count { node ->
            with(density) { node.boundsInRoot.top.toDp() } < 200.dp
        }

    private fun applyStatusBarInsets(top: Dp) {
        val view = composeView()
        val topPx = with(composeTestRule.density) { top.roundToPx() }
        composeTestRule.runOnUiThread {
            val insets = android.view.WindowInsets.Builder()
                .setInsets(android.view.WindowInsets.Type.statusBars(), android.graphics.Insets.of(0, topPx, 0, 0))
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

    @Composable
    private fun PagingRow(item: TestItem) {
        Text(item.text, Modifier.fillMaxWidth().height(rowHeight).testTag(item.id))
    }
}
