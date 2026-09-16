package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 自動往復の画面が、最初に見える分のテンプレートを数え落とさないことを確かめる。
 *
 * 数え直しをコンポジションより後の段階 (効果の本体) で行うと、最初に見える分は数え始めた後に
 * 0 へ戻され、その項目が破棄されるときの分だけが引かれて同時生存が実際より小さくなる。そうなると
 * 「離脱後は 0」の判定が構造的に成立しない。
 *
 * 判定は「載っている項目の数」との一致で行う。数が 0 より大きいことだけを見ると、数え直しの後に
 * 走査が新しい項目を載せた分で埋まってしまい、数え落としを見逃す。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class MeasurementRoundTripCountingTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Before
    fun setUp() {
        MeasurementLifetime.reset()
    }

    /** 画面に載っている項目の数が、そのまま同時生存として数えられている。 */
    @Test
    fun `最初に見える分のテンプレートが数え落とされない`() {
        val items = DemoData.largeItems(60)
        // 画面の計数とは独立に、テンプレートの中で載っている項目を自分で数える。数え直しの
        // 時点だけが違う 2 つの計数を突き合わせるため、数え落としがあれば差として現れる。
        val live = LiveRowCounter()

        composeTestRule.setContent {
            MemoryRoundTripScreen(items = items, maxRoundTrips = 1) { item ->
                DisposableEffect(item.id) {
                    live.enter()
                    onDispose { live.leave() }
                }
                DemoListRow(item)
            }
        }
        composeTestRule.waitForIdle()

        assertTrue("画面に項目が載っていません (載っている数: ${live.alive})", live.alive > 0)
        assertEquals(
            "載っている項目の数と同時生存が一致しません",
            live.alive.toLong(),
            MeasurementLifetime.alive,
        )
    }
}

/** テンプレートの中で、いま載っている項目の数を数える。 */
private class LiveRowCounter {
    var alive: Int = 0
        private set

    fun enter() {
        alive += 1
    }

    fun leave() {
        alive -= 1
    }
}
