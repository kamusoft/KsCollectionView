package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 色を指定していない list の区切り線が、表示モード (画面の構成の夜間モード) の側の既定の色で描かれる
 * ことを画素で確かめる。
 *
 * 既定の色の値は、両プラットフォームで共通の値をここに書いて固定する。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsDefaultSeparatorColorTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    // ---- 値 ----

    /** 既定の色の値は両プラットフォームで共通の値で、ライト用は不透明な #D9D9DE のままである。 */
    @Test
    fun defaultColorsMatchTheSharedValues() {
        assertEquals(Color(0xFFD9D9DE), KsListSeparatorDefaults.lightColor)
        assertEquals(Color(0xFF38383A), KsListSeparatorDefaults.darkColor)
        assertEquals(KsListSeparatorDefaults.lightColor, KsListSeparatorDefaults.color(isDarkTheme = false))
        assertEquals(KsListSeparatorDefaults.darkColor, KsListSeparatorDefaults.color(isDarkTheme = true))
    }

    // ---- 表示モードごとの既定の色 ----

    /** ライトではライト用の既定の色で、先頭行の上端・行の間・最終行の下端に描かれる。 */
    @Test
    fun lightModeDrawsTheLightDefaultColor() {
        setListContent { SeparatorList(color = null) }

        assertSeparators(KsListSeparatorDefaults.lightColor, "ライト")
    }

    /**
     * 端末の表示モードがダークなら、Material のテーマを置かなくてもダーク用の既定の色で描かれる。
     * 位置と本数はライトのときと同じである。
     */
    @Test
    fun darkModeDrawsTheDarkDefaultColorAtTheSamePositions() {
        RuntimeEnvironment.setQualifiers("+night")
        setListContent { SeparatorList(color = null) }

        assertSeparators(KsListSeparatorDefaults.darkColor, "ダーク")
    }

    /** 表示したまま表示モードを切り替えると、区切り線の色が追随し、戻すと元の色に戻る。 */
    @Test
    fun defaultColorFollowsTheDisplayModeWhileShown() {
        var isNight by mutableStateOf(false)
        setListContent {
            TestNightModeOverride(isNight) { SeparatorList(color = null) }
        }
        assertSeparators(KsListSeparatorDefaults.lightColor, "切り替える前のライト")

        composeTestRule.runOnIdle { isNight = true }
        assertSeparators(KsListSeparatorDefaults.darkColor, "ダークへ切り替えた後")

        composeTestRule.runOnIdle { isNight = false }
        assertSeparators(KsListSeparatorDefaults.lightColor, "ライトへ戻した後")
    }

    // ---- 表示モードの判定元 ----

    /** 端末の表示モードがダークなら、ライトの配色の Material のテーマを置いてもダーク用の値で描かれる。 */
    @Test
    fun deviceNightModeIsUsedUnderALightMaterialColorScheme() {
        RuntimeEnvironment.setQualifiers("+night")
        setListContent {
            MaterialTheme(colorScheme = lightColorScheme()) { SeparatorList(color = null) }
        }

        assertSeparators(KsListSeparatorDefaults.darkColor, "ライトの配色の Material のテーマ")
    }

    /** 端末がライトのまま、一覧に届く画面の構成の夜間モードだけをダークにすると、ダーク用の値で描かれる。 */
    @Test
    fun overriddenConfigurationNightModeIsUsed() {
        setListContent {
            TestNightModeOverride(isNight = true) { SeparatorList(color = null) }
        }

        assertSeparators(KsListSeparatorDefaults.darkColor, "画面の構成だけをダークに上書き")
    }

    /** 画面の構成はライトのまま、ダークの配色の Material のテーマだけを置いても、ライト用の値で描かれる。 */
    @Test
    fun darkMaterialColorSchemeAloneDoesNotSwitchTheDefaultColor() {
        setListContent {
            MaterialTheme(colorScheme = darkColorScheme()) { SeparatorList(color = null) }
        }

        assertSeparators(KsListSeparatorDefaults.lightColor, "ダークの配色の Material のテーマだけ")
    }

    // ---- 指定した色 ----

    /** 指定した色は、ライトでもダークでもそのまま描かれる。 */
    @Test
    fun specifiedColorIsKeptInBothDisplayModes() {
        var isNight by mutableStateOf(false)
        setListContent {
            TestNightModeOverride(isNight) { SeparatorList(color = CustomColor) }
        }
        assertSeparators(CustomColor, "ライトで指定した色")

        composeTestRule.runOnIdle { isNight = true }
        assertSeparators(CustomColor, "ダークで指定した色")
    }

    /** ダークで色の指定を外すと、ダーク用の既定の色で描かれる。 */
    @Test
    fun removingTheSpecifiedColorFallsBackToTheDefaultOfTheCurrentMode() {
        RuntimeEnvironment.setQualifiers("+night")
        var color by mutableStateOf<Color?>(CustomColor)
        setListContent { SeparatorList(color = color) }
        assertSeparators(CustomColor, "指定した色")

        composeTestRule.runOnIdle { color = null }
        assertSeparators(KsListSeparatorDefaults.darkColor, "指定を外した後")
    }

    // ---- 補助 ----

    private fun setListContent(content: @Composable () -> Unit) {
        composeTestRule.setContent {
            TestContainer(width = 200.dp, height = 200.dp) { content() }
        }
    }

    /** 2 件・各 50dp の list。項目は背景を塗らないので、線の画素は線の色そのものになる。 */
    @Composable
    private fun SeparatorList(color: Color?) {
        KsCollectionView(
            items = testItems(2),
            key = { it.id },
            listSeparatorColor = color,
            modifier = Modifier.testTag(CollectionTag),
        ) {
            template { Text(text = "", modifier = Modifier.fillMaxWidth().height(50.dp)) }
        }
    }

    /** 線が出るはずの 3 か所が [expected] で、項目の内側には線が無いことを確かめる。 */
    private fun assertSeparators(expected: Color, situation: String) {
        val image = composeTestRule.onNodeWithTag(CollectionTag).capturePixels()
        assertEquals("$situation: 先頭行の上端 (実測 ${image[10, 0].hex()})", expected, image[10, 0])
        assertEquals("$situation: 行の間 (実測 ${image[10, 49].hex()})", expected, image[10, 49])
        assertEquals("$situation: 最終行の下端 (実測 ${image[10, 99].hex()})", expected, image[10, 99])
        assertNotEquals("$situation: 項目の内側には線が無い", expected, image[10, 25])
        assertNotEquals("$situation: 最終行の下には線が無い", expected, image[10, 100])
    }

    private companion object {
        const val CollectionTag = "collection"

        /** 既定の色のどちらとも違う、表示モードで値の変わらない色。 */
        val CustomColor = Color(0xFF2F6FED)
    }
}
