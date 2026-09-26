package jp.kamusoft.kscollectionview.samples.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「グループ化」の初期データが iOS Sample と同じ並び・同じグループ分けになることを確かめる。
 *
 * 期待値 (グループの数・大きいグループの番号・先頭と末尾のグループの件数) は、iOS Sample の
 * `GroupingDemoData` と同じ規則から求めた値。
 */
class GroupingDemoDataTest {

    private val items = GroupingDemoData.items

    /** グループの番号ごとの件数 (配列の順)。 */
    private val sizes: List<Pair<Int, Int>> =
        items.groupingBy { it.group }.eachCount().toList()

    @Test
    fun `項目は ID 1 から 10000 の昇順で中身は大量件数と同じ`() {
        assertEquals((1..10_000).toList(), items.map { it.id })
        assertEquals(DemoData.largeItems(10_000), items.map { it.row })
    }

    @Test
    fun `グループは 378 あり番号は切った順に 1 から続く`() {
        assertEquals(378, sizes.size)
        assertEquals((1..378).toList(), sizes.map { it.first })
        // 同じグループの項目は続いて並ぶ (番号は配列の順に増えるだけ)。
        assertTrue(items.zipWithNext().all { (a, b) -> b.group == a.group || b.group == a.group + 1 })
    }

    @Test
    fun `大きいグループは 1 番 182 番 347 番で ID 1 4401 8201 から始まる`() {
        val large = sizes.filter { it.second == 1_200 }.map { it.first }
        assertEquals(listOf(1, 182, 347), large)
        assertEquals(
            listOf(1, 4_401, 8_201),
            large.map { group -> items.first { it.group == group }.id },
        )
    }

    @Test
    fun `小さいグループは 5 件から 30 件`() {
        val small = sizes.filter { it.second != 1_200 }.map { it.second }
        assertTrue(small.all { it in 5..30 })
    }

    @Test
    fun `先頭と末尾のグループの件数が iOS と同じ`() {
        assertEquals(listOf(1_200, 12, 16, 14, 11), sizes.take(5).map { it.second })
        assertEquals(listOf(29, 18, 23), sizes.takeLast(3).map { it.second })
    }
}
