package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.saveable.SaverScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 「差分更新」画面の操作の組み替え規則を確かめる。
 *
 * 期待値は iOS Sample の `DiffUpdateModel` と同じ規則から求めた値。同じ初期状態から同じ順で
 * 同じ操作をすれば、両プラットフォームで同じ並び・同じグループ分けになる。
 */
class DiffUpdateModelTest {

    private fun DiffUpdateModel.ids(): List<Int> = items.map { it.id }

    private fun DiffUpdateModel.shape(): List<Pair<Int, Int>> = items.map { it.id to it.group }

    @Test
    fun `初期は ID 1 から 20 を 5 件ずつ A から D のグループに`() {
        val model = DiffUpdateModel()
        assertEquals((1..20).toList(), model.ids())
        assertEquals(List(20) { it / 5 }, model.items.map { it.group })
        assertEquals(
            listOf("グループ A", "グループ B", "グループ C", "グループ D"),
            (0..3).map { DiffUpdateModel.groupName(it) },
        )
    }

    @Test
    fun `位置は挿入と対象で数え方が違う`() {
        assertEquals(listOf(0, 10, 20), DiffUpdatePosition.entries.map { it.insertionIndex(20) })
        assertEquals(listOf(0, 10, 19), DiffUpdatePosition.entries.map { it.targetIndex(20) })
        assertNull(DiffUpdatePosition.Middle.targetIndex(0))
    }

    @Test
    fun `挿入は新しい ID をその位置の項目と同じグループに入れる`() {
        val model = DiffUpdateModel()
            .inserting(DiffUpdatePosition.Head)
            .inserting(DiffUpdatePosition.Middle)
            .inserting(DiffUpdatePosition.Tail)
        assertEquals(21 to 0, model.shape()[0])
        // 21 件の中ほど (10) の項目は ID 10 (グループ B)。
        assertEquals(22 to 1, model.shape()[10])
        // 末尾は最後の項目 (グループ D) と同じ。
        assertEquals(23 to 3, model.shape().last())
        assertEquals(24, model.nextId)
    }

    @Test
    fun `削除と更新は対象の位置の項目に効く`() {
        val model = DiffUpdateModel()
            .deleting(DiffUpdatePosition.Tail)
            .updating(DiffUpdatePosition.Middle)
        assertEquals((1..19).toList(), model.ids())
        // 19 件の中ほど (9) は ID 10。ID は変えずに印が付く。
        assertEquals("Item 10 ★", model.items[9].row.title)
        assertEquals(1, model.items[9].revision)
        assertEquals("Item 10 ★", model.updating(DiffUpdatePosition.Middle).items[9].row.title)
    }

