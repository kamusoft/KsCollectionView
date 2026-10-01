package jp.kamusoft.kscollectionview

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 並べ替えのドラッグ (スイッチ・置いたときの知らせ・一覧の中だけ・受け入れと戻り・グループをまたぐ移動・
 * 判定・端での自動スクロール・長押しとタップ) を、長押しからのドラッグを合成して確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsReorderDragTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 項目の高さ。見出しも同じ高さにする。 */
    private val rowHeight = 100.dp

    @After
    fun tearDown() {
        KsDiagnostics.debugOverride = null
    }

    private fun px(dp: Dp): Float = with(composeTestRule.density) { dp.toPx() }

    /** 上から [row] 行目 (1 行 100dp) の中の、上から [fraction] の高さの点。x は中央。 */
    private fun rowPoint(row: Int, fraction: Float = 0.5f): Offset =
        Offset(px(150.dp), px(rowHeight) * (row + fraction))

    private fun items(vararg ids: String, group: TestKind = TestKind.Message): List<TestItem> =
        ids.map { TestItem(it, it, group) }

    /** X (A, B)・Y (C, D) の配列。グループの値は kind (X = Message、Y = Ad)。 */
    private fun twoGroups(): List<TestItem> =
        items("A", "B", group = TestKind.Message) + items("C", "D", group = TestKind.Ad)

    /** 一覧の設定を差し替えられる状態。 */
    private class Harness {
        var items by mutableStateOf(listOf<TestItem>())
        var enabled by mutableStateOf(true)
        var layout: KsLayout by mutableStateOf(KsLayout.List)
        var grouped by mutableStateOf(false)
        var headers by mutableStateOf(true)
        var accept = true
        var canMove: ((TestItem) -> Boolean)? = null
        var canDrop: ((KsReorderMove<TestItem>) -> Boolean)? = null
        var redraws by mutableIntStateOf(0)
        val moves = mutableListOf<KsReorderMove<TestItem>>()
        val longTaps = mutableListOf<TestItem>()
        val taps = mutableListOf<TestItem>()
        var onItemTapDeclared = false
    }

    private fun setContent(harness: Harness) {
        composeTestRule.setContent {
            TestContainer(300.dp, 600.dp) {
                ReorderList(harness)
            }
        }
    }

    @Composable
    private fun ReorderList(harness: Harness, tag: String = ReorderListTag) {
        // 描き直しの回数を読み、ほかの状態の変化による再コンポジションを起こせるようにする。
        val redraws = harness.redraws
        KsCollectionView(
            items = harness.items,
            key = { it.id },
            modifier = Modifier.testTag(tag),
            layout = harness.layout,
            groups = if (harness.grouped) {
                if (harness.headers) {
                    KsGroups(by = { it.kind }, pinnedHeaders = false) { kind, _ ->
                        Text("$kind $redraws", Modifier.fillMaxWidth().height(rowHeight).testTag("header-$kind"))
                    }
                } else {
                    KsGroups(by = { it.kind })
                }
            } else {
                null
            },
            onItemTap = if (harness.onItemTapDeclared) { item -> harness.taps += item } else null,
            onItemLongTap = { item -> harness.longTaps += item },
            listSeparators = false,
            reorder = KsReorder(
                enabled = harness.enabled,
                onMove = { move ->
                    harness.moves += move
                    harness.accept
                },
                canMove = harness.canMove,
                canDrop = harness.canDrop,
            ),
        ) {
            template { item ->
                Box(Modifier.fillMaxWidth().height(rowHeight).background(Color.White).testTag(item.id)) {
                    Text(item.text)
                }
            }
        }
    }

    /** 項目の中身の上端 (ピクセル、一覧の根からの位置)。 */
    private fun topOf(id: String): Float =
        px(composeTestRule.onNodeWithTag(id, useUnmergedTree = true).getUnclippedBoundsInRoot().top)

    /** 表示中の並び (上端の順)。 */
    private fun order(vararg ids: String): List<String> = ids.sortedBy { topOf(it) }

    /** 戻りの動きと配置のアニメーションを終わらせる。 */
    private fun settle() {
        composeTestRule.mainClock.advanceTimeBy(2_000)
        composeTestRule.waitForIdle()
    }

    // ---- 並べ替えのスイッチ ----

    /** スイッチが有効の間は、長押しでドラッグが始まり、項目が指に合わせて動く。 */
    @Test
    fun longPressStartsDragAndItemFollowsFinger() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        val before = topOf("A")
        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(0, 0.8f)))
        val moved = topOf("A") - before

        assertEquals("指が動いた分 (30dp) だけ項目が動く", px(30.dp), moved, 2f)
        composeTestRule.reorderRelease()
        settle()
        assertTrue("元の位置に置いたので知らせない", harness.moves.isEmpty())
    }

    /** スイッチが無効の間と、並べ替えを設定していない一覧では、長押ししてもドラッグは始まらない。 */
    @Test
    fun disabledSwitchDoesNotStartDrag() {
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            enabled = false
        }
        var withoutReorder by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(300.dp, 600.dp) {
                if (withoutReorder) {
                    KsCollectionView(
                        items = harness.items,
                        key = { it.id },
                        modifier = Modifier.testTag(ReorderListTag),
                        listSeparators = false,
                    ) {
                        template { item ->
                            Box(Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) { Text(item.text) }
                        }
                    }
                } else {
                    ReorderList(harness)
                }
            }
        }

        for (variant in 0..1) {
            withoutReorder = variant == 1
            composeTestRule.waitForIdle()
            composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
            settle()
            assertEquals("並びは変わらない (variant=$variant)", listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
        }
        assertTrue(harness.moves.isEmpty())
    }

    /** ドラッグ中にスイッチが無効になったら取りやめ、元の位置に戻して知らせない。 */
    @Test
    fun disablingSwitchDuringDragCancels() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        harness.enabled = false
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()
        settle()

        assertTrue(harness.moves.isEmpty())
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
        assertTrue("取りやめた後の長押しの知らせも呼ばない", harness.longTaps.isEmpty())
    }

    /** ドラッグ中に layout を差し替えると取りやめ、元の位置に戻して新しい layout で表示する。 */
    @Test
    fun changingLayoutDuringDragCancels() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        harness.layout = KsLayout.Grid(KsColumns.Fixed(2))
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()
        settle()

        assertTrue(harness.moves.isEmpty())
        val a = composeTestRule.onNodeWithTag("A", useUnmergedTree = true).getUnclippedBoundsInRoot()
        val b = composeTestRule.onNodeWithTag("B", useUnmergedTree = true).getUnclippedBoundsInRoot()
        assertEquals("A と B が同じ行に並ぶ (2 列のグリッド)", a.top.value, b.top.value, 1f)
        assertTrue("A は元の位置 (左の列)", a.left < b.left)
    }

    /** ドラッグ中にグループの宣言を変えても取りやめる。 */
    @Test
    fun changingGroupsDuringDragCancels() {
        val harness = Harness().apply { items = twoGroups() }
        setContent(harness)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        harness.grouped = true
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()
        settle()

        assertTrue(harness.moves.isEmpty())
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
        assertEquals("新しいグループの宣言で見出しが出る", 1, composeTestRule.countNodesWithTag("header-Ad"))
    }

    /** 2 列のグリッドでも同じように並べ替えられ、置いたときの処理が呼ばれる。 */
    @Test
    fun gridReordersToo() {
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            layout = KsLayout.Grid(KsColumns.Fixed(2))
        }
        setContent(harness)

        // A (左上) を D (右下) の枠へ運ぶ。D は A より後ろなので、D の後ろ (末尾) になる。
        val cellA = Offset(px(75.dp), px(50.dp))
        val cellD = Offset(px(225.dp), px(150.dp))
        composeTestRule.reorderDragAndDrop(cellA, listOf(Offset(px(150.dp), px(100.dp)), cellD))
        settle()

        assertEquals(listOf("A->end@-"), harness.moves.map { it.describe() })
    }

    // ---- 置いたときの知らせ ----

    /** 置いたときに 1 回だけ、動かした項目と行き先 (D の前) を知らせ、グループの値は添えない。 */
    @Test
    fun dropNotifiesOnceWithDestination() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(
            rowPoint(0),
            listOf(rowPoint(1, 0.6f), rowPoint(2, 0.3f), rowPoint(2, 0.7f)),
        )

        assertEquals(listOf("A->before:D@-"), harness.moves.map { it.describe() })
        assertTrue("動かした項目は配列の要素そのもの", harness.moves.single().item === harness.items[0])
        val destination = harness.moves.single().destination as KsReorderDestination.Before
        assertTrue("行き先の項目も配列の要素そのもの", destination.item === harness.items[3])
    }

    /**
     * 粗い刻みで 1 度に 2 行先まで動かして止めても、置き場所の隙間は持ち上げた項目の下にあり、繰り上がった
     * 項目は持ち上げた項目の裏に隠れずに見える (止めたまま時間が経っても同じ)。
     */
    @Test
    fun coarseMoveKeepsGapUnderLiftedItem() {
        val harness = Harness().apply { items = items("A", "B", "C", "D", "E") }
        setContent(harness)

        // A の中ほどをつかみ、1 回の移動で C の上半分 (元の並びの 2 行目の 0.45) まで運んで止める。
        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(2, 0.45f)))
        composeTestRule.mainClock.advanceTimeBy(3_000)
        composeTestRule.waitForIdle()

        val lifted = topOf("A")
        assertEquals("持ち上げた項目は指の下 (上端は 1.95 行目)", px(rowHeight) * 1.95f, lifted, 2f)
        assertEquals("B は先頭へ繰り上がる", 0f, topOf("B"), 2f)
        assertEquals("C も繰り上がり、持ち上げた項目の裏に残らない", px(rowHeight), topOf("C"), 2f)
        assertEquals("D は動かない (隙間は持ち上げた項目の下)", px(rowHeight) * 3, topOf("D"), 2f)
        composeTestRule.reorderRelease()
        assertEquals(listOf("A->before:D@-"), harness.moves.map { it.describe() })
    }

    /** 最後の項目の後ろに置いたら、行き先は末尾。 */
    @Test
    fun dropAfterLastIsEnd() {
        val harness = Harness().apply { items = items("A", "B", "C") }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.7f), rowPoint(2, 0.8f)))

        assertEquals(listOf("A->end@-"), harness.moves.map { it.describe() })
    }

    /** 元の位置に戻して指を離したら知らせない。 */
    @Test
    fun dropAtOriginalDoesNotNotify() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        // B を C の下半分 (C の後ろ) へ運び、入れ替わって上へ来た C の上半分 (C の前 = 元の位置) へ戻す。
        composeTestRule.reorderDragAndDrop(rowPoint(1), listOf(rowPoint(2, 0.7f), rowPoint(1, 0.3f)))
        settle()

        assertTrue(harness.moves.isEmpty())
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
    }

    // ---- 並べ替えは一覧の中だけ ----

    /** 一覧 P の項目を、隣の一覧 Q の上で離しても、Q には入らず、どちらの処理も呼ばれない。 */
    @Test
    fun cannotDropIntoAnotherList() {
        val p = Harness().apply { items = items("P1", "P2", "P3") }
        val q = Harness().apply { items = items("Q1", "Q2", "Q3") }
        composeTestRule.setContent {
            Row {
                Box(Modifier.size(150.dp, 600.dp)) { ReorderList(p, "list-p") }
                Box(Modifier.size(150.dp, 600.dp)) { ReorderList(q, "list-q") }
            }
        }

        val list = composeTestRule.onNodeWithTag("list-p")
        list.performTouchInput { down(Offset(px(75.dp), px(50.dp))) }
        composeTestRule.mainClock.advanceTimeBy(ReorderLongPressMillis)
        composeTestRule.waitForIdle()
        for (x in listOf(120.dp, 180.dp, 225.dp)) {
            list.performTouchInput { moveTo(Offset(px(x), px(150.dp))) }
            composeTestRule.waitForIdle()
        }
        list.performTouchInput { up() }
        settle()

        assertTrue(p.moves.isEmpty())
        assertTrue(q.moves.isEmpty())
        assertEquals(listOf("P1", "P2", "P3"), order("P1", "P2", "P3"))
        assertEquals(listOf("Q1", "Q2", "Q3"), order("Q1", "Q2", "Q3"))
    }

    // ---- 受け入れと元に戻す ----

    /** 受け入れないと返したら、項目は元の位置に戻る。 */
    @Test
    fun rejectedMoveReturnsToOriginal() {
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            accept = false
        }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        settle()

        assertEquals(1, harness.moves.size)
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
        assertEquals(0f, topOf("A"), 1f)
    }

    /** 受け入れたら、配列が届くまで置いた並びのまま表示し、届いた後もその位置のまま。 */
    @Test
    fun acceptedMoveKeepsDroppedOrderUntilArrayArrives() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        settle()
        assertEquals("配列が届く前", listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))

        val (a, b, c, d) = harness.items
        harness.items = listOf(b, c, a, d)
        settle()
        assertEquals("配列が届いた後", listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))
        assertEquals(px(rowHeight) * 2, topOf("A"), 1f)
    }

    /** 置いた時点と同じ配列のまま描き直されても、置いた位置のまま待ち、その後の配列にも位置は変わらない。 */
    @Test
    fun redrawWithSameArrayKeepsDroppedOrder() {
        val harness = Harness().apply {
            items = twoGroups()
            grouped = true
        }
        setContent(harness)

        // 見出し X (0 行目)、A、B、見出し Y、C、D。A を D の前 (C の下半分) へ運ぶ。
        composeTestRule.reorderDragAndDrop(rowPoint(1), listOf(rowPoint(3, 0.5f), rowPoint(4, 0.7f)))
        settle()
        assertEquals(listOf("A->before:D@Ad"), harness.moves.map { it.describe() })

        harness.redraws += 1
        harness.items = harness.items.toList()
        settle()
        assertEquals("同じ配列の描き直しでは置いた並びのまま", listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))

        val (a, b, c, d) = harness.items
        harness.items = listOf(b, c, a.copy(kind = TestKind.Ad), d)
        settle()
        assertEquals(listOf("B", "C", "A", "D"), order("A", "B", "C", "D"))
    }

    /** 受け入れて並べ替えた配列を渡した後、並べ替える前の配列を渡し直すと元の並びで表示する。 */
    @Test
    fun saveFailureRestoresOriginalOrder() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)
        val original = harness.items

        composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        val (a, b, c, d) = original
        harness.items = listOf(b, c, a, d)
        settle()
        harness.items = original.toList()
        settle()

        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
    }

    // ---- グループをまたぐ移動 ----

    /** X (A, B)・Y (C, D) の A を C と D の間に置くと、行き先は D の前・グループ Y。 */
    @Test
    fun dropIntoMiddleOfOtherGroup() {
        val harness = Harness().apply {
            items = twoGroups()
            grouped = true
        }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(1), listOf(rowPoint(3, 0.5f), rowPoint(4, 0.7f)))

        assertEquals(listOf("A->before:D@Ad"), harness.moves.map { it.describe() })
    }

    /** D を Y の見出しの下半分で離すと C の前・Y、上半分で離すと末尾・X。 */
    @Test
    fun aboveAndBelowGroupHeader() {
        val harness = Harness().apply {
            items = twoGroups()
            grouped = true
            accept = false
        }
        setContent(harness)

        // 見出し X (0)、A (1)、B (2)、見出し Y (3)、C (4)、D (5)。D の中ほどをつかむので、持ち上げた項目は
        // 指より半行上から描かれる。持ち上げた項目が Y の見出しより下 (C の位置) にあるとき / Y の見出しより上
        // (B の後ろ) にあるときに離す。
        composeTestRule.reorderDragAndDrop(rowPoint(5), listOf(rowPoint(4, 0.6f), rowPoint(4, 0.2f)))
        settle()
        composeTestRule.reorderDragAndDrop(rowPoint(5), listOf(rowPoint(4, 0.4f), rowPoint(3, 0.2f)))
        settle()

        assertEquals(
            listOf("D->before:C@Ad", "D->end@Message"),
            harness.moves.map { it.describe() },
        )
    }

    /** 見出しの無いグループでも、境目より上 (B の下半分) で離すと末尾・X。 */
    @Test
    fun boundaryWithoutHeaders() {
        val harness = Harness().apply {
            items = twoGroups()
            grouped = true
            headers = false
        }
        setContent(harness)

        // A (0)、B (1)、C (2)、D (3)。D の中ほどをつかみ、持ち上げた項目の上端を境目 (C の上端) より少し上へ運ぶ。
        composeTestRule.reorderDragAndDrop(rowPoint(3), listOf(rowPoint(2, 0.4f), rowPoint(2, 0.2f)))

        assertEquals(listOf("D->end@Message"), harness.moves.map { it.describe() })
    }

    /** 最後の 1 件を別のグループへ動かしている間も元の見出しは残り、元のグループへ戻して離すと知らせない。 */
    @Test
    fun lastItemDragKeepsHeaderAndCanReturn() {
        val harness = Harness().apply {
            items = items("A", group = TestKind.Message) + items("B", "C", group = TestKind.Ad)
            grouped = true
        }
        setContent(harness)

        // 見出し X (0)、A (1)、見出し Y (2)、B (3)、C (4)。A を B の下半分 (B の後ろ) へ。
        composeTestRule.reorderDragTo(rowPoint(1), listOf(rowPoint(2, 0.7f), rowPoint(3, 0.7f)))
        assertEquals("ドラッグ中も X の見出しは残る", 1, composeTestRule.countNodesWithTag("header-Message"))
        assertTrue("A は Y の中に入っている", topOf("A") > topOf("B"))
        // 見出し X (0) の下半分 (X の先頭) へ戻して離す。
        for (point in listOf(rowPoint(2, 0.3f), rowPoint(1, 0.3f), rowPoint(0, 0.8f))) {
            composeTestRule.onNodeWithTag(ReorderListTag).performTouchInput { moveTo(point) }
            composeTestRule.waitForIdle()
        }
        composeTestRule.reorderRelease()
        settle()

        assertTrue("元の位置に置いたので知らせない", harness.moves.isEmpty())
        assertTrue("A は X に戻る", topOf("A") < topOf("B"))
    }

    /** 受け入れた時点で、項目が無くなったグループは見出しごと表示されなくなり、配列が届いた後もそのまま。 */
    @Test
    fun acceptingRemovesEmptyGroup() {
        val harness = Harness().apply {
            items = items("A", group = TestKind.Message) + items("B", "C", group = TestKind.Ad)
            grouped = true
        }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(1), listOf(rowPoint(2, 0.7f), rowPoint(3, 0.7f)))
        settle()
        assertEquals(listOf("A->before:C@Ad"), harness.moves.map { it.describe() })
        assertEquals("受け入れた時点で X は消える", 0, composeTestRule.countNodesWithTag("header-Message"))

        val (a, b, c) = harness.items
        harness.items = listOf(b, a.copy(kind = TestKind.Ad), c)
        settle()
        assertEquals(0, composeTestRule.countNodesWithTag("header-Message"))
        assertEquals(listOf("B", "A", "C"), order("A", "B", "C"))
    }

    // ---- 動かせるかと置けるかの判定 ----

    /** 「動かせるか」が偽の項目は、長押しして指を動かしてもドラッグが始まらない (ほかの項目は動かせる)。 */
    @Test
    fun immovableItemDoesNotLift() {
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            canMove = { it.id != "B" }
        }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(1), listOf(rowPoint(2, 0.6f), rowPoint(3, 0.7f)))
        settle()
        assertTrue(harness.moves.isEmpty())
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))

        composeTestRule.reorderDragAndDrop(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.7f)))
        assertEquals(listOf("A->before:D@-"), harness.moves.map { it.describe() })
    }

    /** 「ここに置けるか」がグループをまたがせないとき、別のグループへは入らず、離すと元の位置に戻る。 */
    @Test
    fun canDropBlocksOtherGroup() {
        val harness = Harness().apply {
            items = twoGroups()
            grouped = true
            canDrop = { move -> move.group == move.item.kind }
        }
        setContent(harness)

        // 見出し X (0)、A (1)、B (2)、見出し Y (3)、C (4)、D (5)。A を C の下半分まで運ぶ。
        composeTestRule.reorderDragTo(rowPoint(1), listOf(rowPoint(2, 0.7f), rowPoint(3, 0.7f), rowPoint(4, 0.7f)))
        assertEquals("C は動かない (Y の中へ入らない)", px(rowHeight) * 4, topOf("C"), 1f)
        composeTestRule.reorderRelease()
        settle()

        assertTrue(harness.moves.isEmpty())
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
    }

    // ---- 端での自動スクロール ----

    /**
     * 先頭付近の項目を一覧の下端の近くに置いたままにすると、一覧が下へスクロールし続け、指を戻すと止まり、
     * スクロールした先で置ける。持ち上げた項目の置き場所が表示範囲の外に出ても、項目は指の下に描かれ続ける。
     */
    @Test
    fun autoScrollCarriesItemBeyondScreen() {
        val harness = Harness().apply {
            items = testItems(40)
            // 置き場所を元の位置に留めたまま遠くへ運ぶため、いったんどこにも置けないようにする。
            canDrop = { false }
        }
        setContent(harness)
        val list = composeTestRule.onNodeWithTag(ReorderListTag)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(3), Offset(px(150.dp), px(595.dp))))
        composeTestRule.mainClock.advanceTimeBy(3_000)
        composeTestRule.waitForIdle()
        assertEquals("item-0 の置き場所 (先頭) は表示範囲の外", 0, composeTestRule.countNodesWithTag("item-1"))
        assertEquals(
            "持ち上げた項目は指の下に描かれ続ける",
            px(595.dp) - px(50.dp),
            topOf("item-0"),
            2f,
        )

        // 指を中ほどへ戻すと止まる。
        list.performTouchInput { moveTo(Offset(px(150.dp), px(300.dp))) }
        composeTestRule.waitForIdle()
        val firstVisible = (2..39).first { composeTestRule.countNodesWithTag("item-$it") > 0 }
        composeTestRule.mainClock.advanceTimeBy(1_000)
        composeTestRule.waitForIdle()
        assertEquals(
            "指を戻すとスクロールは止まる",
            firstVisible,
            (2..39).first { composeTestRule.countNodesWithTag("item-$it") > 0 },
        )

        // 置けるようにして、スクロールした先で置く。
        harness.canDrop = null
        harness.redraws += 1
        composeTestRule.waitForIdle()
        list.performTouchInput { moveTo(Offset(px(150.dp), px(330.dp))) }
        composeTestRule.waitForIdle()
        composeTestRule.reorderRelease()

        val move = harness.moves.single()
        val destination = move.destination as KsReorderDestination.Before
        assertTrue(
            "スクロールした先 (最初の画面の外) の項目の前に置く: ${move.describe()}",
            destination.item.id.removePrefix("item-").toInt() > 6,
        )
    }

    /** 長い list の 3 つのグループ (各 13〜14 件)。X (Message)・Y (Ad)・Z (System)。 */
    private fun longGroups(): List<TestItem> =
        (0 until 40).map { index ->
            val kind = when {
                index < 13 -> TestKind.Message
                index < 26 -> TestKind.Ad
                else -> TestKind.System
            }
            TestItem("item-$index", "item $index", kind)
        }

    /**
     * item-1 (見出し X の下の 2 件目) を下端まで運び、約 0.3 秒自動スクロールさせてから、下端のまま離す。
     * 自動スクロールが末尾まで進まないよう、時間は手で進める。
     */
    private fun dragToBottomEdgeAndRelease() {
        composeTestRule.reorderDragTo(rowPoint(2), listOf(rowPoint(4)))
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.onNodeWithTag(ReorderListTag).performTouchInput { moveTo(Offset(px(150.dp), px(595.dp))) }
        repeat(18) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
        }
        assertTrue("自動スクロールで送られている", composeTestRule.countNodesWithTag("header-Message") == 0)
        assertTrue("一覧の末尾は表示されていない", composeTestRule.countNodesWithTag("item-39") == 0)
        composeTestRule.reorderRelease()
        composeTestRule.mainClock.autoAdvance = true
        settle()
    }

    /**
     * 長い list の途中で、先頭付近の項目を下端まで運び、自動スクロールさせたまま下端で離す。行き先は離した位置の
     * 近く (同じグループの中) になり、一覧の最後のグループの末尾へは飛ばない。持ち上げた項目は表示範囲に残る。
     */
    @Test
    fun releaseAtBottomEdgeDuringAutoScrollPlacesNearFinger() {
        val harness = Harness().apply {
            items = longGroups()
            grouped = true
        }
        setContent(harness)

        // 見出し X (0)、item-0 (1)、item-1 (2)。item-1 を下端まで運び、少しだけ自動スクロールさせる。
        dragToBottomEdgeAndRelease()

        val move = harness.moves.single()
        assertEquals("元と同じグループに置く: ${move.describe()}", TestKind.Message, move.group)
        val top = topOf("item-1")
        assertTrue("置いた項目は表示範囲に残る (上端 $top)", top >= 0f && top < px(600.dp))
    }

    /**
     * 「グループをまたがせない」判定がある一覧でも、グループの中の置ける位置で下端のまま離すと、元の位置へ
     * 戻らずに置かれ、置いたときの処理が呼ばれる。ドラッグ中に、表示されていない最後のグループの行き先で判定を
     * 呼ばない。
     */
    @Test
    fun releaseAtBottomEdgeWithCanDropPlaces() {
        val askedGroups = mutableSetOf<Any?>()
        val harness = Harness().apply {
            items = longGroups()
            grouped = true
            canDrop = { move ->
                askedGroups += move.group
                move.group == move.item.kind
            }
        }
        setContent(harness)

        dragToBottomEdgeAndRelease()

        val move = harness.moves.single()
        assertEquals(TestKind.Message, move.group)
        assertTrue("最後のグループの行き先で判定を呼ばない: $askedGroups", TestKind.System !in askedGroups)
    }

    /** 同じ行き先に留まったまま判定の条件が変わり置けなくなったら、離しても置かずに元の位置へ戻す。 */
    @Test
    fun canDropRecheckedOnRelease() {
        var allowed = true
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            canDrop = { allowed }
        }
        setContent(harness)

        composeTestRule.reorderDragTo(rowPoint(0), listOf(rowPoint(1, 0.6f), rowPoint(2, 0.2f)))
        assertTrue("置ける間は仮の並びが動く", topOf("B") < px(rowHeight) * 0.5f)
        allowed = false
        composeTestRule.reorderRelease()
        settle()

        assertTrue("判定が偽になった行き先には置かない", harness.moves.isEmpty())
        assertEquals(listOf("A", "B", "C", "D"), order("A", "B", "C", "D"))
    }

    // ---- 長押しとタップ ----

    /** 並べ替えが有効な間は、動かせる項目でも動かせない項目でも長押しの知らせは呼ばれない。 */
    @Test
    fun longTapNotCalledWhileReorderEnabled() {
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            canMove = { it.id != "B" }
        }
        setContent(harness)

        composeTestRule.reorderDragAndDrop(rowPoint(0), emptyList())
        settle()
        composeTestRule.reorderDragAndDrop(rowPoint(1), emptyList())
        settle()

        assertTrue(harness.longTaps.isEmpty())
    }

    /** 並べ替えが有効な間も、タップは onItemTap に渡る。持ち上げた後に離したときは呼ばれない。 */
    @Test
    fun tapWorksWhileReorderEnabled() {
        val harness = Harness().apply {
            items = items("A", "B", "C", "D")
            onItemTapDeclared = true
        }
        setContent(harness)

        composeTestRule.onNodeWithTag(ReorderListTag).performTouchInput { click(rowPoint(2)) }
        composeTestRule.waitForIdle()
        assertEquals(listOf("C"), harness.taps.map { it.id })

        composeTestRule.reorderDragAndDrop(rowPoint(1), emptyList())
        settle()
        assertEquals("持ち上げた後に離してもタップにしない", listOf("C"), harness.taps.map { it.id })
    }

    /** スイッチを無効に戻すと、長押しが onItemLongTap に渡る。 */
    @Test
    fun disablingSwitchRestoresLongTap() {
        val harness = Harness().apply { items = items("A", "B", "C", "D") }
        setContent(harness)

        harness.enabled = false
        composeTestRule.waitForIdle()
        composeTestRule.reorderDragAndDrop(rowPoint(2), emptyList())

        assertEquals(listOf("C"), harness.longTaps.map { it.id })
        assertTrue(harness.moves.isEmpty())
    }
}
