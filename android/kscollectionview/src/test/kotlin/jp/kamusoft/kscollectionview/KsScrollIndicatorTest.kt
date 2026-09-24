package jp.kamusoft.kscollectionview

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 縦スクロールインジケータの表示・消え方・位置と、スクロールで再コンポーズを起こさないことを確かめる。
 *
 * 時間は mainClock を手で進めて決定的に扱う。表示の判定は実際の描画結果 (画素) で行う。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsScrollIndicatorTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val containerWidth = 300.dp
    private val containerHeight = 600.dp
    private val itemHeight = 100.dp

    /** コンポーネントの背景色。バーが描かれていない画素はこの色になる。 */
    private val background = Color.White

    @After
    fun tearDown() {
        composeTestRule.mainClock.autoAdvance = true
    }

    // ---- 表示と消え方 ----

    /** スクロールしていない間はバーを描かない。 */
    @Test
    fun indicatorIsHiddenBeforeScrolling() {
        setScrollableContent(itemCount = 30)

        assertEquals(0f, indicatorAlpha(), AlphaTolerance)
    }

    /** ドラッグでスクロールしている間はバーを完全な濃さで描く。 */
    @Test
    fun indicatorIsShownWhileDragging() {
        setScrollableContent(itemCount = 30)
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease()

        assertEquals(1f, indicatorAlpha(), AlphaTolerance)
        releaseWithoutFling()
    }

    /**
     * 止まってから 1 秒はそのまま残り、そこからフェードで消える。
     *
     * フェードの途中は中間の濃さを通り、フェードの長さを過ぎると描かれない。
     */
    @Test
    fun indicatorFadesOutAfterScrollStops() {
        setScrollableContent(itemCount = 30)
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease()
        releaseWithoutFling()
        assertEquals("指を離した直後は表示したまま", 1f, indicatorAlpha(), AlphaTolerance)

        advanceTimeBy(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS - 100)
        assertEquals("消え始める前は表示したまま", 1f, indicatorAlpha(), AlphaTolerance)

        advanceTimeBy(100 + KsScrollIndicatorDefaults.FADE_OUT_MILLIS / 2L)
        val midFade = indicatorAlpha()
        assertTrue("フェードの途中は中間の濃さ (実測 $midFade)", midFade > 0.1f && midFade < 0.9f)

        advanceTimeBy(KsScrollIndicatorDefaults.FADE_OUT_MILLIS.toLong())
        assertEquals("フェードの後は描かれない", 0f, indicatorAlpha(), AlphaTolerance)
    }

    /** 消えるのを待つ間に再びドラッグすると、消えずに表示し直す。 */
    @Test
    fun draggingAgainBeforeHideKeepsIndicatorShown() {
        setScrollableContent(itemCount = 30)
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease()
        releaseWithoutFling()
        advanceTimeBy(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS + KsScrollIndicatorDefaults.FADE_OUT_MILLIS / 2L)
        assertTrue("フェードの途中まで進んでいる", indicatorAlpha() < 0.9f)

        dragWithoutRelease()
        assertEquals("再びドラッグすると完全な濃さに戻る", 1f, indicatorAlpha(), AlphaTolerance)
        releaseWithoutFling()
        advanceTimeBy(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS - 100)
        assertEquals("消え始める時間は最後に止まった時点から数え直す", 1f, indicatorAlpha(), AlphaTolerance)
    }

    /** コンテンツが表示領域に収まるときは、ドラッグしてもバーを描かない。 */
    @Test
    fun indicatorIsNotShownWhenContentFits() {
        setScrollableContent(itemCount = 3)
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease()

        assertEquals(0f, indicatorAlpha(), AlphaTolerance)
        releaseWithoutFling()
    }

    /** スクロール命令によるスクロールではバーを描かない (利用者の操作によるスクロールだけで出す)。 */
    @Test
    fun indicatorIsNotShownForProgrammaticScroll() {
        val controller = KsScrollController()
        setScrollableContent(itemCount = 30, controller = controller)
        composeTestRule.mainClock.autoAdvance = false

        composeTestRule.runOnUiThread { controller.scrollTo(id = "item-20") }
        val deadline = System.nanoTime() + 10_000_000_000L
        var maxAlpha = 0f
        while (controller.processedCommandCount < 1) {
            if (System.nanoTime() > deadline) {
                fail("命令が処理されない (実測 ${controller.processedCommandCount} 件)")
            }
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            maxAlpha = maxOf(maxAlpha, indicatorAlpha())
        }
        composeTestRule.onNodeWithTag("item-20").assertExists()
        assertEquals("スクロール中のどのフレームでも描かれない", 0f, maxAlpha, AlphaTolerance)
    }

    // ---- 再コンポーズ ----

    /**
     * バーの表示・移動・フェードは描き直しだけで行い、コンポーネント本体もセルも再コンポーズしない。
     *
     * コンポーネント本体の再コンポーズはテンプレート宣言ブロックの評価回数、セルの再コンポーズは
     * 最初から表示されていたセルの content の実行回数で数える。ドラッグの量は 1 行に満たない
     * 距離にとどめ、最初から表示されていたセルが画面外へ出ないようにする。
     */
    @Test
    fun scrollingDoesNotRecomposeCollectionOrCells() {
        var bodyCompositions = 0
        val cellCompositions = mutableMapOf<String, Int>()
        composeTestRule.setContent {
            TestContainer(width = containerWidth, height = containerHeight) {
                KsCollectionView(
                    items = testItems(30),
                    key = { it.id },
                    modifier = Modifier.background(background).testTag(CollectionTag),
                    listSeparators = false,
                ) {
                    bodyCompositions++
                    template { item ->
                        SideEffect { cellCompositions[item.id] = (cellCompositions[item.id] ?: 0) + 1 }
                        Box(Modifier.fillMaxWidth().height(itemHeight).testTag(item.id))
                    }
                }
            }
        }
        composeTestRule.waitForIdle()
        val initialBody = bodyCompositions
        val initiallyVisible = (0 until 6).map { "item-$it" }
        val initialCells = initiallyVisible.associateWith { cellCompositions[it] ?: 0 }
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease(distance = itemHeight / 2)
        assertEquals("ドラッグ中はバーが描かれている", 1f, indicatorAlpha(), AlphaTolerance)
        releaseWithoutFling()
        advanceTimeBy(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS + KsScrollIndicatorDefaults.FADE_OUT_MILLIS + 100L)
        assertEquals("フェードまで終わっている", 0f, indicatorAlpha(), AlphaTolerance)

        assertEquals("コンポーネント本体は再コンポーズしない", initialBody, bodyCompositions)
        assertEquals(
            "最初から表示されていたセルは再コンポーズしない",
            initialCells,
            initiallyVisible.associateWith { cellCompositions[it] ?: 0 },
        )
    }

    // ---- 位置と長さ ----

    /** バーは末尾側の端から決まった距離に、決まった太さで、スクロール量に比例した位置に描かれる。 */
    @Test
    fun indicatorIsDrawnAtTrailingEdgeWithDefaultMetrics() {
        setScrollableContent(itemCount = 30)
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease()
        val image = collectionPixels()
        val (thickness, inset) = with(composeTestRule.density) {
            KsScrollIndicatorDefaults.thickness.roundToPx() to KsScrollIndicatorDefaults.edgeInset.roundToPx()
        }
        val barRows = (0 until image.height).filter { y -> isBarPixel(image[image.width - inset - thickness / 2 - 1, y]) }
        assertTrue("バーが描かれている", barRows.isNotEmpty())
        // バーの外側 (端との隙間) には何も描かれない。
        barRows.forEach { y ->
            assertEquals("端との隙間は背景のまま", background, image[image.width - 1, y])
            assertEquals("バーの内側 (太さの外) は背景のまま", background, image[image.width - inset - thickness - 2, y])
        }
        // 長さは表示領域とコンテンツの比 (600 / 3000) に沿う。
        val expectedLength = with(composeTestRule.density) {
            ((containerHeight - KsScrollIndicatorDefaults.edgeInset * 2) * (600f / 3000f)).toPx()
        }
        assertEquals("長さは表示領域とコンテンツの比に沿う", expectedLength, barRows.size.toFloat(), 3f)
        // 位置は実際のスクロール量 / 最大のスクロール量 (2400) に比例する。ドラッグの距離からは
        // タッチの閾値の分が差し引かれるため、スクロール量は項目の位置から実測する。
        val scrolled = itemHeight * 2 - composeTestRule.onNodeWithTag("item-2").getUnclippedBoundsInRoot().top
        val expectedTop = with(composeTestRule.density) {
            val track = (containerHeight - KsScrollIndicatorDefaults.edgeInset * 2).toPx()
            KsScrollIndicatorDefaults.edgeInset.toPx() + (track - expectedLength) * (scrolled / (itemHeight * 24))
        }
        assertEquals("位置はスクロール量に比例する", expectedTop, barRows.first().toFloat(), 2f)
        releaseWithoutFling()
    }

    /**
     * 上下に contentPadding があっても、末尾まで送るとバーは下端に、先頭へ戻すと上端に届く。
     *
     * 余白は、末尾まで送ったときに上側の余白の領域に前の行が残る値 (上 50 / 下 60、項目の高さ 100)
     * にする。この条件では、公式のスクロール量をそのまま使うと末尾で 1 行分手前に止まる。
     */
    @Test
    fun indicatorReachesBothEndsWithContentPadding() {
        setScrollableContent(itemCount = 30, contentPadding = PaddingValues(top = 50.dp, bottom = 60.dp))
        composeTestRule.mainClock.autoAdvance = false
        val inset = with(composeTestRule.density) { KsScrollIndicatorDefaults.edgeInset.roundToPx() }

        dragWithoutRelease(distance = 4000.dp)
        composeTestRule.onNodeWithTag("item-29").assertExists()
        val atEnd = barRows(collectionPixels())
        assertEquals("末尾ではバーの下端が下端から決まった距離に届く", (collectionPixels().height - inset - 1).toFloat(), atEnd.last().toFloat(), 1f)
        releaseWithoutFling()

        dragWithoutRelease(distance = (-4000).dp)
        val atStart = barRows(collectionPixels())
        assertEquals("先頭ではバーの上端が上端から決まった距離に届く", inset.toFloat(), atStart.first().toFloat(), 1f)
        releaseWithoutFling()
    }

    /**
     * 上下に contentPadding があっても、先へ送る間にバーの位置が逆戻りしない。
     *
     * 上側の余白の領域に前の行が見えている間に位置が 1 行分戻る食い違いを捕まえるため、
     * 項目の高さより細かい刻みで送り、刻みごとの位置を確かめる。余白の合計は項目の高さと
     * 異なる値にし、余白の分を一律に差し引くだけの補正でも逆戻りが残る条件にする。
     */
    @Test
    fun indicatorDoesNotMoveBackwardWithContentPadding() {
        setScrollableContent(itemCount = 30, contentPadding = PaddingValues(top = 30.dp, bottom = 40.dp))
        assertBarNeverMovesBackwardWhileDragging()
    }

    /**
     * 3 列のグリッドに全幅の header を置いた構成でも、上下に contentPadding があるとき先へ送る間に
     * バーの位置が逆戻りしない。
     *
     * 1 行に複数の項目が並び、header (高さ 60) が項目の行 (高さ 100) と異なる高さで行 0 を占める。
     * 位置の補正が項目の数ではなく行の間の距離で働くことを、header と項目の行が上側の余白の
     * 領域に残る区間を含めて確かめる。
     */
    @Test
    fun indicatorDoesNotMoveBackwardInGridWithHeaderAndContentPadding() {
        setScrollableContent(
            itemCount = 90,
            contentPadding = PaddingValues(top = 30.dp, bottom = 40.dp),
            layout = KsLayout.Grid(columns = KsColumns.Fixed(3)),
            headerHeight = 60.dp,
        )
        assertBarNeverMovesBackwardWhileDragging()
    }

    /** 項目の高さより細かい刻みで上へドラッグし、刻みごとにバーの上端が逆戻りしないことを確かめる。 */
    private fun assertBarNeverMovesBackwardWhileDragging() {
        composeTestRule.mainClock.autoAdvance = false
        val stepPx = with(composeTestRule.density) { 20.dp.toPx() }

        composeTestRule.onNodeWithTag(CollectionTag).performTouchInput {
            down(center)
            // タッチの閾値を越えてドラッグを始める。
            repeat(5) { moveBy(Offset(0f, -stepPx), delayMillis = 16) }
        }
        composeTestRule.mainClock.advanceTimeByFrame()
        composeTestRule.waitForIdle()
        val tops = mutableListOf(barRows(collectionPixels()).first())
        repeat(40) {
            composeTestRule.onNodeWithTag(CollectionTag).performTouchInput {
                moveBy(Offset(0f, -stepPx), delayMillis = 16)
            }
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            tops += barRows(collectionPixels()).first()
        }
        tops.zipWithNext().forEachIndexed { i, (before, after) ->
            assertTrue("刻み $i で位置が逆戻りした ($before → $after、全体 $tops)", after >= before)
        }
        assertTrue("先へ進んでいる (全体 $tops)", tops.last() > tops.first())
        releaseWithoutFling()
    }

    /** ドラッグから続く慣性スクロールの間は、指を離してから時間が経っても表示を保つ。 */
    @Test
    fun indicatorStaysShownDuringFlingAfterDrag() {
        setScrollableContent(itemCount = 300)
        composeTestRule.mainClock.autoAdvance = false

        composeTestRule.onNodeWithTag(CollectionTag).performTouchInput {
            swipeUp(startY = bottom - 10f, endY = centerY, durationMillis = 80)
        }
        composeTestRule.mainClock.advanceTimeByFrame()
        composeTestRule.waitForIdle()

        advanceTimeBy(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS + 100)
        val first = barRows(collectionPixels()).first()
        assertEquals("指を離して消える時間を過ぎても、慣性スクロール中は表示したまま", 1f, indicatorAlpha(), AlphaTolerance)
        advanceTimeBy(100)
        val second = barRows(collectionPixels()).first()
        assertTrue("この時点でまだ慣性スクロールが続いている ($first → $second)", second > first)

        // 慣性スクロールが止まった後は、所定の時間の後に消える。
        val deadline = System.nanoTime() + 30_000_000_000L
        var previous = second
        var stillFrames = 0
        while (stillFrames < 3) {
            if (System.nanoTime() > deadline) fail("慣性スクロールが止まらない (位置 $previous)")
            advanceTimeBy(100)
            val rows = barRows(collectionPixels())
            val top = rows.firstOrNull() ?: break
            stillFrames = if (top == previous) stillFrames + 1 else 0
            previous = top
        }
        advanceTimeBy(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS + KsScrollIndicatorDefaults.FADE_OUT_MILLIS + 100L)
        assertEquals("止まった後は消える", 0f, indicatorAlpha(), AlphaTolerance)
    }

    /** 先頭では上端から、末尾では下端から決まった距離の位置に描き、長さは表示領域とコンテンツの比に沿う。 */
    @Test
    fun boundsReachBothEndsOfTrack() {
        val size = Size(300f, 600f)
        val top = ksScrollIndicatorBounds(size, 0, 3000, 600, LayoutDirection.Ltr, 3f, 3f, 36f)
        val bottom = ksScrollIndicatorBounds(size, 2400, 3000, 600, LayoutDirection.Ltr, 3f, 3f, 36f)
        assertNotNull(top)
        assertNotNull(bottom)
        assertEquals("先頭では上端から距離を空けた位置", 3f, top!!.top, 0.01f)
        assertEquals("末尾では下端から距離を空けた位置", 597f, bottom!!.bottom, 0.01f)
        assertEquals("長さは (全高 − 上下の距離) × 表示領域 / コンテンツ", 594f * 600f / 3000f, top.height, 0.01f)
        assertEquals("末尾側の端から距離を空けた位置", 294f, top.left, 0.01f)
        assertEquals("太さ", 3f, top.width, 0.01f)
    }

    /** コンテンツが非常に長いときも、バーは最短の長さより短くならない。 */
    @Test
    fun boundsRespectMinimumLength() {
        val bounds = ksScrollIndicatorBounds(Size(300f, 600f), 500_000, 1_000_000, 600, LayoutDirection.Ltr, 3f, 3f, 36f)
        assertEquals(36f, bounds!!.height, 0.01f)
        assertEquals("最短の長さでも中央の位置に描く", 3f + (594f - 36f) * 0.5f, bounds.top, 0.5f)
    }

    /** コンテンツが表示領域に収まるときは描くものが無い。 */
    @Test
    fun boundsAreNullWhenContentFits() {
        assertNull(ksScrollIndicatorBounds(Size(300f, 600f), 0, 600, 600, LayoutDirection.Ltr, 3f, 3f, 36f))
        assertNull(ksScrollIndicatorBounds(Size(300f, 600f), 0, 300, 600, LayoutDirection.Ltr, 3f, 3f, 36f))
    }

    /** 右から左へのレイアウトでは末尾側 (左端) に描く。 */
    @Test
    fun boundsFollowLayoutDirection() {
        val bounds = ksScrollIndicatorBounds(Size(300f, 600f), 0, 3000, 600, LayoutDirection.Rtl, 3f, 3f, 36f)
        assertEquals(3f, bounds!!.left, 0.01f)
    }

    // ---- 色 ----

    /** ライトモードでは黒 35%、ダークモードでは白 50% で描く。 */
    @Test
    fun colorFollowsDarkTheme() {
        assertEquals(Color.Black.copy(alpha = 0.35f), KsScrollIndicatorDefaults.color(isDarkTheme = false))
        assertEquals(Color.White.copy(alpha = 0.5f), KsScrollIndicatorDefaults.color(isDarkTheme = true))
    }

    /** ダークモードの端末ではダークモードの色で描かれる。 */
    @Test
    fun indicatorUsesDarkColorInNightMode() {
        RuntimeEnvironment.setQualifiers("+night")
        setScrollableContent(itemCount = 30, backgroundColor = Color.Black)
        composeTestRule.mainClock.autoAdvance = false

        dragWithoutRelease()
        val pixel = barPixel()
        // 黒の背景に白 50% を重ねると、各成分がおよそ 0.5 になる。
        assertEquals("ダークモードの色 (実測 $pixel)", 0.5f, pixel.red, 0.03f)
        releaseWithoutFling()
    }

    // ---- 補助 ----

    private fun setScrollableContent(
        itemCount: Int,
        controller: KsScrollController? = null,
        backgroundColor: Color = background,
        contentPadding: PaddingValues = PaddingValues(0.dp),
        layout: KsLayout = KsLayout.List,
        headerHeight: Dp? = null,
    ) {
        composeTestRule.setContent {
            TestContainer(width = containerWidth, height = containerHeight) {
                KsCollectionView(
                    items = testItems(itemCount),
                    key = { it.id },
                    modifier = Modifier.background(backgroundColor).testTag(CollectionTag),
                    listSeparators = false,
                    scrollController = controller,
                    contentPadding = contentPadding,
                    layout = layout,
                    header = headerHeight?.let { height -> { Box(Modifier.fillMaxWidth().height(height)) } },
                ) {
                    template { item -> Box(Modifier.fillMaxWidth().height(itemHeight).testTag(item.id)) }
                }
            }
        }
        composeTestRule.waitForIdle()
    }

    /** 指を置いたまま上へドラッグする (コンテンツは下へ進む)。負の距離では下へドラッグする。 */
    private fun dragWithoutRelease(distance: Dp = 150.dp) {
        val distancePx = with(composeTestRule.density) { distance.toPx() }
        composeTestRule.onNodeWithTag(CollectionTag).performTouchInput {
            down(center)
            repeat(DragSteps) { moveBy(Offset(0f, -distancePx / DragSteps), delayMillis = 16) }
        }
        composeTestRule.mainClock.advanceTimeByFrame()
        composeTestRule.waitForIdle()
    }

    /** 指を止めてから離し、慣性スクロールを起こさずにスクロールを終える。 */
    private fun releaseWithoutFling() {
        composeTestRule.onNodeWithTag(CollectionTag).performTouchInput {
            // 速度の見積もりから動いていた区間を外すため、同じ位置に留まってから離す。
            repeat(10) { moveBy(Offset.Zero, delayMillis = 16) }
            up()
        }
        composeTestRule.mainClock.advanceTimeByFrame()
        composeTestRule.waitForIdle()
    }

    private fun advanceTimeBy(millis: Long) {
        composeTestRule.mainClock.advanceTimeBy(millis)
        composeTestRule.waitForIdle()
    }

    private fun collectionPixels(): PixelMap = composeTestRule.onNodeWithTag(CollectionTag).readPixels()

    /** バーの太さの中央の列で、背景から最も離れた画素。 */
    private fun barPixel(): Color {
        val image = collectionPixels()
        val x = barColumn(image)
        val bg = image[image.width - 1, image.height / 2]
        return (0 until image.height).map { image[x, it] }.maxBy { distance(it, bg) }
    }

    /**
     * バーの濃さの推定値。白の背景に黒 35% を重ねた画素の暗さを 1 とした比。
     *
     * フェードの途中は濃さに比例して背景へ近づくため、中間の値になる。
     */
    private fun indicatorAlpha(): Float {
        val pixel = barPixel()
        val fullDarkness = KsScrollIndicatorDefaults.lightColor.alpha
        return ((background.red - pixel.red) / fullDarkness).coerceIn(0f, 1f)
    }

    private fun barColumn(image: PixelMap): Int {
        val (thickness, inset) = with(composeTestRule.density) {
            KsScrollIndicatorDefaults.thickness.roundToPx() to KsScrollIndicatorDefaults.edgeInset.roundToPx()
        }
        return image.width - inset - thickness / 2 - 1
    }

    /** バーの太さの中央の列で、バーが描かれている行の一覧 (上から順)。 */
    private fun barRows(image: PixelMap): List<Int> {
        val x = barColumn(image)
        return (0 until image.height).filter { y -> isBarPixel(image[x, y]) }
    }

    private fun isBarPixel(pixel: Color): Boolean = distance(pixel, background) > 0.05f

    private fun distance(a: Color, b: Color): Float =
        maxOf(kotlin.math.abs(a.red - b.red), kotlin.math.abs(a.green - b.green), kotlin.math.abs(a.blue - b.blue))

    private companion object {
        const val CollectionTag = "collection"
        const val DragSteps = 10

        /** 画素の量子化と色空間の丸めを吸収する許容差。 */
        const val AlphaTolerance = 0.05f
    }
}

/** 指定した節点の描画結果を画素として読む。 */
private fun SemanticsNodeInteraction.readPixels(): PixelMap {
    val node = fetchSemanticsNode()
    val view = (node.root as ViewRootForTest).view
    val whole = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
    view.draw(Canvas(whole))
    val bounds = node.boundsInRoot
    val left = bounds.left.toInt()
    val top = bounds.top.toInt()
    val width = bounds.width.toInt().coerceAtMost(view.width - left)
    val height = bounds.height.toInt().coerceAtMost(view.height - top)
    return Bitmap.createBitmap(whole, left, top, width, height).asImageBitmap().toPixelMap()
}
