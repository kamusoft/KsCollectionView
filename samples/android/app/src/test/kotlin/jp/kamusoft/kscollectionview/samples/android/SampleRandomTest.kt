package jp.kamusoft.kscollectionview.samples.android

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 擬似乱数が iOS Sample と同じ数列を出すことを確かめる。
 *
 * 期待値は iOS Sample の `SampleRandom` と同じ式 (32 ビット xorshift、シフト量 13 / 17 / 5) で
 * 求めた値。プラットフォーム間の一致は言語をまたぐためコンパイラでは守れず、同じ値の表との
 * 突き合わせで守る。
 */
class SampleRandomTest {

    @Test
    fun `種 20260924 の最初の 5 つが iOS と同じ`() {
        val random = SampleRandom(20_260_924u)
        assertEquals(
            listOf(577_617_541u, 571_989_819u, 3_890_916_259u, 3_779_907_436u, 1_821_316_284u),
            List(5) { random.next() },
        )
    }

    @Test
    fun `範囲指定は次の値を上限で割った余り`() {
        val expected = SampleRandom(20_260_924u).let { r -> List(5) { (r.next() % 26u).toInt() } }
        val random = SampleRandom(20_260_924u)
        assertEquals(expected, List(5) { random.next(bound = 26) })
    }

    @Test
    fun `状態を種にして作り直すと同じ続きの数列を出す`() {
        val original = SampleRandom(20_260_925u)
        repeat(3) { original.next() }
        val resumed = SampleRandom(original.state)
        assertEquals(List(5) { original.next() }, List(5) { resumed.next() })
    }

    @Test
    fun `シャッフルは末尾から 1 まで下げながら入れ替える`() {
        // 種 20260925 で 1〜20 を混ぜた並び (iOS と同じ規則から求めた値)。
        val values = (1..20).toMutableList()
        SampleRandom(20_260_925u).shuffle(values)
        assertEquals(
            listOf(19, 13, 6, 5, 18, 8, 10, 15, 11, 4, 3, 9, 12, 7, 2, 14, 16, 20, 1, 17),
            values,
        )
    }
}
