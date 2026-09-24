package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.collectIsDraggedAsState
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
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest

/**
 * 縦スクロールインジケータの見た目と表示時間。
 *
 * 値は iOS の `UIScrollView` の既定のインジケータに合わせる。バーはコンポーネントの全高
 * (contentPadding の領域を含む) を走り、スクロール量は contentPadding を含むコンテンツ全体に
 * 対する割合で表す。先頭では上端、末尾では下端に届く。iOS 側は余白をセクションの内側余白で
 * 表すため、インジケータがその余白を含む全高を走るのと揃えるためである。
 */
internal object KsScrollIndicatorDefaults {
    /** バーの太さ。角は太さの半分で丸める。 */
    val thickness = 3.dp

    /** コンポーネントの末尾側の端・上端・下端からバーまでの距離。 */
    val edgeInset = 3.dp

    /** バーの最短の長さ。コンテンツが長くてもこれより短くしない。 */
    val minLength = 36.dp

    /** ライトモードのバーの色 (黒 35%)。 */
    val lightColor: Color = Color.Black.copy(alpha = 0.35f)

    /** ダークモードのバーの色 (白 50%)。 */
    val darkColor: Color = Color.White.copy(alpha = 0.5f)

    /** スクロールが止まってから消え始めるまでの時間。 */
    const val HIDE_DELAY_MILLIS: Long = 1_000L

    /** 消えるときのフェードの長さ。 */
    const val FADE_OUT_MILLIS: Int = 250

    /** 消えるときのフェードの緩急。iOS の ease-in-ease-out と同じ曲線。 */
    val fadeOutEasing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)

    /** 表示モードに応じたバーの色。 */
    fun color(isDarkTheme: Boolean): Color = if (isDarkTheme) darkColor else lightColor
}

/**
 * インジケータの表示の濃さ (0 = 非表示、1 = 表示) を持ち、利用者の操作によるスクロールに合わせて動かす。
 *
 * 利用者がドラッグを始めると即座に表示し、そのドラッグから続く慣性スクロールが止まってから
 * 一定時間後にフェードで消す。スクロール命令 (プログラムによるスクロール) では表示しない
 * (iOS の `UIScrollView` もプログラムによるアニメーションつきスクロールではインジケータを出さない)。
 *
 * 返す値は描画フェーズでだけ読む前提。コンポジションで読むとスクロールのたびに再コンポーズが起きる。
 */
@Composable
internal fun rememberKsScrollIndicatorVisibility(
    gridState: LazyGridState,
): Animatable<Float, AnimationVector1D> {
    val visibility = remember(gridState) { Animatable(0f) }
    // 値はこの下の effect の中でだけ読む (コンポジションでは読まない)。
    val isDragged = gridState.interactionSource.collectIsDraggedAsState()
    LaunchedEffect(gridState, isDragged) {
        // ドラッグで始まったスクロールの間 (慣性スクロールを含む) だけ表示を保つ。
        var isUserScroll = false
        snapshotFlow { isDragged.value to gridState.isScrollInProgress }
            .collectLatest { (dragged, scrolling) ->
                if (dragged) isUserScroll = true
                if (dragged || (isUserScroll && scrolling)) {
                    visibility.snapTo(1f)
                } else {
                    isUserScroll = false
                    if (visibility.value > 0f) {
                        // 待機とフェードの途中で新しいスクロールが始まると、collectLatest が
                        // この処理を取り消して表示し直す。
                        delay(KsScrollIndicatorDefaults.HIDE_DELAY_MILLIS)
                        visibility.animateTo(
                            targetValue = 0f,
                            animationSpec = tween(
                                durationMillis = KsScrollIndicatorDefaults.FADE_OUT_MILLIS,
                                easing = KsScrollIndicatorDefaults.fadeOutEasing,
                            ),
                        )
                    }
                }
            }
    }
    return visibility
}

