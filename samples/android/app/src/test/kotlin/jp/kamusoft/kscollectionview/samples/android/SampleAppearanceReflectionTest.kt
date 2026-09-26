package jp.kamusoft.kscollectionview.samples.android

import android.content.Context
import android.content.res.Configuration
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.SingletonImageLoader
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 保存した外観が Activity の表示モードに上書きされ、配色の組と Material の配色に届くことを確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
class SampleAppearanceReflectionTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val context: Context = ApplicationProvider.getApplicationContext()

    /**
     * 保存した外観と、画像の共有ローダーを初期状態に戻す。
     *
     * 共有ローダーは同じ JVM の他のテストが既定の構成で作っていることがあり、そのままでは
     * MainActivity の入口 (観測用の構成への差し替え) が「作成済み」として失敗する。端末では入口が
     * 最初の読み込みより前に走るため起きない。後始末でも戻し、差し替えた構成を他のテストに残さない。
     */
    @Before
    @After
    fun resetSharedState() {
        context.getSharedPreferences("sample_appearance", Context.MODE_PRIVATE).edit().clear().commit()
        SingletonImageLoader.reset()
    }

    @Test
    fun `ダークを保存すると端末がライトでも Activity の表示モードがダークになる`() {
        SampleAppearanceStore.save(context, SampleAppearance.Dark)
        assertEquals(SampleAppearance.Dark to Configuration.UI_MODE_NIGHT_YES, launchAndReadNightMode())
    }

    @Test
    @Config(qualifiers = "night")
    fun `ライトを保存すると端末がダークでも Activity の表示モードがライトになる`() {
        SampleAppearanceStore.save(context, SampleAppearance.Light)
        assertEquals(Configuration.UI_MODE_NIGHT_NO, launchAndReadNightMode().second)
    }

    @Test
    @Config(qualifiers = "night")
    fun `システムでは端末の表示モードがそのまま効く`() {
        assertEquals(Configuration.UI_MODE_NIGHT_YES, launchAndReadNightMode().second)
    }

    @Test
    @Config(qualifiers = "night")
    fun `表示モードがダークなら配色はダークの組で Material の配色も同じ組から取る`() {
        lateinit var observed: Triple<Boolean, SamplePalette, Pair<Long, Long>>
        composeTestRule.setContent {
            SampleAppTheme {
                observed = Triple(
                    isSystemInDarkTheme(),
                    LocalSamplePalette.current,
                    MaterialTheme.colorScheme.primary.value.toLong() to
                        MaterialTheme.colorScheme.surfaceContainer.value.toLong(),
                )
            }
        }
        composeTestRule.waitForIdle()

        assertEquals(true, observed.first)
        assertEquals(SamplePalette.Dark, observed.second)
        assertEquals(
            SamplePalette.Dark.accent.value.toLong() to SamplePalette.Dark.background.value.toLong(),
            observed.third,
        )
    }

    @Test
    fun `表示モードがライトなら配色はライトの組になる`() {
        lateinit var palette: SamplePalette
        composeTestRule.setContent {
            SampleAppTheme { palette = LocalSamplePalette.current }
        }
        composeTestRule.waitForIdle()

        assertEquals(SamplePalette.Light, palette)
    }

    /** MainActivity を起動し、保存済みの外観と Activity の表示モードの夜間の部分を読む。 */
    private fun launchAndReadNightMode(): Pair<SampleAppearance, Int> =
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            var result: Pair<SampleAppearance, Int>? = null
            scenario.onActivity { activity ->
                result = SampleAppearanceStore.load(activity) to
                    (activity.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK)
            }
            checkNotNull(result)
        }
}
