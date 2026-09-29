package jp.kamusoft.kscollectionview

import android.view.View
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
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
 * ページングの 6 つの表示 (どの状態と件数で何を出すか・置き場・既定の見え方・差し替え・再試行) を確かめる。
 *
 * 一覧は幅 300dp・高さ 600dp、行の高さ 60dp。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPagingDisplayTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val rowHeight = 60.dp
    private val width = 300.dp
    private val height = 600.dp
    private val tolerance = 1.dp

    /** 状態と件数から出す表示は、表のとおりに高々 1 つに決まる。 */
    @Test
    fun displayIsResolvedFromStateAndEmptiness() {
        val expected = mapOf(
            (KsPagingState.Appending to false) to KsPagingDisplay.AppendingIndicator,
            (KsPagingState.Appending to true) to KsPagingDisplay.LoadingPlaceholder,
            (KsPagingState.Failed to false) to KsPagingDisplay.FailedFooter,
            (KsPagingState.Failed to true) to KsPagingDisplay.FailedPlaceholder,
            (KsPagingState.EndReached to false) to KsPagingDisplay.EndReachedFooter,
            (KsPagingState.EndReached to true) to KsPagingDisplay.EmptyPlaceholder,
            (KsPagingState.Refreshing to false) to null,
            (KsPagingState.Refreshing to true) to KsPagingDisplay.LoadingPlaceholder,
            (KsPagingState.Idle to false) to null,
            (KsPagingState.Idle to true) to null,
        )
        for ((key, display) in expected) {
            assertEquals("$key", display, KsPagingDisplay.resolve(key.first, isEmpty = key.second))
        }
    }

    /** 項目があり状態を追加読み込み中にすると、標準の読み込み中の表示が文言なしで 1 つ出る (置き場は KsPagingAppendingIndicatorTest)。 */
    @Test
    fun appendingIndicatorShowsDefaultProgressWithoutText() {
        val vm = KsPagingProbeVm(testItems(3), state = KsPagingState.EndReached)
        setPagingContent(vm, footer = { Box(Modifier.fillMaxWidth().height(40.dp).testTag("root-footer")) })
        assertEquals(0, composeTestRule.countIndeterminateProgress())

        composeTestRule.runOnUiThread { vm.state = KsPagingState.Appending }
        composeTestRule.awaitCondition("読み込み中の表示", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 1
        }
        assertNoText(isIndeterminateProgressNodeText())
    }

    /** 項目が 0 件で状態が追加読み込み中なら、項目の代わりに標準の読み込み中の表示が 1 つ真ん中に出る。 */
    @Test
    fun loadingPlaceholderShowsSingleDefaultProgressInCenter() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.Appending)
        setPagingContent(vm)
        assertEquals(1, composeTestRule.countIndeterminateProgress())
        val bounds = composeTestRule.onNode(isIndeterminateProgress).getUnclippedBoundsInRoot()
        assertNear(height / 2, (bounds.top + bounds.bottom) / 2, "縦の真ん中")
        assertNear(width / 2, (bounds.left + bounds.right) / 2, "横の真ん中")
    }

    /** 0 件で取り直し中のときも最初の読み込み中が出る。 */
    @Test
    fun loadingPlaceholderAlsoShowsWhileRefreshingEmpty() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.Refreshing)
        setPagingContent(vm)
        assertEquals(1, composeTestRule.countIndeterminateProgress())
    }

    /** 差し替えていないとき、失敗・終端・空は (項目があってもなくても) 何も出さない。 */
    @Test
    fun failedEndReachedAndEmptyShowNothingByDefault() {
        val vm = KsPagingProbeVm(testItems(3), state = KsPagingState.Failed)
        setPagingContent(vm, footer = { Box(Modifier.fillMaxWidth().height(10.dp).testTag("root-footer")) })
        for (isEmpty in listOf(false, true)) {
            for (state in listOf(KsPagingState.Failed, KsPagingState.EndReached)) {
                composeTestRule.runOnUiThread {
                    vm.items = if (isEmpty) emptyList() else testItems(3)
                    vm.state = state
                }
                composeTestRule.waitForIdle()
                val label = "${if (isEmpty) "0 件" else "項目あり"}・$state"
                assertEquals(label, 0, composeTestRule.countIndeterminateProgress())
                assertEquals("$label: 利用者のフッターは出る", 1, composeTestRule.countNodesWithTag("root-footer"))
                if (!isEmpty) {
                    // フッターの枠のページングの部分は高さを持たない (最後の項目のすぐ下に利用者のフッター)。
                    assertNear(composeTestRule.bottomOfTag("item-2"), composeTestRule.topOfTag("root-footer"), label)
                }
            }
        }
        assertEquals("項目があれば頼まない・0 件でも待機でなければ頼まない", 0, vm.loadMoreCount)
    }

    /** 6 つの表示をすべて差し替えると、表の組み合わせに対応する差し替えた表示だけが出る。 */
    @Test
    fun substitutedDisplaysAppearOnlyForTheirCombination() {
        val tags = listOf("appending", "failed", "end", "loading", "failed-empty", "empty")
        val expectations = listOf(
            Triple(KsPagingState.Appending, false, "appending"),
            Triple(KsPagingState.Failed, false, "failed"),
            Triple(KsPagingState.EndReached, false, "end"),
            Triple(KsPagingState.Appending, true, "loading"),
            Triple(KsPagingState.Refreshing, true, "loading"),
            Triple(KsPagingState.Failed, true, "failed-empty"),
            Triple(KsPagingState.EndReached, true, "empty"),
            Triple(KsPagingState.Idle, false, null),
            Triple(KsPagingState.Idle, true, null),
            Triple(KsPagingState.Refreshing, false, null),
        )
        val vm = KsPagingProbeVm(testItems(3))
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    paging = allSubstituted(vm),
                ) { template { item -> PagingRow(item) } }
            }
        }
        for ((state, isEmpty, tag) in expectations) {
            composeTestRule.runOnUiThread {
                vm.state = state
                vm.items = if (isEmpty) emptyList() else testItems(3)
            }
            composeTestRule.waitForIdle()
            for (candidate in tags) {
                val count = composeTestRule.countNodesWithTag(candidate)
                assertEquals("$state・${if (isEmpty) "0 件" else "項目あり"}: $candidate", if (candidate == tag) 1 else 0, count)
            }
            assertEquals("差し替えたので既定の読み込み中は出ない", 0, composeTestRule.countIndeterminateProgress())
        }
    }

    /** 項目があるときに引っ張らずに状態を取り直し中にしても、項目はそのまま並び、ページングの表示は出ない。 */
    @Test
    fun vmStartedRefreshShowsNothingOverItems() {
        val vm = KsPagingProbeVm(testItems(3))
        setPagingContent(vm)
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Refreshing }
        composeTestRule.waitForIdle()
        assertEquals(1, composeTestRule.countNodesWithTag("item-0"))
        assertNear(0.dp, composeTestRule.topOfTag("item-0"), "項目は並んだまま")
        assertEquals(0, composeTestRule.countIndeterminateProgress())
    }

    /** 次のページの読み込み中を出している一覧で、配列を変えずに状態を待機にすると、読み込み中の表示は消える。 */
    @Test
    fun stateOnlyChangeUpdatesDisplay() {
        val vm = KsPagingProbeVm(testItems(3), state = KsPagingState.Appending)
        setPagingContent(vm)
        assertEquals(1, composeTestRule.countIndeterminateProgress())

        composeTestRule.runOnUiThread { vm.state = KsPagingState.EndReached }
        composeTestRule.awaitCondition("読み込み中の表示が消える", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 0
        }
        // 待機に戻したときも出ない (0 件でもないので頼みが出ても表示は無い)。
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Appending }
        composeTestRule.awaitCondition("読み込み中の表示が出る") { composeTestRule.countIndeterminateProgress() == 1 }
        composeTestRule.runOnUiThread { vm.state = KsPagingState.Idle }
        composeTestRule.awaitCondition("待機で消える") { composeTestRule.countIndeterminateProgress() == 0 }
    }

    /**
     * 表示範囲の真ん中まで届く高さのルートのヘッダーと重なっても、失敗 (0 件) の表示がヘッダーより手前に
     * 見え、中の再試行を押せる (タッチはヘッダーに奪われない)。
     */
    @Test
    fun emptyDisplayOverHeaderIsFrontmostAndRetryIsTappable() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.Failed)
        var headerTaps = 0
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    header = {
                        Box(
                            Modifier.fillMaxWidth().height(height * 0.75f).clickable { headerTaps += 1 }
                                .testTag("root-header"),
                        )
                    },
                    paging = KsPaging(
                        state = vm.state,
                        onLoadMore = vm.loadMore,
                        failedPlaceholder = { retry ->
                            Text("再試行", Modifier.clickable(onClick = retry).testTag("retry"))
                        },
                    ),
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
        val retry = composeTestRule.onNodeWithTag("retry").getUnclippedBoundsInRoot()
        assertTrue("再試行はヘッダーと重なる位置にある", retry.bottom < composeTestRule.bottomOfTag("root-header"))

        composeTestRule.onNodeWithTag("retry").performClick()
        composeTestRule.awaitCondition("再試行の次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals("ヘッダーはタッチを受けない", 0, headerTaps)

        // 0 件の表示の外 (ヘッダーの上端近く) へのタッチはヘッダーへ通る。
        composeTestRule.onNodeWithTag("root-header").performClickAt(topFraction = 0.05f)
        assertEquals("表示の外のタッチはヘッダーへ通る", 1, headerTaps)
    }

    /** 0 件の表示は、上下の安全領域 (ステータスバー・ナビゲーションバー) を除いた範囲の真ん中に出る。 */
    @Test
    fun emptyDisplayIsCenteredWithinVerticalSafeArea() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.EndReached)
        val fullHeight = 800.dp
        composeTestRule.setContent {
            TestContainer(400.dp, fullHeight) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    paging = KsPaging(
                        state = vm.state,
                        onLoadMore = vm.loadMore,
                        emptyPlaceholder = { Box(Modifier.height(20.dp).fillMaxWidth().testTag("empty")) },
                    ),
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
        assertNear(fullHeight / 2, center("empty"), "安全領域が無ければ一覧の真ん中")

        val top = 24.dp
        val bottom = 48.dp
        applySystemBarInsets(top, bottom)
        assertNear(top + (fullHeight - top - bottom) / 2, center("empty"), "上下の安全領域を除いた範囲の真ん中")
    }

    /** 項目があるときの失敗の表示の再試行は、次ページ要求を呼ぶ。 */
    @Test
    fun retryInFailedFooterRequestsNextPage() {
        val vm = KsPagingProbeVm(testItems(3), state = KsPagingState.Failed)
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    paging = KsPaging(
                        state = vm.state,
                        onLoadMore = vm.loadMore,
                        failedFooter = { retry -> Text("再試行", Modifier.clickable(onClick = retry).testTag("retry")) },
                    ),
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
        composeTestRule.assertStaysFor("失敗では自動で頼まない") { vm.loadMoreCount }
        composeTestRule.onNodeWithTag("retry").performClick()
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
    }

    /** 0 件で失敗・Pull to Refresh を付けた一覧で、失敗 (0 件) の再試行は取り直しではなく次ページ要求を呼ぶ。 */
    @Test
    fun retryInFailedPlaceholderRequestsNextPageNotRefresh() {
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.Failed)
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    paging = KsPaging(
                        state = vm.state,
                        onLoadMore = vm.loadMore,
                        failedPlaceholder = { retry -> Text("再試行", Modifier.clickable(onClick = retry).testTag("retry")) },
                    ),
                    onRefresh = vm.refresh,
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithTag("retry").performClick()
        composeTestRule.awaitCondition("次ページ要求", observed = { vm.loadMoreCount }) { vm.loadMoreCount == 1 }
        assertEquals("取り直しは呼ばれない", 0, vm.refreshCount)
    }

    /** 既定の読み込み中の表示は、読み上げでは不定の進捗 (読み込み中の要素) として出て、文言を持たない。 */
    @Test
    fun defaultProgressIsExposedAsIndeterminateProgressWithoutText() {
        val vm = KsPagingProbeVm(testItems(3), state = KsPagingState.Appending)
        setPagingContent(vm)
        val footerProgress = composeTestRule.onNode(isIndeterminateProgress).fetchSemanticsNode()
        assertTrue(footerProgress.config.contains(SemanticsProperties.ProgressBarRangeInfo))
        assertEquals("文言を持たない", null, footerProgress.config.getOrNull(SemanticsProperties.Text))
        assertEquals(null, footerProgress.config.getOrNull(SemanticsProperties.ContentDescription))

        composeTestRule.runOnUiThread {
            vm.items = emptyList()
            vm.state = KsPagingState.Appending
        }
        composeTestRule.waitForIdle()
        val placeholderProgress = composeTestRule.onNode(isIndeterminateProgress).fetchSemanticsNode()
        assertEquals(null, placeholderProgress.config.getOrNull(SemanticsProperties.Text))
    }

    // ---- 補助 ----

    private fun allSubstituted(vm: KsPagingProbeVm) = KsPaging(
        state = vm.state,
        onLoadMore = vm.loadMore,
        appendingIndicator = { Text("読み込み中", Modifier.testTag("appending")) },
        failedFooter = { _ -> Text("失敗", Modifier.testTag("failed")) },
        endReachedFooter = { Text("終端", Modifier.testTag("end")) },
        loadingPlaceholder = { Text("最初の読み込み中", Modifier.testTag("loading")) },
        failedPlaceholder = { _ -> Text("失敗 (0 件)", Modifier.testTag("failed-empty")) },
        emptyPlaceholder = { Text("空", Modifier.testTag("empty")) },
    )

    private fun setPagingContent(vm: KsPagingProbeVm, footer: (@Composable () -> Unit)? = null) {
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    footer = footer,
                    listSeparators = false,
                    paging = KsPaging(state = vm.state, onLoadMore = vm.loadMore),
                ) { template { item -> PagingRow(item) } }
            }
        }
        composeTestRule.waitForIdle()
    }

    private fun center(tag: String): Dp {
        val bounds = composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot()
        return (bounds.top + bounds.bottom) / 2
    }

    /** 読み込み中の表示の節点が持つ文言 (無ければ空)。 */
    private fun isIndeterminateProgressNodeText(): List<String> =
        composeTestRule.onAllNodes(isIndeterminateProgress, useUnmergedTree = true).fetchSemanticsNodes()
            .flatMap { node -> node.config.getOrNull(SemanticsProperties.Text).orEmpty().map { it.text } }

    private fun assertNoText(texts: List<String>) {
        assertTrue("読み込み中の表示に文言がある (実測 $texts)", texts.isEmpty())
    }

    /** 節点の上から [topFraction] の高さ・横の真ん中を押す。 */
    private fun androidx.compose.ui.test.SemanticsNodeInteraction.performClickAt(topFraction: Float) {
        performTouchInput { click(Offset(centerX, height * topFraction)) }
        composeTestRule.waitForIdle()
    }

    /** コンポーズの根のビューへ、上端にステータスバー・下端にナビゲーションバーの insets を配る。 */
    private fun applySystemBarInsets(top: Dp, bottom: Dp) {
        val view = composeView()
        val topPx = with(composeTestRule.density) { top.roundToPx() }
        val bottomPx = with(composeTestRule.density) { bottom.roundToPx() }
        composeTestRule.runOnUiThread {
            val insets = android.view.WindowInsets.Builder()
                .setInsets(android.view.WindowInsets.Type.statusBars(), android.graphics.Insets.of(0, topPx, 0, 0))
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

    @Composable
    private fun PagingRow(item: TestItem) {
        Text(item.text, Modifier.fillMaxWidth().height(rowHeight).testTag(item.id))
    }
}
