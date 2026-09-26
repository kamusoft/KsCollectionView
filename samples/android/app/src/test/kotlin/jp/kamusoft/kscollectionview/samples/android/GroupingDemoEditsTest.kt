package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.saveable.SaverScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * 「グループ化」画面の 2 つの操作の組み替え規則を確かめる (iOS Sample と同じ規則)。
 */
class GroupingDemoEditsTest {

    /** グループの番号の並びから配列を作る。ID は 1 から順に振る。 */
    private fun itemsOf(vararg groups: Int): List<GroupingDemoItem> =
        groups.mapIndexed { index, group ->
            GroupingDemoItem(row = DemoItem(id = index + 1, title = "Item ${index + 1}"), group = group)
        }

    private fun List<GroupingDemoItem>.shape(): List<Pair<Int, Int>> = map { it.id to it.group }

    @Test
    fun `反転はグループの順だけを逆にしてグループの中の順は保つ`() {
        val items = itemsOf(1, 1, 2, 2, 2, 3)
        assertEquals(
            listOf(6 to 3, 3 to 2, 4 to 2, 5 to 2, 1 to 1, 2 to 1),
            GroupingDemoEdits.reversingGroups(items).shape(),
        )
    }

    @Test
    fun `末尾に近い項目は次のグループの先頭へ移る`() {
        // グループ 2 (ID 3〜5) の ID 5 は末尾までの件数 0 が先頭までの件数 2 以下。
        val items = itemsOf(1, 1, 2, 2, 2, 3)
        assertEquals(
            listOf(1 to 1, 2 to 1, 3 to 2, 4 to 2, 5 to 3, 6 to 3),
            GroupingDemoEdits.movingItem(4, items).shape(),
        )
    }

    @Test
    fun `真ん中の項目は末尾までと先頭までが等しいので次のグループへ移る`() {
        val items = itemsOf(1, 1, 2, 2, 2, 3)
        assertEquals(
            listOf(1 to 1, 2 to 1, 3 to 2, 5 to 2, 4 to 3, 6 to 3),
            GroupingDemoEdits.movingItem(3, items).shape(),
        )
    }

    @Test
    fun `先頭に近い項目は前のグループの末尾へ移る`() {
        val items = itemsOf(1, 1, 2, 2, 2, 3)
        assertEquals(
            listOf(1 to 1, 2 to 1, 3 to 1, 4 to 2, 5 to 2, 6 to 3),
            GroupingDemoEdits.movingItem(2, items).shape(),
        )
    }

    @Test
    fun `近い側に隣が無ければ反対側へ移る`() {
        // 最初のグループの先頭 → 前が無いので次のグループの先頭へ。
        val items = itemsOf(1, 1, 1, 2, 2)
        assertEquals(
            listOf(2 to 1, 3 to 1, 1 to 2, 4 to 2, 5 to 2),
            GroupingDemoEdits.movingItem(0, items).shape(),
        )
        // 最後のグループの末尾 → 次が無いので前のグループの末尾へ。
        assertEquals(
            listOf(1 to 1, 2 to 1, 3 to 1, 5 to 1, 4 to 2),
            GroupingDemoEdits.movingItem(4, items).shape(),
        )
    }

    @Test
    fun `グループが 1 つだけなら何もしない`() {
        val items = itemsOf(1, 1, 1)
        assertSame(items, GroupingDemoEdits.movingItem(1, items))
    }

    @Test
    fun `操作の後も同じグループの項目は続いて並ぶ`() {
        var items = GroupingDemoData.items
        listOf(0, 1_199, 1_200, 5_000, 9_999).forEach { offset ->
            items = GroupingDemoEdits.movingItem(offset, items)
            items = GroupingDemoEdits.reversingGroups(items)
        }
        val runs = items.zipWithNext().count { (a, b) -> a.group != b.group } + 1
        assertEquals(items.map { it.group }.distinct().size, runs)
        assertEquals(10_000, items.size)
    }

    @Test
    fun `保存した操作の記録から同じ配列に戻る`() {
        val state = GroupingDemoState()
        state.moveItem(1_199)
        state.reverseGroups()
        state.moveItem(3)
        val saved = with(GroupingDemoState.Saver) { SaverScope { true }.save(state) }!!
        val restored = GroupingDemoState.Saver.restore(saved)
        assertEquals(state.items, restored!!.items)
    }
}
