package jp.kamusoft.kscollectionview

import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowLog

/**
 * グループ化 (グループの構成・見出し・固定・間隔・区切り線・差分・スクロール命令・位置の保持) の
 * 見え方を確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsCollectionViewGroupingTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 位置の比較に使う許容差 (端数丸めの吸収)。 */
    private val tolerance = 1.dp

    private val containerWidth = 300.dp
    private val containerHeight = 600.dp
    private val rowHeight = 50.dp
    private val headerHeight = 30.dp

    @Before
    fun setUp() {
        ShadowLog.clear()
    }

    @After
    fun tearDown() {
        KsDiagnostics.debugOverride = null
    }

    // ---- グループの構成と見出し ----

    /** 続いた同じ値が 1 つのグループになり、各グループの先頭行の前に値と件数の見出しが出る。 */
    @Test
    fun consecutiveValuesFormGroupsWithHeaders() {
        setGroupedContent(foods("果物" to 2, "野菜" to 3))

        onHeader("果物").assertTextEquals("果物 2")
        onHeader("野菜").assertTextEquals("野菜 3")
        assertNear(0.dp, topOf("header-果物"), "最初の見出しはコンテンツの先頭")
        assertNear(bottomOf("header-果物"), topOf("果物-0"), "見出しの直後に先頭行")
        assertNear(bottomOf("果物-1"), topOf("header-野菜"), "前のグループの最終行の直後に次の見出し")
        assertNear(bottomOf("header-野菜"), topOf("野菜-0"), "見出しの直後に先頭行")
    }

    /** グループを指定しなければ見出しは出ず、全要素が 1 続きで並ぶ。 */
    @Test
    fun withoutGroupsItemsAreContiguous() {
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(items = foods("果物" to 2, "野菜" to 1), key = { it.id }, listSeparators = false) {
                    template { food -> FoodRow(food) }
                }
            }
        }

        assertEquals(0, composeTestRule.countNodesWithTag("header-果物"))
        assertNear(bottomOf("果物-1"), topOf("野菜-0"), "グループの区切りは無い")
    }

    /** 項目のキーとグループの値が同じ値でも、重複キーにならず見出しと項目がどちらも出る。 */
    @Test
    fun groupValueEqualToItemKeyDoesNotCollide() {
        KsDiagnostics.debugOverride = true
        val items = listOf(Food(id = "果物", category = "果物"), Food(id = "りんご", category = "果物"))

        setGroupedContent(items)

        onHeader("果物").assertIsDisplayed()
        composeTestRule.onNodeWithTag("果物").assertIsDisplayed()
        composeTestRule.onNodeWithTag("りんご").assertIsDisplayed()
    }

    /** 離れて現れた同じグループの値は debug ビルドでは停止する。 */
    @Test
    fun separatedGroupValueStopsInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            setGroupedContent(separatedFoods())
        }
    }

    /**
     * 離れて現れた同じグループの値は release ビルドでは落ちず、配列の順のまま 3 つのグループとして
     * 全項目が表示され、警告ログが出る。
     */
    @Test
    fun separatedGroupValueContinuesInRelease() {
        KsDiagnostics.debugOverride = false

        setGroupedContent(separatedFoods(), headerTag = { value, _ -> "header-$value-${headerIndex++}" })

        val headers = composeTestRule.onAllHeaders()
        assertEquals("見出しは 3 つ", listOf("果物 1", "野菜 1", "果物 1"), headers)
        for (id in listOf("果物-0", "野菜-0", "果物2-0")) {
            composeTestRule.onNodeWithTag(id).assertIsDisplayed()
        }
        assertTrue("2 つめの果物は野菜の後", topOf("果物2-0") > topOf("野菜-0"))
        assertWarned("離れた位置")
    }

    /** 状態保存に載せられないグループの値は debug ビルドでは停止する。 */
    @Test
    fun unsavableGroupValueStopsInDebug() {
        KsDiagnostics.debugOverride = true
        val unsavable = Any()

        assertThrows(IllegalStateException::class.java) {
            composeTestRule.setContent {
                TestContainer(containerWidth, containerHeight) {
                    KsCollectionView(
                        items = foods("果物" to 2),
                        key = { it.id },
                        groups = KsGroups(by = { unsavable }),
                    ) {
                        template { food -> FoodRow(food) }
                    }
                }
            }
        }
    }

    /** グリッドでは見出しが全幅を占め、グループの先頭の項目は見出しの次の行の行頭に置かれる。 */
    @Test
    fun gridHeaderSpansFullWidthAndGroupStartsAtLineStart() {
        setGroupedContent(foods("果物" to 3, "野菜" to 2), layout = KsLayout.Grid(KsColumns.Fixed(2)))

        assertNear(containerWidth, widthOf("header-野菜"), "見出しは全幅")
        assertNear(0.dp, leftOf("果物-2"), "奇数件のグループの最終行は 1 列")
        assertNear(bottomOf("果物-2"), topOf("header-野菜"), "最終行の後に次の見出し")
        assertNear(0.dp, leftOf("野菜-0"), "次のグループの先頭は行頭")
        assertNear(bottomOf("header-野菜"), topOf("野菜-0"), "見出しの次の行")
    }

    /** 見出しのないグループでも、グループの先頭の項目は行頭に置かれ、最終行の項目は 1 列分の幅のまま。 */
    @Test
    fun headerlessGroupStartsOnNewLineInGrid() {
        setGroupedContent(
            foods("果物" to 3, "野菜" to 2),
            layout = KsLayout.Grid(KsColumns.Fixed(2)),
            withHeader = false,
        )

        assertNear(0.dp, leftOf("野菜-0"), "次のグループの先頭は行頭")
        assertNear(bottomOf("果物-2"), topOf("野菜-0"), "前のグループの最終行の次の行")
        assertNear(containerWidth / 2, widthOf("果物-2"), "行の残りを占める項目も 1 列分の幅")
        assertNear(0.dp, leftOf("果物-2"), "1 列目に置かれる")
    }

    /** ルートのヘッダーは最初の見出しより前に、フッターは最後のグループの最終行より後に出る。 */
    @Test
    fun rootHeaderAndFooterSurroundGroups() {
        setGroupedContent(foods("果物" to 2, "野菜" to 2), rootHeader = true, rootFooter = true)

        assertNear(0.dp, topOf("root-header"), "ヘッダーは先頭")
        assertNear(bottomOf("root-header"), topOf("header-果物"), "最初の見出しはヘッダーの後")
        assertNear(bottomOf("野菜-1"), topOf("root-footer"), "フッターは最後のグループの最終行の後")
    }

    /** 件数が変わると見出しの内容が更新され、見出しは作り直されない。 */
    @Test
    fun headerContentUpdatesWithoutRecreation() {
        var items by mutableStateOf(foods("果物" to 2, "野菜" to 1))
        var headerCreations = 0
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    groups = KsGroups(by = { it.category }) { category, foodsInGroup ->
                        remember(category) { headerCreations++ }
                        HeaderText(category, "$category ${foodsInGroup.size}")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }
        onHeader("果物").assertTextEquals("果物 2")
        val createdBefore = headerCreations

        composeTestRule.runOnUiThread { items = foods("果物" to 3, "野菜" to 1) }
        composeTestRule.waitForIdle()

        onHeader("果物").assertTextEquals("果物 3")
        assertEquals("見出しは作り直されない", createdBefore, headerCreations)
    }

    // ---- グループの値の取り出し方の差し替え ----

    /** 同じ配列のままラムダを別の区切り方に切り替えると、見出しと境目が新しい構成で表示される。 */
    @Test
    fun switchingGroupValueLambdaRegroupsSameItems() {
        val items = foods("果物" to 2, "野菜" to 3)
        val firstHalf = setOf("果物-0", "果物-1", "野菜-0")
        var byHalf by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                val by: (Food) -> String = if (byHalf) {
                    { food -> if (food.id in firstHalf) "前半" else "後半" }
                } else {
                    { food -> food.category }
                }
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    listSeparators = false,
                    groups = KsGroups(by = by) { group, foodsInGroup ->
                        HeaderText("header-$group", "$group ${foodsInGroup.size}")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }
        composeTestRule.waitForIdle()
        onHeader("果物").assertTextEquals("果物 2")

        composeTestRule.runOnUiThread { byHalf = true }
        composeTestRule.waitForIdle()

        assertEquals("古いグループの見出しは残らない", 0, composeTestRule.countNodesWithTag("header-果物"))
        assertEquals("古いグループの見出しは残らない", 0, composeTestRule.countNodesWithTag("header-野菜"))
        assertEquals(listOf("前半 3", "後半 2"), composeTestRule.onAllHeaders())
        assertNear(0.dp, topOf("header-前半"), "最初の見出しはコンテンツの先頭")
        assertNear(bottomOf("header-前半"), topOf("果物-0"), "見出しの直後に先頭行")
        assertNear(bottomOf("野菜-0"), topOf("header-後半"), "新しい境目に次の見出し")
        assertNear(bottomOf("header-後半"), topOf("野菜-1"), "見出しの直後に先頭行")
    }

    /**
     * 同じグループの値を返す別のラムダに差し替えても、グループの構成は組み直さない。無関係な
     * 再コンポーズでも組み直さない。
     */
    @Test
    fun equivalentGroupValueLambdaDoesNotRegroup() {
        val items = foods("果物" to 2, "野菜" to 3)
        var useAlias by mutableStateOf(false)
        var unrelated by mutableStateOf(0)
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                val by: (Food) -> String = if (useAlias) {
                    { food -> food.id.substringBefore('-') }
                } else {
                    { food -> food.category }
                }
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    listSeparators = false,
                    groups = KsGroups(by = by) { group, foodsInGroup ->
                        HeaderText("header-$group", "$group ${foodsInGroup.size} ($unrelated)")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }
        composeTestRule.waitForIdle()
        val appliedBefore = KsGroupingProbe.appliedPlanCount

        composeTestRule.runOnUiThread { unrelated = 1 }
        composeTestRule.waitForIdle()
        onHeader("果物").assertTextEquals("果物 2 (1)")
        composeTestRule.runOnUiThread { useAlias = true }
        composeTestRule.waitForIdle()

        assertEquals("グループの値が同じなのに組み直しています", appliedBefore, KsGroupingProbe.appliedPlanCount)
        assertEquals(listOf("果物 2 (1)", "野菜 3 (1)"), composeTestRule.onAllHeaders())
    }

    /**
     * 等しいが中身の違うグループの値 (ID で比べ、表示名を持つ) を返すラムダに切り替えると、構成は
     * 組み直さずに、見出しには新しいグループの値が渡る。
     */
    @Test
    fun equalButDifferentGroupValueReachesHeader() {
        val items = foods("果物" to 2, "野菜" to 3)
        var renamed by mutableStateOf(false)
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                val by: (Food) -> Category = if (renamed) {
                    { food -> Category(food.category, "新しい${food.category}") }
                } else {
                    { food -> Category(food.category, food.category) }
                }
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    listSeparators = false,
                    groups = KsGroups(by = by) { category, foodsInGroup ->
                        HeaderText("header-${category.id}", "${category.label} ${foodsInGroup.size}")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }
        composeTestRule.waitForIdle()
        assertEquals(listOf("果物 2", "野菜 3"), composeTestRule.onAllHeaders())
        val appliedBefore = KsGroupingProbe.appliedPlanCount

        composeTestRule.runOnUiThread { renamed = true }
        composeTestRule.waitForIdle()

        assertEquals(listOf("新しい果物 2", "新しい野菜 3"), composeTestRule.onAllHeaders())
        assertEquals("グループの値が等しいので組み直さない", appliedBefore, KsGroupingProbe.appliedPlanCount)
    }

    /** 同じ ID で内容だけ変わった項目の配列に差し替えると、見出しには新しい項目が渡る。 */
    @Test
    fun sameIdItemsWithNewContentReachHeader() {
        var items by mutableStateOf(pricedFoods(price = 100))
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    listSeparators = false,
                    groups = KsGroups(by = { it.category }) { category, foodsInGroup ->
                        HeaderText("header-$category", "$category ${foodsInGroup.sumOf { it.price }}")
                    },
                ) {
                    template { food -> Text(food.id, Modifier.fillMaxWidth().height(rowHeight)) }
                }
            }
        }
        composeTestRule.waitForIdle()
        assertEquals(listOf("果物 200", "野菜 300"), composeTestRule.onAllHeaders())

        composeTestRule.runOnUiThread { items = pricedFoods(price = 150) }
        composeTestRule.waitForIdle()

        assertEquals(listOf("果物 300", "野菜 450"), composeTestRule.onAllHeaders())
    }

    // ---- 見出しの固定 ----

    /** 固定の設定を指定しなければ、グループの途中までスクロールしても見出しが上端に表示される。 */
    @Test
    fun headersArePinnedByDefault() {
        setGroupedContent(foods("果物" to 30, "野菜" to 30))

        scrollToLazyIndex(10)

        onHeader("果物").assertIsDisplayed()
        assertNear(0.dp, topOf("header-果物"), "見出しは上端に固定される")
    }

    /** 次の見出しが上端に達すると、固定中の見出しは押し上げられ、入れ替わる。 */
    @Test
    fun nextHeaderPushesPinnedHeader() {
        setGroupedContent(foods("果物" to 30, "野菜" to 30))

        // 2 つめの見出しの上端を表示範囲の上端から 10dp の位置に置く (押し上げの途中)。
        scrollToLazyIndex(31)
        scrollBy(-10.dp)
        assertNear(10.dp, topOf("header-野菜"), "2 つめの見出しは上端の少し下")
        assertNear(topOf("header-野菜"), bottomOf("header-果物"), "最初の見出しは 2 つめに押し上げられる")
        assertEquals(
            "押し上げられている間も最初の見出しは薄れない (見出しの背景色のまま)",
            HeaderBackground,
            collectionPixels()[250, 5],
        )

        scrollToLazyIndex(40)
        assertNear(0.dp, topOf("header-野菜"), "2 つめの見出しが上端に固定される")
        assertEquals("最初の見出しは表示範囲の外へ出る", 0, composeTestRule.countNodesWithTag("header-果物"))
    }

    /**
     * グリッドでグループの最後の行の最後の項目が同じ行の他の項目より低くても、固定中の見出しは
     * 次の見出しと接するまで上端に留まり、そこから押し上げられる (上端に見出しの無い帯ができない)。
     */
    @Test
    fun pushStartsAtNextHeaderEvenWhenLastItemOfGridRowIsShorter() {
        // 果物の最後の行は左 (果物-8) が高く、右の最後の項目 (果物-9) が低い。
        tallFoodIds = setOf("果物-8")
        setGroupedContent(foods("果物" to 10, "野菜" to 30), layout = KsLayout.Grid(KsColumns.Fixed(2)))

        // 2 つめの見出しを上端から (見出しの高さ + 20dp) 下に置く: まだ押し上げられない。
        scrollToLazyIndex(11)
        scrollBy(-(headerHeight + 20.dp))
        assertNear(headerHeight + 20.dp, topOf("header-野菜"), "2 つめの見出しは上端から見出しの高さ + 20dp 下")
        assertNear(rowHeight + 60.dp, heightOf("果物-8"), "最後の行の左の項目は高い")
        assertNear(topOf("果物-8"), topOf("果物-9"), "最後の行の 2 項目は同じ行にある")
        assertNear(0.dp, topOf("header-果物"), "最初の見出しは上端に固定されたまま")

        // 2 つめの見出しを上端から 20dp 下に置く: 押し上げられ、2 つの見出しが接する。
        scrollBy(headerHeight)
        assertNear(20.dp, topOf("header-野菜"), "2 つめの見出しは上端から 20dp 下")
        assertNear(topOf("header-野菜"), bottomOf("header-果物"), "最初の見出しは 2 つめと接して押し上げられる")
    }

    /** 固定を外すと、見出しはコンテンツと一緒にスクロールして表示範囲の外へ出る。 */
    @Test
    fun unpinnedHeaderScrollsAway() {
        setGroupedContent(foods("果物" to 30, "野菜" to 30), pinned = false)

        scrollToLazyIndex(10)

        onHeader("果物").assertIsNotDisplayed()
    }

    // ---- 間隔 ----

    /** 既定では見出しの前後に間隔は無く、行と行の間にだけ行間が入る。 */
    @Test
    fun rowSpacingIsOnlyBetweenRows() {
        setGroupedContent(
            foods("果物" to 2, "野菜" to 2),
            layout = KsLayout.List(rowSpacing = 6.dp),
        )

        assertNear(bottomOf("header-果物"), topOf("果物-0"), "見出しと先頭行の間に行間は無い")
        assertNear(6.dp, topOf("果物-1") - bottomOf("果物-0"), "行と行の間に行間")
        assertNear(bottomOf("果物-1"), topOf("header-野菜"), "最終行と次の見出しの間に行間は無い")
    }

    /** グループ間の間隔と見出しの下の間隔を指定すると、それぞれの位置に入り、コンテンツの先頭と末尾には入らない。 */
    @Test
    fun groupAndHeaderItemSpacingAreApplied() {
        setGroupedContent(
            foods("果物" to 3, "野菜" to 3),
            layout = KsLayout.Grid(
                columns = KsColumns.Fixed(2),
                rowSpacing = 4.dp,
                groupSpacing = 24.dp,
                headerItemSpacing = 8.dp,
            ),
        )

        assertNear(0.dp, topOf("header-果物"), "コンテンツの先頭にグループ間の間隔は入らない")
        assertNear(8.dp, topOf("果物-0") - bottomOf("header-果物"), "見出しの下の間隔")
        assertNear(4.dp, topOf("果物-2") - bottomOf("果物-0"), "行と行の間は行間")
        assertNear(24.dp, topOf("header-野菜") - bottomOf("果物-2"), "グループ間の間隔")
        assertNear(8.dp, topOf("野菜-0") - bottomOf("header-野菜"), "見出しの下の間隔")
    }

    /** グループ間の間隔はコンテンツの末尾に入らない。 */
    @Test
    fun groupSpacingIsNotAddedAtContentEnd() {
        setGroupedContent(
            foods("果物" to 10, "野菜" to 10),
            layout = KsLayout.List(groupSpacing = 24.dp),
        )

        scrollToLazyIndex(21)

        assertNear(containerHeight, bottomOf("野菜-9"), "最終行の下端がコンテンツの末尾")
    }

    /** グループ間の間隔は固定中の見出しと一緒に上端に貼り付かない。 */
    @Test
    fun spacingDoesNotStickWithPinnedHeader() {
        setGroupedContent(
            foods("果物" to 30, "野菜" to 30),
            layout = KsLayout.List(groupSpacing = 24.dp, headerItemSpacing = 8.dp),
        )

        scrollToLazyIndex(10)

        assertNear(0.dp, topOf("header-果物"), "見出しは上端に固定される (上に空白を持たない)")
        assertNear(headerHeight, heightOf("header-果物"), "見出しは自分の高さのまま (下に空白を持たない)")
    }

    /** 負のグループ間の間隔・見出しの下の間隔は不正入力として検出される。 */
    @Test
    fun negativeGroupSpacingsAreInvalid() {
        assertTrue(KsLayout.List(groupSpacing = (-1).dp).invalidValueMessages().isNotEmpty())
        assertTrue(KsLayout.List(headerItemSpacing = (-1).dp).invalidValueMessages().isNotEmpty())
        assertTrue(
            KsLayout.Grid(KsColumns.Fixed(2), groupSpacing = (-1).dp).invalidValueMessages().isNotEmpty(),
        )
        assertTrue(
            KsLayout.Grid(KsColumns.Fixed(2), headerItemSpacing = (-1).dp).invalidValueMessages().isNotEmpty(),
        )
    }

    /** 負の間隔は debug ビルドでは停止する。 */
    @Test
    fun negativeGroupSpacingStopsInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            setGroupedContent(foods("果物" to 2), layout = KsLayout.List(groupSpacing = (-4).dp))
        }
    }

    /** 負の間隔は release ビルドでは 0 として表示を継続し、警告ログを出す。 */
    @Test
    fun negativeGroupSpacingIsZeroInRelease() {
        KsDiagnostics.debugOverride = false

        setGroupedContent(
            foods("果物" to 2, "野菜" to 2),
            layout = KsLayout.List(groupSpacing = (-4).dp, headerItemSpacing = (-4).dp),
        )

        assertNear(bottomOf("果物-1"), topOf("header-野菜"), "グループ間の間隔は 0")
        assertNear(bottomOf("header-果物"), topOf("果物-0"), "見出しの下の間隔は 0")
        assertWarned("groupSpacing")
        assertWarned("headerItemSpacing")
    }

    // ---- 区切り線 ----

    /** 見出しつきのグループでは、各グループの先頭行の上端・行の間・最終行の下端に線があり、見出しはその間にある。 */
    @Test
    fun separatorsSurroundEachGroupWithHeaders() {
        setGroupedContent(foods("果物" to 2, "野菜" to 2), itemBackground = Color.White)

        val image = collectionPixels()
        val color = KsListSeparatorDefaults.color
        // 0-30: 果物の見出し / 30-80, 80-130: 果物 / 130-160: 野菜の見出し / 160-210, 210-260: 野菜
        assertEquals("果物の先頭行の上端", color, image[10, 30])
        assertEquals("果物の行の間", color, image[10, 79])
        assertEquals("果物の最終行の下端", color, image[10, 129])
        assertNotEquals("見出しの中には線が無い", color, image[10, 145])
        assertEquals("野菜の先頭行の上端", color, image[10, 160])
        assertEquals("野菜の最終行の下端", color, image[10, 259])
    }

    /** 見出しを宣言しないグループの境目には線が 1 本だけ出る。 */
    @Test
    fun headerlessGroupBoundaryHasSingleSeparator() {
        setGroupedContent(foods("果物" to 2, "野菜" to 2), withHeader = false, itemBackground = Color.White)

        val image = collectionPixels()
        val color = KsListSeparatorDefaults.color
        // 0-50, 50-100: 果物 / 100-150, 150-200: 野菜
        assertEquals("最初のグループの先頭行の上端", color, image[10, 0])
        assertEquals("境目の線 (果物の最終行の下端)", color, image[10, 99])
        assertNotEquals("境目に 2 本目の線は無い", color, image[10, 100])
        assertEquals("最後の行の下端", color, image[10, 199])
    }

    // ---- 差分 ----

    /** グループの値を変えた項目は新しいグループへ移って表示される。 */
    @Test
    fun itemMovesToAnotherGroup() {
        val fruits = foods("果物" to 2)
        val vegetables = foods("野菜" to 2)
        var items by mutableStateOf(fruits + vegetables)
        setGroupedContent(itemsProvider = { items })

        val moved = fruits[1].copy(category = "野菜")
        composeTestRule.runOnUiThread { items = listOf(fruits[0], moved) + vegetables }
        composeTestRule.waitForIdle()

        onHeader("果物").assertTextEquals("果物 1")
        onHeader("野菜").assertTextEquals("野菜 3")
        assertTrue("移した項目は野菜の見出しより後", topOf("果物-1") >= bottomOf("header-野菜") - tolerance)
    }

    /** グループの並び順を反転すると、見出しがそれぞれのグループの項目と一緒に移動する。 */
    @Test
    fun reversingGroupsMovesHeadersWithItems() {
        val fruits = foods("果物" to 2)
        val vegetables = foods("野菜" to 2)
        var items by mutableStateOf(fruits + vegetables)
        setGroupedContent(itemsProvider = { items })

        composeTestRule.runOnUiThread { items = vegetables + fruits }
        composeTestRule.waitForIdle()

        assertNear(0.dp, topOf("header-野菜"), "野菜の見出しが先頭")
        assertNear(bottomOf("header-野菜"), topOf("野菜-0"), "野菜の項目は野菜の見出しの後")
        assertNear(bottomOf("野菜-1"), topOf("header-果物"), "果物の見出しは野菜の後")
        assertNear(bottomOf("header-果物"), topOf("果物-0"), "果物の項目は果物の見出しの後")
    }

    /** 最後の項目が消えたグループは見出しごと消える。 */
    @Test
    fun emptiedGroupLosesItsHeader() {
        var items by mutableStateOf(foods("果物" to 2, "肉" to 1))
        setGroupedContent(itemsProvider = { items })
        onHeader("肉").assertIsDisplayed()

        composeTestRule.runOnUiThread { items = foods("果物" to 2) }
        composeTestRule.waitForIdle()

        assertEquals(0, composeTestRule.countNodesWithTag("header-肉"))
    }

    /** 見出しは差分の間も同じキーで保たれる (グループの並べ替えで作り直されない)。 */
    @Test
    fun headersKeepIdentityAcrossReordering() {
        val fruits = foods("果物" to 2)
        val vegetables = foods("野菜" to 2)
        var items by mutableStateOf(fruits + vegetables)
        val creations = mutableMapOf<String, Int>()
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    groups = KsGroups(by = { it.category }) { category, foodsInGroup ->
                        remember { creations[category] = (creations[category] ?: 0) + 1 }
                        HeaderText(category, "$category ${foodsInGroup.size}")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }

        composeTestRule.runOnUiThread { items = vegetables + fruits }
        composeTestRule.waitForIdle()

        assertEquals("見出しは作り直されない", mapOf("果物" to 1, "野菜" to 1), creations)
    }

    // ---- スクロール命令 ----

    /** ID で先頭へ送る命令は、項目を固定中の見出しのすぐ下に置く。 */
    @Test
    fun scrollToItemPlacesItBelowPinnedHeader() {
        val controller = KsScrollController()
        setGroupedContent(
            foods("果物" to 30, "野菜" to 30),
            controller = controller,
            layout = KsLayout.List(rowSpacing = 4.dp),
        )

        composeTestRule.runOnUiThread { controller.scrollTo(id = "野菜-10", animated = false) }
        awaitCommands(controller, 1)

        assertNear(0.dp, topOf("header-野菜"), "項目のグループの見出しが上端に固定される")
        assertNear(bottomOf("header-野菜"), topOf("野菜-10"), "項目は見出しのすぐ下")
    }

    /** アニメーションつきの命令でも、項目は固定中の見出しのすぐ下に着く。 */
    @Test
    fun animatedScrollToItemPlacesItBelowPinnedHeader() {
        val controller = KsScrollController()
        setGroupedContent(foods("果物" to 30, "野菜" to 30), controller = controller)

        composeTestRule.runOnUiThread { controller.scrollTo(id = "野菜-10") }
        awaitCommands(controller, 1)

        assertNear(bottomOf("header-野菜"), topOf("野菜-10"), "項目は見出しのすぐ下")
    }

    /** 最後のグループの項目への命令と末尾への命令は、グループをまたいで解決される。 */
    @Test
    fun scrollCommandsResolveAcrossGroups() {
        val controller = KsScrollController()
        setGroupedContent(foods("果物" to 30, "野菜" to 30, "肉" to 30), controller = controller)

        composeTestRule.runOnUiThread { controller.scrollTo(id = "肉-20", position = KsScrollPosition.Center) }
        awaitCommands(controller, 1)
        composeTestRule.onNodeWithTag("肉-20").assertIsDisplayed()
        assertNear(containerHeight / 2, (topOf("肉-20") + bottomOf("肉-20")) / 2, "中央に置かれる")

        composeTestRule.runOnUiThread { controller.scrollToEnd() }
        awaitCommands(controller, 2)
        assertNear(containerHeight, bottomOf("肉-29"), "末尾の項目が表示範囲の下端")
    }

    // ---- 回転と列数の変化 ----

    /** 縦長から横長に変わって列数が変わっても、表示範囲の先頭にあった項目は固定中の見出しのすぐ下に戻る。 */
    @Test
    fun columnChangeKeepsLeadingItemBelowPinnedHeader() {
        var width by mutableStateOf(300.dp)
        var height by mutableStateOf(600.dp)
        val controller = KsScrollController()
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = foods("果物" to 80, "野菜" to 80),
                    key = { it.id },
                    layout = KsLayout.Grid(KsColumns.Fixed(portrait = 2, landscape = 4)),
                    scrollController = controller,
                    groups = KsGroups(by = { it.category }) { category, foodsInGroup ->
                        HeaderText(category, "$category ${foodsInGroup.size}")
                    },
                ) {
                    template { food -> FoodRow(food) }
                }
            }
        }
        composeTestRule.runOnUiThread { controller.scrollTo(id = "果物-42", animated = false) }
        awaitCommands(controller, 1)
        // 見出しの裏に隠れた行 (果物-40, 41) と X (果物-42) は、4 列では同じ行になる。既定の位置の
        // 保ち方 (隠れた項目の行を先頭に保つ) では X が見出しの裏に隠れる条件にする。
        assertNear(bottomOf("header-果物"), topOf("果物-42"), "縦長で見出しのすぐ下に X")

        composeTestRule.runOnUiThread {
            width = 400.dp
            height = 300.dp
        }
        composeTestRule.waitForIdle()

        assertNear(0.dp, topOf("header-果物"), "見出しは上端に固定されたまま")
        assertNear(bottomOf("header-果物"), topOf("果物-42"), "横長でも見出しのすぐ下の行に X")
        assertNear(200.dp, leftOf("果物-42"), "X は 4 列 (幅 100) の 3 列目")
    }

    // ---- 端を表示中の端への挿入 ----

    /** list で先頭を表示中に配列の先頭へ挿入すると、先頭に留まり挿入した項目が表示される。 */
    @Test
    fun insertionAtStartWhileShowingStartStaysAtStartInList() {
        assertInsertionAtStartStaysAtStart(KsLayout.List)
    }

    /** グリッドで先頭を表示中に配列の先頭へ挿入すると、先頭に留まり挿入した項目が表示される。 */
    @Test
    fun insertionAtStartWhileShowingStartStaysAtStartInGrid() {
        assertInsertionAtStartStaysAtStart(KsLayout.Grid(KsColumns.Fixed(2)))
    }

    /** list で末尾を表示中に配列の末尾へ挿入すると、末尾に留まり挿入した項目が表示される。 */
    @Test
    fun insertionAtEndWhileShowingEndStaysAtEndInList() {
        assertInsertionAtEndStaysAtEnd(KsLayout.List)
    }

    /** グリッドで末尾を表示中に配列の末尾へ挿入すると、末尾に留まり挿入した項目が表示される。 */
    @Test
    fun insertionAtEndWhileShowingEndStaysAtEndInGrid() {
        assertInsertionAtEndStaysAtEnd(KsLayout.Grid(KsColumns.Fixed(2)))
    }

    private fun assertInsertionAtStartStaysAtStart(layout: KsLayout) {
        var items by mutableStateOf(testItems(40))
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(items = items, key = { it.id }, layout = layout, listSeparators = false) {
                    template { item -> Box(Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) }
                }
            }
        }

        composeTestRule.runOnUiThread { items = listOf(TestItem("new", "new")) + items }
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithTag("new").assertIsDisplayed()
        assertNear(0.dp, topOf("new"), "挿入した項目が先頭に表示される")
        assertTrue("元の先頭は後ろへずれる", topOf("item-0") > 0.dp || leftOf("item-0") > 0.dp)
    }

    private fun assertInsertionAtEndStaysAtEnd(layout: KsLayout) {
        // 奇数件にして、グリッドでは末尾への挿入で最終行が埋まる (行が増えない) 場合も通す。
        var items by mutableStateOf(testItems(41))
        val controller = KsScrollController()
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    layout = layout,
                    scrollController = controller,
                    listSeparators = false,
                ) {
                    template { item -> Box(Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) }
                }
            }
        }
        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        awaitCommands(controller, 1)

        composeTestRule.runOnUiThread { items = items + TestItem("new", "new") + TestItem("new2", "new2") }
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithTag("new2").assertIsDisplayed()
        assertNear(containerHeight, bottomOf("new2"), "挿入した項目が末尾に表示される")
    }

    /** ルートのフッターの下端まで表示中に末尾へ挿入すると、フッターの下端に留まり、挿入した項目がフッターの前に出る。 */
    @Test
    fun insertionAtEndWithFooterStaysAtFooterBottom() {
        var items by mutableStateOf(testItems(40))
        val controller = KsScrollController()
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    scrollController = controller,
                    footer = { Box(Modifier.fillMaxWidth().height(40.dp).testTag("root-footer")) },
                    listSeparators = false,
                ) {
                    template { item -> Box(Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) }
                }
            }
        }
        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        awaitCommands(controller, 1)

        composeTestRule.runOnUiThread { items = items + TestItem("new", "new") }
        composeTestRule.waitForIdle()

        assertNear(containerHeight, bottomOf("root-footer"), "フッターの下端に留まる")
        assertNear(topOf("root-footer"), bottomOf("new"), "挿入した項目はフッターの前")
    }

    /** グループありで、最初のグループの先頭と最後のグループの末尾への挿入も端に留まる。 */
    @Test
    fun insertionAtGroupEdgesStaysAtEdges() {
        var items by mutableStateOf(foods("果物" to 20, "野菜" to 20))
        val controller = KsScrollController()
        setGroupedContent(itemsProvider = { items }, controller = controller)

        composeTestRule.runOnUiThread { items = listOf(Food("果物-new", "果物")) + items }
        composeTestRule.waitForIdle()
        assertNear(bottomOf("header-果物"), topOf("果物-new"), "最初のグループの先頭に表示される")

        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        awaitCommands(controller, 1)
        composeTestRule.runOnUiThread { items = items + Food("野菜-new", "野菜") }
        composeTestRule.waitForIdle()
        assertNear(containerHeight, bottomOf("野菜-new"), "最後のグループの末尾に表示される")
    }

    // ---- 差分と端への挿入のアニメーション ----

    /** グループの並び順を反転すると、見出しは新しい位置へ飛ばず、途中の位置を通って動く。 */
    @Test
    fun reversingGroupsAnimatesHeaders() {
        val fruits = foods("果物" to 2)
        val vegetables = foods("野菜" to 2)
        var items by mutableStateOf(fruits + vegetables)
        setGroupedContent(itemsProvider = { items })
        val before = topOf("header-野菜")

        val tops = recordFrames(frames = 40, change = { items = vegetables + fruits }) { topOf("header-野菜") }

        assertIntermediate(tops, from = before, to = 0.dp, "野菜の見出しは途中の位置を通って先頭へ動く")
        assertNear(0.dp, topOf("header-野菜"), "最終的に先頭へ着く")
    }

    /** 固定中の見出しも、グループの消滅で後ろの見出しが繰り上がるときに途中の位置を通って動く。 */
    @Test
    fun pinnedHeaderAnimatesWhenPreviousGroupDisappears() {
        var items by mutableStateOf(foods("肉" to 1, "果物" to 3))
        setGroupedContent(itemsProvider = { items })
        val before = topOf("header-果物")

        val tops = recordFrames(frames = 40, change = { items = foods("果物" to 3) }) { topOf("header-果物") }

        assertIntermediate(tops, from = before, to = 0.dp, "果物の見出しは途中の位置を通って先頭へ動く")
    }

    /** いちばん上で先頭へ挿入すると、元の先頭の項目は途中の位置を通って後ろへずれ、挿入した項目が先頭に出る。 */
    @Test
    fun insertionAtStartAnimatesWhileShowingStart() {
        var items by mutableStateOf(testItems(40))
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(items = items, key = { it.id }, listSeparators = false) {
                    template { item -> Box(Modifier.fillMaxWidth().height(rowHeight).testTag(item.id)) }
                }
            }
        }

        val tops = recordFrames(frames = 40, change = { items = listOf(TestItem("new", "new")) + items }) {
            topOf("item-0")
        }

        assertIntermediate(tops, from = 0.dp, to = rowHeight, "元の先頭は途中の位置を通って後ろへずれる")
        assertNear(0.dp, topOf("new"), "挿入した項目が先頭に出る")
    }

    /**
     * いちばん下で末尾へ挿入すると、表示範囲は一瞬で飛ばず、数フレームかけて末尾まで進み、挿入した項目は
     * フェードで現れる (list)。
     */
    @Test
    fun insertionAtEndFollowsSmoothlyAndFadesInList() {
        assertInsertionAtEndAnimates(KsLayout.List, initialCount = 40)
    }

    /** グリッドで末尾に新しい行ができる挿入でも、表示範囲は数フレームかけて進み、挿入した項目はフェードで現れる。 */
    @Test
    fun insertionAtEndFollowsSmoothlyAndFadesInGrid() {
        // 偶数件の 2 列グリッドに 1 件足し、新しい行ができる条件にする。
        assertInsertionAtEndAnimates(KsLayout.Grid(KsColumns.Fixed(2)), initialCount = 40)
    }

    /** グリッドで最終行の空きに入る末尾への挿入は、表示範囲を動かさずにその場でフェードで現れる。 */
    @Test
    fun insertionIntoLastRowGapFadesInPlace() {
        var items by mutableStateOf(testItems(41))
        val controller = KsScrollController()
        setInsertionContent(KsLayout.Grid(KsColumns.Fixed(2)), itemsProvider = { items }, controller = controller)
        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        awaitCommands(controller, 1)
        val lastBottom = bottomOf("item-40")

        val colors = recordFrames(frames = 40, change = { items = items + TestItem("new", "new") }) {
            if (composeTestRule.countNodesWithTag("new") == 0) null else pixelAtCenter("new")
        }

        assertNear(lastBottom, bottomOf("item-40"), "表示範囲は動かない")
        assertFadesIn(colors)
    }

    private fun assertInsertionAtEndAnimates(layout: KsLayout, initialCount: Int) {
        var items by mutableStateOf(testItems(initialCount))
        val controller = KsScrollController()
        setInsertionContent(layout, itemsProvider = { items }, controller = controller)
        composeTestRule.runOnUiThread { controller.scrollToEnd(animated = false) }
        awaitCommands(controller, 1)
        val lastTag = "item-${initialCount - 1}"
        val lastBottom = bottomOf(lastTag)
        assertNear(containerHeight, lastBottom, "挿入前は末尾を表示している")

        val bottoms = mutableListOf<Dp>()
        val colors = recordFrames(frames = 60, change = { items = items + TestItem("new", "new") }) {
            bottoms += bottomOf(lastTag)
            if (composeTestRule.countNodesWithTag("new") == 0) null else pixelAtCenter("new")
        }

        assertNear(lastBottom, bottoms.first(), "挿入を反映したフレームで表示範囲は飛ばない")
        assertIntermediate(bottoms, from = lastBottom, to = lastBottom - rowHeight, "表示範囲は途中の位置を通って進む")
        assertNear(containerHeight, bottomOf("new"), "最終的に挿入した項目が末尾に表示される")
        assertFadesIn(colors)
    }

    private fun setInsertionContent(
        layout: KsLayout,
        itemsProvider: () -> List<TestItem>,
        controller: KsScrollController,
    ) {
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = itemsProvider(),
                    key = { it.id },
                    layout = layout,
                    modifier = Modifier.background(Color.White).testTag(CollectionTag),
                    scrollController = controller,
                    listSeparators = false,
                ) {
                    template { item ->
                        Box(Modifier.fillMaxWidth().height(rowHeight).background(ItemColor).testTag(item.id))
                    }
                }
            }
        }
        composeTestRule.waitForIdle()
    }

    /**
     * 時計を止めて [change] を反映し、1 フレームずつ進めながら [sample] の値を集める。
     * 最後に時計を戻して落ち着くまで待つ。
     */
    private fun <T> recordFrames(frames: Int, change: () -> Unit, sample: () -> T): List<T> {
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { change() }
        val values = mutableListOf<T>()
        repeat(frames) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            values += sample()
        }
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()
        return values
    }

    /** [values] が [from] と [to] の間 (両端を除く) の値を 3 フレーム以上通っている。 */
    private fun assertIntermediate(values: List<Dp>, from: Dp, to: Dp, message: String) {
        val low = minOf(from, to) + tolerance
        val high = maxOf(from, to) - tolerance
        val intermediates = values.filter { it > low && it < high }.distinct()
        assertTrue("$message (実測 ${values.map { it.value }})", intermediates.size >= 3)
    }

    /** 挿入した項目の色が、背景と項目の色の間の半透明を通ってから項目の色に落ち着く。 */
    private fun assertFadesIn(colors: List<Color?>) {
        val shown = colors.filterNotNull()
        assertTrue("挿入した項目が表示される (実測 $colors)", shown.isNotEmpty())
        val translucent = shown.filter { it != ItemColor && it != Color.White }
        assertTrue("挿入した項目は半透明の途中を通る (実測 $shown)", translucent.size >= 2)
        assertEquals("最終的に不透明になる", ItemColor, shown.last())
    }

    private fun pixelAtCenter(tag: String): Color {
        val node = bounds(tag)
        val collection = bounds(CollectionTag)
        val density = composeTestRule.density.density
        val x = (((node.left + node.right) / 2) - collection.left).value * density
        val y = (((node.top + node.bottom) / 2) - collection.top).value * density
        val pixels = collectionPixels()
        return pixels[x.toInt().coerceIn(0, pixels.width - 1), y.toInt().coerceIn(0, pixels.height - 1)]
    }

    // ---- 補助 ----

    private data class Food(val id: String, val category: String)

    /** 価格を持つ項目。ID と区分が同じで価格だけ違う配列を作るために使う。 */
    private data class PricedFood(val id: String, val category: String, val price: Int)

    /** ID で比べ、表示名を比べないグループの値。状態保存に載るよう Serializable にする。 */
    private class Category(val id: String, val label: String) : java.io.Serializable {
        override fun equals(other: Any?): Boolean = other is Category && id == other.id

        override fun hashCode(): Int = id.hashCode()
    }

    /** 「果物」2 件と「野菜」3 件を、すべて同じ価格で作る。 */
    private fun pricedFoods(price: Int): List<PricedFood> =
        (0 until 2).map { PricedFood("果物-$it", "果物", price) } +
            (0 until 3).map { PricedFood("野菜-$it", "野菜", price) }

    /** カテゴリと件数の組から、カテゴリごとに続いた配列を作る。ID は「カテゴリ-連番」。 */
    private fun foods(vararg groups: Pair<String, Int>): List<Food> =
        groups.flatMap { (category, count) -> (0 until count).map { Food("$category-$it", category) } }

    /** 「果物, 野菜, 果物」と離れて同じ値が現れる配列。 */
    private fun separatedFoods(): List<Food> =
        listOf(Food("果物-0", "果物"), Food("野菜-0", "野菜"), Food("果物2-0", "果物"))

    private var headerIndex = 0

    /** 行の高さを [rowHeight] より 60dp 高くする項目の ID。 */
    private var tallFoodIds: Set<String> = emptySet()

    private fun setGroupedContent(
        items: List<Food> = emptyList(),
        itemsProvider: (() -> List<Food>)? = null,
        layout: KsLayout = KsLayout.List,
        withHeader: Boolean = true,
        pinned: Boolean = true,
        rootHeader: Boolean = false,
        rootFooter: Boolean = false,
        controller: KsScrollController? = null,
        itemBackground: Color? = null,
        headerTag: (String, Int) -> String = { value, _ -> "header-$value" },
    ) {
        composeTestRule.setContent {
            TestContainer(containerWidth, containerHeight) {
                KsCollectionView(
                    items = itemsProvider?.invoke() ?: items,
                    key = { it.id },
                    layout = layout,
                    modifier = Modifier.background(Color.White).testTag(CollectionTag),
                    header = if (rootHeader) {
                        { Box(Modifier.fillMaxWidth().height(40.dp).testTag("root-header")) }
                    } else {
                        null
                    },
                    footer = if (rootFooter) {
                        { Box(Modifier.fillMaxWidth().height(40.dp).testTag("root-footer")) }
                    } else {
                        null
                    },
                    scrollController = controller,
                    groups = if (withHeader) {
                        KsGroups(by = { it.category }, pinnedHeaders = pinned) { category, foodsInGroup ->
                            val tag = remember { headerTag(category, foodsInGroup.size) }
                            HeaderText(tag, "$category ${foodsInGroup.size}")
                        }
                    } else {
                        KsGroups(by = { it.category })
                    },
                ) {
                    template { food -> FoodRow(food, itemBackground) }
                }
            }
        }
        composeTestRule.waitForIdle()
    }

    @Composable
    private fun FoodRow(food: Food, background: Color? = null) {
        Text(
            text = food.id,
            modifier = Modifier
                .fillMaxWidth()
                .height(if (food.id in tallFoodIds) rowHeight + 60.dp else rowHeight)
                .then(if (background != null) Modifier.background(background) else Modifier)
                .testTag(food.id),
        )
    }

    /** 見出し。背景は不透明にし、固定中に下の行が透けないようにする。 */
    @Composable
    private fun HeaderText(tag: String, text: String) {
        Text(
            text = text,
            modifier = Modifier
                .fillMaxWidth()
                .height(headerHeight)
                .background(HeaderBackground)
                .testTag(if (tag.startsWith("header-")) tag else "header-$tag"),
        )
    }

    private fun onHeader(value: String) = composeTestRule.onNodeWithTag("header-$value")

    /** 表示中の見出しの文言を上から順に返す。 */
    private fun androidx.compose.ui.test.junit4.ComposeTestRule.onAllHeaders(): List<String> =
        onAllNodes(androidx.compose.ui.test.SemanticsMatcher("見出し") { node ->
            node.config.getOrElseNullable(androidx.compose.ui.semantics.SemanticsProperties.TestTag) { null }
                ?.startsWith("header-") == true
        }).fetchSemanticsNodes()
            .sortedBy { it.boundsInRoot.top }
            .map { node ->
                node.config[androidx.compose.ui.semantics.SemanticsProperties.Text].joinToString { it.text }
            }

    private fun scrollToLazyIndex(index: Int) {
        composeTestRule.onNode(hasScrollAction()).performScrollToIndex(index)
        composeTestRule.waitForIdle()
    }

    /** コンテンツを [distance] だけ先へ送る (負の値で戻す)。 */
    private fun scrollBy(distance: Dp) {
        val px = with(composeTestRule.density) { distance.toPx() }
        composeTestRule.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) {
            it(0f, px)
        }
        composeTestRule.waitForIdle()
    }

    private fun awaitCommands(controller: KsScrollController, count: Int) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (controller.processedCommandCount < count) {
            if (System.nanoTime() > deadline) {
                fail("命令が処理されない (期待 $count 件 / 実測 ${controller.processedCommandCount} 件)")
            }
            composeTestRule.waitForIdle()
            composeTestRule.mainClock.advanceTimeByFrame()
        }
        composeTestRule.waitForIdle()
    }

    private fun assertNear(expected: Dp, actual: Dp, message: String) {
        assertTrue(
            "$message (期待 $expected / 実測 $actual)",
            kotlin.math.abs((expected - actual).value) <= tolerance.value,
        )
    }

    private fun assertWarned(fragment: String) {
        val warnings = ShadowLog.getLogsForTag("KsCollectionView").filter { it.type == Log.WARN }.map { it.msg }
        assertTrue("警告ログに「$fragment」が出る (実測 $warnings)", warnings.any { it.contains(fragment) })
    }

    private fun bounds(tag: String) = composeTestRule.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun topOf(tag: String): Dp = bounds(tag).top

    private fun bottomOf(tag: String): Dp = bounds(tag).bottom

    private fun leftOf(tag: String): Dp = bounds(tag).left

    private fun widthOf(tag: String): Dp = bounds(tag).width

    private fun heightOf(tag: String): Dp = bounds(tag).height

    private fun collectionPixels(): PixelMap = composeTestRule.onNodeWithTag(CollectionTag).readPixels()

    private companion object {
        const val CollectionTag = "collection"

        /** 見出しの背景色。 */
        val HeaderBackground = Color(0xFFEEEEEE)

        /** 挿入のアニメーションを見る項目の色。 */
        val ItemColor = Color(0xFF3366CC)
    }
}

/** 指定した節点の描画結果を画素として読む。 */
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
