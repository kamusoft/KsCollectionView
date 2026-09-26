package jp.kamusoft.kscollectionview

import android.os.Parcel
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** グループの構成と、項目の位置・lazy の index・行の番号の対応表を確かめる。 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
internal class KsGroupPlanTest {

    /** 果物 2 件・野菜 3 件の配列。 */
    private val foods = listOf("果物", "果物", "野菜", "野菜", "野菜")

    private fun resolve(
        values: List<Any?>,
        hasHeaders: Boolean = true,
        pinsHeaders: Boolean = true,
        hasRootHeader: Boolean = false,
        hasRootFooter: Boolean = false,
    ): KsGroupResolution = resolveGroups(
        items = values,
        groupValueOf = { it },
        hasHeaders = hasHeaders,
        pinsHeaders = pinsHeaders,
        hasRootHeader = hasRootHeader,
        hasRootFooter = hasRootFooter,
    )

    /** 続いた同じ値が 1 つのグループになり、配列の順に並ぶ。 */
    @Test
    fun consecutiveValuesFormOneGroup() {
        val plan = resolve(foods).plan

        assertEquals(2, plan.groupCount)
        assertEquals("果物", plan.groupValue(0))
        assertEquals(0 until 2, plan.groupStart(0) until plan.groupEnd(0))
        assertEquals("野菜", plan.groupValue(1))
        assertEquals(2 until 5, plan.groupStart(1) until plan.groupEnd(1))
        assertTrue("正しい入力では診断は無い", resolve(foods).diagnostics.isEmpty())
    }

    /**
     * lazy には「ルートのヘッダー → (見出し → 項目) → フッター」の順に並び、項目の位置と lazy の
     * index が双方向に対応する。
     */
    @Test
    fun lazyIndicesIncludeRootHeaderAndGroupHeaders() {
        val plan = resolve(foods, hasRootHeader = true, hasRootFooter = true).plan

        // 0: ヘッダー / 1: 果物の見出し / 2, 3: 果物 / 4: 野菜の見出し / 5..7: 野菜 / 8: フッター
        assertEquals(9, plan.totalLazyCount)
        assertEquals(listOf(2, 3, 5, 6, 7), (0 until 5).map(plan::lazyIndexOfItem))
        assertEquals(listOf(-1, -1, 0, 1, -1, 2, 3, 4, -1), (0 until 9).map(plan::itemIndexOfLazy))
        assertEquals(1, plan.headerLazyIndex(0))
        assertEquals(4, plan.headerLazyIndex(1))
        assertEquals(listOf(-1, 0, -1, -1, 1, -1, -1, -1, -1), (0 until 9).map(plan::groupOfHeaderLazy))
        assertTrue(plan.isRootHeader(0))
        assertTrue(plan.isRootFooter(8))
    }

    /** 見出しを宣言しないグループは見出しを並べず、項目の位置と lazy の index はルートのヘッダー分だけずれる。 */
    @Test
    fun headerlessGroupsPlaceNoHeaders() {
        val plan = resolve(foods, hasHeaders = false, hasRootHeader = true).plan

        assertEquals(6, plan.totalLazyCount)
        assertEquals(listOf(1, 2, 3, 4, 5), (0 until 5).map(plan::lazyIndexOfItem))
        assertEquals(listOf(-1, 0, 1, 2, 3, 4), (0 until 6).map(plan::itemIndexOfLazy))
        assertEquals("見出しが無ければ固定もしない", false, plan.pinsHeaders)
    }

    /** グループを宣言しないときは配列全体が 1 つのグループになる。 */
    @Test
    fun withoutGroupsWholeArrayIsOneGroup() {
        val plan = resolveGroups(
            items = foods,
            groupValueOf = null,
            hasHeaders = false,
            pinsHeaders = false,
            hasRootHeader = true,
            hasRootFooter = false,
        ).plan

        assertEquals(1, plan.groupCount)
        assertEquals(5, plan.groupEnd(0))
        assertEquals(listOf(1, 2, 3, 4, 5), (0 until 5).map(plan::lazyIndexOfItem))
    }

