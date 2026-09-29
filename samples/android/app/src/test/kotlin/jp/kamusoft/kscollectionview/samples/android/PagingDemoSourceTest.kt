package jp.kamusoft.kscollectionview.samples.android

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「ページング」画面の偽の取得元の並び・件数・終端・失敗・0 件を確かめる。
 *
 * 期待値は iOS Sample の `PagingDemoSource` と同じ規則から求めた値。同じページの番号には、
 * 両プラットフォームで同じ並びが返る。
 */
class PagingDemoSourceTest {

    @Test
    fun `全 10000 件を 1 ページ 50 件で返す`() {
        assertEquals(10_000, PagingDemoSource.TotalCount)
        assertEquals(50, PagingDemoSource.PageSize)
    }

    @Test
    fun `ページ n は ID n×50+1 から 50 件で タイトルは Item と ID`() {
        val first = PagingDemoSource.page(page = 0, isEmpty = false)
        assertEquals((1..50).toList(), first.items.map { it.id })
        assertEquals("Item 1", first.items.first().title)
        assertEquals("Item 50", first.items.last().title)
        assertFalse(first.isLast)

        val second = PagingDemoSource.page(page = 1, isEmpty = false)
        assertEquals((51..100).toList(), second.items.map { it.id })
    }

    @Test
    fun `最後のページは Item 10000 で終わり 最後のページとして返す`() {
        val last = PagingDemoSource.page(page = 199, isEmpty = false)
        assertEquals((9_951..10_000).toList(), last.items.map { it.id })
        assertTrue(last.isLast)
        // 最後を越えたページは 0 件・最後のページ。
        val beyond = PagingDemoSource.page(page = 200, isEmpty = false)
        assertEquals(emptyList<DemoItem>(), beyond.items)
        assertTrue(beyond.isLast)
    }

    @Test
    fun `すべてのページをつなぐと Item 1 から Item 10000 が 1 回ずつ並ぶ`() {
        val ids = (0 until 200).flatMap { PagingDemoSource.page(it, isEmpty = false).items.map(DemoItem::id) }
        assertEquals((1..10_000).toList(), ids)
    }

    @Test
    fun `0 件にするとどのページも 0 件・最後のページ`() {
        listOf(0, 1, 199).forEach { page ->
            val result = PagingDemoSource.page(page, isEmpty = true)
            assertEquals(emptyList<DemoItem>(), result.items)
            assertTrue(result.isLast)
        }
    }

    @Test
    fun `失敗させると 0 件の設定より優先して失敗する`() = runBlocking {
        val source = PagingDemoSource(delayMilliseconds = 0)
        val failure = runCatching { source.fetch(page = 0, fails = true, isEmpty = true) }.exceptionOrNull()
        assertTrue("失敗させる設定で ${failure} が返った", failure is PagingDemoFailure)
        assertEquals((1..50).toList(), source.fetch(page = 0, fails = false, isEmpty = false).items.map { it.id })
    }

    @Test
    fun `既定の遅延は 1 秒`() {
        assertEquals(1_000, PagingDemoSource().delayMilliseconds)
    }
}
