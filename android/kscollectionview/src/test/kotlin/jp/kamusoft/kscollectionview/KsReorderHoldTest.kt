package jp.kamusoft.kscollectionview

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertHasNoClickAction
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onParent
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * ドラッグ中に届いた配列の控え方・ドラッグ中のページングとスクロール命令・表示範囲の先頭の保ち方・
 * 読み上げの移動操作・並べ替えが有効な間のタップのフィードバックを確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsReorderHoldTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val rowHeight = 100.dp

    private fun px(dp: Dp): Float = with(composeTestRule.density) { dp.toPx() }

    private fun rowPoint(row: Int, fraction: Float = 0.5f): Offset =
        Offset(px(150.dp), px(rowHeight) * (row + fraction))

    private fun items(vararg ids: String, group: TestKind = TestKind.Message): List<TestItem> =
        ids.map { TestItem(it, it, group) }

    private class Vm(items: List<TestItem>) {
        var items by mutableStateOf(items)
        var enabled by mutableStateOf(true)
        var grouped by mutableStateOf(false)
        var accept = true
        var canMove: ((TestItem) -> Boolean)? = null
        var canDrop: ((KsReorderMove<TestItem>) -> Boolean)? = null
        var actions: KsReorderAccessibilityActions? = KsReorderAccessibilityActions("前へ移動", "後ろへ移動")
        var onItemTap: ((TestItem) -> Unit)? = null
        var onItemLongTap: ((TestItem) -> Unit)? = null
        var redraws by mutableStateOf(0)
        val moves = mutableListOf<KsReorderMove<TestItem>>()
    }

    private fun setContent(
        vm: Vm,
        controller: KsScrollController? = null,
        paging: KsPagingProbeVm? = null,
    ) {
        composeTestRule.setContent {
            TestContainer(300.dp, 600.dp) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    modifier = Modifier.testTag(ReorderListTag),
                    groups = if (vm.grouped) KsGroups(by = { it.kind }) else null,
                    onItemTap = vm.onItemTap,
                    onItemLongTap = vm.onItemLongTap,
                    listSeparators = false,
                    scrollController = controller,
                    paging = paging?.let { KsPaging(state = it.state, onLoadMore = it.loadMore) },
                    reorder = KsReorder(
                        enabled = vm.enabled,
                        onMove = { move ->
                            vm.moves += move
                            vm.accept
                        },
                        canMove = vm.canMove,
                        canDrop = vm.canDrop,
                        accessibilityActions = vm.actions,
                    ),
                ) {
                    template { item ->
                        Box(Modifier.fillMaxWidth().height(rowHeight).background(Color.White).testTag(item.id)) {
                            Text(item.text, Modifier.testTag("${item.id}-text"))
                        }
                    }
                }
            }
        }
    }

    private fun topOf(id: String): Float =
        px(composeTestRule.onNodeWithTag(id, useUnmergedTree = true).getUnclippedBoundsInRoot().top)

    /** 項目が表示されているか。読み上げの操作を付けた項目は中身がまとめられるため、まとめる前の木で数える。 */
    private fun isShown(id: String): Boolean =
        composeTestRule.onAllNodesWithTag(id, useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()

    private fun order(vararg ids: String): List<String> = ids.filter { isShown(it) }.sortedBy { topOf(it) }

    private fun settle() {
        composeTestRule.mainClock.advanceTimeBy(2_000)
        composeTestRule.waitForIdle()
    }

    // ---- ドラッグ中に届いた配列 ----

    /** ドラッグ中に、ほかの項目の中身を変えた配列が届いても、指を離すまで表示は変わらない。 */
    @Test
    fun arrayDuringDragIsNotAppliedUntilRelease() {
        val vm = Vm(items("A", "B", "C", "D"))
        vm.accept = false
        setContent(vm)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f)))
        vm.items = vm.items.map { if (it.id == "D") it.copy(text = "D2") else it }
        settle()
        composeTestRule.onNodeWithTag("D-text", useUnmergedTree = true).assertTextEquals("D")

        composeTestRule.reorderRelease()
        settle()
        composeTestRule.onNodeWithTag("D-text", useUnmergedTree = true).assertTextEquals("D2")
    }

    /**
     * ドラッグ中に並べ替えを含まない配列が届いて控えられていても、受け入れたら控えた配列の並びに一度も
     * 戻らず、置いた並びのまま VM の配列に従う。
     */
    @Test
    fun acceptingDiscardsHeldArray() {
        val vm = Vm(items("A", "B", "C", "D"))
        setContent(vm)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        vm.items = vm.items.map { if (it.id == "D") it.copy(text = "D2") else it }
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()

        // 受け入れた直後から VM の配列が届くまでのフレームで、控えた配列の並び (A が先頭) に戻らない。
        repeat(30) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            assertEquals("フレーム $it", listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))
        }
        val (a, b, c, d) = vm.items
        vm.items = listOf(b, c, a, d)
        settle()
        assertEquals(listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))
        composeTestRule.onNodeWithTag("D-text", useUnmergedTree = true).assertTextEquals("D2")
    }

    /** ドラッグ中に末尾に項目を足した配列が届いて控えられ、受け入れないと、元の位置に戻って足した項目も出る。 */
    @Test
    fun rejectingAppliesLatestHeldArray() {
        val vm = Vm(items("A", "B", "C"))
        vm.accept = false
        setContent(vm)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        vm.items = vm.items + items("E")
        settle()
        assertFalse("ドラッグ中は足した項目を出さない", isShown("E"))

        composeTestRule.reorderRelease()
        settle()
        assertEquals(listOf("A", "B", "C", "E"), order("A", "B", "C", "E"))
    }

    /** ドラッグ中の項目 B を取り除いた配列が控えられ、受け入れないと、B は元の位置に戻ってから表示されなくなる。 */
    @Test
    fun rejectingWithHeldArrayWithoutDraggedItem() {
        val vm = Vm(items("A", "B", "C", "D"))
        vm.accept = false
        setContent(vm)

        composeTestRule.reorderDragTo(rowPoint(1), listOf(rowPoint(2, 0.6f), rowPoint(3, 0.7f)))
        vm.items = vm.items.filterNot { it.id == "B" }
        composeTestRule.waitForIdle()
        // 戻りの動きの途中を見るため、時間を手で進める。
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.reorderRelease()
        repeat(3) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
        }
        assertTrue("離した直後は B が元の位置へ戻る途中で表示されている", isShown("B"))

        composeTestRule.mainClock.autoAdvance = true
        settle()
        assertFalse("戻り終えたら B は表示されない", isShown("B"))
        assertEquals(listOf("A", "C", "D"), order("A", "C", "D"))
    }

    /**
     * 末尾を表示中のドラッグの間に末尾へ項目を足した配列が控えられ、元の位置に置くと、戻り終えてから当てた
     * 配列で末尾への挿入として末尾に留める (直前の並びはドラッグの前の並び)。
     */
    @Test
    fun heldAppendAtEndKeepsEnd() {
        val vm = Vm(testItems(10))
        val controller = KsScrollController()
        setContent(vm, controller = controller)
        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        settle()
        assertEquals("末尾を表示している", px(600.dp) - px(rowHeight), topOf("item-9"), 1f)

        // item-7 (上から 2 行目) を持ち上げて少し動かし、元の位置で離す。
        val grab = Offset(px(150.dp), topOf("item-7") + px(rowHeight) * 0.5f)
        composeTestRule.reorderDragTo(grab, listOf(grab + Offset(0f, px(20.dp))))
        vm.items = vm.items + TestItem("item-10", "item 10")
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()
        settle()

        assertTrue(vm.moves.isEmpty())
        assertEquals("足した項目まで末尾に留める", px(600.dp) - px(rowHeight), topOf("item-10"), 2f)
    }

    // ---- ドラッグ中のページングとスクロール命令 ----

    /** ドラッグ中は端での自動スクロールで末尾の近くまで運んでも次のページを頼まず、離した後に頼む。 */
    @Test
    fun noLoadMoreDuringDrag() {
        val vm = Vm(testItems(30))
        vm.canDrop = { false }
        val paging = KsPagingProbeVm(vm.items)
        setContent(vm, paging = paging)
        composeTestRule.waitForIdle()
        assertEquals("最初は末尾から遠いので頼まない", 0, paging.loadMoreCount)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(3), Offset(px(150.dp), px(598.dp))))
        composeTestRule.mainClock.advanceTimeBy(8_000)
        composeTestRule.waitForIdle()
        assertTrue("末尾の近くまで運んだ", isShown("item-29"))
        assertEquals("ドラッグ中は頼まない", 0, paging.loadMoreCount)

        composeTestRule.reorderRelease()
        composeTestRule.awaitCondition("離した後の次ページ要求", observed = { paging.loadMoreCount }) {
            paging.loadMoreCount == 1
        }
    }

    /** ドラッグ中の先頭へのスクロール命令は、ドラッグ中は実行せず、離して配列を当てた後に実行する。 */
    @Test
    fun scrollCommandDuringDragRunsAfterRelease() {
        val vm = Vm(testItems(30))
        vm.accept = false
        val controller = KsScrollController()
        setContent(vm, controller = controller)
        composeTestRule.onNode(hasScrollAction())
            .performTouchInput { swipeUp(startY = bottom - 10f, endY = top + 10f) }
        settle()
        val firstBefore = (0 until 30).first { isShown("item-$it") }
        assertTrue("先頭から離れた位置で始める", firstBefore > 0)

        composeTestRule.reorderDragTo(rowPoint(2), listOf(rowPoint(3, 0.4f)))
        composeTestRule.runOnUiThread { controller.scrollToStart(animated = false) }
        settle()
        assertEquals("ドラッグ中は命令でスクロールしない", 0, controller.processedCommandCount)
        assertFalse(isShown("item-0"))

        composeTestRule.reorderRelease()
        composeTestRule.awaitCondition("離した後の命令の実行", observed = { controller.processedCommandCount }) {
            controller.processedCommandCount == 1
        }
        settle()
        assertEquals(0f, topOf("item-0"), 1f)
    }

    // ---- 表示範囲の先頭 ----

    /** 表示範囲の先頭の項目を持ち上げて下へ動かしても、一覧は跳ばずに、次の項目が先頭へ繰り上がる。 */
    @Test
    fun movingFirstVisibleItemDoesNotJump() {
        val vm = Vm(testItems(30))
        val controller = KsScrollController()
        setContent(vm, controller = controller)
        composeTestRule.runOnUiThread { controller.scrollTo(id = "item-5", animated = false) }
        settle()
        assertEquals("item-5 が先頭", 0f, topOf("item-5"), 1f)

        // item-5 (0〜100dp) を持ち上げ、item-6 (100〜200dp) の下半分へ運ぶ。端での自動スクロールの範囲の外で動かす。
        composeTestRule.reorderDragTo(rowPoint(0, 0.8f), listOf(rowPoint(1, 0.3f), rowPoint(1, 0.6f)))
        settle()

        assertEquals("item-6 が先頭へ繰り上がる (一覧は跳ばない)", 0f, topOf("item-6"), 2f)
        assertEquals("持ち上げた項目は指の下", px(rowHeight) * 0.8f, topOf("item-5"), 2f)
        composeTestRule.reorderRelease()
        settle()
        assertEquals(listOf("item-6", "item-5", "item-7"), order("item-5", "item-6", "item-7"))
    }

    /**
     * 画面を占める高い行が 1 件だけ見えている長い list で、その行を持ち上げて少し動かしても、行き先は一覧の
     * 最後のグループの末尾へ飛ばず、離すと元の位置なので知らせない。
     */
    @Test
    fun onlyLiftedItemVisibleKeepsPlacement() {
        val vm = Vm(testItems(10))
        vm.actions = null
        val controller = KsScrollController()
        composeTestRule.setContent {
            TestContainer(300.dp, 600.dp) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    modifier = Modifier.testTag(ReorderListTag),
                    listSeparators = false,
                    scrollController = controller,
                    reorder = KsReorder(enabled = true, onMove = { move -> vm.moves += move; true }),
                ) {
                    template { item ->
                        // item-3 だけ、表示範囲 (600dp) より高い 800dp の行にする。
                        val height = if (item.id == "item-3") 800.dp else rowHeight
                        Box(Modifier.fillMaxWidth().height(height).background(Color.White).testTag(item.id)) {
                            Text(item.text)
                        }
                    }
                }
            }
        }
        composeTestRule.runOnUiThread { controller.scrollTo(id = "item-3", animated = false) }
        settle()
        assertFalse("見えているのは item-3 だけ", isShown("item-2") || isShown("item-4"))

        composeTestRule.reorderDragTo(Offset(px(150.dp), px(300.dp)), listOf(Offset(px(150.dp), px(330.dp))))
        settle()
        assertTrue("持ち上げた行は表示範囲に残る", isShown("item-3"))
        assertFalse(
            "置き場所は元のまま (一覧の末尾へ飛ぶと、後ろの項目が繰り上がって見える)",
            isShown("item-4") || isShown("item-9"),
        )
        composeTestRule.reorderRelease()
        settle()

        assertTrue("元の位置に置いたので知らせない: ${vm.moves.map { it.describe() }}", vm.moves.isEmpty())
        composeTestRule.runOnUiThread { controller.scrollToStart(animated = false) }
        settle()
        assertEquals(listOf("item-2", "item-3"), order("item-2", "item-3"))
    }

    // ---- 読み上げの移動操作 ----

    private fun customActions(id: String): List<String> =
        composeTestRule.onNodeWithTag(id, useUnmergedTree = true).onParent()
            .fetchSemanticsNode().config.getOrNull(SemanticsActions.CustomActions)
            ?.map { it.label }
            .orEmpty()

    private fun perform(id: String, label: String): Boolean {
        val action = composeTestRule.onNodeWithTag(id, useUnmergedTree = true).onParent()
            .fetchSemanticsNode().config.getOrNull(SemanticsActions.CustomActions)
            ?.firstOrNull { it.label == label }
            ?: error("$id に $label の操作が無い")
        var result = false
        composeTestRule.runOnUiThread { result = action.action() }
        composeTestRule.waitForIdle()
        return result
    }

    /** A の「後ろへ移動」で置いたときの処理が 1 回呼ばれ、行き先は C の前。受け入れたら A は動く。 */
    @Test
    fun accessibilityMoveNext() {
        val vm = Vm(items("A", "B", "C"))
        setContent(vm)

        // 読み上げの焦点は、項目の中身 (文字) をまとめた 1 つの節点に当たり、その節点に操作が付く。
        val focused = composeTestRule.onNode(hasText("A")).fetchSemanticsNode()
        assertEquals(
            listOf("後ろへ移動"),
            focused.config.getOrNull(SemanticsActions.CustomActions)?.map { it.label },
        )
        assertTrue(perform("A", "後ろへ移動"))
        settle()

        assertEquals(listOf("A->before:C@-"), vm.moves.map { it.describe() })
        assertEquals(listOf("B", "A", "C"), order("A", "B", "C"))
    }

    /** 受け入れない操作では項目は動かない。 */
    @Test
    fun accessibilityMoveRejected() {
        val vm = Vm(items("A", "B", "C"))
        vm.accept = false
        setContent(vm)

        assertFalse(perform("A", "後ろへ移動"))
        settle()

        assertEquals(1, vm.moves.size)
        assertEquals(listOf("A", "B", "C"), order("A", "B", "C"))
    }

    /** X (A, B)・Y (C, D) の C の「前へ移動」は、行き先が末尾・X になる。 */
    @Test
    fun accessibilityMoveAcrossGroups() {
        val vm = Vm(items("A", "B", group = TestKind.Message) + items("C", "D", group = TestKind.Ad))
        vm.grouped = true
        setContent(vm)

        assertTrue(perform("C", "前へ移動"))

        assertEquals(listOf("C->end@Message"), vm.moves.map { it.describe() })
    }

    /**
     * 操作を出さない場合: スイッチが無効ならどの項目にも無く、動かせない項目にも無く、先頭の項目には
     * 「前へ移動」が、最後の項目には「後ろへ移動」が無い。置けない行き先への操作も無い。文言を渡さなければ無い。
     */
    @Test
    fun accessibilityActionsAbsentWhenNotApplicable() {
        val vm = Vm(items("A", "B", "C", "D"))
        vm.canMove = { it.id != "B" }
        vm.canDrop = { move -> !(move.item.id == "C" && move.destination is KsReorderDestination.End) }
        setContent(vm)

        assertEquals(listOf("後ろへ移動"), customActions("A"))
        assertEquals("動かせない項目には無い", emptyList<String>(), customActions("B"))
        assertEquals("置けない行き先 (末尾) への操作は無い", listOf("前へ移動"), customActions("C"))
        assertEquals(listOf("前へ移動"), customActions("D"))

        vm.enabled = false
        composeTestRule.waitForIdle()
        for (id in listOf("A", "B", "C", "D")) {
            assertEquals("スイッチが無効なら無い ($id)", emptyList<String>(), customActions(id))
        }

        vm.enabled = true
        vm.actions = null
        vm.items = vm.items.toList()
        composeTestRule.waitForIdle()
        assertEquals("文言を渡さなければ無い", emptyList<String>(), customActions("A"))
    }

    // ---- グループの宣言を毎回作り直す書き方 ----

    /**
     * グループの値のラムダを Composable ではない関数の中で作り、描き直しのたびに別のインスタンスになる書き方
     * でも、受け入れた後に VM の配列を待つ間に次のドラッグを始めて置ける (取りやめにならない)。
     */
    @Test
    fun recreatedGroupLambdaDoesNotCancelDragWhileAwaiting() {
        val vm = Vm(items("A", "B", group = TestKind.Message) + items("C", "D", group = TestKind.Ad))
        vm.actions = null
        val lambdas = mutableSetOf<Any>()
        composeTestRule.setContent {
            TestContainer(300.dp, 600.dp) {
                val groups = recreatedGroups(vm.redraws)
                lambdas += groups.by
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    modifier = Modifier.testTag(ReorderListTag),
                    groups = groups,
                    listSeparators = false,
                    reorder = KsReorder(enabled = true, onMove = { move -> vm.moves += move; true }),
                ) {
                    template { item ->
                        Box(Modifier.fillMaxWidth().height(rowHeight).background(Color.White).testTag(item.id)) {
                            Text(item.text)
                        }
                    }
                }
            }
        }

        // 見出しなしのグループ: A (0)、B (1)、C (2)、D (3)。A を D の前へ置いて受け入れる (VM は配列を渡さない)。
        composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.6f)))
        settle()
        assertEquals(listOf("A->before:D@Ad"), vm.moves.map { it.describe() })
        assertEquals(listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))

        // 待っている間に B を持ち上げて動かす。動かすたびに描き直され、グループのラムダは別のインスタンスになる。
        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(0, 0.8f), rowPoint(1, 0.3f)))
        vm.redraws += 1
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithTag(ReorderListTag).performTouchInput { moveTo(rowPoint(1, 0.6f)) }
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()
        settle()

        assertTrue("描き直しのたびにラムダが作り直されている (${lambdas.size})", lambdas.size >= 2)
        assertEquals("2 回目のドラッグも取りやめにならず知らせる", 2, vm.moves.size)
    }

    // ---- 並べ替えが有効な間のタップ ----

    /** 長押しの知らせだけを宣言した一覧では、並べ替えが有効な間はタップの受け口もフィードバックも無い。 */
    @Test
    fun longTapOnlyListHasNoTapFeedbackWhileReorderEnabled() {
        val vm = Vm(items("A", "B", "C"))
        val longTaps = mutableListOf<TestItem>()
        vm.onItemLongTap = { longTaps += it }
        vm.actions = null
        setContent(vm)

        composeTestRule.onNodeWithTag("B", useUnmergedTree = true).onParent().assertHasNoClickAction()
        composeTestRule.onNodeWithTag(ReorderListTag).performTouchInput { click(rowPoint(1)) }
        composeTestRule.waitForIdle()
        assertTrue(longTaps.isEmpty())
        assertTrue(vm.moves.isEmpty())
    }
}

/**
 * グループの宣言を、Composable ではない関数の中で毎回作る。呼ぶたびにグループの値のラムダが別のインスタンスに
 * なる (Compose のラムダを覚える仕組みは Composable 関数の中に書いたラムダにしか効かないため)。
 */
private fun recreatedGroups(version: Int): KsGroups<TestItem, TestKind> =
    KsGroups(by = { item -> if (version >= 0) item.kind else item.kind })
