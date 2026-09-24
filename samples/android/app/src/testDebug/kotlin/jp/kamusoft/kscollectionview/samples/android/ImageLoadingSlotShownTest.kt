package jp.kamusoft.kscollectionview.samples.android

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.InternalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowLog

/**
 * 読み込み中の表示の「組み立て」と「画面に出た」を分けて数えられることを確かめる。
 *
 * 本体の画像表示は、画面に出る前に組み立てた画像について読み込み中の表示を中身として組み立てて
 * おき、画面に置かれた時点で先読みの項目に当たれば中身を描かずに画像を描く。遅延グリッドは画面外の
 * アイテムを測るだけで置かないこともある。どちらも組み立ての回数 (`sized`) には数えられるが、
 * 画面には出ていないので `shown` に数えてはいけない。ここではその 2 つの形 (親が中身を描かない・
 * 測るだけで置かない) と、画面外に置かれて描かれてから見える位置へ来る形を、本体の構造と同じ
 * 形の親で再現して固定する。
 *
 * 描画の有無を見るため、実描画を行う設定で動かす。描画は View を直接描いて確実に走らせる。
 *
 * 計数の実体 (`src/counterEnabled`) と計測用の画面 (`src/measurement`) を前提にするため、
 * debug 専用の `src/testDebug` に置く。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageLoadingSlotShownTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Before
    fun startCounting() {
        ImageLoadingSlotCounter.reset()
        ImageLoadingSlotCounter.setEnabled(true)
        ShadowLog.clear()
    }

    @After
    fun stopCounting() {
        ImageLoadingSlotCounter.setEnabled(false)
    }

    /** 置かれて描かれた読み込み中は、組み立てと画面に出た回数の両方に数える。 */
    @Test
    fun `画面に出て描かれた読み込み中は shown に数える`() {
        composeTestRule.setContent {
            Box(modifier = Modifier.size(CellSide)) { CountedSlot(itemId = 1) }
        }
        drawFrame()

        val tally = awaitTally(itemId = 1) { it.shown >= 1 }
        assertTrue("組み立てが数えられていません: $tally", tally.sized >= 1)
        assertEquals("1 つの表示で画面に出た回数が 1 回ではありません", 1L, tally.shown)

        // 描き直しても同じ表示は数え直さない。
        drawFrame()
        assertEquals(1L, ImageLoadingSlotCounter.tally(1).shown)
    }

    /**
     * 置かれても親が中身を描かなければ、画面に出たとは数えない。
     *
     * 本体が画面に出る時点で先読みの項目に当たったときの形 (読み込み中を中身として組み立てて
     * 置くが、中身を描かずに画像を描く) と同じ。
     */
    @Test
    fun `画面に出る時点で先読みに当たり描かれなかった読み込み中は shown に数えない`() {
        composeTestRule.setContent {
            Box(
                modifier = Modifier
                    .size(CellSide)
                    // 中身 (読み込み中) を描かず、代わりに引き当てた画像を描く親の代役。
                    .drawWithContent { },
            ) {
                CountedSlot(itemId = 2)
            }
        }
        drawFrame()

        val tally = awaitTally(itemId = 2) { it.sized >= 1 }
        drawFrame()
        composeTestRule.waitForIdle()
        assertEquals(
            "描かれていない読み込み中が画面に出たと数えられました: ${ImageLoadingSlotCounter.tally(2)}",
            0L,
            ImageLoadingSlotCounter.tally(2).shown,
        )
        assertTrue(tally.sized >= 1)
    }

    /** 測るだけで置かれない読み込み中 (画面外の先行合成) は、画面に出たとは数えない。 */
    @Test
    fun `測るだけで置かれない読み込み中は shown に数えない`() {
        composeTestRule.setContent {
            // 子を測るが置かない親。遅延グリッドが画面外のアイテムを先に組み立てて測る形の代役。
            Layout(
                content = { Box(modifier = Modifier.size(CellSide)) { CountedSlot(itemId = 3) } },
                modifier = Modifier.size(CellSide),
            ) { measurables, constraints ->
                measurables.forEach { it.measure(constraints) }
                layout(constraints.maxWidth, constraints.maxHeight) {}
            }
        }
        drawFrame()

        awaitTally(itemId = 3) { it.sized >= 1 }
        drawFrame()
        composeTestRule.waitForIdle()
        assertEquals(0L, ImageLoadingSlotCounter.tally(3).shown)
    }

    /**
     * 画面外に置かれて描かれた読み込み中は、見える位置に来た時点で 1 回数える。
     *
     * 見える範囲に掛かる前は数えない。見える位置へ来た後は、描き直しが無くても位置の変化で数える。
     */
    @Test
    fun `画面外で描かれた読み込み中は見える位置に来た時点で数える`() {
        var offset by mutableStateOf(OutsideOffset)
        composeTestRule.setContent {
            Box(modifier = Modifier.size(CellSide).clipToBounds()) {
                Box(modifier = Modifier.offset(y = offset).size(CellSide)) { CountedSlot(itemId = 4) }
            }
        }
        drawFrame()
        awaitTally(itemId = 4) { it.sized >= 1 }
        assertEquals("見える範囲の外で数えられました", 0L, ImageLoadingSlotCounter.tally(4).shown)

        offset = 0.dp
        composeTestRule.waitForIdle()
        drawFrame()

        assertEquals(1L, awaitTally(itemId = 4) { it.shown >= 1 }.shown)
    }

    /** 画面に出た行は、組み立ての行と先頭の語で分かれ、iOS Sample と同じ書式で出る。 */
    @Test
    fun `画面に出た行は組み立ての行と分けて出す`() {
        ImageLoadingSlotCounter.record(itemId = 7, width = 240, height = 240)
        ImageLoadingSlotCounter.recordShown(itemId = 7, width = 240, height = 240)
        ImageLoadingSlotCounter.beginSession()
        ImageLoadingSlotCounter.recordShown(itemId = 7, width = 240, height = 240)

        val lines = ShadowLog.getLogsForTag(ImageLoadingSlotTag).map { it.msg }
        assertEquals(
            listOf(
                "loading session=0 item=7 size=240x240 sized=1 unsized=0 total=1/0",
                "shown session=0 item=7 size=240x240 shown=1 total=1",
                "shown session=1 item=7 size=240x240 shown=1 total=2",
            ),
            lines,
        )
        assertEquals(ImageLoadingSlotTally(shown = 1), ImageLoadingSlotCounter.delta(7))
    }

    /** 画面に出た回数は印の書式に入れない。印は iOS Sample と同じ書式 (組み立ての回数) のまま。 */
    @Test
    fun `画面に出た回数は印の書式を変えない`() {
        ImageLoadingSlotCounter.record(itemId = 1, width = 240, height = 240)
        ImageLoadingSlotCounter.recordShown(itemId = 1, width = 240, height = 240)

        assertEquals(
            "slots session=0 items=1 sized=1 unsized=0 lines=1 total=1/0/1 1:1/0",
            imageLoadingSlotSummary(
                session = ImageLoadingSlotCounter.session,
                delta = ImageLoadingSlotCounter.deltaSnapshot(),
                total = ImageLoadingSlotCounter.snapshot(),
            ),
        )
    }

    /** 観測用の画面の読み込み中の表示は、組み立てと画面に出た時点を別の行で出す。 */
    @Test
    fun `観測用の画面は組み立てと画面に出た時点を別の行で出す`() {
        composeTestRule.setContent {
            // 並べて置き、どちらも見える範囲に掛かるようにする。
            Row {
                Box(modifier = Modifier.size(CellSide)) { ObservedLoadingSlot(itemId = 5, inner = null) }
                // 中身を描かない親の下では、組み立ての行だけが出る。
                Box(modifier = Modifier.size(CellSide).drawWithContent { }) {
                    ObservedLoadingSlot(itemId = 6, inner = null)
                }
            }
        }
        drawFrame()

        val lines = awaitObserveLines { lines -> lines.any { it.startsWith("loading-shown id=5 ") } }
        assertTrue(lines.any { it.startsWith("loading-enter id=5 t=") })
        assertTrue(lines.any { it.startsWith("loading-enter id=6 t=") })
        drawFrame()
        composeTestRule.waitForIdle()
        val settled = observeLines()
        assertEquals(1, settled.count { it.startsWith("loading-shown id=5 t=") })
        assertTrue(
            "描かれていない観測用の読み込み中が画面に出たと記録されました: $settled",
            settled.none { it.startsWith("loading-shown id=6 ") },
        )
    }

    /** 数えることを要求した実行と同じ、数える読み込み中の表示を置く。 */
    @Composable
    private fun CountedSlot(itemId: Int) {
        val slot = ImageLoadingSlotCounter.rememberLoadingSlot(itemId)
        checkNotNull(slot) { "数える実行なのに読み込み中の表示が渡されませんでした" }.invoke()
    }

    /**
     * View を直接描いて、描画を 1 回走らせる。
     *
     * 画面の取り込み (`captureToImage`) は描画完了の待ち方が Robolectric に対応しておらず制限時間で
     * 失敗するため、待ちを挟まない同期の描画で代える。
     */
    @OptIn(InternalComposeUiApi::class)
    private fun drawFrame() {
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread {
            val view = (composeTestRule.onRoot().fetchSemanticsNode().root as ViewRootForTest).view
            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(bitmap))
        }
    }

    private fun observeLines(): List<String> =
        ShadowLog.getLogsForTag(ImageLoadingObserveTag).map { it.msg }

    /**
     * 計数が条件を満たすまで待つ。上限は実時間で区切り、超えたら実測値を添えて失敗させる。
     *
     * @param itemId 対象の要素の識別子
     * @param condition 待つ条件
     */
    private fun awaitTally(
        itemId: Any,
        condition: (ImageLoadingSlotTally) -> Boolean,
    ): ImageLoadingSlotTally {
        val deadline = System.nanoTime() + TimeoutMillis * 1_000_000L
        while (!condition(ImageLoadingSlotCounter.tally(itemId))) {
            if (System.nanoTime() > deadline) {
                throw AssertionError(
                    "計数が条件を満たしませんでした (最後に読めた計数: ${ImageLoadingSlotCounter.tally(itemId)})",
                )
            }
            composeTestRule.waitForIdle()
            // 待機対象へ実行機会を譲る。ヒントに留まる譲り方では譲れる保証がない。
            Thread.sleep(1)
        }
        return ImageLoadingSlotCounter.tally(itemId)
    }

    /**
     * 観測の行が条件を満たすまで待つ。上限は実時間で区切り、超えたら実測値を添えて失敗させる。
     *
     * @param condition 待つ条件
     */
    private fun awaitObserveLines(condition: (List<String>) -> Boolean): List<String> {
        val deadline = System.nanoTime() + TimeoutMillis * 1_000_000L
        while (!condition(observeLines())) {
            if (System.nanoTime() > deadline) {
                throw AssertionError("観測の行が条件を満たしませんでした (最後に読めた行: ${observeLines()})")
            }
            composeTestRule.waitForIdle()
            Thread.sleep(1)
        }
        return observeLines()
    }

    private companion object {
        /** 表示枠の一辺。枠が決まった状態で組み立てるための値。 */
        val CellSide = 120.dp

        /** 見える範囲の外へ置くためのずらし量。枠の一辺より大きくする。 */
        val OutsideOffset = 400.dp

        /** 条件が満たされるのを待つ上限。 */
        const val TimeoutMillis = 5_000L
    }
}
