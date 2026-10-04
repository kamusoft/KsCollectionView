package jp.kamusoft.kscollectionview

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs

/**
 * 一覧の `loadingIndicatorColor` が、差し替えていない次のページの読み込み中・最初の読み込み中と、
 * Pull to Refresh のインジケータの矢印に効くことを、実際の描画結果 (画素) で確かめる。
 *
 * テーマの色はどれも互いに違う色にしてあり、どの色で描かれたかを画素の色で見分ける。読み込み中の表示は
 * 回り続けるため、画素の位置は決めずに、範囲の中にその色の画素があるかどうかで判定する。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsLoadingIndicatorColorTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val rowHeight = 60.dp
    private val width = 300.dp
    private val height = 600.dp

    /** 一覧に渡す色。試験の側から書き換える。 */
    private var indicatorColor: Color? by mutableStateOf(null)

    // ---- 色を指定した一覧 ----

    /** 項目がある一覧を追加読み込み中にすると、次のページの読み込み中が指定した色で描かれる。 */
    @Test
    fun appendingIndicatorIsDrawnInSpecifiedColor() {
        indicatorColor = Specified
        setCollection(KsPagingProbeVm(testItems(40), state = KsPagingState.Appending))

        awaitProgressDrawnIn(Specified, "次のページの読み込み中")
        assertEquals("テーマの primary では描かない", 0, progressPixels(ThemePrimary))
    }

    /** 項目が 0 件の一覧では、追加読み込み中でも取り直し中でも、最初の読み込み中が指定した色で描かれる。 */
    @Test
    fun loadingPlaceholderIsDrawnInSpecifiedColorWhileAppendingAndRefreshing() {
        indicatorColor = Specified
        val vm = KsPagingProbeVm(emptyList(), state = KsPagingState.Appending)
        setCollection(vm)

        awaitProgressDrawnIn(Specified, "追加読み込み中の最初の読み込み中")
        assertEquals("テーマの primary では描かない", 0, progressPixels(ThemePrimary))

        composeTestRule.runOnUiThread { vm.state = KsPagingState.Refreshing }
        awaitProgressDrawnIn(Specified, "取り直し中の最初の読み込み中")
        assertEquals("テーマの primary では描かない", 0, progressPixels(ThemePrimary))
    }

    /** ページングを付けた一覧で引っ張ると、インジケータの矢印が指定した色で描かれ、下地はテーマの色のまま。 */
    @Test
    fun pullIndicatorArrowIsDrawnInSpecifiedColorWithPaging() {
        indicatorColor = Specified
        setCollection(waitingRefreshVm(), withPaging = true)
        pullAndWaitForRefresh()

        awaitPullIndicatorDrawnIn(Specified, "指定した色の矢印")
        assertEquals("既定の矢印の色では描かない", 0, topAreaPixels(ThemeArrow))
        assertContainerIsThemeColor()
    }

    /** ページングを付けない一覧でも、引っ張るとインジケータの矢印が指定した色で描かれ、下地はテーマの色のまま。 */
    @Test
    fun pullIndicatorArrowIsDrawnInSpecifiedColorWithoutPaging() {
        indicatorColor = Specified
        setCollection(waitingRefreshVm(), withPaging = false)
        pullAndWaitForRefresh()

        awaitPullIndicatorDrawnIn(Specified, "指定した色の矢印")
        assertEquals("既定の矢印の色では描かない", 0, topAreaPixels(ThemeArrow))
        assertContainerIsThemeColor()
    }

    // ---- 差し替えた表示 ----

    /**
     * 2 つの読み込み中を差し替えた一覧では、差し替えた表示が利用者の色のまま出る。色を自分で決めた表示は
     * その色で、色を決めていない標準の部品はテーマの primary で描かれ、どちらも指定した色にはならない。
     */
    @Test
    fun replacedDisplaysKeepTheirOwnColors() {
        indicatorColor = Specified
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        setCollection(vm, replaced = true)

        composeTestRule.awaitCondition("差し替えた次のページの読み込み中", observed = { progressPixels(UserColor) }) {
            progressPixels(UserColor) > 0
        }
        assertEquals("指定した色では描かない", 0, wholePixels(Specified))

        composeTestRule.runOnUiThread { vm.items = emptyList() }
        composeTestRule.awaitCondition("差し替えた最初の読み込み中", observed = { progressPixels(ThemePrimary) }) {
            composeTestRule.countIndeterminateProgress() == 1 && progressPixels(ThemePrimary) > 0
        }
        assertEquals("指定した色では描かない", 0, wholePixels(Specified))
    }

    // ---- 表示中に色を変える ----

    /** 次のページの読み込み中を出したまま指定を別の色に変えると、新しい色で描かれる。 */
    @Test
    fun appendingIndicatorFollowsColorChangeWhileShown() {
        indicatorColor = Specified
        setCollection(KsPagingProbeVm(testItems(40), state = KsPagingState.Appending))
        awaitProgressDrawnIn(Specified, "はじめの色")

        composeTestRule.runOnUiThread { indicatorColor = Changed }
        awaitProgressDrawnIn(Changed, "変えた後の色")
        assertEquals("前の色では描かない", 0, progressPixels(Specified))
    }

    /** 最初の読み込み中を出したまま指定を別の色に変えると、新しい色で描かれる。 */
    @Test
    fun loadingPlaceholderFollowsColorChangeWhileShown() {
        indicatorColor = Specified
        setCollection(KsPagingProbeVm(emptyList(), state = KsPagingState.Appending))
        awaitProgressDrawnIn(Specified, "はじめの色")

        composeTestRule.runOnUiThread { indicatorColor = Changed }
        awaitProgressDrawnIn(Changed, "変えた後の色")
        assertEquals("前の色では描かない", 0, progressPixels(Specified))
    }

    /** 取り直しの処理を待たせてインジケータを出したまま指定を別の色に変えると、矢印が新しい色で描かれる。 */
    @Test
    fun pullIndicatorFollowsColorChangeWhileShown() {
        indicatorColor = Specified
        setCollection(waitingRefreshVm())
        pullAndWaitForRefresh()
        awaitPullIndicatorDrawnIn(Specified, "はじめの色")

        composeTestRule.runOnUiThread { indicatorColor = Changed }
        awaitPullIndicatorDrawnIn(Changed, "変えた後の色")
        assertEquals("前の色では描かない", 0, topAreaPixels(Specified))
        assertContainerIsThemeColor()
    }

    // ---- 表示中に指定を外す ----

    /** 次のページの読み込み中を出したまま指定を外すと、テーマの primary で描かれる。 */
    @Test
    fun appendingIndicatorReturnsToThemeColorWhenCleared() {
        indicatorColor = Specified
        setCollection(KsPagingProbeVm(testItems(40), state = KsPagingState.Appending))
        awaitProgressDrawnIn(Specified, "はじめの色")

        composeTestRule.runOnUiThread { indicatorColor = null }
        awaitProgressDrawnIn(ThemePrimary, "指定を外した後の色")
        assertEquals("外した色では描かない", 0, progressPixels(Specified))
    }

    /** 最初の読み込み中を出したまま指定を外すと、テーマの primary で描かれる。 */
    @Test
    fun loadingPlaceholderReturnsToThemeColorWhenCleared() {
        indicatorColor = Specified
        setCollection(KsPagingProbeVm(emptyList(), state = KsPagingState.Appending))
        awaitProgressDrawnIn(Specified, "はじめの色")

        composeTestRule.runOnUiThread { indicatorColor = null }
        awaitProgressDrawnIn(ThemePrimary, "指定を外した後の色")
        assertEquals("外した色では描かない", 0, progressPixels(Specified))
    }

    /** 取り直しの処理を待たせてインジケータを出したまま指定を外すと、矢印が既定の色で描かれる。 */
    @Test
    fun pullIndicatorReturnsToDefaultColorWhenCleared() {
        indicatorColor = Specified
        setCollection(waitingRefreshVm())
        pullAndWaitForRefresh()
        awaitPullIndicatorDrawnIn(Specified, "はじめの色")

        composeTestRule.runOnUiThread { indicatorColor = null }
        awaitPullIndicatorDrawnIn(ThemeArrow, "指定を外した後の色")
        assertEquals("外した色では描かない", 0, topAreaPixels(Specified))
        assertContainerIsThemeColor()
    }

    // ---- 色を指定しない一覧 ----

    /** 色を指定しない一覧では、ページングの 2 つの読み込み中がテーマの primary で描かれる。 */
    @Test
    fun pagingDisplaysUseThemePrimaryWithoutColor() {
        val vm = KsPagingProbeVm(testItems(40), state = KsPagingState.Appending)
        setCollection(vm)
        awaitProgressDrawnIn(ThemePrimary, "次のページの読み込み中")

        composeTestRule.runOnUiThread { vm.items = emptyList() }
        composeTestRule.awaitCondition("最初の読み込み中", observed = { progressPixels(ThemePrimary) }) {
            composeTestRule.countIndeterminateProgress() == 1 && progressPixels(ThemePrimary) > 0
        }
    }

    /** 色を指定しない一覧では、Pull to Refresh のインジケータが Material の既定の色 (矢印と下地) で描かれる。 */
    @Test
    fun pullIndicatorUsesMaterialDefaultsWithoutColor() {
        setCollection(waitingRefreshVm())
        pullAndWaitForRefresh()

        awaitPullIndicatorDrawnIn(ThemeArrow, "既定の色の矢印")
        assertContainerIsThemeColor()
    }

    // ---- 補助 ----

    /** 取り直しの処理が門で待つ VM。インジケータを出したままにする。 */
    private fun waitingRefreshVm(): KsPagingProbeVm =
        KsPagingProbeVm(testItems(40)).also { it.refreshGate = CompletableDeferred() }

    /**
     * 一覧を置く。[replaced] が true なら 2 つの読み込み中を差し替える (次のページの読み込み中は色を自分で
     * 決めた表示、最初の読み込み中は色を決めていない標準の部品)。
     */
    private fun setCollection(vm: KsPagingProbeVm, withPaging: Boolean = true, replaced: Boolean = false) {
        composeTestRule.setContent {
            MaterialTheme(colorScheme = TestColorScheme) {
                Box(Modifier.size(width, height).background(ListBackground).testTag(ContainerTag)) {
                    KsCollectionView(
                        items = vm.items,
                        key = { it.id },
                        paging = if (withPaging) {
                            KsPaging(
                                state = vm.state,
                                onLoadMore = vm.loadMore,
                                appendingIndicator = if (replaced) {
                                    { CircularProgressIndicator(color = UserColor) }
                                } else {
                                    null
                                },
                                loadingPlaceholder = if (replaced) {
                                    { CircularProgressIndicator() }
                                } else {
                                    null
                                },
                            )
                        } else {
                            null
                        },
                        onRefresh = vm.refresh,
                        loadingIndicatorColor = indicatorColor,
                    ) { template { item -> ColorRow(item) } }
                }
            }
        }
        composeTestRule.waitForIdle()
    }

    /** 一覧の上端から下へ指を滑らせて離し、取り直しの処理が呼ばれるまで待つ。 */
    private fun pullAndWaitForRefresh() {
        composeTestRule.onNode(hasScrollAction(), useUnmergedTree = true).performTouchInput {
            swipeDown(startY = top + 10f, endY = bottom - 10f, durationMillis = 300)
        }
        composeTestRule.awaitCondition("インジケータが出る", observed = { composeTestRule.countIndeterminateProgress() }) {
            composeTestRule.countIndeterminateProgress() == 1
        }
    }

    /** 不定の読み込み中の表示 (1 つだけ出ている前提) の範囲に [color] の画素が出るまで待つ。 */
    private fun awaitProgressDrawnIn(color: Color, label: String) {
        composeTestRule.awaitCondition(label, observed = { progressPixels(color) }) {
            composeTestRule.countIndeterminateProgress() == 1 && progressPixels(color) > 0
        }
    }

    /** Pull to Refresh のインジケータが出る上端の範囲に [color] の画素が出るまで待つ。 */
    private fun awaitPullIndicatorDrawnIn(color: Color, label: String) {
        composeTestRule.awaitCondition(label, observed = { topAreaPixels(color) }) { topAreaPixels(color) > 0 }
    }

    /** インジケータの丸い下地がテーマの色で描かれている (下地の面積のうち、まとまった数の画素がその色)。 */
    private fun assertContainerIsThemeColor() {
        val count = topAreaPixels(ThemeContainer)
        assertTrue("下地がテーマの色で描かれる (その色の画素 $count)", count >= MinContainerPixels)
    }

    /** 不定の読み込み中の表示の範囲にある [color] の画素の数。表示が 1 つでなければ 0。 */
    private fun progressPixels(color: Color): Int {
        val nodes = composeTestRule.onAllNodes(isIndeterminateProgress).fetchSemanticsNodes()
        if (nodes.size != 1) return 0
        return capture().count(color, nodes.single().boundsInRoot)
    }

    /** 一覧の上端から [TopAreaHeight] の範囲にある [color] の画素の数。 */
    private fun topAreaPixels(color: Color): Int {
        val container = composeTestRule.onNodeWithTag(ContainerTag).fetchSemanticsNode().boundsInRoot
        val areaHeight = with(composeTestRule.density) { TopAreaHeight.toPx() }
        return capture().count(color, container.copy(bottom = container.top + areaHeight))
    }

    /** 一覧の全体にある [color] の画素の数。 */
    private fun wholePixels(color: Color): Int =
        capture().count(color, composeTestRule.onNodeWithTag(ContainerTag).fetchSemanticsNode().boundsInRoot)

    /**
     * 画面の描画結果を画素として読む。一覧を載せている View を Bitmap へ同期で描く
     * (Compose 1.11 の `captureToImage()` は Robolectric で描画の完了を待てない)。
     */
    @OptIn(androidx.compose.ui.InternalComposeUiApi::class)
    private fun capture(): PixelMap {
        val view = (composeTestRule.onRoot().fetchSemanticsNode().root as ViewRootForTest).view
        val whole = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(whole))
        return whole.asImageBitmap().toPixelMap()
    }

    @Composable
    private fun ColorRow(item: TestItem) {
        Text(item.text, Modifier.fillMaxWidth().height(rowHeight).testTag(item.id))
    }

    private companion object {
        const val ContainerTag = "color-container"

        /** 一覧の背景。 */
        val ListBackground = Color.White

        /** 一覧に指定する色と、表示中に変える先の色。 */
        val Specified = Color(0xFFE040FB)
        val Changed = Color(0xFFFF6D00)

        /** 差し替えた表示が自分で決める色。 */
        val UserColor = Color(0xFF00B8D4)

        /** テーマの primary (ページングの読み込み中の既定の色)。 */
        val ThemePrimary = Color(0xFF00C853)

        /** Pull to Refresh のインジケータの矢印と下地の既定の色になる、テーマの色。 */
        val ThemeArrow = Color(0xFF2962FF)
        val ThemeContainer = Color(0xFFFFF59D)

        val TestColorScheme = lightColorScheme(
            primary = ThemePrimary,
            onSurfaceVariant = ThemeArrow,
            surfaceContainerHigh = ThemeContainer,
        )

        /** Pull to Refresh のインジケータが収まる、一覧の上端からの範囲。 */
        val TopAreaHeight = 200.dp

        /** 下地が描かれていると判定する画素の数の下限 (下地は直径 40dp の円)。 */
        const val MinContainerPixels = 500

        /** 同じ色とみなす、色の成分ごとの差の上限。 */
        const val ChannelTolerance = 3f / 255f
    }

    /** [bounds] の範囲 (画面の外は除く) にある、[color] と同じ色の画素の数。 */
    private fun PixelMap.count(color: Color, bounds: Rect): Int {
        val left = bounds.left.toInt().coerceIn(0, width)
        val right = bounds.right.toInt().coerceIn(0, width)
        val top = bounds.top.toInt().coerceIn(0, height)
        val bottom = bounds.bottom.toInt().coerceIn(0, height)
        var count = 0
        for (y in top until bottom) {
            for (x in left until right) {
                val pixel = this[x, y]
                if (abs(pixel.red - color.red) <= ChannelTolerance &&
                    abs(pixel.green - color.green) <= ChannelTolerance &&
                    abs(pixel.blue - color.blue) <= ChannelTolerance &&
                    pixel.alpha >= 1f - ChannelTolerance
                ) {
                    count += 1
                }
            }
        }
        return count
    }
}
