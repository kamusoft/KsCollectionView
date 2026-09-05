package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 操作を伴うデモ画面と検証画面が、iOS Sample と同じ初期値・同じ切り替え結果になることを確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class SampleDemoScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 「リスト」画面の区切り線は「既定」で始まる。 */
    @Test
    fun `リスト画面の区切り線の初期選択は既定である`() {
        composeTestRule.setContent { ListDemoScreen() }

        composeTestRule.onNodeWithText("既定").assertIsSelected()
    }

    /** 3 択はどれを選んでも選択が移り、項目の表示は変わらない。 */
    @Test
    fun `リスト画面の区切り線は 3 択を選び直せる`() {
        composeTestRule.setContent { ListDemoScreen() }

        composeTestRule.onNodeWithText("アクセント").performClick()
        composeTestRule.onNodeWithText("アクセント").assertIsSelected()
        composeTestRule.onNodeWithText("Apple").assertIsDisplayed()

        composeTestRule.onNodeWithText("なし").performClick()
        composeTestRule.onNodeWithText("なし").assertIsSelected()
        composeTestRule.onNodeWithText("Apple").assertIsDisplayed()
    }

    /** 「グリッド (固定列)」画面は grid で始まり、list へ切り替えても同じ 9 件を出す。 */
    @Test
    fun `グリッド固定列画面は grid で始まり list へ切り替えられる`() {
        composeTestRule.setContent { FixedGridDemoScreen() }

        composeTestRule.onNodeWithText("grid").assertIsSelected()
        composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()
        composeTestRule.onNodeWithText("Item 9").assertIsDisplayed()

        composeTestRule.onNodeWithText("list").performClick()
        composeTestRule.onNodeWithText("list").assertIsSelected()
        composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()
    }

    /** 親の状態で展開する経路は、行のタップで本文が現れ、再タップで消える。 */
    @Test
    fun `検証画面は親の状態の経路で展開と折りたたみができる`() {
        composeTestRule.setContent { HeightChangeVerificationScreen() }

        composeTestRule.onNodeWithText("展開中: 0 行").assertIsDisplayed()

        composeTestRule.onNodeWithText("行 2 の先頭").performClick()
        composeTestRule.onNodeWithText("行 2 本文 1").assertIsDisplayed()
        composeTestRule.onNodeWithText("展開中: 1 行").assertIsDisplayed()

        composeTestRule.onNodeWithText("行 2 の先頭").performClick()
        composeTestRule.onNodeWithText("行 2 本文 1").assertDoesNotExist()
        composeTestRule.onNodeWithText("展開中: 0 行").assertIsDisplayed()
    }

    /** テンプレート内の状態で展開する経路は、親の計数を動かさずに本文だけが現れる。 */
    @Test
    fun `検証画面はテンプレート内の状態の経路で展開できる`() {
        composeTestRule.setContent { HeightChangeVerificationScreen() }

        composeTestRule.onNodeWithText("テンプレート内 state").performClick()
        composeTestRule.onNodeWithText("行 3 の先頭").performClick()

        composeTestRule.onNodeWithText("行 3 本文 1").assertIsDisplayed()
        // 親はタップを知らないため、親が持つ展開中の行数は 0 のまま。
        composeTestRule.onNodeWithText("展開中: 0 行").assertIsDisplayed()
    }

    /**
     * テンプレート内の状態は、可視範囲と先読み分を超えて往復すると初期値へ戻る。
     *
     * Compose の Lazy 系は可視範囲外の項目の Composition を捨てるため、テンプレートの中で
     * `remember` した展開状態は範囲外へ出た時点で失われる。残したい状態は項目のモデル側
     * (親が持つ状態) へ置く、という契約をこのテストが押さえる。
     */
    @Test
    fun `検証画面のテンプレート内の状態は画面外への往復で初期値へ戻る`() {
        composeTestRule.setContent { HeightChangeVerificationScreen() }

        composeTestRule.onNodeWithText("テンプレート内 state").performClick()
        composeTestRule.onNodeWithText("行 3 の先頭").performClick()
        composeTestRule.onNodeWithText("行 3 本文 1").assertIsDisplayed()

        // 可視範囲 + 先読み分を確実に超える位置まで送り、対象の行を Composition から外す。
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(LastRowIndex)
        composeTestRule.onNodeWithText("行 3 の先頭").assertDoesNotExist()

        // 戻すと行は作り直され、テンプレート内の展開状態は初期値 (折りたたみ) になっている。
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(0)
        composeTestRule.onNodeWithText("行 3 の先頭").assertIsDisplayed()
        composeTestRule.onNodeWithText("行 3 本文 1").assertDoesNotExist()
    }

    /**
     * 選択状態は構成変更 (回転) をまたいで保たれる。
     *
     * 実機の回転は Activity の再生成であり、`remember` では失われる。iOS の `@State` と
     * 同じ振る舞いにそろえるため、保存と復元をまたいでも選択が残ることを確かめる。
     */
    @Test
    fun `グリッド固定列画面の選択は保存と復元をまたいで残る`() {
        val restorationTester = StateRestorationTester(composeTestRule)
        restorationTester.setContent { FixedGridDemoScreen() }

        composeTestRule.onNodeWithText("list").performClick()
        composeTestRule.onNodeWithText("list").assertIsSelected()

        restorationTester.emulateSavedInstanceStateRestore()

        composeTestRule.onNodeWithText("list").assertIsSelected()
    }

    /** レイアウトの切り替えは検証画面でも効く。 */
    @Test
    fun `検証画面は list と grid を切り替えられる`() {
        composeTestRule.setContent { HeightChangeVerificationScreen() }

        composeTestRule.onNodeWithText("list").assertIsSelected()
        composeTestRule.onNodeWithText("grid").performClick()
        composeTestRule.onNodeWithText("grid").assertIsSelected()
        composeTestRule.onNodeWithText("行 1 の先頭").assertIsDisplayed()
    }

    private companion object {
        /** 検証画面の最終行の index (画面外へ確実に送るための送り先)。 */
        const val LastRowIndex = 59
    }
}
