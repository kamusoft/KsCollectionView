package jp.kamusoft.kscollectionview

import android.util.Log
import androidx.compose.foundation.IndicationNodeFactory
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.node.DelegatableNode
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHasNoClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onParent
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.launch
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowLog

/** タップ・長押しのコールバックとフィードバック、スクロール命令の順序と解決を確かめる。 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsCollectionViewInteractionTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** コンテナの寸法。1 項目 100dp × 30 件で、表示範囲の 5 倍のコンテンツになる。 */
    private val containerWidth = 300.dp
    private val containerHeight = 600.dp
    private val itemHeight = 100.dp
    private val itemCount = 30

    /** 位置の比較に使う許容差 (端数丸めの吸収)。 */
    private val tolerance = 2.dp

    @Before
    fun setUp() {
        ShadowLog.clear()
    }

    @After
    fun tearDown() {
        KsDiagnostics.debugOverride = null
        KsTapFeedback.indicationOverride = null
    }

    // ---- タップとフィードバック ----

    /** タップしたときにその要素そのものがコールバックへ渡る。 */
    @Test
    fun tapPassesTappedItemToCallback() {
        var tapped: TestItem? = null
        val items = testItems(5)
        setTapContent(items = items, onItemTap = { tapped = it })

        onItem("item-2").performTouchInput { click() }
        composeTestRule.waitForIdle()

        assertEquals(items[2], tapped)
    }

    /**
     * ハンドラを宣言した項目はタップとフィードバックの受け口を持つ。
     *
     * フィードバックの描画そのものは Robolectric では実行されないため (押下状態は成立するが
     * 塗りが描かれない)、ここでは受け口が項目に付くことまでを確かめる。
     */
    @Test
    fun tapHandlerAttachesTapAndFeedbackTarget() {
        setTapContent(
            items = testItems(5),
            onItemTap = {},
            onItemLongTap = {},
            touchFeedbackColor = Color(0xFFFF0000),
        )

        itemRoot("item-2").assertHasClickAction()
        assertTrue(
            "長押しの受け口も項目に付く",
            itemRoot("item-2").fetchSemanticsNode()
                .config.contains(SemanticsActions.OnLongClick),
        )
    }

    /**
     * ハンドラを宣言しない項目はタップの受け口を持たず、したがってフィードバックも出ない。
     *
     * フィードバックはタップの受け口に付くため、受け口が無いことが「フィードバックを出さない」
     * ことと同義になる。
     */
    @Test
    fun noHandlerMeansNoTapTargetAndNoFeedback() {
        setTapContent(items = testItems(5), onItemTap = null, onItemLongTap = null)

        itemRoot("item-2").assertHasNoClickAction()
        assertTrue(
            "長押しの受け口も付かない",
            !onItem("item-2").fetchSemanticsNode()
                .config.contains(SemanticsActions.OnLongClick),
        )
    }

    /** 長押しでは長押しのコールバックだけが呼ばれ、通常タップのコールバックは呼ばれない。 */
    @Test
    fun longTapPassesItemAndSuppressesTap() {
        var tapped: TestItem? = null
        var longTapped: TestItem? = null
        val items = testItems(5)
        setTapContent(
            items = items,
            onItemTap = { tapped = it },
            onItemLongTap = { longTapped = it },
        )

        onItem("item-3").performTouchInput { longClick() }
        composeTestRule.waitForIdle()

        assertEquals(items[3], longTapped)
        assertNull("長押しが成立したタッチでは通常タップは発火しない", tapped)
    }

    /** 項目内のボタンがタッチを処理した場合、項目のタップは発火しない (背景の余白では発火する)。 */
    @Test
    fun itemButtonConsumesTouchInsteadOfItemTap() {
        var tapped: TestItem? = null
        var buttonClicks = 0
        val items = testItems(5)
        setButtonInItemContent(
            items = items,
            onItemTap = { tapped = it },
            onButtonClick = { buttonClicks++ },
        )

        onItem("item-1-button").performTouchInput { click() }
        composeTestRule.waitForIdle()
        assertEquals(1, buttonClicks)
        assertNull("項目内のボタンを押したときは項目のタップは発火しない", tapped)

        // 項目背景の余白 (ボタンの下) をタップすると項目のタップが発火する。
        onItem("item-1").performTouchInput {
            click(Offset(width / 2f, height * 0.9f))
        }
        composeTestRule.waitForIdle()
        assertEquals(items[1], tapped)
    }

    /**
     * 項目内のボタンを押下している間、項目のフィードバックは始まらない。
     *
     * 項目のフィードバックは項目の `InteractionSource` の押下として現れるため、そこへ押下が
     * 流れないことが「フィードバックが発火しない」ことと同義になる。
     */
    @Test
    fun itemButtonPressDoesNotStartItemFeedback() {
        val indication = RecordingIndication()
        KsTapFeedback.indicationOverride = indication
        setButtonInItemContent(onItemTap = {})

        // 子のボタンを押下し続ける。押下のフィードバックは遅延して始まるため時間を進める。
        onItem("item-1-button").performTouchInput { down(center) }
        composeTestRule.mainClock.advanceTimeBy(300)
        composeTestRule.waitForIdle()
        assertTrue(
            "項目内のボタンを押下している間は項目のフィードバックが始まらない (実測 ${indication.presses})",
            indication.presses.isEmpty(),
        )

        onItem("item-1-button").performTouchInput { up() }
        composeTestRule.waitForIdle()
        assertTrue("離した後も項目のフィードバックは始まらない", indication.presses.isEmpty())

        // 項目背景 (ボタンの下) の押下では項目のフィードバックが始まる。
        onItem("item-1").performTouchInput { down(Offset(width / 2f, height * 0.9f)) }
        composeTestRule.mainClock.advanceTimeBy(300)
        composeTestRule.waitForIdle()
        assertTrue(
            "項目背景の押下では項目のフィードバックが始まる",
            indication.presses.any { it is PressInteraction.Press },
        )
        onItem("item-1").performTouchInput { up() }
        composeTestRule.waitForIdle()
    }

    // ---- スクロール制御 ----

    /** 配列に無い ID への命令は何も起こさず、警告ログを残す。 */
    @Test
    fun scrollToMissingIdDoesNothing() {
        KsDiagnostics.debugOverride = true
        val controller = KsScrollController()
        setScrollContent(controller = controller)

        val before = topOf("item-0")
        composeTestRule.runOnUiThread { controller.scrollTo(id = "item-does-not-exist") }
        awaitCommands(controller, 1)

        assertNear(before, topOf("item-0"), "存在しない ID ではスクロールしない")
        assertWarned("id が配列にありません", "存在しない ID への命令は黙って捨てず警告を残す")
    }

    /** ヘッダーを宣言しても、ID 指定のスクロールは要素そのものを表示範囲の先頭に置く。 */
    @Test
    fun scrollToItemAccountsForHeaderIndex() {
        val controller = KsScrollController()
        setScrollContent(controller = controller, header = true)

        composeTestRule.runOnUiThread { controller.scrollTo(id = "item-10") }
        awaitCommands(controller, 1)

        composeTestRule.onNodeWithTag("item-10").assertIsDisplayed()
        assertNear(0.dp, topOf("item-10"), "ヘッダーは要素の index に数えない")
    }

    /** contentPadding を宣言すると、Start / Center / End は余白の内側の表示範囲を基準にする。 */
    @Test
    fun scrollPositionsUseViewportInsideContentPadding() {
        val controller = KsScrollController()
        val topPadding = 40.dp
        val bottomPadding = 60.dp
        setScrollContent(
            controller = controller,
            contentPadding = PaddingValues(top = topPadding, bottom = bottomPadding),
        )
        val innerHeight = containerHeight - topPadding - bottomPadding

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-10", position = KsScrollPosition.Start)
        }
        awaitCommands(controller, 1)
        assertNear(topPadding, topOf("item-10"), "Start は内側の表示範囲の先頭に合わせる")

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-10", position = KsScrollPosition.Center)
        }
        awaitCommands(controller, 2)
        assertNear(
            topPadding + (innerHeight - itemHeight) / 2,
            topOf("item-10"),
            "Center は内側の表示範囲の中央に合わせる",
        )

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-10", position = KsScrollPosition.End)
        }
        awaitCommands(controller, 3)
        assertNear(
            topPadding + innerHeight - itemHeight,
            topOf("item-10"),
            "End は内側の表示範囲の末尾に合わせる",
        )
    }

    /** ID 指定の Center は対象を表示範囲の中央に置く。 */
    @Test
    fun scrollToCenterPlacesItemAtViewportCenter() {
        val controller = KsScrollController()
        setScrollContent(controller = controller)

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-20", position = KsScrollPosition.Center)
        }
        awaitCommands(controller, 1)

        val bounds = composeTestRule.onNodeWithTag("item-20").getUnclippedBoundsInRoot()
        val center = bounds.top + bounds.height / 2
        assertNear(containerHeight / 2, center, "対象が表示範囲の中央に来る")
    }

    /** 配列の差し替えと同じ処理で出した命令は、差し替え後の配列で解決される。 */
    @Test
    fun scrollToEndReachesItemAddedInTheSameFrame() {
        val controller = KsScrollController()
        var items by mutableStateOf(testItems(itemCount))
        setScrollContent(controller = controller, items = { items })

        composeTestRule.runOnUiThread {
            items = items + TestItem(id = "appended", text = "appended")
            controller.scrollToEnd()
        }
        awaitCommands(controller, 1)

        composeTestRule.onNodeWithTag("appended").assertIsDisplayed()
    }

    /** 連続する命令は発行順に処理され、最終的な位置は最後の命令で決まる。 */
    @Test
    fun laterCommandWinsOverEarlierOne() {
        val controller = KsScrollController()
        setScrollContent(controller = controller)

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-25")
            controller.scrollTo(id = "item-5")
        }
        awaitCommands(controller, 2)

        composeTestRule.onNodeWithTag("item-5").assertIsDisplayed()
        assertNear(0.dp, topOf("item-5"), "最後の命令の位置で止まる")
    }

    /** 実行前に対象が消えた命令は何もせず、後続の命令はそのまま実行される。 */
    @Test
    fun commandForRemovedItemIsSkippedAndLaterCommandRuns() {
        val controller = KsScrollController()
        val initial = testItems(itemCount)
        var items by mutableStateOf(initial)
        setScrollContent(controller = controller, items = { items })

        composeTestRule.runOnUiThread {
            items = initial.filterNot { it.id == "item-10" }
            controller.scrollTo(id = "item-10")
            controller.scrollToEnd()
        }
        awaitCommands(controller, 2)

        composeTestRule.onNodeWithTag("item-${itemCount - 1}").assertIsDisplayed()
    }

    /** 中央に置けない位置の要求は、スクロール可能範囲の端で止まる。 */
    @Test
    fun unreachableCenterClampsToScrollableEnd() {
        val controller = KsScrollController()
        setScrollContent(controller = controller)

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-28", position = KsScrollPosition.Center)
        }
        awaitCommands(controller, 1)

        composeTestRule.onNodeWithTag("item-28").assertIsDisplayed()
        val last = composeTestRule.onNodeWithTag("item-${itemCount - 1}").getUnclippedBoundsInRoot()
        assertNear(containerHeight, last.top + last.height, "末尾で止まる")
    }

    /**
     * Center 指定のアニメーションは 1 方向だけに動く。
     *
     * 対象をいったん表示範囲の先頭に合わせてから中央へ戻す動きになっていないことを、
     * 毎フレームのスクロール量の系列で判定する (最終位置だけでは往復を検出できない)。
     */
    @Test
    fun animatedCenterScrollNeverReversesDirection() {
        val controller = KsScrollController()
        setScrollContent(controller = controller)

        val samples = recordScrollDuringCommand(controller) {
            controller.scrollTo(id = "item-20", position = KsScrollPosition.Center)
        }

        assertTrue("下方向へ動く (実測 ${samples.first()} → ${samples.last()})", samples.last() > samples.first())
        assertNoReversal(samples)
        assertTrue(
            "1 フレームで飛ばずアニメーションする (実測 ${samples.size} フレーム中 ${samples.distinct().size} 種)",
            samples.distinct().size >= 5,
        )
        // 表示範囲 600dp・項目 100dp なので、中央に置いた対象の先頭は 250dp の位置に来る。
        assertNear(
            itemHeight * 20 - (containerHeight - itemHeight) / 2,
            samples.last(),
            "対象が表示範囲の中央に来る",
        )
    }

    /** End 指定のアニメーションも 1 方向だけに動く。 */
    @Test
    fun animatedEndScrollNeverReversesDirection() {
        val controller = KsScrollController()
        setScrollContent(controller = controller)

        val samples = recordScrollDuringCommand(controller) {
            controller.scrollTo(id = "item-20", position = KsScrollPosition.End)
        }

        assertNoReversal(samples)
        assertNear(
            itemHeight * 20 - (containerHeight - itemHeight),
            samples.last(),
            "対象が表示範囲の末尾に来る",
        )
    }

    /**
     * 高さの異なるテンプレートが混ざっていても、Center 指定は 1 方向だけに動く。
     *
     * 対象が表示範囲の外にあるときの高さは可視項目からの推定になるため、推定が外れたときに
     * 逆向きの補正が入らないことをここで見る。
     */
    @Test
    fun animatedCenterScrollNeverReversesWithMixedItemHeights() {
        val controller = KsScrollController()
        val items = (0 until itemCount).map { index ->
            TestItem(
                id = "item-$index",
                text = "item $index",
                kind = if (index % 2 == 0) TestKind.Message else TestKind.Ad,
            )
        }
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    template = { it.kind },
                    scrollController = controller,
                    listSeparators = false,
                ) {
                    template(TestKind.Message) { item ->
                        Box(Modifier.fillMaxWidth().height(60.dp).testTag(item.id)) { Text(item.text) }
                    }
                    template(TestKind.Ad) { item ->
                        Box(Modifier.fillMaxWidth().height(160.dp).testTag(item.id)) { Text(item.text) }
                    }
                }
            }
        }

        // 偶数 index は 60dp、奇数 index は 160dp。コンテンツ先頭からの位置はその積み上げ。
        val samples = recordScrollDuringCommand(
            controller = controller,
            contentOffsetOf = { index -> 60.dp * ((index + 1) / 2) + 160.dp * (index / 2) },
        ) {
            controller.scrollTo(id = "item-21", position = KsScrollPosition.Center)
        }

        assertNoReversal(samples)
        composeTestRule.onNodeWithTag("item-21").assertIsDisplayed()
    }

    /** 1 つのコントローラを 2 つのコレクションへ接続すると、最後に接続した側だけが動く。 */
    @Test
    fun lastAttachedCollectionWins() {
        KsDiagnostics.debugOverride = true
        val controller = KsScrollController()
        val items = testItems(itemCount)
        composeTestRule.setContent {
            Column(Modifier.size(containerWidth, containerHeight)) {
                ScrollTestCollection(items, controller, Modifier.height(300.dp), prefix = "a")
                ScrollTestCollection(items, controller, Modifier.height(300.dp), prefix = "b")
            }
        }

        val firstOfA = topOf("a-item-0")
        composeTestRule.runOnUiThread { controller.scrollToEnd() }
        awaitCommands(controller, 1)

        composeTestRule.onNodeWithTag("b-item-${itemCount - 1}").assertIsDisplayed()
        assertNear(firstOfA, topOf("a-item-0"), "先に接続した側は動かない")
    }

    /** どのコレクションにも接続していないコントローラへの命令は何も起こさない。 */
    @Test
    fun unattachedControllerIsNoOp() {
        val controller = KsScrollController()
        setScrollContent(controller = null)

        val before = topOf("item-0")
        composeTestRule.runOnUiThread { controller.scrollToStart() }
        composeTestRule.waitForIdle()

        assertNear(before, topOf("item-0"), "未接続の命令では何も起きない")
        assertEquals(0, controller.processedCommandCount)
    }

    /** 接続を解除した後のコントローラへの命令はスクロールを起こさず、例外にもならない。 */
    @Test
    fun detachedControllerIsNoOp() {
        val controller = KsScrollController()
        var attached by mutableStateOf(true)
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                ScrollTestCollection(
                    items = testItems(itemCount),
                    controller = if (attached) controller else null,
                    modifier = Modifier,
                )
            }
        }

        // 接続中は命令が届くことを先に確かめ、比較の起点を先頭以外の位置にする。
        composeTestRule.runOnUiThread { controller.scrollTo(id = "item-10") }
        awaitCommands(controller, 1)
        assertNear(0.dp, topOf("item-10"), "接続中の命令は届く")

        composeTestRule.runOnUiThread { attached = false }
        composeTestRule.waitForIdle()

        val before = topOf("item-10")
        composeTestRule.runOnUiThread { controller.scrollToEnd() }
        // 命令が処理されるだけの時間を与えても位置が動かないことを見る。
        repeat(10) {
            composeTestRule.waitForIdle()
            composeTestRule.mainClock.advanceTimeByFrame()
        }
        composeTestRule.waitForIdle()

        assertNear(before, topOf("item-10"), "接続解除後の命令ではスクロールしない")
    }

    // ---- 進行方向の判定 ----

    /**
     * 対象が先頭可視項目と同じでも、要求する位置が今より下なら後方、上なら前方と判定する。
     *
     * 到着後の補正はこの向きにだけ掛かるため、判定が逆になると「行き過ぎて戻る」動きになる。
     * 要求するオフセットと `firstVisibleItemScrollOffset` は基準の向きが逆なので、
     * そろえずに比べると同じ index の中で前後を区別できなくなる。
     */
    @Test
    fun forwardScrollIsJudgedByRequestedTopWithinSameItem() {
        val state = LazyGridState(firstVisibleItemIndex = 3, firstVisibleItemScrollOffset = 100)

        // 対象の上端を表示範囲の 200px 内側へ置く要求 = 今 (100px 上に隠れている) より下へ動く。
        assertFalse(
            "同じ項目の中で下へ動かす要求は後方と判定する",
            state.isForwardScroll(index = 3, scrollOffset = -200),
        )
        // 上端をさらに 300px 上へ隠す要求 = 今より上へ動く。
        assertTrue(
            "同じ項目の中で上へ動かす要求は前方と判定する",
            state.isForwardScroll(index = 3, scrollOffset = 300),
        )
        // 今と同じ位置の要求は前方ではない。
        assertFalse(
            "同じ位置の要求は前方と判定しない",
            state.isForwardScroll(index = 3, scrollOffset = 100),
        )
    }

    /** 対象が先頭可視項目と別の項目なら、index の前後がそのまま進行方向になる。 */
    @Test
    fun forwardScrollIsJudgedByIndexOrderForOtherItems() {
        val state = LazyGridState(firstVisibleItemIndex = 3, firstVisibleItemScrollOffset = 100)

        assertTrue("後ろの項目へは前方", state.isForwardScroll(index = 4, scrollOffset = -200))
        assertFalse("前の項目へは後方", state.isForwardScroll(index = 2, scrollOffset = -200))
    }

    // ---- 補助 ----

    /**
     * 命令を出してから処理し切るまでのスクロール量を毎フレーム記録する。
     *
     * 動きの過程を見るためクロックの自動進行を止め、フレームを 1 つずつ進めて標本を取る。
     * 上限は実時間の deadline で区切り、超えたときはその時点の値を添えて失敗させる。
     */
    private fun recordScrollDuringCommand(
        controller: KsScrollController,
        contentOffsetOf: (Int) -> Dp = { itemHeight * it },
        issue: () -> Unit,
    ): kotlin.collections.List<Dp> {
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        val samples = mutableListOf(currentScrollDp(contentOffsetOf))
        composeTestRule.runOnUiThread { issue() }

        val deadline = System.nanoTime() + 30_000_000_000L
        while (controller.processedCommandCount < 1) {
            if (System.nanoTime() > deadline) {
                fail("命令が処理されない (実測のスクロール量 ${samples.map { it.value }})")
            }
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            samples += currentScrollDp(contentOffsetOf)
        }
        // 到着後に補正が入る場合はここに現れる。
        repeat(30) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            samples += currentScrollDp(contentOffsetOf)
        }
        composeTestRule.mainClock.autoAdvance = true
        return samples
    }

    /**
     * 進行方向と逆向きの移動が無いことを確かめる。
     *
     * @param allowance 逆向きと数えない大きさ。端数丸めの吸収に使う
     */
    private fun assertNoReversal(
        samples: kotlin.collections.List<Dp>,
        allowance: Dp = tolerance,
    ) {
        val forward = samples.last() > samples.first()
        val reversals = samples.zipWithNext().count { (previous, next) ->
            val delta = (next - previous).value
            if (forward) delta < -allowance.value else delta > allowance.value
        }
        assertEquals(
            "進行方向と逆向きの移動が無い (実測 ${samples.map { it.value }})",
            0,
            reversals,
        )
    }

    /**
     * 現在のスクロール量を表示中の項目の位置から求める。
     *
     * 行間 0 で並べているため、可視の先頭項目の index と画面上の位置から換算できる。
     *
     * @param contentOffsetOf index の項目がコンテンツ先頭から何 dp の位置にあるか
     */
    private fun currentScrollDp(contentOffsetOf: (Int) -> Dp): Dp {
        val nodes = composeTestRule.onAllNodes(
            SemanticsMatcher("項目のタグを持つ節点") { node ->
                node.config.getOrNull(SemanticsProperties.TestTag)
                    ?.matches(Regex("item-\\d+")) == true
            },
            useUnmergedTree = true,
        ).fetchSemanticsNodes()
        if (nodes.isEmpty()) fail("項目が 1 つも表示されていない")
        val first = nodes.minBy { node ->
            node.config[SemanticsProperties.TestTag].removePrefix("item-").toInt()
        }
        val index = first.config[SemanticsProperties.TestTag].removePrefix("item-").toInt()
        val topDp = with(composeTestRule.density) { first.positionInRoot.y.toDp() }
        return contentOffsetOf(index) - topDp
    }

    private fun assertNear(expected: Dp, actual: Dp, message: String) {
        assertTrue(
            "$message (期待 $expected / 実測 $actual)",
            kotlin.math.abs((expected - actual).value) <= tolerance.value,
        )
    }

    private fun topOf(tag: String): Dp =
        composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot().top

    /**
     * 命令が処理し切られるまで待つ。
     *
     * 表示を変えない命令でも処理済み件数の変化で完了を観測できる。上限は実時間で区切り、
     * 超えたときはその時点の実測値を添えて失敗させる。
     */
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

    private fun setTapContent(
        items: List<TestItem>,
        onItemTap: ((TestItem) -> Unit)? = null,
        onItemLongTap: ((TestItem) -> Unit)? = null,
        touchFeedbackColor: Color? = null,
    ) {
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    onItemTap = onItemTap,
                    onItemLongTap = onItemLongTap,
                    touchFeedbackColor = touchFeedbackColor,
                    listSeparators = false,
                ) {
                    template { item ->
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(itemHeight)
                                .background(Color.White)
                                .testTag(item.id),
                        ) {
                            Text(item.text)
                        }
                    }
                }
            }
        }
    }

    private fun setScrollContent(
        controller: KsScrollController?,
        items: () -> List<TestItem> = { testItems(itemCount) },
        header: Boolean = false,
        contentPadding: PaddingValues = PaddingValues(0.dp),
    ) {
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                ScrollTestCollection(
                    items = items(),
                    controller = controller,
                    modifier = Modifier,
                    header = header,
                    contentPadding = contentPadding,
                )
            }
        }
    }

    /** 項目の中にボタンを持つコレクション。ボタンの下は項目背景の余白として残す。 */
    private fun setButtonInItemContent(
        items: List<TestItem> = testItems(5),
        onItemTap: (TestItem) -> Unit,
        onButtonClick: () -> Unit = {},
    ) {
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(items = items, key = { it.id }, onItemTap = onItemTap) {
                    template { item ->
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(itemHeight)
                                .testTag(item.id),
                            contentAlignment = Alignment.TopStart,
                        ) {
                            // 項目の上部だけを占めるボタン。下部は項目背景の余白として残す。
                            Box(
                                modifier = Modifier
                                    .size(80.dp, 40.dp)
                                    .testTag("${item.id}-button")
                                    .clickable { onButtonClick() },
                            )
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun ScrollTestCollection(
        items: List<TestItem>,
        controller: KsScrollController?,
        modifier: Modifier,
        prefix: String = "",
        header: Boolean = false,
        contentPadding: PaddingValues = PaddingValues(0.dp),
    ) {
        KsCollectionView(
            items = items,
            key = { it.id },
            modifier = modifier,
            contentPadding = contentPadding,
            header = if (header) {
                { Box(Modifier.fillMaxWidth().height(40.dp).testTag("${prefix}header")) }
            } else {
                null
            },
            scrollController = controller,
            listSeparators = false,
        ) {
            template { item ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(itemHeight)
                        .testTag(if (prefix.isEmpty()) item.id else "$prefix-${item.id}"),
                ) {
                    Text(item.text)
                }
            }
        }
    }

    /** ライブラリのタグで警告ログが出ていることを確かめる。 */
    private fun assertWarned(fragment: String, message: String) {
        val warnings = ShadowLog.getLogsForTag("KsCollectionView")
            .filter { it.type == Log.WARN }
            .map { it.msg }
        assertTrue("$message (実測 $warnings)", warnings.any { it.contains(fragment) })
    }

    /** 項目の content の finder。タップハンドラ付きの項目は semantics がマージされるため unmerged で引く。 */
    private fun onItem(tag: String) =
        composeTestRule.onNodeWithTag(tag, useUnmergedTree = true)

    /** 項目のルート (ライブラリが content を包む節点)。タップの受け口はここに付く。 */
    private fun itemRoot(tag: String) = onItem(tag).onParent()
}


/**
 * 項目のフィードバックの発火だけを記録する差し替え用の表現。
 *
 * 押下がどの `InteractionSource` に流れたかを観測するために使い、描画は content をそのまま通す。
 */
private class RecordingIndication : IndicationNodeFactory {

    val presses: MutableList<PressInteraction> = mutableListOf()

    override fun create(interactionSource: InteractionSource): DelegatableNode =
        RecordingNode(interactionSource)

    override fun equals(other: Any?): Boolean = other === this

    override fun hashCode(): Int = System.identityHashCode(this)

    private inner class RecordingNode(
        private val interactionSource: InteractionSource,
    ) : Modifier.Node(), DrawModifierNode {

        override fun onAttach() {
            coroutineScope.launch {
                interactionSource.interactions.collect { interaction ->
                    if (interaction is PressInteraction) presses += interaction
                }
            }
        }

        override fun ContentDrawScope.draw() {
            drawContent()
        }
    }
}
