package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.saveable.SaverScope
import jp.kamusoft.kscollectionview.KsReorderDestination
import jp.kamusoft.kscollectionview.KsReorderMove
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「並べ替え」画面のデータとモデルの並べ替えの規則を確かめる。
 *
 * 期待値は iOS Sample の `ReorderDemoModel` と同じ規則から求めた値。
 */
class ReorderDemoModelTest {

    /** 帯を消すまでの待ちをテストが手で終わらせるモデル。 */
    private class Fixture {
        var timeout = CompletableDeferred<Unit>()
        val model = ReorderDemoModel(
            noticeScope = CoroutineScope(Dispatchers.Unconfined),
            awaitNoticeTimeout = { timeout.await() },
        )

        /** 帯を出してから決まった時間がたったことにする。 */
        fun elapseNoticeTimeout() {
            val current = timeout
            timeout = CompletableDeferred()
            current.complete(Unit)
        }
    }

    private fun ReorderDemoModel.item(id: Int): ReorderDemoItem = items.first { it.id == id }

    private fun ReorderDemoModel.ids(range: IntRange): List<Int> = items.slice(range).map { it.id }

    private fun ReorderDemoModel.indexOf(id: Int): Int = items.indexOfFirst { it.id == id }

    private fun ReorderDemoModel.before(id: Int, next: Int, group: Int?): KsReorderMove<ReorderDemoItem> =
        KsReorderMove(item(id), KsReorderDestination.Before(item(next)), group)

    private fun ReorderDemoModel.end(id: Int, group: Int?): KsReorderMove<ReorderDemoItem> =
        KsReorderMove(item(id), KsReorderDestination.End, group)

    /** 同じグループの値の項目が続いている (離れた位置に同じ値が現れない) か。 */
    private fun List<ReorderDemoItem>.groupsAreContiguous(): Boolean {
        val runs = zipWithNext().count { (a, b) -> a.group != b.group } + 1
        return runs == map { it.group }.distinct().size
    }

    @Test
    fun `初期の配列は 10000 件を 100 件ずつ 100 のグループに分け 10 の倍数は動かせない`() {
        val model = Fixture().model

        assertEquals((1..10_000).toList(), model.items.map { it.id })
        assertEquals((1..100).toList(), model.items.map { it.group }.distinct())
        assertTrue(model.items.groupBy { it.group }.values.all { it.size == 100 })
        assertEquals(listOf(1, 1, 2), listOf(model.item(1).group, model.item(100).group, model.item(101).group))
        assertEquals((1..1_000).map { it * 10 }, model.items.filterNot { it.isMovable }.map { it.id })
        assertEquals("Item 10 (移動不可)", reorderRowTitle(model.item(10)).text)
        assertEquals("Item 9", reorderRowTitle(model.item(9)).text)
    }

    @Test
    fun `切り替えは並べ替えとグループだけが初めからオン`() {
        val model = Fixture().model

        assertEquals(
            listOf(true, true, false, false),
            listOf(model.isReorderEnabled, model.isGrouped, model.keepsGroups, model.rejectsMoves),
        )
        assertNull(model.notice)
    }

    @Test
    fun `Item 1 を Item 3 と Item 4 の間に置くと 2 3 1 4 の順になる`() {
        val model = Fixture().model

        assertTrue(model.move(model.before(1, next = 4, group = 1)))

        assertEquals(listOf(2, 3, 1, 4), model.ids(0..3))
        assertEquals(1, model.item(1).group)
    }

    @Test
    fun `別のグループの途中へ置くとグループの値を書き換えてその位置に入れる`() {
        val model = Fixture().model

        assertTrue(model.move(model.before(1, next = 102, group = 2)))

        assertEquals(model.indexOf(101) + 1, model.indexOf(1))
        assertEquals(model.indexOf(102) - 1, model.indexOf(1))
        assertEquals(2, model.item(1).group)
        assertEquals(99, model.items.count { it.group == 1 })
        assertEquals(101, model.items.count { it.group == 2 })
        assertTrue(model.items.groupsAreContiguous())
    }

