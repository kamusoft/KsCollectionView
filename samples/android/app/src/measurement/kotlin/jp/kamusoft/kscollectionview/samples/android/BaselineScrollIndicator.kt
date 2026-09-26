package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.ScrollableState
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridItemInfo
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.roundToInt

/*
 * 比較対象 (素の Lazy 系) に付ける縦スクロールインジケータ。
 *
 * ライブラリは既定で縦スクロールインジケータを描く。比較対象にも同じ機能を同じ位置 (グリッド /
 * リストの前面) に付けないと、相対の差にインジケータ自身のコストが混ざる。Compose には標準の描画が
 * 無いため、ライブラリ内部の描画 (見た目・表示の契機・位置の求め方) をここに写して持つ。
 * ライブラリ側の描画を変えたときは、ここもあわせて直す。
 */

/** バーの太さ。角は太さの半分で丸める。 */
private val IndicatorThickness = 3.dp

/** 末尾側の端・上端・下端からバーまでの距離。 */
private val IndicatorEdgeInset = 3.dp

/** バーの最短の長さ。 */
private val IndicatorMinLength = 36.dp

/** バーの色 (ライトモード。Sample はライトモードだけを使う)。 */
private val IndicatorColor = Color.Black.copy(alpha = 0.35f)

/** スクロールが止まってから消え始めるまでの時間。 */
private const val IndicatorHideDelayMillis = 1_000L

/** 消えるときのフェードの長さ。 */
private const val IndicatorFadeOutMillis = 250

/** 消えるときのフェードの緩急。 */
private val IndicatorFadeOutEasing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)

/**
 * インジケータの表示の濃さを持ち、利用者の操作によるスクロールに合わせて動かす。
 *
 * ドラッグを始めると即座に表示し、そのドラッグから続く慣性スクロールが止まってから一定時間後に
 * フェードで消す。
 *
 * @param state 位置を読むスクロールの状態
 * @param interactionSource ドラッグを読む操作の発生源
 */
@Composable
fun rememberBaselineScrollIndicatorVisibility(
    state: ScrollableState,
    interactionSource: InteractionSource,
): Animatable<Float, AnimationVector1D> {
    val visibility = remember(state) { Animatable(0f) }
    val isDragged = interactionSource.collectIsDraggedAsState()
    LaunchedEffect(state, isDragged) {
        var isUserScroll = false
        snapshotFlow { isDragged.value to state.isScrollInProgress }
            .collectLatest { (dragged, scrolling) ->
                if (dragged) isUserScroll = true
                if (dragged || (isUserScroll && scrolling)) {
                    visibility.snapTo(1f)
                } else {
                    isUserScroll = false
                    if (visibility.value > 0f) {
                        delay(IndicatorHideDelayMillis)
                        visibility.animateTo(
                            targetValue = 0f,
                            animationSpec = tween(
                                durationMillis = IndicatorFadeOutMillis,
                                easing = IndicatorFadeOutEasing,
                            ),
                        )
                    }
                }
            }
    }
    return visibility
}

/**
 * グリッドの前面に縦スクロールインジケータを描く。全幅の項目を持たないグリッド用。
 *
 * @param state 位置と長さを読むグリッドの状態
 * @param visibility [rememberBaselineScrollIndicatorVisibility] が動かす表示の濃さ
 */
fun Modifier.baselineScrollIndicator(
    state: LazyGridState,
    visibility: Animatable<Float, AnimationVector1D>,
): Modifier = drawWithContent {
    drawContent()
    val metrics = state.scrollIndicatorState ?: return@drawWithContent
    drawIndicator(visibility.value, metrics.scrollOffset, metrics.contentSize, metrics.viewportSize)
}

/**
 * リストの前面に縦スクロールインジケータを描く。
 *
 * @param state 位置と長さを読むリストの状態
 * @param visibility [rememberBaselineScrollIndicatorVisibility] が動かす表示の濃さ
 */
fun Modifier.baselineScrollIndicator(
    state: LazyListState,
    visibility: Animatable<Float, AnimationVector1D>,
): Modifier = drawWithContent {
    drawContent()
    val metrics = state.scrollIndicatorState ?: return@drawWithContent
    drawIndicator(visibility.value, metrics.scrollOffset, metrics.contentSize, metrics.viewportSize)
}

