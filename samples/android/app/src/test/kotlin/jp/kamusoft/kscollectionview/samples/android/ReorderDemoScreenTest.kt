package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 「並べ替え」画面の初期の表示・操作の切り替え・長押しの帯を確かめる。
 *
 * 操作の順と出る表示は iOS Sample の同じ画面の UI テストと同じ筋にする。ドラッグでの並べ替えそのものは
 * ライブラリの結合テストと iOS Sample の UI テストが確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class ReorderDemoScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun count(text: String, substring: Boolean = false): Int =
        composeTestRule.onAllNodes(hasText(text, substring = substring)).fetchSemanticsNodes().size

    /**
     * 文言 [text] の要素の数が [expected] になるまで、コンポジションとフレームを進めて待つ。時間切れなら、
     * そのとき数えた数を添えて失敗させる。
     */
    private fun waitForCount(text: String, expected: Int, timeoutMillis: Long = 5_000) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (System.currentTimeMillis() < deadline) {
            composeTestRule.waitForIdle()
            if (count(text) == expected) return
            composeTestRule.mainClock.advanceTimeByFrame()
            Thread.sleep(1)
        }
        fail("「$text」が ${timeoutMillis}ms 以内に $expected 個にならなかった (いま ${count(text)} 個)")
    }

    /** 項目を長押しする (指を動かさずに離す)。 */
    private fun longPress(text: String) {
        composeTestRule.onNodeWithText(text).performTouchInput { longClick() }
        composeTestRule.waitForIdle()
    }

    @Test
    fun `開くとグループ 1 の見出しと Item 1 から並び 切り替えは並べ替えとグループだけがオン`() {
        composeTestRule.setContent { ReorderDemoScreen() }

        composeTestRule.onNodeWithText("グループ 1").assertIsDisplayed()
        composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()
        composeTestRule.onNodeWithText("Item 10 (移動不可)").assertIsDisplayed()
        composeTestRule.onNodeWithText(ReorderDemoText.Summary).assertIsDisplayed()
        composeTestRule.onNodeWithText(ReorderDemoText.Reorder).assertIsOn()
        composeTestRule.onNodeWithText(ReorderDemoText.Grouped).assertIsOn()
        composeTestRule.onNodeWithText(ReorderDemoText.KeepsGroups).assertIsOff()
        composeTestRule.onNodeWithText(ReorderDemoText.RejectsMoves).assertIsOff()
        // 1 行目の順は Item 1, 2, 3。
        val tops = (1..3).map { composeTestRule.onNodeWithText("Item $it").getUnclippedBoundsInRoot().top }
        assertEquals(tops.sorted(), tops)
    }

    @Test
    fun `並べ替えのスイッチを切って長押しすると 長押し Item 5 の帯が出て 3 秒で消える`() {
        composeTestRule.setContent { ReorderDemoScreen() }

        composeTestRule.onNodeWithText(ReorderDemoText.Reorder).performClick()
        composeTestRule.onNodeWithText(ReorderDemoText.Reorder).assertIsOff()
        longPress("Item 5")

        waitForCount("長押し: Item 5", 1)
        // 帯は操作のパネルより上 (画面の上寄り) に出る。
        val banner = composeTestRule.onNodeWithText("長押し: Item 5").getUnclippedBoundsInRoot()
        val summary = composeTestRule.onNodeWithText(ReorderDemoText.Summary).getUnclippedBoundsInRoot()
        assertTrue("帯 $banner がパネル $summary より上に無い", banner.bottom < summary.top)

        composeTestRule.mainClock.advanceTimeBy(SamplePanelMetrics.BannerDurationMillis + 1_000)
        waitForCount("長押し: Item 5", 0)
    }

    @Test
    fun `並べ替えのスイッチがオンの間は長押ししても帯が出ない`() {
        composeTestRule.setContent { ReorderDemoScreen() }

        longPress("Item 5")
        repeat(10) { composeTestRule.mainClock.advanceTimeByFrame() }
        composeTestRule.waitForIdle()

        assertEquals(0, count("長押し:", substring = true))
        assertEquals(1, count("Item 5"))
    }

    @Test
    fun `グループをオフにすると見出しが消え グリッドに切り替えても項目が並ぶ`() {
        composeTestRule.setContent { ReorderDemoScreen() }

        composeTestRule.onNodeWithText(ReorderDemoText.Grouped).performClick()
        waitForCount("グループ 1", 0)
        composeTestRule.onNodeWithText("グリッド").performClick()
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()
        val one = composeTestRule.onNodeWithText("Item 1").getUnclippedBoundsInRoot()
        val two = composeTestRule.onNodeWithText("Item 2").getUnclippedBoundsInRoot()
        assertEquals("2 列のグリッドで Item 1 と Item 2 が同じ行にない", one.top, two.top)
    }

    @Test
    fun `操作を畳むと丸いボタンだけが残り 広げると切り替えの状態が戻る`() {
        composeTestRule.setContent { ReorderDemoScreen() }
        composeTestRule.onNodeWithText(ReorderDemoText.RejectsMoves).performClick()

        composeTestRule.onNodeWithContentDescription(SamplePanelText.Fold).performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithContentDescription(SamplePanelText.Unfold).assertIsDisplayed()
        assertEquals(0, count(ReorderDemoText.Summary))

        composeTestRule.onNodeWithContentDescription(SamplePanelText.Unfold).performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText(ReorderDemoText.RejectsMoves).assertIsOn()
    }

    @Test
    fun `切り替えと表示の形は保存と復元をまたいで残る`() {
        val restorationTester = StateRestorationTester(composeTestRule)
        restorationTester.setContent { ReorderDemoScreen() }
        composeTestRule.onNodeWithText(ReorderDemoText.KeepsGroups).performClick()
        composeTestRule.onNodeWithText("グリッド").performClick()
        composeTestRule.waitForIdle()

        restorationTester.emulateSavedInstanceStateRestore()

        composeTestRule.onNodeWithText(ReorderDemoText.KeepsGroups).assertIsOn()
        val one = composeTestRule.onNodeWithText("Item 1").getUnclippedBoundsInRoot()
        val two = composeTestRule.onNodeWithText("Item 2").getUnclippedBoundsInRoot()
        assertEquals("復元後にグリッドになっていない", one.top, two.top)
    }
}