    @Test
    fun `グループの末尾へ置くとそのグループの最後の項目の後ろに入る`() {
        val model = Fixture().model

        assertTrue(model.move(model.end(1, group = 2)))

        assertEquals(model.indexOf(200) + 1, model.indexOf(1))
        assertEquals(model.indexOf(201) - 1, model.indexOf(1))
        assertEquals(2, model.item(1).group)
        assertTrue(model.items.groupsAreContiguous())
    }

    @Test
    fun `グループがオフの間は行き先の隣の項目のグループの値に合わせる`() {
        val model = Fixture().model
        model.isGrouped = false

        // この項目の前: その項目 (Item 101、グループ 2) に合わせる。
        assertTrue(model.move(model.before(1, next = 101, group = null)))
        assertEquals(2, model.item(1).group)
        assertEquals(model.indexOf(101) - 1, model.indexOf(1))

        // 末尾: 最後の項目 (Item 10000、グループ 100) に合わせる。
        assertTrue(model.move(model.end(2, group = null)))
        assertEquals(100, model.item(2).group)
        assertEquals(2, model.items.last().id)

        // オンに戻しても、同じグループの値が離れた位置に現れない。
        model.isGrouped = true
        assertTrue(model.items.groupsAreContiguous())
    }

    @Test
    fun `置いても受け入れないがオンなら並べ替えず受け入れなかった帯を 3 秒出す`() {
        val fixture = Fixture()
        val model = fixture.model
        model.rejectsMoves = true

        assertFalse(model.move(model.before(1, next = 4, group = 1)))

        assertEquals((1..4).toList(), model.ids(0..3))
        assertEquals(ReorderDemoText.Rejected, model.notice)
        fixture.elapseNoticeTimeout()
        assertNull(model.notice)
        assertEquals(ReorderDemoText.Rejected, model.lastNotice)
    }

    @Test
    fun `グループをまたがせないがオンの間は元のグループへだけ置ける`() {
        val model = Fixture().model

        // オフの間はどこにでも置ける。
        assertTrue(model.canDrop(model.before(1, next = 102, group = 2)))

        model.keepsGroups = true
        assertTrue(model.canDrop(model.before(1, next = 4, group = 1)))
        assertTrue(model.canDrop(model.end(1, group = 1)))
        assertFalse(model.canDrop(model.before(1, next = 102, group = 2)))
        assertFalse(model.canDrop(model.end(1, group = 2)))
        // グループをオフにしている間 (知らせにグループの値が無い) は置ける。
        assertTrue(model.canDrop(model.before(1, next = 102, group = null)))
    }

    @Test
    fun `長押しで長押し Item N の帯を出し 次の帯を出したらその文言に替える`() {
        val fixture = Fixture()
        val model = fixture.model

        model.didLongPress(model.item(5))
        assertEquals("長押し: Item 5", model.notice)

        model.didLongPress(model.item(6))
        assertEquals("長押し: Item 6", model.notice)
        fixture.elapseNoticeTimeout()
        assertNull(model.notice)
    }

    @Test
    fun `保存して戻すと並べ替えた配列と切り替えの値が残る`() {
        val scope = CoroutineScope(Dispatchers.Unconfined)
        val model = ReorderDemoModel(noticeScope = scope)
        model.move(model.before(1, next = 102, group = 2))
        model.isGrouped = false
        model.move(model.end(3, group = null))
        model.keepsGroups = true
        model.isReorderEnabled = false

        val saver = ReorderDemoModel.saver(scope)
        val saved = with(saver) { SaverScope { true }.save(model) }!!
        val restored = saver.restore(saved)!!

        assertEquals(model.items, restored.items)
        assertEquals(
            listOf(false, false, true, false),
            listOf(restored.isReorderEnabled, restored.isGrouped, restored.keepsGroups, restored.rejectsMoves),
        )
    }
}
