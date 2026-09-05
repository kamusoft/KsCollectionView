package jp.kamusoft.kscollectionview

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlin.math.abs
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** layout 値・スペーシング・余白・区切り線・ヘッダー / フッター・content 配置の見え方を確かめる。 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w1000dp-h1000dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsCollectionViewLayoutTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 位置の比較に使う許容差 (端数丸めの吸収)。 */
    private val tolerance = 1.dp

    private fun assertNear(expected: Dp, actual: Dp, message: String) {
        assertTrue(
            "$message (期待 $expected / 実測 $actual)",
            kotlin.math.abs((expected - actual).value) <= tolerance.value,
        )
    }

    @After
    fun tearDown() {
        KsDiagnostics.debugOverride = null
    }

    /** 0 以下の列数・0 以下の最小幅・負のスペーシングは不正入力として検出される。 */
    @Test
    fun invalidLayoutValuesAreDetected() {
        assertTrue(
            "0 以下の列数は不正入力",
            KsLayout.Grid(columns = KsColumns.Fixed(0)).invalidValueMessages().isNotEmpty(),
        )
        assertTrue(
            "向き別指定でも 0 以下の列数は不正入力",
            KsLayout.Grid(columns = KsColumns.Fixed(portrait = 2, landscape = 0))
                .invalidValueMessages().isNotEmpty(),
        )
        assertTrue(
            "0 以下の最小アイテム幅は不正入力",
            KsLayout.Grid(columns = KsColumns.Adaptive(0.dp)).invalidValueMessages().isNotEmpty(),
        )
        assertTrue(
            "負の行間は不正入力",
            KsLayout.List(rowSpacing = (-1).dp).invalidValueMessages().isNotEmpty(),
        )
        assertTrue(
            "負の列間は不正入力",
            KsLayout.Grid(columns = KsColumns.Fixed(2), columnSpacing = (-1).dp)
                .invalidValueMessages().isNotEmpty(),
        )
        assertTrue(
            "適正な値は検出されない",
            KsLayout.Grid(columns = KsColumns.Fixed(2), rowSpacing = 8.dp).invalidValueMessages()
                .isEmpty(),
        )
    }

    /** 不正な layout 値は debug ビルドでは停止する。 */
    @Test
    fun invalidLayoutValueStopsInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            composeTestRule.setContent {
                TestContainer(width = 300.dp, height = 600.dp) {
                    KsCollectionView(
                        items = testItems(2),
                        key = { it.id },
                        layout = KsLayout.Grid(columns = KsColumns.Fixed(0)),
                    ) {
                        template { item -> Text(item.text) }
                    }
                }
            }
        }
    }

    /** 固定列の指定どおりの列数で並ぶ。 */
    @Test
    fun fixedColumnsPlacesItemsInDeclaredColumnCount() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(6),
                    key = { it.id },
                    layout = KsLayout.Grid(columns = KsColumns.Fixed(3)),
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("item-1").getUnclippedBoundsInRoot()
        val third = composeTestRule.onNodeWithTag("item-2").getUnclippedBoundsInRoot()
        val fourth = composeTestRule.onNodeWithTag("item-3").getUnclippedBoundsInRoot()

        assertNear(first.top, second.top, "1 行目の項目は同じ高さに並ぶ")
        assertNear(first.top, third.top, "1 行目の項目は同じ高さに並ぶ")
        assertTrue("4 件目は次の行へ折り返す", fourth.top >= first.bottom)
        assertNear(100.dp, first.width, "3 列なら 1 項目は幅の 1/3")
    }

    /** adaptive は最小幅を下回らない最大の列数を選び、列間は指定値のまま余剰幅を項目へ配る。 */
    @Test
    fun adaptiveColumnsKeepsColumnSpacingAndDistributesRemainder() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(4),
                    key = { it.id },
                    layout = KsLayout.Grid(
                        columns = KsColumns.Adaptive(minItemWidth = 120.dp),
                        columnSpacing = 20.dp,
                    ),
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("item-1").getUnclippedBoundsInRoot()
        val third = composeTestRule.onNodeWithTag("item-2").getUnclippedBoundsInRoot()

        assertNear(first.top, second.top, "300dp / 最小 120dp / 列間 20dp なら 2 列になる")
        assertTrue("3 件目は次の行へ折り返す", third.top >= first.bottom)
        assertNear(140.dp, first.width, "余剰幅は項目の幅へ配分される")
        assertNear(20.dp, second.left - first.right, "列間は指定値のまま保たれる")
    }

    /** 向き別列数はコンテナの縦横比で切り替わる (コンテナが縦長)。 */
    @Test
    fun orientationColumnsUsesPortraitCountWhenContainerIsTall() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                OrientationGrid()
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        assertNear(150.dp, first.width, "高さ > 幅なら 2 列")
    }

    /** 向き別列数はコンテナの縦横比で切り替わる (コンテナが横長)。 */
    @Test
    fun orientationColumnsUsesLandscapeCountWhenContainerIsWide() {
        composeTestRule.setContent {
            TestContainer(width = 600.dp, height = 300.dp) {
                OrientationGrid()
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        assertNear(150.dp, first.width, "幅 >= 高さなら 4 列")
    }

    /** layout を差し替えるとデータを保ったまま表示形態が切り替わり、先頭ではない位置も保たれる。 */
    @Test
    fun switchingLayoutKeepsDataAndAnchorItemVisible() {
        var layout by mutableStateOf<KsLayout>(KsLayout.List)

        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(items = testItems(40), key = { it.id }, layout = layout) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        // 先頭ではない位置までスクロールし、そのときの先頭可視要素をアンカーにする。
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(20)
        val anchorId = "item-20"
        composeTestRule.onNodeWithTag(anchorId).assertIsDisplayed()
        assertNear(0.dp, composeTestRule.onNodeWithTag(anchorId).getUnclippedBoundsInRoot().top, "アンカーが先頭可視要素になる")

        layout = KsLayout.Grid(columns = KsColumns.Fixed(2))
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithTag(anchorId).assertIsDisplayed()
        val anchor = composeTestRule.onNodeWithTag(anchorId).getUnclippedBoundsInRoot()
        val next = composeTestRule.onNodeWithTag("item-21").getUnclippedBoundsInRoot()
        assertNear(anchor.top, next.top, "2 列グリッドとして並ぶ")
        assertEquals("先頭へ戻らない", 0, composeTestRule.countNodesWithTag("item-0"))
    }

    /** 行間・列間は指定した分だけ空き、既定では詰めて並ぶ。 */
    @Test
    fun rowAndColumnSpacingAreApplied() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(4),
                    key = { it.id },
                    layout = KsLayout.Grid(
                        columns = KsColumns.Fixed(2),
                        rowSpacing = 8.dp,
                        columnSpacing = 8.dp,
                    ),
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("item-1").getUnclippedBoundsInRoot()
        val third = composeTestRule.onNodeWithTag("item-2").getUnclippedBoundsInRoot()

        assertNear(8.dp, second.left - first.right, "列の間に指定の間隔が空く")
        assertNear(8.dp, third.top - first.bottom, "行の間に指定の間隔が空く")
    }

    /** 既定 (未指定) では行間・列間ともに間隔なしで詰めて並ぶ。 */
    @Test
    fun spacingDefaultsToZero() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(4),
                    key = { it.id },
                    layout = KsLayout.Grid(columns = KsColumns.Fixed(2)),
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("item-1").getUnclippedBoundsInRoot()
        val third = composeTestRule.onNodeWithTag("item-2").getUnclippedBoundsInRoot()

        assertNear(0.dp, second.left - first.right, "列間の既定は 0")
        assertNear(0.dp, third.top - first.bottom, "行間の既定は 0")
    }

    /** 括弧なしの `KsLayout.List` は行間 0 のリストとして扱われる。 */
    @Test
    fun listWithoutParenthesesBehavesAsDefaultList() {
        assertEquals(
            "括弧なしと行間 0 の指定は同じ値",
            KsLayout.List(rowSpacing = 0.dp),
            KsLayout.List,
        )
        assertTrue("括弧なしでも list として扱われる", KsLayout.List.isList)
        assertEquals("括弧なしの行間は 0", 0.dp, KsLayout.List.effectiveRowSpacing)
        assertTrue("括弧なしの指定は適正な値", KsLayout.List.invalidValueMessages().isEmpty())

        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    layout = KsLayout.List,
                    listSeparators = false,
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("item-1").getUnclippedBoundsInRoot()

        assertNear(300.dp, first.width, "1 列で並ぶ")
        assertNear(0.dp, second.top - first.bottom, "行間は 0")
    }

    /** 括弧なしの宣言でも named 引数で行間を指定できる。 */
    @Test
    fun listRowSpacingIsAppliedWhenSpecified() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    layout = KsLayout.List(rowSpacing = 12.dp),
                    listSeparators = false,
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("item-1").getUnclippedBoundsInRoot()

        assertNear(12.dp, second.top - first.bottom, "指定した行間だけ空く")
    }

    /** contentPadding の内側にコンテンツが置かれる。 */
    @Test
    fun contentPaddingInsetsContent() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    contentPadding = PaddingValues(start = 16.dp, end = 24.dp, top = 12.dp),
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        assertNear(16.dp, first.left, "左の内側余白の分だけ内側に置かれる")
        assertNear(260.dp, first.width, "左右の内側余白の分だけ幅が狭くなる")
        assertNear(12.dp, first.top, "上の内側余白の分だけ内側に置かれる")
    }

    /** 区切り線は既定で先頭行の上端・行間・最終行の下端に出る。 */
    @Test
    fun listSeparatorsAreDrawnByDefault() {
        setSeparatorContent(separators = true, color = null)

        val pixels = capturedPixels()
        assertEquals(KsListSeparatorDefaults.color, pixels.topLine)
        assertEquals(KsListSeparatorDefaults.color, pixels.betweenLine)
        assertEquals(KsListSeparatorDefaults.color, pixels.bottomLine)
        assertNotEquals(KsListSeparatorDefaults.color, pixels.insideItem)
    }

    /** 不透明な背景を持つテンプレートでも、区切り線は content に隠れず 3 本とも見える。 */
    @Test
    fun listSeparatorsAreDrawnOverOpaqueItemBackground() {
        setSeparatorContent(separators = true, color = null, itemBackground = Color.White)

        val pixels = capturedPixels()
        assertEquals("先頭行の上端の線が content の背景に隠れない", KsListSeparatorDefaults.color, pixels.topLine)
        assertEquals("行間の線が content の背景に隠れない", KsListSeparatorDefaults.color, pixels.betweenLine)
        assertEquals("最終行の下端の線が content の背景に隠れない", KsListSeparatorDefaults.color, pixels.bottomLine)
        assertEquals("項目の内側は content の背景色のまま", Color.White, pixels.insideItem)
    }

    /** listSeparators = false ではどの区切り線も出ない。 */
    @Test
    fun listSeparatorsCanBeTurnedOff() {
        setSeparatorContent(separators = false, color = null)

        val pixels = capturedPixels()
        assertNotEquals(KsListSeparatorDefaults.color, pixels.topLine)
        assertNotEquals(KsListSeparatorDefaults.color, pixels.betweenLine)
        assertNotEquals(KsListSeparatorDefaults.color, pixels.bottomLine)
    }

    /** listSeparatorColor で色だけを変えられる (位置・本数は既定と同じ)。 */
    @Test
    fun listSeparatorColorChangesOnlyTheColor() {
        val custom = Color(0xFF2F6FED)
        setSeparatorContent(separators = true, color = custom)

        val pixels = capturedPixels()
        assertEquals(custom, pixels.topLine)
        assertEquals(custom, pixels.betweenLine)
        assertEquals(custom, pixels.bottomLine)
    }

    /** listSeparators = false のときは listSeparatorColor を指定しても何も描かれない。 */
    @Test
    fun listSeparatorColorDrawsNothingWhenSeparatorsAreHidden() {
        val custom = Color(0xFF2F6FED)
        setSeparatorContent(separators = false, color = custom)

        val pixels = capturedPixels()
        assertNotEquals(custom, pixels.topLine)
        assertNotEquals(custom, pixels.betweenLine)
        assertNotEquals(custom, pixels.bottomLine)
    }

    /** グリッドでは区切り線を描かない。 */
    @Test
    fun gridDrawsNoSeparators() {
        composeTestRule.setContent {
            TestContainer(width = 200.dp, height = 200.dp) {
                KsCollectionView(
                    items = testItems(4),
                    key = { it.id },
                    layout = KsLayout.Grid(columns = KsColumns.Fixed(2)),
                    modifier = Modifier.testTag(CollectionTag),
                ) {
                    template { Text("", Modifier.fillMaxWidth().height(50.dp)) }
                }
            }
        }

        val image = composeTestRule.onNodeWithTag(CollectionTag).readPixels()
        assertNotEquals(KsListSeparatorDefaults.color, image[10, 0])
        assertNotEquals(KsListSeparatorDefaults.color, image[10, 49])
    }

    /** ヘッダーはコンテンツと一緒にスクロールして画面外へ出る。 */
    @Test
    fun headerScrollsAwayWithContent() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 300.dp) {
                KsCollectionView(
                    items = testItems(50),
                    key = { it.id },
                    header = { Text("見出し", Modifier.fillMaxWidth().height(40.dp)) },
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }
        composeTestRule.onNodeWithText("見出し").assertIsDisplayed()

        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(30)

        composeTestRule.onNodeWithText("見出し").assertIsNotDisplayed()
    }

    /** 配列が空でもヘッダーとフッターは表示される。 */
    @Test
    fun headerAndFooterAreShownForEmptyItems() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 300.dp) {
                KsCollectionView(
                    items = emptyList<TestItem>(),
                    key = { it.id },
                    header = { Text("見出し", Modifier.fillMaxWidth().height(40.dp)) },
                    footer = { Text("末尾", Modifier.fillMaxWidth().height(40.dp)) },
                ) {
                    template { item -> Text(item.text, Modifier.testTag("cell")) }
                }
            }
        }

        composeTestRule.onNodeWithText("見出し").assertIsDisplayed()
        composeTestRule.onNodeWithText("末尾").assertIsDisplayed()
        assertEquals(0, composeTestRule.countNodesWithTag("cell"))
    }

    /** グリッドではヘッダーが全列分の幅を占める。 */
    @Test
    fun headerSpansAllColumnsInGrid() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(6),
                    key = { it.id },
                    layout = KsLayout.Grid(columns = KsColumns.Fixed(3)),
                    header = { Text("見出し", Modifier.fillMaxWidth().height(40.dp).testTag("header")) },
                ) {
                    template { item ->
                        Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
                    }
                }
            }
        }

        val header = composeTestRule.onNodeWithTag("header").getUnclippedBoundsInRoot()
        val first = composeTestRule.onNodeWithTag("item-0").getUnclippedBoundsInRoot()
        assertNear(300.dp, header.width, "ヘッダーは 3 列分の幅を占める")
        assertTrue("要素はヘッダーの下から並ぶ", first.top >= header.bottom)
    }

    /** 行の高さはコンテンツに応じて決まり、行同士に余分な空白が生じない。 */
    @Test
    fun rowHeightFollowsContent() {
        val items = listOf(
            TestItem("a", "短い"),
            TestItem("b", "とても長い本文がここに入り複数行に折り返される想定のテキストです"),
            TestItem("c", "短い"),
        )
        composeTestRule.setContent {
            TestContainer(width = 120.dp, height = 600.dp) {
                KsCollectionView(items = items, key = { it.id }, listSeparators = false) {
                    template { item -> Text(item.text, Modifier.fillMaxWidth().testTag(item.id)) }
                }
            }
        }

        val first = composeTestRule.onNodeWithTag("a").getUnclippedBoundsInRoot()
        val second = composeTestRule.onNodeWithTag("b").getUnclippedBoundsInRoot()
        val third = composeTestRule.onNodeWithTag("c").getUnclippedBoundsInRoot()

        assertTrue("折り返す行は高くなる", second.height > first.height)
        assertNear(first.bottom, second.top, "行の間に余分な空白が生じない")
        assertNear(second.bottom, third.top, "行の間に余分な空白が生じない")
    }

    /** 幅に余りのある content は水平中央、幅いっぱいの content は項目の先頭から敷かれる。 */
    @Test
    fun narrowContentIsCenteredAndWideContentFillsFromStart() {
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = listOf(TestItem("narrow", "ab"), TestItem("wide", "cd")),
                    key = { it.id },
                    template = { it.id },
                    layout = KsLayout.Grid(columns = KsColumns.Fixed(2)),
                ) {
                    template("narrow") { item -> Text(item.text, Modifier.testTag(item.id)) }
                    template("wide") { item ->
                        Text(item.text, Modifier.fillMaxWidth().testTag(item.id))
                    }
                }
            }
        }

        val narrow = composeTestRule.onNodeWithTag("narrow").getUnclippedBoundsInRoot()
        val wide = composeTestRule.onNodeWithTag("wide").getUnclippedBoundsInRoot()

        val narrowCenter = narrow.left + narrow.width / 2
        assertNear(75.dp, narrowCenter, "狭い content は項目の水平中央に置かれる")
        assertNear(150.dp, wide.left, "幅いっぱいの content は項目の先頭から敷かれる")
        assertNear(150.dp, wide.width, "幅いっぱいの content は項目の幅を占める")
    }

    // ---- 区切り線の検証用の下ごしらえ ----

    private fun setSeparatorContent(
        separators: Boolean,
        color: Color?,
        itemBackground: Color? = null,
    ) {
        composeTestRule.setContent {
            TestContainer(width = 200.dp, height = 200.dp) {
                KsCollectionView(
                    items = testItems(2),
                    key = { it.id },
                    listSeparators = separators,
                    listSeparatorColor = color,
                    modifier = Modifier.testTag(CollectionTag),
                ) {
                    template {
                        Text(
                            text = "",
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                                .then(
                                    if (itemBackground != null) {
                                        Modifier.background(itemBackground)
                                    } else {
                                        Modifier
                                    },
                                ),
                        )
                    }
                }
            }
        }
    }

    private class SeparatorPixels(
        val topLine: Color,
        val betweenLine: Color,
        val bottomLine: Color,
        val insideItem: Color,
    )

    /** 2 件・各 50dp のリストで、区切り線が出るはずの位置と項目の内側の色を読む。 */
    private fun capturedPixels(): SeparatorPixels {
        val image = composeTestRule.onNodeWithTag(CollectionTag).readPixels()
        return SeparatorPixels(
            topLine = image[10, 0],
            betweenLine = image[10, 49],
            bottomLine = image[10, 99],
            insideItem = image[10, 25],
        )
    }

    // ---- 行の高さ変化のアニメーション ----

    /** 親の状態で行が展開するとき、行の高さは 1 フレームで飛ばず複数フレームにまたがって変わる。 */
    @Test
    fun rowHeightChangeFromParentStateAnimates() {
        var isExpanded by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(items = testItems(5), key = { it.id }, listSeparators = false) {
                    template { item ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(
                                    if (isExpanded && item.id == "item-0") {
                                        ExpandedHeight
                                    } else {
                                        CollapsedHeight
                                    },
                                )
                                .testTag(item.id),
                        )
                    }
                }
            }
        }

        assertRowHeightAnimates { composeTestRule.runOnUiThread { isExpanded = true } }
    }

    /** テンプレート内の状態で行が展開するときも、行の高さの変化はアニメーションする。 */
    @Test
    fun rowHeightChangeFromTemplateStateAnimates() {
        var expandFirstRow: (() -> Unit)? = null
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(items = testItems(5), key = { it.id }, listSeparators = false) {
                    template { item ->
                        var isExpanded by remember { mutableStateOf(false) }
                        if (item.id == "item-0") {
                            expandFirstRow = { isExpanded = true }
                        }
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(if (isExpanded) ExpandedHeight else CollapsedHeight)
                                .testTag(item.id),
                        )
                    }
                }
            }
        }

        assertRowHeightAnimates { composeTestRule.runOnUiThread { expandFirstRow?.invoke() } }
    }

    /** グリッドでも行の高さの変化はアニメーションする。 */
    @Test
    fun rowHeightChangeAnimatesInGrid() {
        var isExpanded by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(6),
                    key = { it.id },
                    layout = KsLayout.Grid(columns = KsColumns.Fixed(2)),
                ) {
                    template { item ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(
                                    if (isExpanded && item.id == "item-0") {
                                        ExpandedHeight
                                    } else {
                                        CollapsedHeight
                                    },
                                )
                                .testTag(item.id),
                        )
                    }
                }
            }
        }

        // 2 列なので item-2 が 2 行目の先頭。1 行目の高さの変化に押されて下がる。
        assertRowHeightAnimates(followerTag = "item-2") {
            composeTestRule.runOnUiThread { isExpanded = true }
        }
    }

    /** ヘッダーの高さが変わるときも、その変化はアニメーションする。 */
    @Test
    fun headerHeightChangeAnimates() {
        var isExpanded by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    listSeparators = false,
                    header = {
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(if (isExpanded) ExpandedHeight else CollapsedHeight)
                                .testTag("header"),
                        )
                    },
                ) {
                    template { item ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(CollapsedHeight)
                                .testTag(item.id),
                        )
                    }
                }
            }
        }

        // ヘッダーの高さの変化に押されて、先頭の項目が下がる。
        assertRowHeightAnimates(followerTag = "item-0") {
            composeTestRule.runOnUiThread { isExpanded = true }
        }
    }

    /**
     * 折りたたむ途中で、行の中身の下端が行の下端から離れない。
     *
     * 行の高さだけが縮んで中身が先に縮み終わると、その間に何も描かれない帯ができる
     * (区切り線とタップ領域は途中の高さを使うため、中身との間が空く)。帯が出ないことを、
     * 毎フレームの「中身の下端」と「次の行の上端」の一致で見る。
     */
    @Test
    fun rowHeightCollapseKeepsContentBottomAtRowBottom() {
        var isExpanded by mutableStateOf(true)
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(items = testItems(5), key = { it.id }) {
                    template { item ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(
                                    if (isExpanded && item.id == "item-0") {
                                        ExpandedHeight
                                    } else {
                                        CollapsedHeight
                                    },
                                )
                                .testTag(item.id),
                        )
                    }
                }
            }
        }

        assertNear(ExpandedHeight, topOf("item-1"), "折りたたむ前は展開後の高さの分だけ下にある")

        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { isExpanded = false }

        val rowBottoms = mutableListOf<Dp>()
        val gaps = mutableListOf<Dp>()
        repeat(60) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            val rowBottom = topOf("item-1")
            rowBottoms += rowBottom
            gaps += rowBottom - bottomOf("item-0")
        }
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()

        val intermediates = rowBottoms.filter {
            it > CollapsedHeight + tolerance && it < ExpandedHeight - tolerance
        }
        assertTrue(
            "折りたたみも中間の高さを通る (実測 ${rowBottoms.map { it.value }})",
            intermediates.size >= 3,
        )
        assertTrue(
            "中身の下端と行の下端が全フレームで一致する (実測の差 ${gaps.map { it.value }})",
            gaps.all { abs(it.value) <= tolerance.value },
        )
        assertNear(CollapsedHeight, topOf("item-1"), "最終的に折りたたみ後の高さに落ち着く")
    }

    /**
     * 高さの制約に従わない content を持つテンプレートでも、補間の途中で content が行の外へ
     * 描かれない。
     *
     * 補間中は content を行の高さで測り直すが、`requiredHeight` のように制約を無視する content は
     * 測り直しても縮まない。描画の切り取りが効いていないと、次の行が描かれる領域まで content の
     * 色が出る。行の下端より下の画素を中間フレームごとに数えて判定する。
     */
    @Test
    fun rowHeightAnimationClipsContentIgnoringHeightConstraint() {
        var isExpanded by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    modifier = Modifier.testTag(CollectionTag).background(PageColor),
                    listSeparators = false,
                ) {
                    template { item ->
                        if (item.id == "item-0") {
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .requiredHeight(
                                        if (isExpanded) ExpandedHeight else CollapsedHeight,
                                    )
                                    .background(ContentColor),
                            )
                        } else {
                            Box(Modifier.fillMaxWidth().height(CollapsedHeight).testTag(item.id))
                        }
                    }
                }
            }
        }

        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { isExpanded = true }

        val overflows = mutableListOf<Int>()
        repeat(60) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            val rowBottom = topOf("item-1")
            if (rowBottom > CollapsedHeight + tolerance && rowBottom < ExpandedHeight - tolerance) {
                overflows += contentPixelCountBelow(rowBottom)
            }
        }
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()

        assertTrue(
            "補間の中間フレームが観測できている (実測 ${overflows.size} フレーム)",
            overflows.size >= 3,
        )
        assertTrue(
            "行の下端より下に content の画素が出ない (実測 $overflows)",
            overflows.all { it == 0 },
        )
    }

    /**
     * 項目が再利用されても、前にその位置に居た項目の高さや進行中の補間は持ち越さない。
     *
     * 補間を始めた直後に画面外へ送り、戻したときに最初のフレームから本来の高さで現れることを見る。
     */
    @Test
    fun reusedItemDoesNotInheritPreviousRowHeight() {
        var isExpanded by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(items = testItems(60), key = { it.id }, listSeparators = false) {
                    template { item ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .height(
                                    if (isExpanded && item.id == "item-0") {
                                        ExpandedHeight
                                    } else {
                                        CollapsedHeight
                                    },
                                )
                                .testTag(item.id),
                        )
                    }
                }
            }
        }

        // 補間の途中で画面外へ送る。
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { isExpanded = true }
        repeat(2) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
        }
        composeTestRule.mainClock.autoAdvance = true

        val list = composeTestRule.onNode(hasScrollAction())
        list.performScrollToIndex(59)
        composeTestRule.waitForIdle()

        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        list.performScrollToIndex(0)

        val heights = mutableListOf<Dp>()
        repeat(10) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            heights += bottomOf("item-0") - topOf("item-0")
        }
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()

        assertTrue(
            "再利用後は最初のフレームから本来の高さで現れる (実測 ${heights.map { it.value }})",
            heights.all { abs((ExpandedHeight - it).value) <= tolerance.value },
        )
    }

    /** 行の下端より下に content の色の画素がいくつ描かれているかを数える。 */
    private fun contentPixelCountBelow(rowBottom: Dp): Int {
        val image = composeTestRule.onNodeWithTag(CollectionTag).readPixels()
        val start = with(composeTestRule.density) { (rowBottom + 2.dp).roundToPx() }
        val end = with(composeTestRule.density) { (rowBottom + 40.dp).roundToPx() }
            .coerceAtMost(image.height - 1)
        if (start > end) return 0
        return (start..end).count { y -> image[10, y] == ContentColor }
    }

    /**
     * 展開の操作で下の行の位置が中間の値を通って動くことを確かめる。
     *
     * 最終状態だけを見るとアニメーションの有無を判別できないため、クロックの自動進行を止めて
     * フレームごとの位置を記録し、中間の位置が複数フレーム現れることを見る。
     *
     * @param followerTag 展開する行の下に来る行のタグ
     * @param expand 展開を起こす操作
     */
    private fun assertRowHeightAnimates(followerTag: String = "item-1", expand: () -> Unit) {
        val before = topOf(followerTag)
        assertNear(CollapsedHeight, before, "展開前は折りたたみ時の高さの分だけ下にある")

        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        expand()

        val samples = mutableListOf<Dp>()
        repeat(60) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            samples += topOf(followerTag)
        }
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()

        val intermediates = samples.filter {
            it > before + tolerance && it < ExpandedHeight - tolerance
        }
        assertTrue(
            "高さの変化が中間の位置を通る (実測 ${samples.map { it.value }})",
            intermediates.size >= 3,
        )
        assertTrue(
            "中間の位置は行きつ戻りつしない (実測 ${samples.map { it.value }})",
            samples.zipWithNext().all { (previous, next) -> next >= previous - tolerance },
        )
        assertNear(ExpandedHeight, topOf(followerTag), "最終的に展開後の高さに落ち着く")
    }

    private fun topOf(tag: String): Dp =
        composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot().top

    private fun bottomOf(tag: String): Dp =
        composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot().bottom

    private companion object {
        const val CollectionTag = "collection"

        /** 行の高さ変化の検証で使う、折りたたみ時と展開時の行の高さ。 */
        val CollapsedHeight = 80.dp
        val ExpandedHeight = 240.dp

        /** 切り取りの検証で使う、ページ背景と content の色。 */
        val PageColor = Color(0xFF0B1F3A)
        val ContentColor = Color(0xFFE23A2E)
    }
}

/**
 * ノードの描画結果を画素として読む。
 *
 * Compose 1.11 の `captureToImage()` は描画完了の待ち方が Robolectric に対応しておらず、
 * フレームの確定通知が来ないまま制限時間で失敗する (Robolectric 用の分岐は 1.12 で入った)。
 * ここではノードを載せている View を自前で Bitmap へ描き、ノードの矩形だけを切り出す。
 * 待ちを挟まない同期の描画なので、収束待ちの問題も持ち込まない。
 */
@OptIn(androidx.compose.ui.InternalComposeUiApi::class)
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

/** 向き別列数の宣言。コンテナの縦横比だけで列数が変わることを見る。 */
@androidx.compose.runtime.Composable
private fun OrientationGrid() {
    KsCollectionView(
        items = testItems(8),
        key = { it.id },
        layout = KsLayout.Grid(columns = KsColumns.Fixed(portrait = 2, landscape = 4)),
    ) {
        template { item ->
            Text(item.text, Modifier.fillMaxWidth().height(50.dp).testTag(item.id))
        }
    }
}