    /** 行はルートのヘッダー / フッターと見出しを 1 行、各グループの項目を切り上げの行数で数える。 */
    @Test
    fun rowsCountHeadersAsOneRowAndRoundUpEachGroup() {
        val plan = resolve(foods, hasRootHeader = true, hasRootFooter = true).plan
        val rows = plan.rows(columns = 2)

        // 0: ヘッダー / 1: 果物の見出し / 2: 果物 2 件 / 3: 野菜の見出し / 4, 5: 野菜 3 件 / 6: フッター
        assertEquals(7, rows.totalRows)
        assertEquals(
            listOf(0, 1, 2, 2, 3, 4, 4, 5, 6),
            (0 until plan.totalLazyCount).map(rows::rowOfLazy),
        )
    }

    /** 見出しのないグループも、各グループの最終行は次のグループと同じ行にならない。 */
    @Test
    fun headerlessRowsStartEachGroupOnNewRow() {
        val plan = resolve(listOf("A", "A", "A", "B", "B"), hasHeaders = false).plan
        val rows = plan.rows(columns = 2)

        assertEquals(3, rows.totalRows)
        assertEquals(listOf(0, 0, 1, 2, 2), (0 until 5).map(rows::rowOfLazy))
    }

    /** 離れて現れた同じ値は別々のグループになり、何回目かで見出しのキーが分かれ、診断が出る。 */
    @Test
    fun separatedSameValueBecomesSeparateGroupWithDiagnostic() {
        val resolution = resolve(listOf("果物", "野菜", "果物"))
        val plan = resolution.plan

        assertEquals(3, plan.groupCount)
        assertEquals(KsGroupHeaderKey("果物", 0), plan.headerKey(0))
        assertEquals(KsGroupHeaderKey("野菜", 0), plan.headerKey(1))
        assertEquals(KsGroupHeaderKey("果物", 1), plan.headerKey(2))
        assertNotEquals(plan.headerKey(0), plan.headerKey(2))
        assertTrue(
            "離れた同じ値は診断される (実測 ${resolution.diagnostics})",
            resolution.diagnostics.any { it.contains("離れた位置") },
        )
    }

    /** 状態保存に載せられないグループの値は診断される。 */
    @Test
    fun unsavableGroupValueIsDiagnosed() {
        class NotSavable

        val resolution = resolve(listOf(NotSavable()))

        assertTrue(
            "載せられない型は診断される (実測 ${resolution.diagnostics})",
            resolution.diagnostics.any { it.contains("状態保存") },
        )
        assertTrue("文字列・数値・null は載せられる", resolve(listOf("a", 1, null)).diagnostics.isEmpty())
    }

    /** 見出しのキーは項目のキーと同じ値でも等しくならず、状態保存 (Parcel) を往復できる。 */
    @Test
    fun headerKeyIsDistinctFromItemKeyAndParcelable() {
        val key = KsGroupHeaderKey("果物", 0)
        assertNotEquals("果物" as Any, key as Any)

        val parcel = Parcel.obtain()
        try {
            parcel.writeParcelable(key, 0)
            parcel.setDataPosition(0)
            @Suppress("DEPRECATION")
            val restored = parcel.readParcelable<KsGroupHeaderKey>(KsGroupHeaderKey::class.java.classLoader)
            assertEquals(key, restored)
        } finally {
            parcel.recycle()
        }
    }

    /** 項目の上下の間隔: 先頭行は見出しの下の間隔、他の行は行間、最後以外のグループの最終行の下はグループ間の間隔。 */
    @Test
    fun itemSpacingFollowsGroupRows() {
        val plan = resolve(foods).plan
        val spacing = KsGroupSpacing(row = 4.dp, headerItem = 8.dp, group = 24.dp)

        // 2 列: 果物は 1 行、野菜は 2 行 (3 件目が 2 行目)。
        assertEquals(8.dp, plan.topSpacing(position = 0, columns = 2, spacing = spacing))
        assertEquals(8.dp, plan.topSpacing(position = 1, columns = 2, spacing = spacing))
        assertEquals(4.dp, plan.topSpacing(position = 2, columns = 2, spacing = spacing))
        assertEquals(24.dp, plan.bottomSpacing(group = 0, position = 1, columns = 2, spacing = spacing))
        assertEquals(0.dp, plan.bottomSpacing(group = 1, position = 0, columns = 2, spacing = spacing))
        assertEquals("最後のグループの下には入らない", 0.dp, plan.bottomSpacing(1, 2, 2, spacing))

        val headerless = resolve(foods, hasHeaders = false).plan
        assertEquals("見出しが無ければ先頭行の上は 0", 0.dp, headerless.topSpacing(0, 2, spacing))
    }
}
