package jp.kamusoft.kscollectionview.samples.android

import android.content.Context
import android.content.res.Configuration
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 外観の選択の文言・初期値・保存と読み戻し・選択中の読み上げを確かめる。
 *
 * 文言と保存の値の期待値は iOS Sample の `SampleAppearance.swift` の宣言をそのまま書き写したもの。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class SampleAppearanceTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Before
    fun clearSavedAppearance() {
        context.getSharedPreferences("sample_appearance", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test
    fun `外観の見出し・項目・読み上げ文言・保存の値が iOS と一致する`() {
        assertEquals("外観", SampleAppearance.SectionTitle)
        assertEquals(listOf("システム", "ライト", "ダーク"), SampleAppearance.entries.map { it.title })
        assertEquals("選択中", SampleAppearance.SelectedStateDescription)
        assertEquals("appearance", SampleAppearance.StorageKey)
        assertEquals(listOf("system", "light", "dark"), SampleAppearance.entries.map { it.storageValue })
    }

    @Test
    fun `保存が無いときの選択はシステムである`() {
        assertEquals(SampleAppearance.System, SampleAppearance.Initial)
        assertEquals(SampleAppearance.System, SampleAppearanceStore.load(context))
    }

    @Test
    fun `保存した値が読み戻せる`() {
        SampleAppearance.entries.forEach { appearance ->
            SampleAppearanceStore.save(context, appearance)
            assertEquals(appearance, SampleAppearanceStore.load(context))
        }
    }

    @Test
    fun `未知の保存値はシステムとして読む`() {
        context.getSharedPreferences("sample_appearance", Context.MODE_PRIVATE).edit()
            .putString(SampleAppearance.StorageKey, "sepia").commit()
        assertEquals(SampleAppearance.System, SampleAppearanceStore.load(context))
    }

    @Test
    fun `システムは表示モードを上書きせずライトとダークは夜間モードだけを上書きする`() {
        SampleAppearanceStore.save(context, SampleAppearance.System)
        assertNull(SampleAppearanceStore.nightModeOverride(context))

        SampleAppearanceStore.save(context, SampleAppearance.Light)
        val light = SampleAppearanceStore.nightModeOverride(context)!!
        assertEquals(Configuration.UI_MODE_NIGHT_NO, light.uiMode)
        // 夜間モード以外は未設定のまま (端末の文字の大きさ等を上書きしない)。
        assertEquals(Configuration().apply { uiMode = Configuration.UI_MODE_NIGHT_NO }, light)

        SampleAppearanceStore.save(context, SampleAppearance.Dark)
        assertEquals(Configuration.UI_MODE_NIGHT_YES, SampleAppearanceStore.nightModeOverride(context)!!.uiMode)
    }

    @Test
    fun `ルートメニューは選択中の項目だけを選択中と読む`() {
        composeTestRule.setContent {
            RootMenuScreen(
                appearance = SampleAppearance.Dark,
                onSelectAppearance = {},
                onSelectDemo = {},
                onSelectVerification = {},
            )
        }

        composeTestRule.onNodeWithText("外観").assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        composeTestRule.onNodeWithText("ダーク")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "選択中"))
        listOf("システム", "ライト").forEach { title ->
            composeTestRule.onNodeWithText(title)
                .assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.StateDescription))
        }
        // 印は読み上げの対象にしない。
        composeTestRule.onNodeWithText("✓").assertDoesNotExist()
    }

    @Test
    fun `ルートメニューの外観の項目を選ぶとその外観が通知される`() {
        val selected = mutableListOf<SampleAppearance>()
        composeTestRule.setContent {
            RootMenuScreen(
                appearance = SampleAppearance.System,
                onSelectAppearance = { selected += it },
                onSelectDemo = {},
                onSelectVerification = {},
            )
        }

        composeTestRule.onNodeWithText("ライト").performClick()
        composeTestRule.onNodeWithText("ダーク").performClick()
        composeTestRule.waitForIdle()

        assertEquals(listOf(SampleAppearance.Light, SampleAppearance.Dark), selected)
    }

    @Test
    fun `ルートメニューは外観の項目群をデモ画面の項目より前に置く`() {
        composeTestRule.setContent {
            RootMenuScreen(
                appearance = SampleAppearance.System,
                onSelectAppearance = {},
                onSelectDemo = {},
                onSelectVerification = {},
            )
        }

        val top = listOf("外観", "システム", "ライト", "ダーク", "リスト").map { title ->
            composeTestRule.onNodeWithText(title).fetchSemanticsNode().boundsInRoot.top
        }
        assertEquals(top.sorted(), top)
    }
}
