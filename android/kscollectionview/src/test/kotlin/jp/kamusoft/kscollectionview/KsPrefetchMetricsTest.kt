package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Test

/** 先読みの列幅を、`LazyVerticalGrid` がセルの幅を決めるのと同じ規則で解けることを確かめる。 */
internal class KsPrefetchMetricsTest {

    private val density = Density(2f)

    private fun resolve(
        layout: KsLayout,
        containerWidthPx: Int,
        isPortrait: Boolean = true,
        contentPadding: PaddingValues = PaddingValues(0.dp),
        layoutDirection: LayoutDirection = LayoutDirection.Ltr,
    ): Int = resolveColumnWidthPx(layout, containerWidthPx, isPortrait, contentPadding, layoutDirection, density)

    /** list は 1 列で、余白を除いた幅がそのまま列の幅になる。 */
    @Test
    fun listIsOneColumn() {
        assertEquals(
            // 800 - (8 + 8) × 2
            768,
            resolve(KsLayout.List, 800, contentPadding = PaddingValues(horizontal = 8.dp)),
        )
    }

    /** 固定の列数はコンテナの向きで決まり、列間隔を差し引いて均等に割る。 */
    @Test
    fun fixedColumnsFollowTheOrientation() {
        val layout = KsLayout.Grid(columns = KsColumns.Fixed(portrait = 3, landscape = 5), columnSpacing = 8.dp)
        val padding = PaddingValues(8.dp)

        // (1080 - 32 - 16 × 2) / 3 = 338
        assertEquals(338, resolve(layout, 1080, isPortrait = true, contentPadding = padding))
        // (2340 - 32 - 16 × 4) / 5 = 448 (端数は切り捨て)
        assertEquals(448, resolve(layout, 2340, isPortrait = false, contentPadding = padding))
    }

    /** 最小幅の列は `LazyVerticalGrid` と同じく floor((幅 + 間隔) / (最小幅 + 間隔)) 列になる。 */
    @Test
    fun adaptiveColumnsMatchTheLazyGridRule() {
        val layout = KsLayout.Grid(columns = KsColumns.Adaptive(100.dp), columnSpacing = 10.dp)

        // (1000 + 20) / (200 + 20) = 4 列、(1000 - 20 × 3) / 4 = 235
        assertEquals(235, resolve(layout, 1000))
    }

    /** 左右で違う余白は、書字方向に関わらず左右の合計を差し引く。 */
    @Test
    fun asymmetricPaddingIsSubtractedInBothDirections() {
        val padding = PaddingValues(start = 10.dp, end = 30.dp)

        assertEquals(920, resolve(KsLayout.List, 1000, contentPadding = padding))
        assertEquals(920, resolve(KsLayout.List, 1000, contentPadding = padding, layoutDirection = LayoutDirection.Rtl))
    }

    /** 余白と列間隔の合計がコンテナの幅を超える間、またはコンテナの幅が未確定の間は 0 (解けない)。 */
    @Test
    fun unresolvableWidthIsZero() {
        val layout = KsLayout.Grid(columns = KsColumns.Fixed(3), columnSpacing = 100.dp)

        assertEquals(0, resolve(layout, 300, contentPadding = PaddingValues(horizontal = 10.dp)))
        assertEquals(0, resolve(KsLayout.List, 0))
        assertEquals(0, resolve(KsLayout.List, 100, contentPadding = PaddingValues(horizontal = 50.dp)))
    }

    /** 固定の幅は表示倍率を掛けて四捨五入し、1 以上にする。 */
    @Test
    fun fixedWidthPixelsAreRoundedAndAtLeastOne() {
        val metrics = KsPrefetchMetrics(columnWidthPx = 0, density = 2.625f)

        assertEquals(105, metrics.pixels(40.dp))
        assertEquals(1, metrics.pixels(0.1.dp))
    }
}
