package jp.kamusoft.kscollectionview

import android.util.Log
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/** 配列・安定 ID・テンプレート宣言と差分更新の挙動を確かめる。 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsCollectionViewCoreTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Before
    fun setUp() {
        ShadowLog.clear()
    }

    @After
    fun tearDown() {
        KsDiagnostics.debugOverride = null
    }

    /** key ラムダで宣言した配列は全件に到達でき、同時にコンポジションされる項目は一部に留まる。 */
    @Test
    fun displaysEveryItemAndKeepsComposedItemsBounded() {
        val items = testItems(100)
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }) {
                    template { item ->
                        Text(
                            text = item.text,
                            modifier = Modifier.fillMaxWidth().height(50.dp).testTag("cell"),
                        )
                    }
                }
            }
        }

        composeTestRule.onNodeWithText("item 0").assertIsDisplayed()

        val composed = composeTestRule.countNodesWithTag("cell")
        assertTrue(
            "同時にコンポジションされる項目は可視範囲 + 先読み分に留まる (実測 $composed 件)",
            composed < items.size,
        )

        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(99)
        composeTestRule.onNodeWithText("item 99").assertIsDisplayed()
    }

    /** 重複した ID は、後に現れた要素だけを残して表示を継続する (debug 以外)。 */
    @Test
    fun duplicateIdKeepsLaterItemWhenNotDebug() {
        KsDiagnostics.debugOverride = false
        val items = listOf(
            TestItem(id = "a", text = "first"),
            TestItem(id = "a", text = "second"),
            TestItem(id = "b", text = "other"),
        )

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag("cell"))
                    }
                }
            }
        }

        composeTestRule.onNodeWithText("second").assertIsDisplayed()
        assertEquals(0, composeTestRule.countNodesWithText("first"))
        assertEquals(2, composeTestRule.countNodesWithTag("cell"))
        assertWarned("重複した key", "重複した key は黙って畳まず警告を残す")
    }

    /** 重複した ID は debug ビルドでは停止する。 */
    @Test
    fun duplicateIdStopsInDebug() {
        KsDiagnostics.debugOverride = true
        val items = listOf(TestItem("a", "first"), TestItem("a", "second"))

        assertThrows(IllegalStateException::class.java) {
            resolveItems(items, key = { it.id }, template = null, context = context)
        }
    }

    /** 状態保存に載せられない型を key が返した場合は debug ビルドで停止する。 */
    @Test
    fun unsavableKeyStopsInDebug() {
        KsDiagnostics.debugOverride = true
        class OpaqueKey
        val items = listOf(TestItem("a", "first"))

        assertThrows(IllegalStateException::class.java) {
            resolveItems(items, key = { OpaqueKey() }, template = null, context = context)
        }
    }

    /** 同じ ID・同じキーで内容だけ変えると、項目の remember した値は作り直されない。 */
    @Test
    fun contentUpdateKeepsRememberedStateOfItem() {
        var stamps = 0
        var items by mutableStateOf(listOf(TestItem("a", "before")))

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }) {
                    template { item ->
                        val stamp = remember { stamps++ }
                        Text(
                            text = "${item.text}/$stamp",
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                        )
                    }
                }
            }
        }
        composeTestRule.onNodeWithText("before/0").assertIsDisplayed()

        items = listOf(TestItem("a", "after"))
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("after/0").assertIsDisplayed()
    }

    /** 同じ ID でもテンプレートキーが変わった要素は新しいテンプレートで描かれる。 */
    @Test
    fun templateKeyChangeRedrawsWithNewTemplate() {
        var items by mutableStateOf(listOf(TestItem("a", "x", TestKind.Message)))

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }, template = { it.kind }) {
                    template(TestKind.Message) { item ->
                        Text("MSG:${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                    template(TestKind.Ad) { item ->
                        Text("AD:${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                }
            }
        }
        composeTestRule.onNodeWithText("MSG:x").assertIsDisplayed()

        items = listOf(TestItem("a", "x", TestKind.Ad))
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("AD:x").assertIsDisplayed()
        assertEquals(0, composeTestRule.countNodesWithText("MSG:x"))
    }

    /** テンプレートの中で読んだ親の状態は、親の再コンポーズで反映される。 */
    @Test
    fun parentStateReadInsideTemplateIsReflected() {
        val items = testItems(3)
        var selectedId by mutableStateOf("item-0")

        composeTestRule.setContent {
            TestContainer {
                val selected = selectedId
                KsCollectionView(items = items, key = { it.id }) {
                    template { item ->
                        val mark = if (item.id == selected) "*" else "-"
                        Text("$mark${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                }
            }
        }
        composeTestRule.onNodeWithText("*item 0").assertIsDisplayed()
        composeTestRule.onNodeWithText("-item 1").assertIsDisplayed()

        selectedId = "item-1"
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("-item 0").assertIsDisplayed()
        composeTestRule.onNodeWithText("*item 1").assertIsDisplayed()
    }

    /** 要素は自分のキー値に対応するテンプレートで描かれる。 */
    @Test
    fun templatePerKeyValueIsApplied() {
        val items = listOf(
            TestItem("a", "one", TestKind.Message),
            TestItem("b", "two", TestKind.Ad),
        )

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }, template = { it.kind }) {
                    template(TestKind.Message) { item ->
                        Text("MSG:${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                    template(TestKind.Ad) { item ->
                        Text("AD:${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                }
            }
        }

        composeTestRule.onNodeWithText("MSG:one").assertIsDisplayed()
        composeTestRule.onNodeWithText("AD:two").assertIsDisplayed()
    }

    /** キー登録なしの軽量形でも全件が描かれる。 */
    @Test
    fun singleTemplateFormDrawsEveryItem() {
        val items = testItems(3)

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag("cell"))
                    }
                }
            }
        }

        assertEquals(3, composeTestRule.countNodesWithTag("cell"))
    }

    /** 同じキーへの二重登録は、後の宣言で描いて表示を継続する (debug 以外)。 */
    @Test
    fun duplicateTemplateRegistrationKeepsLastWhenNotDebug() {
        KsDiagnostics.debugOverride = false
        val items = listOf(TestItem("a", "x", TestKind.Message))

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = items, key = { it.id }, template = { it.kind }) {
                    template(TestKind.Message) { item ->
                        Text("FIRST:${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                    template(TestKind.Message) { item ->
                        Text("SECOND:${item.text}", Modifier.fillMaxWidth().height(50.dp))
                    }
                }
            }
        }

        composeTestRule.onNodeWithText("SECOND:x").assertIsDisplayed()
        assertEquals(0, composeTestRule.countNodesWithText("FIRST:x"))
        assertWarned("同じキーに複数のテンプレート", "二重登録は黙って後勝ちにせず警告を残す")
    }

    /** 同じキーへの二重登録は debug ビルドでは停止する。 */
    @Test
    fun duplicateTemplateRegistrationStopsInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            composeTestRule.setContent {
                TestContainer {
                    KsCollectionView(
                        items = listOf(TestItem("a", "x", TestKind.Message)),
                        key = { it.id },
                        template = { it.kind },
                    ) {
                        template(TestKind.Message) { Text("first") }
                        template(TestKind.Message) { Text("second") }
                    }
                }
            }
        }
    }

    /** テンプレート未登録のキーの要素は、非表示にせず空の項目として自分の行を占める (debug 以外)。 */
    @Test
    fun unregisteredKeyShowsEmptyItemWhenNotDebug() {
        KsDiagnostics.debugOverride = false
        val items = listOf(
            TestItem("a", "one", TestKind.Message),
            TestItem("b", "two", TestKind.System),
            TestItem("c", "three", TestKind.Ad),
        )

        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    template = { it.kind },
                    listSeparators = false,
                ) {
                    template(TestKind.Message) { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                    template(TestKind.Ad) { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("a").getUnclippedBoundsInRoot()
        val third = composeTestRule.onNodeWithTag("c").getUnclippedBoundsInRoot()
        assertTrue(
            "未登録キーの要素の分だけ後続の項目が下がり、後続の要素は表示され続ける",
            third.top > first.bottom,
        )
        assertWarned("テンプレートが宣言されていないキー", "未登録キーは黙って空にせず警告を残す")
    }

    /** テンプレート未登録のキーの要素は debug ビルドでは停止する。 */
    @Test
    fun unregisteredKeyStopsInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            composeTestRule.setContent {
                TestContainer {
                    KsCollectionView(
                        items = listOf(TestItem("a", "x", TestKind.System)),
                        key = { it.id },
                        template = { it.kind },
                    ) {
                        template(TestKind.Message) { Text("msg") }
                    }
                }
            }
        }
    }

    /** 同じ不正入力の警告は、再コンポーズを繰り返しても 1 回しか出ない (debug 以外)。 */
    @Test
    fun sameWarningIsReportedOnlyOnce() {
        KsDiagnostics.debugOverride = false
        val items = listOf(TestItem("a", "one", TestKind.System))
        var revision by mutableStateOf(0)

        composeTestRule.setContent {
            TestContainer {
                // 引数の変化で KsCollectionView 自身を再コンポーズさせる。
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    modifier = Modifier.testTag("rev-$revision"),
                    template = { it.kind },
                ) {
                    template(TestKind.Message) { Text("msg", Modifier.fillMaxWidth().height(50.dp)) }
                }
            }
        }
        composeTestRule.waitForIdle()

        repeat(3) {
            revision++
            composeTestRule.waitForIdle()
        }

        assertEquals(
            "同じ内容の警告は再コンポーズのたびに繰り返さない",
            1,
            warnings().count { it.contains("テンプレートが宣言されていないキー") },
        )
    }

    /** ライブラリのタグで警告ログが出ていることを確かめる。 */
    private fun assertWarned(fragment: String, message: String) {
        composeTestRule.waitForIdle()
        val warnings = warnings()
        assertTrue("$message (実測 $warnings)", warnings.any { it.contains(fragment) })
    }

    /** ライブラリのタグで出た警告ログの本文。 */
    private fun warnings(): List<String> =
        ShadowLog.getLogsForTag("KsCollectionView")
            .filter { it.type == Log.WARN }
            .map { it.msg }
}
