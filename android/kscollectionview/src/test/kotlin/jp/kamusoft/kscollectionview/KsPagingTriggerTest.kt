package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.CompletableDeferred
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/**
 * 実レイアウトの上で、次ページ要求の発火 (画面に出ている項目の数え方・しきい値・判定し直すきっかけ・
 * 待機のときだけ頼むこと) と、一覧が破棄されたときの取り消し・不正なしきい値を確かめる。
 *
 * 一覧は幅 300dp・高さ 600dp、行の高さ 60dp で、先頭に揃えると画面にちょうど 10 件出る。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPagingTriggerTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val rowHeight = 60.dp
    private val width = 300.dp
    private val height = 600.dp

    @Before
    fun setUp() {
        ShadowLog.clear()
        KsPagingProbe.visibleItemCount = -1
        KsPagingProbe.lastVisibleIndex = null
    }

    @After
    fun tearDown() {
        KsDiagnostics.debugOverride = null
    }

    // ---- 追加読み込みの発火 ----

    /** 100 件・画面に 10 件・既定のしきい値では、いちばん後ろが 88 番目までは頼まず、89 番目に届いたときに 1 回頼む。 */
    @Test
    fun defaultThresholdRequestsWhenLastVisibleReaches89() {
        val vm = KsPagingProbeVm(testItems(100))
        setPagingContent(vm)
        for (top in 0..79) {
            composeTestRule.scrollListToIndex(top)
            assertEquals("いちばん後ろが ${top + 9} 番目で頼んでいる", 0, vm.loadMoreCount)
        }
        assertEquals(10, KsPagingProbe.visibleItemCount)
        composeTestRule.scrollListToIndex(80)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals(89, KsPagingProbe.lastVisibleIndex)
    }

    /** しきい値 2 では 79 番目に届いたときに頼む。 */
    @Test
    fun thresholdTwoRequestsWhenLastVisibleReaches79() {
        val vm = KsPagingProbeVm(testItems(100))
        setPagingContent(vm, threshold = 2f)
        composeTestRule.scrollListToIndex(69)
        composeTestRule.assertStaysFor("78 番目では頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
        composeTestRule.scrollListToIndex(70)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
    }

    /** しきい値 0 では、最後の項目が画面に入った時点で頼み、その前には頼まない。 */
    @Test
    fun thresholdZeroRequestsWhenLastItemIsVisible() {
        val vm = KsPagingProbeVm(testItems(100))
        setPagingContent(vm, threshold = 0f)
        composeTestRule.scrollListToIndex(89)
        composeTestRule.assertStaysFor("98 番目では頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
        composeTestRule.scrollListToIndex(90)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
    }

    /** 2 列のグリッドで画面に 10 件 (5 行) 出ているとき、行ではなく項目の数で数え、89 番目で頼む。 */
    @Test
    fun gridCountsItemsNotRows() {
        val vm = KsPagingProbeVm(testItems(100))
        setPagingContent(vm, layout = KsLayout.Grid(KsColumns.Fixed(2)), rowHeight = 120.dp)
        composeTestRule.scrollListToIndex(78)
        composeTestRule.assertStaysFor("87 番目では頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
        assertEquals("画面に出ている項目は 10 件 (5 行)", 10, KsPagingProbe.visibleItemCount)
        composeTestRule.scrollListToIndex(80)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals(89, KsPagingProbe.lastVisibleIndex)
    }

    /** グループの見出し・ルートのフッター・ページングの表示は、画面に出ている項目にも残りにも数えない。 */
    @Test
    fun headersFootersAndPagingDisplaysAreNotCounted() {
        // 状態を追加読み込み中にして、フッターの枠の中にページングの表示も出す (頼みは出ない)。
        val vm = KsPagingProbeVm(foodItems(), state = KsPagingState.Appending)
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    groups = KsGroups(by = { it.kind }, pinnedHeaders = false) { kind, _ ->
                        Text(kind.name, Modifier.fillMaxWidth().height(rowHeight).testTag("header-${kind.name}"))
                    },
                    footer = { Box(Modifier.fillMaxWidth().height(rowHeight).testTag("root-footer")) },
                    paging = KsPaging(state = vm.state, onLoadMore = vm.loadMore),
                ) {
                    template { item -> PagingRow(item) }
                }
            }
        }
        composeTestRule.waitForIdle()

        // 2 つめの見出しが画面に出ている位置。
        composeTestRule.scrollListToIndex(12)
        assertVisibleCountMatchesItemNodes(vm.items)
        assertEquals(1, composeTestRule.countNodesWithTag("header-Ad"))

        // 末尾 (フッターとページングの表示が出ている位置)。
        composeTestRule.scrollListToIndex(vm.items.size + 2)
        assertEquals(1, composeTestRule.countNodesWithTag("root-footer"))
        assertEquals(1, composeTestRule.countIndeterminateProgress())
        assertVisibleCountMatchesItemNodes(vm.items)
        assertEquals(vm.items.size - 1, KsPagingProbe.lastVisibleIndex)
        assertEquals("追加読み込み中は頼まない", 0, vm.loadMoreCount)
    }

    /** 項目があっても表示範囲がルートのヘッダーだけで埋まっていれば頼まず、スクロールで項目が出てから頼む。 */
    @Test
    fun noVisibleItemMeansNoRequestUntilScrolled() {
        val vm = KsPagingProbeVm(testItems(5))
        setPagingContent(vm, header = { Box(Modifier.fillMaxWidth().height(700.dp).testTag("root-header")) })
        composeTestRule.assertStaysFor("ヘッダーだけの間は頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)

        scrollBy(300.dp)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
    }

    // ---- 判定し直すきっかけ ----

    /** 1 ページが画面に満たないときは、スクロールしなくても、残りがしきい値を超えるまで頼み続ける。 */
    @Test
    fun shortPagesKeepRequestingWithoutScrolling() {
        val vm = KsPagingProbeVm(emptyList())
        vm.onLoadMore = {
            // 状態と配列は同じ回に書き換える。
            items = items + testItems(3, prefix = "p${items.size}")
            state = KsPagingState.Idle
        }
        setPagingContent(vm)
        // 画面に 10 件出る。21 件で「残り 11 > 10」になり止まる。
        composeTestRule.awaitCondition("21 件まで読み込む", observed = { vm.items.size }) { vm.items.size >= 21 }
        composeTestRule.assertStaysFor("残りがしきい値を超えたら止まる") { vm.items.size }
        assertEquals(21, vm.items.size)
        assertEquals(7, vm.loadMoreCount)
    }

    /** 末尾近くで失敗になっている一覧は、状態を待機に戻すと判定し直して頼む。 */
    @Test
    fun returningFromFailedToIdleReevaluates() {
        val vm = KsPagingProbeVm(testItems(100), state = KsPagingState.Failed)
        setPagingContent(vm)
        composeTestRule.scrollListToIndex(90)
        composeTestRule.assertStaysFor("失敗では自動で頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)

        composeTestRule.runOnUiThread { vm.state = KsPagingState.Idle }
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
    }

    /** 終端では、最後の項目までスクロールしても頼まない。 */
    @Test
    fun endReachedNeverRequests() {
        val vm = KsPagingProbeVm(testItems(100), state = KsPagingState.EndReached)
        setPagingContent(vm)
        composeTestRule.scrollListToIndex(100)
        composeTestRule.assertStaysFor("終端では頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
    }

    /** 回転 (一覧の大きさの変化) で画面に出る項目の数が増えて条件を満たすと、スクロールしなくても頼む。 */
    @Test
    fun sizeChangeThatShowsMoreItemsRequests() {
        val vm = KsPagingProbeVm(testItems(20))
        var containerHeight by mutableStateOf(300.dp)
        setPagingContent(vm, containerHeight = { containerHeight })
        composeTestRule.assertStaysFor("5 件出ている間は頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)

        composeTestRule.runOnUiThread { containerHeight = 600.dp }
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals(10, KsPagingProbe.visibleItemCount)
    }

    // ---- ページングの設定・状態 ----

    /** ページングを付けない一覧は、末尾までスクロールしても頼まず、ページングの表示を出さない。 */
    @Test
    fun collectionWithoutPagingNeverRequestsOrShowsPagingDisplays() {
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(items = testItems(30), key = { it.id }) {
                    template { item -> PagingRow(item) }
                }
            }
        }
        composeTestRule.scrollListToIndex(29)
        assertEquals(-1, KsPagingProbe.visibleItemCount)
        assertEquals(0, composeTestRule.countIndeterminateProgress())
    }

    /** ライブラリは次ページ要求を呼んでも状態を書き換えない (追加読み込み中の表示も出ない)。 */
    @Test
    fun libraryDoesNotRewriteState() {
        val vm = KsPagingProbeVm(testItems(5))
        vm.loadMoreGate = CompletableDeferred()
        setPagingContent(vm)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        composeTestRule.assertStaysFor("状態は待機のまま") { vm.state }
        assertEquals(KsPagingState.Idle, vm.state)
        assertEquals("状態を書き換えないので読み込み中の表示は出ない", 0, composeTestRule.countIndeterminateProgress())
        composeTestRule.runOnUiThread { vm.loadMoreGate?.complete(Unit) }
    }

    /** 項目が 0 件・待機・しきい値 0 なら、表示したときに 1 回だけ頼む。 */
    @Test
    fun emptyIdleRequestsOnceWhenShown() {
        val vm = KsPagingProbeVm(emptyList())
        setPagingContent(vm, threshold = 0f)
        composeTestRule.awaitCondition("最初の読み込み", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        composeTestRule.assertStaysFor("頼みが無視されても繰り返さない") { vm.loadMoreCount }
        assertEquals(1, vm.loadMoreCount)
    }

    /**
     * 判定の材料が取れない間 (表示範囲の高さが 0 の間) に状態が「待機 → 追加読み込み中 → 待機」と往復しても、
     * 往復で待ち方の控えが捨てられ、材料が取れるようになったら次を頼める (配列は変わらない)。
     */
    @Test
    fun stateRoundTripWhileEvaluationIsSkippedAllowsNextRequest() {
        val vm = KsPagingProbeVm(testItems(5))
        var containerHeight by mutableStateOf(height)
        setPagingContent(vm, containerHeight = { containerHeight })
        composeTestRule.awaitCondition("最初の頼み", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        composeTestRule.assertStaysFor("頼みが無視されたので繰り返さない") { vm.loadMoreCount }

        composeTestRule.runOnUiThread { containerHeight = 0.dp }
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Appending }
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Idle }
        composeTestRule.waitForIdle()
        assertEquals("材料が取れない間は頼まない", 1, vm.loadMoreCount)

        composeTestRule.runOnUiThread { containerHeight = height }
        composeTestRule.awaitCondition("往復の後の次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 2 }
    }

    // ---- 一覧が破棄されたときの取り消し ----

    /** 次ページ要求の処理の中で待っている間に一覧を含む画面を閉じると、実行中の処理は取り消される。 */
    @Test
    fun closingScreenWhileLoadingCancelsAction() {
        val vm = KsPagingProbeVm(emptyList())
        vm.loadMoreGate = CompletableDeferred()
        var shown by mutableStateOf(true)
        composeTestRule.setContent {
            if (shown) {
                TestContainer(width, height) {
                    KsCollectionView(
                        items = vm.items,
                        key = { it.id },
                        paging = KsPaging(state = vm.state, onLoadMore = vm.loadMore),
                    ) { template { item -> PagingRow(item) } }
                }
            }
        }
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals(false, vm.loadMoreCancelled)

        composeTestRule.runOnUiThread { shown = false }
        composeTestRule.awaitCondition("取り消し", observed = { vm.loadMoreCancelled }) { vm.loadMoreCancelled }
    }

    // ---- 不正なしきい値 ----

    /** release では負のしきい値を警告して 0 として扱い、最後の項目が画面に入った時点で頼む。 */
    @Test
    fun negativeThresholdWarnsAndActsAsZeroInRelease() {
        KsDiagnostics.debugOverride = false
        val vm = KsPagingProbeVm(testItems(100))
        setPagingContent(vm, threshold = -3f)
        composeTestRule.waitForIdle()
        val warnings = ShadowLog.getLogsForTag("KsCollectionView").map { it.msg }
        assertTrue("警告ログが出る (実測 $warnings)", warnings.any { it.contains("ページングのしきい値に -3.0") })
        assertEquals("警告は 1 度だけ", 1, warnings.count { it.contains("ページングのしきい値") })

        composeTestRule.scrollListToIndex(89)
        composeTestRule.assertStaysFor("98 番目では頼まない") { vm.loadMoreCount }
        assertEquals(0, vm.loadMoreCount)
        composeTestRule.scrollListToIndex(90)
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
    }

    /** 有限でないしきい値も不正で、debug では停止する。 */
    @Test
    fun nonFiniteThresholdStopsInDebug() {
        KsDiagnostics.debugOverride = true
        val vm = KsPagingProbeVm(testItems(3))
        assertThrows(IllegalStateException::class.java) {
            setPagingContent(vm, threshold = Float.NaN)
        }
    }

    // ---- 補助 ----

    private fun setPagingContent(
        vm: KsPagingProbeVm,
        threshold: Float = 1f,
        layout: KsLayout = KsLayout.List,
        rowHeight: Dp = this.rowHeight,
        header: (@androidx.compose.runtime.Composable () -> Unit)? = null,
        containerHeight: () -> Dp = { height },
    ) {
        composeTestRule.setContent {
            TestContainer(width, containerHeight()) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    layout = layout,
                    header = header,
                    listSeparators = false,
                    paging = KsPaging(state = vm.state, onLoadMore = vm.loadMore, threshold = threshold),
                ) {
                    template { item -> PagingRow(item, rowHeight) }
                }
            }
        }
        composeTestRule.waitForIdle()
    }

    /** 見出しの 2 グループ (15 件ずつ)。 */
    private fun foodItems(): List<TestItem> =
        (0 until 15).map { TestItem("m-$it", "m $it", TestKind.Message) } +
            (0 until 15).map { TestItem("a-$it", "a $it", TestKind.Ad) }

    /** 判定に使った画面に出ている項目の数が、実際に表示範囲と重なっている項目の節点の数と一致する。 */
    private fun assertVisibleCountMatchesItemNodes(items: List<TestItem>) {
        composeTestRule.waitForIdle()
        val visible = items.count { item ->
            if (composeTestRule.countNodesWithTag(item.id) == 0) return@count false
            val bounds = composeTestRule.onNodeWithTag(item.id).getUnclippedBoundsInRoot()
            bounds.bottom > 0.dp && bounds.top < height
        }
        assertEquals("画面に出ている項目の数", visible, KsPagingProbe.visibleItemCount)
    }

    private fun scrollBy(distance: Dp) {
        val px = with(composeTestRule.density) { distance.toPx() }
        composeTestRule.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, px) }
        composeTestRule.waitForIdle()
    }

    @androidx.compose.runtime.Composable
    private fun PagingRow(item: TestItem, height: Dp = rowHeight) {
        Text(item.text, Modifier.fillMaxWidth().height(height).testTag(item.id))
    }
}