/**
 * 見出しを持つグリッドの前面に縦スクロールインジケータを描く。
 *
 * 公式のコンテンツ全体の長さは全幅の見出しを 1 ÷ 列数 行と数えるため、見出しを 1 行と数える
 * 数え方で長さと位置を求め直す (ライブラリと同じ求め方)。
 *
 * @param state 位置と長さを読むグリッドの状態
 * @param visibility [rememberBaselineScrollIndicatorVisibility] が動かす表示の濃さ
 * @param totalRows 見出しを 1 行と数えた全体の行の数
 * @param rowOfLazy lazy の index が載る行の番号
 * @param isHeader 見出しの再利用種別かどうか
 */
fun Modifier.baselineGroupedScrollIndicator(
    state: LazyGridState,
    visibility: Animatable<Float, AnimationVector1D>,
    totalRows: Int,
    rowOfLazy: (Int) -> Int,
    isHeader: (Any?) -> Boolean,
): Modifier = drawWithContent {
    drawContent()
    if (visibility.value <= 0f) return@drawWithContent
    val metrics = state.scrollIndicatorState ?: return@drawWithContent
    val info = state.layoutInfo
    val visible = info.visibleItemsInfo
    if (visible.isEmpty() || info.totalItemsCount == 0) return@drawWithContent
    val paddings = info.beforeContentPadding + info.afterContentPadding
    val officialLines = (info.totalItemsCount + info.maxSpan - 1) / info.maxSpan.coerceAtLeast(1)
    if (officialLines <= 0) return@drawWithContent
    val lineTotal = (metrics.contentSize - paddings).coerceAtLeast(0)
    val averageLine = lineTotal.toDouble() / officialLines
    val contentSize = paddings + (averageLine * totalRows).roundToInt()

    val firstOnScreen = visible
        .filterNot { it.isDisplacedHeader(visible, isHeader) }
        .minWithOrNull(compareBy<LazyGridItemInfo>({ it.offset.y }, { it.index }))
        ?: return@drawWithContent
    var scrollOffset = (averageLine * rowOfLazy(firstOnScreen.index)).roundToInt() +
        state.firstVisibleItemScrollOffset
    val anchor = visible.firstOrNull { it.index == state.firstVisibleItemIndex }
    if (anchor != null && anchor.row > firstOnScreen.row) {
        scrollOffset += anchor.offset.y - firstOnScreen.offset.y
    }
    drawIndicator(visibility.value, scrollOffset, contentSize, metrics.viewportSize)
}

/** 上端に固定されて本来の位置から動いている見出しかどうか。 */
private fun LazyGridItemInfo.isDisplacedHeader(
    visible: List<LazyGridItemInfo>,
    isHeader: (Any?) -> Boolean,
): Boolean {
    if (!isHeader(contentType)) return false
    val bottom = offset.y + size.height
    return visible.any { it.index > index && it.offset.y < bottom - 1 }
}

/** バーを描く。コンテンツが表示領域に収まるときは描かない。 */
private fun ContentDrawScope.drawIndicator(
    alpha: Float,
    scrollOffset: Int,
    contentSize: Int,
    viewportSize: Int,
) {
    if (alpha <= 0f) return
    val bounds = indicatorBounds(
        containerSize = size,
        scrollOffset = scrollOffset,
        contentSize = contentSize,
        viewportSize = viewportSize,
        layoutDirection = layoutDirection,
        thicknessPx = IndicatorThickness.toPx(),
        edgeInsetPx = IndicatorEdgeInset.toPx(),
        minLengthPx = IndicatorMinLength.toPx(),
    ) ?: return
    drawRoundRect(
        color = IndicatorColor,
        topLeft = bounds.topLeft,
        size = bounds.size,
        cornerRadius = CornerRadius(bounds.width / 2f),
        alpha = alpha,
    )
}

/** バーの矩形を求める。描くものが無いときは null。 */
private fun indicatorBounds(
    containerSize: Size,
    scrollOffset: Int,
    contentSize: Int,
    viewportSize: Int,
    layoutDirection: LayoutDirection,
    thicknessPx: Float,
    edgeInsetPx: Float,
    minLengthPx: Float,
): Rect? {
    if (viewportSize <= 0 || contentSize <= viewportSize) return null
    val trackLength = containerSize.height - edgeInsetPx * 2
    if (trackLength <= 0f) return null
    val length = (trackLength * viewportSize / contentSize)
        .coerceAtLeast(minLengthPx)
        .coerceAtMost(trackLength)
    val fraction = (scrollOffset.toFloat() / (contentSize - viewportSize)).coerceIn(0f, 1f)
    val top = edgeInsetPx + (trackLength - length) * fraction
    val left = when (layoutDirection) {
        LayoutDirection.Ltr -> containerSize.width - edgeInsetPx - thicknessPx
        LayoutDirection.Rtl -> edgeInsetPx
    }
    return Rect(offset = Offset(left, top), size = Size(thicknessPx, length))
}
