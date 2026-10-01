package jp.kamusoft.kscollectionview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 並べ替えの行き先の求め方 (表示から切り離した計算) を確かめる。 */
internal class KsReorderPlannerTest {

    private val end = KsReorderPlacement.End

    /** グループなしの一覧 (配列全体が 1 つのグループ)。 */
    private fun flat(count: Int): KsReorderPlanner =
        KsReorderPlanner(
            resolveGroups(
                items = List(count) { it },
                groupValueOf = null,
                hasHeaders = false,
                pinsHeaders = false,
                hasRootHeader = false,
                hasRootFooter = false,
            ).plan,
        )

    /** グループの値の並び [values] の一覧 (見出しあり)。 */
    private fun grouped(vararg values: String): KsReorderPlanner =
        KsReorderPlanner(
            resolveGroups(
                items = values.toList(),
                groupValueOf = { it },
                hasHeaders = true,
                pinsHeaders = true,
                hasRootHeader = false,
                hasRootFooter = false,
            ).plan,
        )

    /** A, B, C, D (0..3) の A を C と D の間 (動かした項目を除いた 2 番目) に置くと、行き先は D の前。 */
    @Test
    fun placeBetweenCAndDIsBeforeD() {
        val planner = flat(4)
        assertEquals(KsReorderPlacement(0, 3), planner.placement(source = 0, group = 0, position = 2))
        assertEquals("置いた後の位置は C の後ろ", 2, planner.targetIndex(0, KsReorderPlacement(0, 3)))
    }

    /** A, B, C の A を C の後ろに置くと、行き先は末尾。 */
    @Test
    fun placeAfterLastIsEnd() {
        val planner = flat(3)
        val placement = planner.placement(source = 0, group = 0, position = 2)
        assertEquals(KsReorderPlacement(0, end), placement)
        assertEquals(2, planner.targetIndex(0, placement))
    }

    /** 元の位置に置いたときの行き先は、動かす前の行き先と同じになる (知らせない判定に使う)。 */
    @Test
    fun placeAtOriginalEqualsOriginalPlacement() {
        val planner = flat(4)
        assertEquals(planner.originalPlacement(1), planner.placement(source = 1, group = 0, position = 1))
        assertEquals(KsReorderPlacement(0, 2), planner.originalPlacement(1))
        assertEquals("最後の項目の元の位置は末尾", KsReorderPlacement(0, end), planner.originalPlacement(3))
    }

    /** X (A, B)・Y (C, D) の A を C と D の間に置くと、行き先は D の前・グループ Y。 */
    @Test
    fun placeIntoMiddleOfOtherGroup() {
        val planner = grouped("X", "X", "Y", "Y")
        val placement = planner.placement(source = 0, group = 1, position = 1)
        assertEquals(KsReorderPlacement(1, 3), placement)
        assertEquals(2, planner.targetIndex(0, placement))
        val moved = planner.movedPlan(0, placement, keepsEmptyGroups = true)
        assertEquals("X は B だけ", 1, moved.groupEnd(0) - moved.groupStart(0))
        assertEquals("Y は C, A, D", 3, moved.groupEnd(1) - moved.groupStart(1))
    }

    /**
     * X (A, B)・Y (C, D) の D を、Y の見出しより上 (X の末尾) に置くと行き先は末尾・X、見出しより下
     * (Y の先頭) に置くと行き先は C の前・Y。
     */
    @Test
    fun aboveAndBelowHeader() {
        val planner = grouped("X", "X", "Y", "Y")
        val above = planner.placement(source = 3, group = 0, position = 2)
        assertEquals(KsReorderPlacement(0, end), above)
        assertEquals(2, planner.targetIndex(3, above))
        val below = planner.placement(source = 3, group = 1, position = 0)
        assertEquals(KsReorderPlacement(1, 2), below)
        assertEquals(2, planner.targetIndex(3, below))
    }

    /** 見出しの無いグループでも、境目より上は前のグループの末尾になる (グループの区切りは同じ計算)。 */
    @Test
    fun boundaryWithoutHeaders() {
        val plan = resolveGroups(
            items = listOf("X", "X", "Y", "Y"),
            groupValueOf = { it },
            hasHeaders = false,
            pinsHeaders = false,
            hasRootHeader = false,
            hasRootFooter = false,
        ).plan
        val planner = KsReorderPlanner(plan)
        assertEquals(KsReorderPlacement(0, end), planner.placement(source = 3, group = 0, position = 2))
    }

    /** A, B, C の A の「後ろへ移動」は C の前、C の「後ろへ移動」は無い。 */
    @Test
    fun accessibilityNextMovesOneForward() {
        val planner = flat(3)
        assertEquals(KsReorderPlacement(0, 2), planner.nextPlacement(0))
        assertNull("一覧の最後の項目には後ろへの行き先が無い", planner.nextPlacement(2))
        assertNull("一覧の先頭の項目には前への行き先が無い", planner.previousPlacement(0))
        assertEquals(KsReorderPlacement(0, 0), planner.previousPlacement(1))
    }

    /** X (A, B)・Y (C, D) の C の「前へ移動」は末尾・X、B の「後ろへ移動」は C の前・Y。 */
    @Test
    fun accessibilityMovesAcrossGroupBoundary() {
        val planner = grouped("X", "X", "Y", "Y")
        assertEquals(KsReorderPlacement(0, end), planner.previousPlacement(2))
        assertEquals(KsReorderPlacement(1, 2), planner.nextPlacement(1))
        assertEquals("D の後ろへは無い", null, planner.nextPlacement(3))
    }

    /** 最後の 1 件を持ち出すと、ドラッグの間は空のグループを残し、受け入れた構成では取り除く。 */
    @Test
    fun emptyGroupKeptDuringDragAndRemovedOnAccept() {
        val planner = grouped("X", "Y", "Y")
        val placement = planner.placement(source = 0, group = 1, position = 1)
        val dragging = planner.movedPlan(0, placement, keepsEmptyGroups = true)
        assertEquals(2, dragging.groupCount)
        assertEquals("X の見出しは残る (項目 0 件)", 0, dragging.groupEnd(0) - dragging.groupStart(0))
        assertEquals("X", dragging.groupValue(0))
        val accepted = planner.movedPlan(0, placement, keepsEmptyGroups = false)
        assertEquals(1, accepted.groupCount)
        assertEquals("Y", accepted.groupValue(0))
        assertEquals(3, accepted.groupEnd(0))
    }

    /** 動かした並びは、写しを作らずに元の並びを読み替える。 */
    @Test
    fun reorderedListReadsBase() {
        val base = listOf("A", "B", "C", "D")
        assertEquals(listOf("B", "C", "A", "D"), KsReorderedList(base, 0, 2).toList())
        assertEquals(listOf("A", "D", "B", "C"), KsReorderedList(base, 3, 1).toList())
        assertEquals(base, KsReorderedList(base, 2, 2).toList())
    }
}
