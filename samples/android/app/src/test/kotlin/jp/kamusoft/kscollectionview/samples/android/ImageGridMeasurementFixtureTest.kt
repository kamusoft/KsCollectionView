package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 画像の性能計測が、デモ画面「画像グリッド」と同じ土俵で行われることを確かめる。
 *
 * 計測はデモ画面と同じ土俵を測って初めて意味を持つ。土俵が食い違っていてもどちらの画面も
 * 正常に動くため、コンパイラでは守れない。デモ画面と計測用の画面の両方を実際に描いて、
 * 見えるもの (セルの文言) が一致することで守る。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class ImageGridMeasurementFixtureTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 計測用の画面のセルは、デモ画面と同じ「#ID」の文言になる。 */
    @Test
    fun `計測用の画像グリッドはデモ画面と同じ文言のセルを出す`() {
        composeTestRule.setContent {
            ImageGridMeasurementScreen(
                count = DemoData.ImageGridItemCount,
                choice = ImagePrefetchChoice.Disk,
            )
        }

        // デモ画面の同じ位置のセルは「#1」(SampleDemoScreenTest が固定している)。
        composeTestRule.onNodeWithText("#1").assertIsDisplayed()
        composeTestRule.onNodeWithText("#2").assertIsDisplayed()
        // 「大量件数」の土俵の文言が混ざっていないこと。混ざるのは別の生成経路を使った印。
        composeTestRule.onNodeWithText("Item 1").assertDoesNotExist()
    }

    /** 計測用のメモリ往復の画面も同じ土俵を描く。 */
    @Test
    fun `計測用の画像メモリ往復はデモ画面と同じ文言のセルを出す`() {
        composeTestRule.setContent {
            MemoryRoundTripScreen(
                items = ImageGridFixture.items(ScanItemCount),
                maxRoundTrips = 1,
                layout = ImageGridFixture.layout,
                contentPadding = ImageGridFixture.contentPadding,
                prefetchResources = ImageGridFixture.resources(
                    ImagePrefetchChoice.Disk.destination,
                ),
                row = { item -> ImageGridCell(item) },
            )
        }

        composeTestRule.onNodeWithText("#1").assertIsDisplayed()
        composeTestRule.onNodeWithText("Item 1").assertDoesNotExist()
    }

    /** 土俵の要素は ID から決定的に作られ、件数だけが変えられる。 */
    @Test
    fun `土俵の要素は件数だけを変えても内容が変わらない`() {
        val small = ImageGridFixture.items(3)

        assertEquals(listOf("#1", "#2", "#3"), small.map { it.title })
        assertEquals(listOf(1, 2, 3), small.map { it.id })
        // 大きい件数の先頭は、小さい件数と同じ内容になる。
        assertEquals(small, ImageGridFixture.items(10).take(3))
    }

    /** 配置と外周の余白は iOS Sample と同じ値を 1 箇所から配る。 */
    @Test
    fun `土俵の配置と外周の余白は宣言元の値と一致する`() {
        assertEquals(
            KsLayout.Grid(
                columns = KsColumns.Fixed(3),
                rowSpacing = 8.dp,
                columnSpacing = 8.dp,
            ),
            ImageGridFixture.layout,
        )
        assertEquals(PaddingValues(8.dp), ImageGridFixture.contentPadding)
    }

    /** 「なし」の選択では宣言そのものを行わない (空の宣言にしない)。 */
    @Test
    fun `プリフェッチの宣言は到達点を選ばないときだけ無い`() {
        assertEquals(null, ImageGridFixture.resources(ImagePrefetchChoice.None.destination))

        val declared = ImageGridFixture.resources(ImagePrefetchChoice.Disk.destination)
        assertEquals(
            listOf(DemoData.imageUrl(7)),
            declared?.invoke(DemoItem(id = 7, title = "#7")),
        )
    }

    private companion object {
        /** 往復の画面を描くのに使う件数。走査そのものは確かめないため少数でよい。 */
        const val ScanItemCount = 12
    }
}
