package jp.kamusoft.kscollectionview.samples.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「ページング」画面の遅延を起動の追加情報から読む規則を確かめる。iOS Sample の `PagingDelay` と同じく、
 * 0 以上の整数だけを受け取り、受け取れない指定では既定へ戻さずに起動を止める。
 */
class PagingDelayTest {

    @Test
    fun `指定が無ければ既定の 1000 ミリ秒`() {
        assertEquals(PagingDelay.Resolution.Unspecified, PagingDelay.resolve(null))
        assertEquals(1_000, PagingDelay.millisecondsOrFail(PagingDelay.resolve(null)))
    }

    @Test
    fun `整数と整数として読める文字列を受け取る`() {
        assertEquals(PagingDelay.Resolution.Specified(0), PagingDelay.resolve(0))
        assertEquals(PagingDelay.Resolution.Specified(200), PagingDelay.resolve("200"))
        assertEquals(PagingDelay.Resolution.Specified(5_000), PagingDelay.resolve(5_000L))
    }

    @Test
    fun `負数と数値でない値は受け取れず 起動を止める`() {
        listOf<Any>(-1, "-1", "abc", "", 1.5, true).forEach { value ->
            val resolution = PagingDelay.resolve(value)
            assertTrue("$value が受け取られた: $resolution", resolution is PagingDelay.Resolution.Invalid)
            assertThrows(IllegalArgumentException::class.java) { PagingDelay.millisecondsOrFail(resolution) }
        }
    }

    @Test
    fun `追加情報のキーは ks_paging_delay_ms`() {
        assertEquals("ks_paging_delay_ms", SampleRoutes.PagingDelayExtra)
    }
}