    @Test
    fun `グループなしの移動は位置 i から i + n÷2 の位置へ`() {
        val model = DiffUpdateModel()
            .moving(DiffUpdatePosition.Head, grouped = false)
            .moving(DiffUpdatePosition.Middle, grouped = false)
            .moving(DiffUpdatePosition.Tail, grouped = false)
        assertEquals(listOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19), model.ids())
    }

    @Test
    fun `グループありの移動は次のグループの先頭へ移り最後のグループからは最初へ`() {
        val model = DiffUpdateModel().moving(DiffUpdatePosition.Tail, grouped = true)
        assertEquals(20 to 0, model.shape()[0])
        val head = DiffUpdateModel().moving(DiffUpdatePosition.Head, grouped = true)
        assertEquals(listOf(2 to 0, 3 to 0, 4 to 0, 5 to 0, 1 to 1, 6 to 1), head.shape().take(6))
    }

    @Test
    fun `反転は配列全体を逆にする`() {
        assertEquals((20 downTo 1).toList(), DiffUpdateModel().reversed().ids())
    }

    @Test
    fun `グループなしのシャッフルは配列全体を混ぜる`() {
        val model = DiffUpdateModel().shuffled(grouped = false)
        assertEquals(listOf(19, 13, 6, 5, 18, 8, 10, 15, 11, 4, 3, 9, 12, 7, 2, 14, 16, 20, 1, 17), model.ids())
        assertEquals(267_668_225u, model.randomState)
    }

    @Test
    fun `グループありのシャッフルはグループの並びと中を混ぜて乱数を続けて消費する`() {
        val once = DiffUpdateModel().shuffled(grouped = true)
        assertEquals(
            listOf(
                8 to 1, 6 to 1, 9 to 1, 7 to 1, 10 to 1, 19 to 3, 17 to 3, 18 to 3, 20 to 3, 16 to 3,
                15 to 2, 14 to 2, 11 to 2, 12 to 2, 13 to 2, 1 to 0, 3 to 0, 2 to 0, 5 to 0, 4 to 0,
            ),
            once.shape(),
        )
        assertEquals(
            listOf(
                11 to 2, 14 to 2, 15 to 2, 13 to 2, 12 to 2, 17 to 3, 16 to 3, 19 to 3, 18 to 3, 20 to 3,
                8 to 1, 6 to 1, 9 to 1, 7 to 1, 10 to 1, 5 to 0, 4 to 0, 2 to 0, 3 to 0, 1 to 0,
            ),
            once.shuffled(grouped = true).shape(),
        )
    }

    @Test
    fun `操作を続けた結果が iOS と同じ規則の値になる`() {
        val model = DiffUpdateModel()
            .inserting(DiffUpdatePosition.Head)
            .inserting(DiffUpdatePosition.Middle)
            .inserting(DiffUpdatePosition.Tail)
            .moving(DiffUpdatePosition.Middle, grouped = true)
            .moving(DiffUpdatePosition.Tail, grouped = true)
            .deleting(DiffUpdatePosition.Middle)
            .updating(DiffUpdatePosition.Head)
            .reversed()
            .shuffled(grouped = true)
        assertEquals(
            listOf(
                Triple(13, 2, 0), Triple(12, 2, 0), Triple(11, 2, 0), Triple(15, 2, 0), Triple(14, 2, 0),
                Triple(10, 2, 0), Triple(4, 0, 0), Triple(3, 0, 0), Triple(23, 0, 1), Triple(1, 0, 0),
                Triple(2, 0, 0), Triple(21, 0, 0), Triple(5, 0, 0), Triple(7, 1, 0), Triple(6, 1, 0),
                Triple(9, 1, 0), Triple(8, 1, 0), Triple(16, 3, 0), Triple(17, 3, 0), Triple(20, 3, 0),
                Triple(19, 3, 0), Triple(18, 3, 0),
            ),
            model.items.map { Triple(it.id, it.group, it.revision) },
        )
        assertEquals(24, model.nextId)
    }

    @Test
    fun `グループありのどの操作の後も同じグループの項目が続いて並ぶ`() {
        var model = DiffUpdateModel()
        repeat(4) {
            DiffUpdatePosition.entries.forEach { position ->
                model = model.inserting(position).also { it.assertContiguous() }
                model = model.moving(position, grouped = true).also { it.assertContiguous() }
                model = model.updating(position).also { it.assertContiguous() }
                model = model.deleting(position).also { it.assertContiguous() }
            }
            model = model.reversed().also { it.assertContiguous() }
            model = model.shuffled(grouped = true).also { it.assertContiguous() }
        }
    }

    @Test
    fun `グループありへの切り替えは初めて現れた順に集め直す`() {
        val scattered = DiffUpdateModel().shuffled(grouped = false)
        val regrouped = scattered.regrouped()
        regrouped.assertContiguous()
        assertEquals(listOf(3, 2, 1, 0), regrouped.items.map { it.group }.distinct())
        // グループ内の順は保つ (グループ D は 19, 18, 16, 20, 17 の順で現れる)。
        assertEquals(listOf(19, 18, 16, 20, 17), regrouped.items.filter { it.group == 3 }.map { it.id })
    }

    @Test
    fun `元に戻すと配列と次の ID と乱数が初期に戻る`() {
        val model = DiffUpdateModel().inserting(DiffUpdatePosition.Head).shuffled(grouped = false).reset()
        assertEquals(DiffUpdateModel(), model)
    }

    @Test
    fun `保存の形から同じ値に戻る`() {
        val model = DiffUpdateModel().inserting(DiffUpdatePosition.Tail).updating(DiffUpdatePosition.Head)
            .shuffled(grouped = true)
        val saved = with(DiffUpdateModel.Saver) { SaverScope { true }.save(model) }!!
        assertEquals(model, DiffUpdateModel.Saver.restore(saved))
    }

    private fun DiffUpdateModel.assertContiguous() {
        val runs = items.zipWithNext().count { (a, b) -> a.group != b.group } + 1
        assertEquals("同じグループが離れて現れています: ${shape()}", items.map { it.group }.distinct().size, runs)
    }
}
