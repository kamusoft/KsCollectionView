package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 読み込み中の表示を経由した回数が、デモ画面と同じセルから実際に数えられることを確かめる。
 *
 * 「読み込み中を経由していない」を実機で判定するための道具なので、道具そのものが数を出すこと
 * (出ないときに 0 と区別できること) をここで固定する。セルは計測用の別物ではなく、デモ画面が
 * 使うのと同じ [ImageGridCell] を描いて確かめる。
 *
 * あわせて、数えることを要求していない実行では差し込みが起きず本体の既定の表示に戻ることも
 * 固定する。ここが崩れると、読み込み中の既定の表示を観測点に持つ検証画面が本体の既定を
 * 通らなくなる。
 *
 * 計数の実体 (`src/counterEnabled`) を前提にするため、debug 専用の `src/testDebug` に置く。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class ImageLoadingSlotCounterTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Before
    fun startCounting() {
        ImageLoadingSlotCounter.reset()
        ImageLoadingSlotCounter.setEnabled(true)
    }

    @After
    fun stopCounting() {
        ImageLoadingSlotCounter.setEnabled(false)
    }

    /** セルを描くと、その要素の読み込み中が枠の決まった状態で数えられる。 */
    @Test
    fun `セルを描くと読み込み中を経由した回数が要素ごとに数えられる`() {
        composeTestRule.setContent {
            Box(modifier = Modifier.size(CellSide)) {
                ImageGridCell(item = DemoItem(id = 1, title = "#1"))
            }
        }

        // 反映は再コンポジションをまたぐため、実時間の上限つきで条件が満たされるのを待つ。
        val observed = awaitSizedTally(itemId = 1)
        assertTrue(
            "読み込み中を経由した回数が数えられていません (最後に読めた計数: $observed)",
            observed.sized >= 1,
        )
        // 描いていない要素は 0 件のまま。要素をまたいで数が混ざると判定に使えない。
        assertEquals(ImageLoadingSlotTally(), ImageLoadingSlotCounter.tally(2))
    }

    /** 数えることを要求していないときは差し込まず、本体の既定の表示に任せる。 */
    @Test
    fun `数えない実行では読み込み中の表示を差し込まない`() {
        ImageLoadingSlotCounter.setEnabled(false)
        val slots = mutableListOf<(@Composable () -> Unit)?>()

        composeTestRule.setContent {
            // セルが本体へ渡すのと同じ呼び出しで、渡すものが無い (= 本体の既定) ことを見る。
            slots += ImageLoadingSlotCounter.rememberLoadingSlot(1)
            Box(modifier = Modifier.size(CellSide)) {
                ImageGridCell(item = DemoItem(id = 1, title = "#1"))
            }
        }
        composeTestRule.waitForIdle()

        assertTrue("読み込み中の表示の受け渡しが 1 度も起きていません", slots.isNotEmpty())
        assertNull("数えない実行で読み込み中の表示が差し込まれました", slots.last())
        assertEquals(
            "数えない実行で計数が入りました",
            ImageLoadingSlotTally(),
            ImageLoadingSlotCounter.tally(1),
        )
    }

    /** 表示枠が決まる前の読み込み中は、判定に使う側と分けて数える。 */
    @Test
    fun `表示枠が決まる前の読み込み中は別に数える`() {
        ImageLoadingSlotCounter.record(itemId = 9, width = 0, height = 0)
        ImageLoadingSlotCounter.record(itemId = 9, width = 240, height = 240)
        ImageLoadingSlotCounter.record(itemId = 9, width = 240, height = 0)

        assertEquals(
            ImageLoadingSlotTally(sized = 1, unsized = 2),
            ImageLoadingSlotCounter.tally(9),
        )
    }

    /** 計数を 0 に戻せる。戻せないと、測り始めの状態を作れない。 */
    @Test
    fun `計数は 0 に戻せる`() {
        ImageLoadingSlotCounter.record(itemId = 3, width = 240, height = 240)
        ImageLoadingSlotCounter.beginSession()
        ImageLoadingSlotCounter.reset()

        assertEquals(ImageLoadingSlotTally(), ImageLoadingSlotCounter.tally(3))
        assertEquals(emptyMap<Any, ImageLoadingSlotTally>(), ImageLoadingSlotCounter.snapshot())
        assertEquals(0, ImageLoadingSlotCounter.session)
    }

    /**
     * 観測区間を切ると、そこから先の差分が 0 から始まる。
     *
     * 判定規則が「基準点からの差分 `Δsized` が 0」である以上、切り直しで 0 に戻らなければ
     * 初回表示で数えた分がそのまま不合格の材料になってしまう。
     */
    @Test
    fun `区間を切ると差分は 0 から始まる`() {
        ImageLoadingSlotCounter.record(itemId = 5, width = 240, height = 240)
        ImageLoadingSlotCounter.record(itemId = 5, width = 0, height = 0)

        ImageLoadingSlotCounter.beginSession()

        assertEquals(1, ImageLoadingSlotCounter.session)
        assertEquals(ImageLoadingSlotTally(), ImageLoadingSlotCounter.delta(5))
        // 累計は残る。基準点の前後を突き合わせるために消してはいけない。
        assertEquals(
            ImageLoadingSlotTally(sized = 1, unsized = 1),
            ImageLoadingSlotCounter.tally(5),
        )

        ImageLoadingSlotCounter.record(itemId = 5, width = 240, height = 240)

        assertEquals(ImageLoadingSlotTally(sized = 1), ImageLoadingSlotCounter.delta(5))
        assertEquals(
            ImageLoadingSlotTally(sized = 2, unsized = 1),
            ImageLoadingSlotCounter.tally(5),
        )
    }

    /**
     * 区間を切る前に数えた分は、印の差分側に混ざらない。
     *
     * 混ざると「戻ってきたときに読み込み中を経由したか」を初回表示と区別できなくなる。切る前に
     * 数えられていた要素は差分 0 として残り、経由していないことの証跡になる。
     */
    @Test
    fun `区間を切る前の値は差分に混ざらない`() {
        ImageLoadingSlotCounter.record(itemId = 1, width = 240, height = 240)
        ImageLoadingSlotCounter.record(itemId = 2, width = 240, height = 240)

        ImageLoadingSlotCounter.beginSession()
        ImageLoadingSlotCounter.record(itemId = 2, width = 240, height = 240)

        // 内訳は差分の大きい順なので、切る前だけ数えた要素 1 は差分が出た要素 2 より後に来る。
        assertEquals(
            "slots session=1 items=2 sized=1 unsized=0 lines=1 total=3/0/3 2:1/0 1:0/0",
            imageLoadingSlotSummary(
                session = ImageLoadingSlotCounter.session,
                delta = ImageLoadingSlotCounter.deltaSnapshot(),
                total = ImageLoadingSlotCounter.snapshot(),
            ),
        )
    }

    /**
     * 画面の印は、ログと突き合わせられる総数と要素ごとの内訳を出す。
     *
     * 内訳の並びは `sized` → `unsized` の降順で、同値のときは識別子を**文字列として**比べる
     * (iOS Sample の印と同じ並びにするため。識別子が数値でも数値順にはしない)。
     */
    @Test
    fun `印は総数と要素ごとの内訳を出す`() {
        ImageLoadingSlotCounter.record(itemId = 1, width = 240, height = 240)
        ImageLoadingSlotCounter.record(itemId = 1, width = 0, height = 0)
        ImageLoadingSlotCounter.record(itemId = 2, width = 240, height = 240)
        ImageLoadingSlotCounter.record(itemId = 10, width = 240, height = 240)

        // 基準点を切っていない区間 (session=0) では、差分と累計が一致する。
        assertEquals(
            "slots session=0 items=3 sized=3 unsized=1 lines=4 total=3/1/4 1:1/1 10:1/0 2:1/0",
            imageLoadingSlotSummary(
                session = ImageLoadingSlotCounter.session,
                delta = ImageLoadingSlotCounter.deltaSnapshot(),
                total = ImageLoadingSlotCounter.snapshot(),
            ),
        )
    }

    /**
     * 指定した要素の計数が入るまで待つ。
     *
     * 上限は実時間で区切り、超えたらその時点の実測値を添えて失敗させる (待機が足りないのか
     * 数えていないのかを、失敗の表示だけで切り分けられるようにする)。各試行で `waitForIdle()`
     * を呼んで再コンポジションを進める — 条件式だけの待機では反映が進まないことがある
     * (この待機の形は本体の `KsImageTest` の同種ヘルパと同じ)。
     *
     * @param itemId 待つ対象の要素の識別子
     */
    private fun awaitSizedTally(itemId: Any): ImageLoadingSlotTally {
        val deadline = System.nanoTime() + TallyTimeoutMillis * 1_000_000L
        while (ImageLoadingSlotCounter.tally(itemId).sized <= 0) {
            if (System.nanoTime() > deadline) {
                throw AssertionError(
                    "読み込み中の計数が入りませんでした " +
                        "(最後に読めた計数: ${ImageLoadingSlotCounter.tally(itemId)})",
                )
            }
            composeTestRule.waitForIdle()
            // 待機対象へ実行機会を譲る。ヒントに留まる譲り方では譲れる保証がない。
            Thread.sleep(1)
        }
        return ImageLoadingSlotCounter.tally(itemId)
    }

    private companion object {
        /** セルに与える表示枠の一辺。枠が決まった状態で描くための値。 */
        val CellSide = 120.dp

        /** 計数が入るのを待つ上限。 */
        const val TallyTimeoutMillis = 5_000L
    }
}
