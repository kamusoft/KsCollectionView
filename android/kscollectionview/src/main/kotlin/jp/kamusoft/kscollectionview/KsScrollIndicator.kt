package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.lazy.grid.LazyGridItemInfo
import androidx.compose.foundation.lazy.grid.LazyGridLayoutInfo
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
import kotlin.math.roundToInt

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
 *
 * @param extraDragInteractions 一覧の外 (一覧に重ねた表示) から一覧をスクロールさせるドラッグの知らせ。
 *   一覧自身のドラッグと同じく表示する
 */
@Composable
internal fun rememberKsScrollIndicatorVisibility(
    gridState: LazyGridState,
    extraDragInteractions: InteractionSource? = null,
): Animatable<Float, AnimationVector1D> {
    val visibility = remember(gridState) { Animatable(0f) }
    // 値はこの下の effect の中でだけ読む (コンポジションでは読まない)。
    val isDragged = gridState.interactionSource.collectIsDraggedAsState()
    val isExtraDragged = (extraDragInteractions ?: gridState.interactionSource).collectIsDraggedAsState()
    LaunchedEffect(gridState, isDragged, isExtraDragged) {
        // ドラッグで始まったスクロールの間 (慣性スクロールを含む) だけ表示を保つ。
        var isUserScroll = false
        snapshotFlow { (isDragged.value || isExtraDragged.value) to gridState.isScrollInProgress }
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

/** インジケータに渡す、スクロール量とコンテンツ全体の長さ。 */
internal class KsScrollIndicatorMetrics(val scrollOffset: Int, val contentSize: Int)

/**
 * `scrollIndicatorState` の値を、グループの見出しとルートのヘッダー / フッターを 1 行と数える
 * 行の数え方に揃える。
 *
 * 公式のコンテンツ全体の長さは「可視行の平均の高さ × `ceil(lazy の項目数 ÷ 列数)` + 前後の余白」で、
 * 全幅の項目 (見出し・ヘッダー / フッター) を 1 ÷ 列数 行と数えるため、見出しの数に比例して
 * 短く出る。そのままでは末尾に達する前にバーが下端に着く。ここでは公式の値から可視行の平均の高さを
 * 取り出し、[rows] が数えた全体の行数を掛けて長さを求め直す。
 *
 * スクロール量は「可視行の平均の高さ × 画面に見えている最初の行の番号 + 先頭の項目のずれ」で、
 * 行の番号は [rows] の数え方で数え直す。上端に固定されている見出しは本来の位置に無いため、最初の
 * 行には数えない。上側の contentPadding の領域に前の行が見えている間は、公式の値と同じく行の番号と
 * ずれが別の行を指して値が 1 行分小さく出るため、食い違った行どうしの実際の距離を足して揃える。
 * 余白の分を一律に差し引く補正では、送る途中で逆戻りが残る。
 *
 * @param officialContentSize `scrollIndicatorState` のコンテンツ全体の長さ
 * @param info グリッドの現在の配置
 * @param firstVisibleItemIndex 上側の余白の境目にかかる項目の番号
 * @param firstVisibleItemScrollOffset その項目の上へ隠れた量
 * @param rows lazy の index から行の番号への対応と、全体の行数
 */
internal fun ksGroupedScrollIndicatorMetrics(
    officialContentSize: Int,
    info: LazyGridLayoutInfo,
    firstVisibleItemIndex: Int,
    firstVisibleItemScrollOffset: Int,
    rows: KsGroupRows,
): KsScrollIndicatorMetrics? {
    val visible = info.visibleItemsInfo
    if (visible.isEmpty() || info.totalItemsCount == 0) return null
    val paddings = info.beforeContentPadding + info.afterContentPadding
    val officialLines = (info.totalItemsCount + info.maxSpan - 1) / info.maxSpan.coerceAtLeast(1)
    if (officialLines <= 0) return null
    val lineTotal = (officialContentSize - paddings).coerceAtLeast(0)
    val averageLine = lineTotal.toDouble() / officialLines
    val contentSize = paddings + (averageLine * rows.totalRows).roundToInt()

    val firstOnScreen = visible
        .filterNot { it.isDisplacedHeader(visible) }
        .minWithOrNull(compareBy<LazyGridItemInfo>({ it.offset.y }, { it.index }))
        ?: return null
    var scrollOffset = (averageLine * rows.rowOfLazy(firstOnScreen.index)).roundToInt() + firstVisibleItemScrollOffset
    val anchor = visible.firstOrNull { it.index == firstVisibleItemIndex }
    if (anchor != null && anchor.row > firstOnScreen.row) {
        scrollOffset += anchor.offset.y - firstOnScreen.offset.y
    }
    return KsScrollIndicatorMetrics(scrollOffset = scrollOffset, contentSize = contentSize)
}

/**
 * 上端に固定されて本来の位置から動いている見出しかどうか。
 *
 * 固定中の見出しはそのグループの行に重ねて描かれるため、後ろに並ぶ可視の項目が見出しの下端より
 * 上から始まる。本来の位置にある見出しの後ろの項目は、見出しの下端から始まる。
 */
private fun LazyGridItemInfo.isDisplacedHeader(visible: List<LazyGridItemInfo>): Boolean {
    if (contentType != KsGroupHeaderContentType) return false
    val bottom = offset.y + size.height
    return visible.any { it.index > index && it.offset.y < bottom - 1 }
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
 * @param rows 全体の長さと位置を数える行の数え方 (見出しとヘッダー / フッターを 1 行と数える)
 */
internal fun Modifier.ksScrollIndicator(
    gridState: LazyGridState,
    visibility: Animatable<Float, AnimationVector1D>,
    color: Color,
    rows: KsGroupRows,
): Modifier = drawWithContent {
    drawContent()
    val alpha = visibility.value
    if (alpha <= 0f) return@drawWithContent
    val metrics = gridState.scrollIndicatorState ?: return@drawWithContent
    val aligned = ksGroupedScrollIndicatorMetrics(
        officialContentSize = metrics.contentSize,
        info = gridState.layoutInfo,
        firstVisibleItemIndex = gridState.firstVisibleItemIndex,
        firstVisibleItemScrollOffset = gridState.firstVisibleItemScrollOffset,
        rows = rows,
    ) ?: return@drawWithContent
    val bounds = ksScrollIndicatorBounds(
        containerSize = size,
        scrollOffset = aligned.scrollOffset,
        contentSize = aligned.contentSize,
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
