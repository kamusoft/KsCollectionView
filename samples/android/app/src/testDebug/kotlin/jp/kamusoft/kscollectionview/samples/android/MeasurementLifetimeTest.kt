package jp.kamusoft.kscollectionview.samples.android

import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * 計測用の入口が読む同時生存の計数。
 *
 * 置換と離脱の後の判定はこの数だけを根拠にするため、「累計 − 破棄」と最大値の取り方をここで
 * 固定する。数える実体を持たない構成ではこのテストは走らない (置き場が前提を表す)。
 */
class MeasurementLifetimeTest {

    @Before
    fun setUp() {
        MeasurementLifetime.reset()
    }

    @Test
    fun `同時生存は累計から破棄を引いた数になる`() {
        repeat(5) { MeasurementLifetime.enter() }
        repeat(2) { MeasurementLifetime.leave() }

        assertEquals(3L, MeasurementLifetime.alive)
    }

    @Test
    fun `最大の同時生存は破棄で下がらない`() {
        repeat(4) { MeasurementLifetime.enter() }
        repeat(4) { MeasurementLifetime.leave() }

        assertEquals(0L, MeasurementLifetime.alive)
        assertEquals(4L, MeasurementLifetime.peakAlive)
    }

    @Test
    fun `数え直すと最大も 0 に戻る`() {
        repeat(3) { MeasurementLifetime.enter() }
        MeasurementLifetime.reset()

        assertEquals(0L, MeasurementLifetime.alive)
        assertEquals(0L, MeasurementLifetime.peakAlive)
    }
}
