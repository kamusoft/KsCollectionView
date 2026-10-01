package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 「ページング」画面の操作と表示の切り替えを、遅延なしの取得元で確かめる。
 *
 * 操作の順と出る表示は iOS Sample の同じ画面の UI テストと同じ筋にする。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class PagingDemoScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /**
     * 文言 [text] の要素が現れるまで、コンポジションとフレームを進めて待つ。時間切れなら、そのとき
     * 見えていた主な文言を添えて失敗させる。一覧の次ページ要求は配置を観測してから起動するため、
     * フレームを進めないと始まらない。
     */
    private fun waitForText(text: String, timeoutMillis: Long = 5_000) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (System.currentTimeMillis() < deadline) {
            composeTestRule.waitForIdle()
            if (composeTestRule.onAllNodesWithTextCount(text) > 0) return
            composeTestRule.mainClock.advanceTimeByFrame()
            Thread.sleep(1)
        }
        val seen = listOf("Item 1", PagingDemoText.Empty, PagingDemoText.LoadFailed, PagingDemoText.RefreshFailed)
            .filter { composeTestRule.onAllNodesWithTextCount(it) > 0 }
        fail("「$text」が ${timeoutMillis}ms 以内に現れなかった。見えていた文言: $seen")
    }

    private fun ComposeContentTestRule.onAllNodesWithTextCount(text: String, substring: Boolean = false): Int =
        onAllNodes(hasText(text, substring = substring)).fetchSemanticsNodes().size

    /**
     * 最初のページが並ぶまで待つ。並んだ後の表示範囲 (先頭から出るか) はここでは問わない
     * (`開いたら最初のページを読み込んで Item 1 から並べる` が確かめる)。
     */
    private fun waitForFirstPage(timeoutMillis: Long = 5_000) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (System.currentTimeMillis() < deadline) {
            composeTestRule.waitForIdle()
            if (composeTestRule.onAllNodesWithTextCount("Item ", substring = true) > 0) return
            composeTestRule.mainClock.advanceTimeByFrame()
            Thread.sleep(1)
        }
        fail("最初のページが ${timeoutMillis}ms 以内に並ばなかった")
    }

    /**
     * 一覧をいちばん後ろ (項目の後ろのフッターの枠) まで送る。
     *
     * @param itemCount いま並んでいる項目の数。フッターの枠はその次の位置にある
     */
    private fun scrollToLast(itemCount: Int) {
        composeTestRule.waitForIdle()
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(itemCount)
        composeTestRule.waitForIdle()
    }

    private fun toggle(text: String): SemanticsNodeInteraction = composeTestRule.onNodeWithText(text)

    @Test
    fun `開いたら最初のページを読み込んで Item 1 から並べる`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }

        waitForText("Item 1")
        composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()
        composeTestRule.onNodeWithText(PagingDemoText.Summary).assertIsDisplayed()
        toggle(PagingDemoText.FailsNextLoad).assertIsOff()
        toggle(PagingDemoText.IsEmpty).assertIsOff()
    }

    @Test
    fun `中身を 0 件にすると項目の代わりに項目がありませんが出る`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()

        toggle(PagingDemoText.IsEmpty).performClick()

        waitForText(PagingDemoText.Empty)
        composeTestRule.onNodeWithText(PagingDemoText.Empty).assertIsDisplayed()
        assertEquals(0, composeTestRule.onAllNodesWithTextCount("Item ", substring = true))
    }

    @Test
    fun `0 件で失敗させて再読み込みすると 読み込めませんでしたと再試行が出る`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()
        toggle(PagingDemoText.IsEmpty).performClick()
        waitForText(PagingDemoText.Empty)

        toggle(PagingDemoText.FailsNextLoad).performClick()
        composeTestRule.onNodeWithText(PagingDemoText.Reload).performClick()

        waitForText(PagingDemoText.LoadFailed)
        composeTestRule.onNodeWithText(PagingDemoText.Retry).assertIsDisplayed()

        // 切り替えを戻してから、パネルを畳んで「再試行」を押す。この試験の画面 (高さ 800dp) では、下端から
        // 上げたパネルの上端が一覧の真ん中の表示の「再試行」にかかるため。再試行すると、次ページ要求が
        // 0 件の設定のまま読まれて空の表示になる。
        toggle(PagingDemoText.FailsNextLoad).performClick()
        composeTestRule.onNodeWithContentDescription(SamplePanelText.Fold).performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText(PagingDemoText.Retry).performClick()
        waitForText(PagingDemoText.Empty)
    }

    @Test
    fun `項目があるときの取り直しの失敗は 項目を残して上の帯で更新できませんでしたを出し 3 秒で消す`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()

        toggle(PagingDemoText.FailsNextLoad).performClick()
        composeTestRule.onNodeWithText(PagingDemoText.Reload).performClick()

        waitForText(PagingDemoText.RefreshFailed)
        assertTrue(composeTestRule.onAllNodesWithTextCount("Item ", substring = true) > 0)
        composeTestRule.onNodeWithText(PagingDemoText.RefreshFailed).assertIsDisplayed()
        // 知らせは画面の上の帯で出し、パネルの説明の一行は通常の文言のまま。
        composeTestRule.onNodeWithText(PagingDemoText.Summary).assertIsDisplayed()
        composeTestRule.onNodeWithText(PagingDemoText.LoadFailed).assertDoesNotExist()
        // 帯は読み上げにも知らせる領域になっている。
        composeTestRule.onNodeWithText(PagingDemoText.RefreshFailed)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite))
        // 帯はパネルより上 (画面の上寄り) に出る。
        val banner = composeTestRule.onNodeWithText(PagingDemoText.RefreshFailed).getUnclippedBoundsInRoot()
        val summary = composeTestRule.onNodeWithText(PagingDemoText.Summary).getUnclippedBoundsInRoot()
        assertTrue("帯 $banner がパネル $summary より上に無い", banner.bottom < summary.top)

        // 3 秒たつと消える。
        composeTestRule.mainClock.advanceTimeBy(SamplePanelMetrics.BannerDurationMillis + 1_000)
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText(PagingDemoText.RefreshFailed).assertDoesNotExist()
    }

    /**
     * 途中までスクロールしてから、引っ張らずに「再読み込み」すると、取り直しの結果が先頭から表示される。
     * 遅延 0 では取り直し中への書き換えと結果が同じ描画の回にまとまりうるため、取り直し中が一覧に
     * 届いてから取得するモデルの形がここで効く。
     */
    @Test
    fun `途中から再読み込みすると 遅延 0 でも Item 1 から表示される`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(30)
        waitForText("Item 31")
        composeTestRule.onNodeWithText("Item 1").assertDoesNotExist()

        composeTestRule.onNodeWithText(PagingDemoText.Reload).performClick()

        waitForText("Item 1")
        composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()
    }

    /**
     * 一覧の下の余白にパネルの分を入れず、パネルを下端から上げているため、末尾までスクロールしたときの
     * 失敗の表示はパネルの下の帯に丸ごと出て、「再試行」を押せる。パネルを広げたままで確かめる。
     *
     * 末尾に後から現れた表示は表示範囲の外に置かれる (終端になるまでは末尾へ追従しない) ため、
     * 失敗の表示が出てから、もう一度いちばん後ろまで送る。
     */
    @Test
    fun `末尾の失敗の表示はパネルに重ならずパネルの下に出て 再試行を押せる`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()
        toggle(PagingDemoText.FailsNextLoad).performClick()
        scrollToLast(50)
        repeat(60) { composeTestRule.mainClock.advanceTimeByFrame() }
        scrollToLast(50)
        waitForText(PagingDemoText.LoadFailed)
        // 表示の枠が伸び終わるまで進めてから、いちばん後ろに合わせ直して位置を測る。
        composeTestRule.mainClock.advanceTimeBy(1_000)
        scrollToLast(50)

        val panelBottom = composeTestRule.onNodeWithText(PagingDemoText.Summary).getUnclippedBoundsInRoot().bottom
        val message = composeTestRule.onNodeWithText(PagingDemoText.LoadFailed).getUnclippedBoundsInRoot()
        val retry = composeTestRule.onNodeWithText(PagingDemoText.Retry).getUnclippedBoundsInRoot()
        assertTrue("失敗の文言 $message がパネルの下端 $panelBottom より下に無い", message.top > panelBottom)
        assertTrue("再試行 $retry がパネルの下端 $panelBottom より下に無い", retry.top > panelBottom)
        composeTestRule.onNodeWithText(PagingDemoText.Retry).assertIsDisplayed()

        // 切り替えを戻して「再試行」を押すと、次のページが続く。
        toggle(PagingDemoText.FailsNextLoad).performClick()
        composeTestRule.onNodeWithText(PagingDemoText.Retry).performClick()
        repeat(10) { composeTestRule.mainClock.advanceTimeByFrame() }
        scrollToLast(100)
        waitForText("Item 100")
    }

    @Test
    fun `畳むと丸いボタンだけが残り 広げると切り替えの状態を保って戻る`() {
        composeTestRule.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()
        toggle(PagingDemoText.FailsNextLoad).performClick()

        composeTestRule.onNodeWithContentDescription(SamplePanelText.Fold).performClick()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText(PagingDemoText.Reload).assertDoesNotExist()
        composeTestRule.onNodeWithContentDescription(SamplePanelText.Unfold).assertIsDisplayed()

        composeTestRule.onNodeWithContentDescription(SamplePanelText.Unfold).performClick()
        composeTestRule.waitForIdle()
        toggle(PagingDemoText.FailsNextLoad).assertIsOn()
        toggle(PagingDemoText.IsEmpty).assertIsOff()
        composeTestRule.onNodeWithText(PagingDemoText.Reload).assertIsDisplayed()
    }

    @Test
    fun `表示の形と切り替えと畳んだ状態は保存と復元をまたいで残る`() {
        val restorationTester = StateRestorationTester(composeTestRule)
        restorationTester.setContent { PagingDemoScreen(delayMilliseconds = 0) }
        waitForFirstPage()
        toggle(PagingDemoText.FailsNextLoad).performClick()
        composeTestRule.onNodeWithText("グリッド").performClick()
        composeTestRule.onNodeWithContentDescription(SamplePanelText.Fold).performClick()

        restorationTester.emulateSavedInstanceStateRestore()

        waitForFirstPage()
        composeTestRule.onNodeWithContentDescription(SamplePanelText.Unfold).performClick()
        composeTestRule.waitForIdle()
        toggle(PagingDemoText.FailsNextLoad).assertIsOn()
        composeTestRule.onNodeWithText("グリッド").assertIsDisplayed()
    }
}