/**
 * 縦スクロールインジケータのバーの矩形を求める。描くものが無いときは null。
 *
 * コンテンツが表示領域に収まるとき (スクロールできないとき) は描かない。
 *
 * @param containerSize インジケータを描く領域 (コンポーネントの全体) の大きさ
 * @param scrollOffset コンテンツの先頭からのスクロール量
 * @param contentSize コンテンツ全体の長さ (前後の余白を含む)
 * @param viewportSize 表示領域の長さ
 * @param layoutDirection 末尾側の端を決めるレイアウトの向き
 * @param thicknessPx バーの太さ
 * @param edgeInsetPx 端からバーまでの距離
 * @param minLengthPx バーの最短の長さ
 */
internal fun ksScrollIndicatorBounds(
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

/**
 * `scrollIndicatorState` のスクロール量を、同じ状態のコンテンツ全体の長さと同じ数え方に揃える。
 *
 * `scrollIndicatorState` のスクロール量は「可視行の平均の高さ × 先頭行の行番号 + 先頭の項目の
 * ずれ」で求められるが、行番号には画面に見えている最初の行を、ずれには上側の contentPadding の
 * 境目にかかる項目 (`firstVisibleItemIndex`) からの量を使う。上側の余白の領域にまだ前の行が
 * 見えている間はこの 2 つが別の行を指し、スクロール量がその行の分だけ小さく出る。そのため
 * 余白があると、スクロールの途中で位置が逆戻りし、末尾まで送っても割合が 1 に届かない。
 *
 * ここでは行番号の食い違いの分だけ、見えている行どうしの実際の距離を足して揃える。
 * 行の高さを推定し直すのではなく、公式の値の数え方の食い違いだけを補う。
 * 余白が無いとき (2 つが同じ行を指すとき) は公式の値をそのまま返す。
 *
 * @param officialOffset `scrollIndicatorState` のスクロール量
 * @param firstVisibleItemIndex 上側の余白の境目にかかる項目の番号
 * @param visibleItems 表示中の項目 (番号の昇順)
 */
internal fun ksAlignedScrollOffset(
    officialOffset: Int,
    firstVisibleItemIndex: Int,
    visibleItems: List<LazyGridItemInfo>,
): Int {
    val firstOnScreen = visibleItems.firstOrNull() ?: return officialOffset
    val anchor = visibleItems.firstOrNull { it.index == firstVisibleItemIndex } ?: return officialOffset
    if (anchor.row <= firstOnScreen.row) return officialOffset
    return officialOffset + (anchor.offset.y - firstOnScreen.offset.y)
}

/**
 * グリッドの前面に縦スクロールインジケータを描く。
 *
 * 表示の濃さとスクロール位置は描画フェーズでだけ読むため、スクロールしてもコンポジションは
 * やり直されず、描き直しだけが起きる。描くだけでタッチは受け取らないため、つまんで動かせない。
 *
 * @param gridState 位置と長さを読むグリッドの状態
 * @param visibility [rememberKsScrollIndicatorVisibility] が動かす表示の濃さ
 * @param color バーの色
 */
internal fun Modifier.ksScrollIndicator(
    gridState: LazyGridState,
    visibility: Animatable<Float, AnimationVector1D>,
    color: Color,
): Modifier = drawWithContent {
    drawContent()
    val alpha = visibility.value
    if (alpha <= 0f) return@drawWithContent
    val metrics = gridState.scrollIndicatorState ?: return@drawWithContent
    val bounds = ksScrollIndicatorBounds(
        containerSize = size,
        scrollOffset = ksAlignedScrollOffset(
            officialOffset = metrics.scrollOffset,
            firstVisibleItemIndex = gridState.firstVisibleItemIndex,
            visibleItems = gridState.layoutInfo.visibleItemsInfo,
        ),
        contentSize = metrics.contentSize,
        viewportSize = metrics.viewportSize,
        layoutDirection = layoutDirection,
        thicknessPx = KsScrollIndicatorDefaults.thickness.toPx(),
        edgeInsetPx = KsScrollIndicatorDefaults.edgeInset.toPx(),
        minLengthPx = KsScrollIndicatorDefaults.minLength.toPx(),
    ) ?: return@drawWithContent
    drawRoundRect(
        color = color,
        topLeft = bounds.topLeft,
        size = bounds.size,
        cornerRadius = CornerRadius(bounds.width / 2f),
        alpha = alpha,
    )
}
