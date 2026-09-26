package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.onConsumedWindowInsetsChanged
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.lazy.grid.LazyGridItemInfo
import androidx.compose.foundation.lazy.grid.LazyGridLayoutInfo
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import kotlin.math.roundToInt

/**
 * コレクションの上端が、画面上端の安全領域 (ステータスバー・画面の切り欠き) に重なっている長さ。
 *
 * 一覧を画面の全体に広げて置く (edge-to-edge で、上端をステータスバーの裏まで広げる) と、上端に
 * 固定したグループの見出しがバーの裏に隠れる。固定中の見出しは安全領域の境目 (バーのすぐ下) で
 * 止めるため、その境目がコレクションの上端からどれだけ下にあるかをここで求める。
 *
 * 安全領域とみなすのは、ウィンドウの insets のうち `WindowInsets.systemBars` と
 * `WindowInsets.displayCutout` の和から、祖先がすでに消費した分 (`consumeWindowInsets` や
 * `windowInsetsPadding` で処理済みと宣言した分) を除いたもの。上端についてはこれは
 * `WindowInsets.safeDrawing` と同じ値で、IME の insets を読まない分だけ入力中に値が動かない。
 * 消費済みを除くのは、祖先が「上端の insets はこちらで扱った」と宣言した置き方では、コレクションは
 * 安全領域を気にしなくてよい、という Compose の insets の約束に従うためである。
 *
 * そのうえで、残った insets とコレクションの位置を突き合わせ、実際に重なっている長さだけを使う。
 * `Scaffold` の内側余白を `padding` で当てた置き方のように、insets を消費しないまま安全領域の外に
 * 置かれたコレクションでは重なりは 0 で、見え方は変わらない。
 */
@Stable
internal class KsTopSafeArea(private val insets: WindowInsets, private val density: Density) {
    /** 祖先が消費済みの insets。 */
    private var consumed: WindowInsets by mutableStateOf(WindowInsets(0, 0, 0, 0))

    /** コレクションの上端のウィンドウ上の位置 (px)。 */
    private var topInWindow: Float by mutableFloatStateOf(0f)

    /**
     * 安全領域に重なっている長さ (px)。重なっていなければ 0。
     *
     * snapshot state を読むため、配置や描画の中で読むと値が変わったときにやり直される。
     */
    fun overlapPx(): Int {
        val safeTop = insets.exclude(consumed).getTop(density)
        return (safeTop - topInWindow).roundToInt().coerceAtLeast(0)
    }

    /** コレクションの根に付け、消費済みの insets と位置を受け取る修飾。 */
    val modifier: Modifier = Modifier
        .onConsumedWindowInsetsChanged { consumed = it }
        .onGloballyPositioned { topInWindow = it.positionInWindow().y }
}

/** [KsTopSafeArea] を作って覚える。 */
@Composable
internal fun rememberKsTopSafeArea(): KsTopSafeArea {
    val insets = WindowInsets.systemBars.union(WindowInsets.displayCutout)
    val density = LocalDensity.current
    return remember(insets, density) { KsTopSafeArea(insets, density) }
}

/**
 * 上端に固定するグループの見出しを置く位置 (lazy の項目の座標)。
 *
 * Compose の固定見出しは表示範囲の上端 (上側の contentPadding の外側の端) に固定され、次の見出しが
 * 来ると押し上げられる。ここでは固定する上端を安全領域の境目 ([safeTopPx] だけ下) に下げ、押し上げは
 * 次の見出しの位置 (境目より上なら境目で止めた位置) で決める。見出しの本来の位置が境目より下なら動かさない。
 *
 * @param header 位置を求める見出し (表示中の項目)
 * @param safeTopPx 表示範囲の上端から安全領域の境目までの長さ
 */
internal fun LazyGridLayoutInfo.ksPinnedHeaderOffset(header: LazyGridItemInfo, safeTopPx: Int): Int {
    if (safeTopPx <= 0) return header.offset.y
    val boundary = viewportStartOffset + safeTopPx
    var nextHeaderOffset = Int.MAX_VALUE
    var nextHeaderIndex = Int.MAX_VALUE
    for (item in visibleItemsInfo) {
        if (item.contentType == KsGroupHeaderContentType && item.index > header.index && item.index < nextHeaderIndex) {
            nextHeaderIndex = item.index
            nextHeaderOffset = item.offset.y
        }
    }
    // 次の見出しも境目より上には来ない (境目で止まる) ため、押し上げはその止まった位置から測る。
    // 本来の位置から測ると、次の見出しが境目を越えている間、2 つの見出しの間に隙間が空く。
    val pushedLimit = if (nextHeaderOffset == Int.MAX_VALUE) {
        Int.MAX_VALUE
    } else {
        maxOf(boundary, nextHeaderOffset) - header.size.height
    }
    return minOf(maxOf(boundary, header.offset.y), pushedLimit)
}

/**
 * 固定中の見出しが表示範囲の上端から覆っている範囲の下端 (lazy の項目の座標)。覆っている見出しが
 * 無ければ null。
 *
 * 安全領域に重なって置かれたときは、見出しを安全領域の境目で止めるため、覆う範囲は境目から
 * 見出しの下端までに安全領域の分を加えた範囲になる。
 *
 * @param safeTopPx 表示範囲の上端から安全領域の境目までの長さ
 */
internal fun LazyGridLayoutInfo.ksPinnedHeaderCoverageEnd(safeTopPx: Int): Int? {
    val boundary = viewportStartOffset + safeTopPx
    var coverageEnd: Int? = null
    for (item in visibleItemsInfo) {
        if (item.contentType != KsGroupHeaderContentType) continue
        val top = ksPinnedHeaderOffset(item, safeTopPx)
        val bottom = top + item.size.height
        if (top <= boundary + 1 && bottom > boundary) {
            coverageEnd = maxOf(coverageEnd ?: bottom, bottom)
        }
    }
    return coverageEnd
}
