package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.layout.IntrinsicMeasurable
import androidx.compose.ui.layout.IntrinsicMeasureScope
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.LayoutModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** 高さがまだ一度も測られていないことを表す値。 */
private const val KsUnspecifiedHeight = -1

/**
 * 行の高さ変化の補間の仕方。跳ね返らずに落ち着く。
 *
 * 収束とみなす幅は 1 px。px 単位の高さでは、これより細かい差は表示に現れない。
 */
private val KsHeightAnimationSpec: AnimationSpec<Int> = spring(
    dampingRatio = Spring.DampingRatioNoBouncy,
    stiffness = Spring.StiffnessMediumLow,
    visibilityThreshold = 1,
)

/**
 * content の高さが変わったとき、この修飾を付けた箱の高さをその値へ補間して追従させる。
 *
 * 補間している間は content 自身も現在の高さで測り直す。content の背景・枠が箱の高さと同じ量で
 * 伸び縮みするため、外側 (区切り線・タップ領域) が使う高さとの間に何も描かれない帯ができない。
 * 補間している間は描画を箱の高さで切り取る。渡した高さの制約に従わない content
 * (`Modifier.requiredHeight` を使うものなど) が行の外へ描かれないようにするため。
 *
 * content には高さの制約だけを渡し、幅は下限を外して測る。箱の幅は与えられた幅のままとし、
 * content が狭いときの水平位置は [horizontalAlignment] で決める。
 *
 * 最初の測定では補間しない (高さ 0 から自然高へ伸びる動きを出さない)。項目が再利用されたときも
 * 直前の項目の高さは持ち越さない。
 *
 * この修飾を付けた箱は、高さの制約を content までそのまま渡す必要がある
 * (`Box` なら `propagateMinConstraints = true`)。
 *
 * @param horizontalAlignment content が箱より狭いときの水平位置
 * @param tracker 補間の開始と終了を数える先。同じコレクションの配置のアニメーションを止めるのに使う
 */
internal fun Modifier.ksAnimatedHeight(
    horizontalAlignment: Alignment.Horizontal = Alignment.Start,
    tracker: KsHeightAnimationTracker? = null,
): Modifier = this then KsAnimatedHeightElement(horizontalAlignment, tracker)

/**
 * 同じコレクションの中で進行中の、行の高さ変化の補間の数を数える。
 *
 * 補間の間は後ろの行が毎フレーム少しずつ押し出される。この押し出しを配置のアニメーション
 * (`animateItem`) が追いかけると、押し出される行が高さの変化に遅れ、行の間に何も描かれない帯が
 * できる。補間の間は配置のアニメーションを止めるために、この数を読む。
 *
 * 補間は、始めた測定では高さを変えず、次のフレーム以降に高さを動かす。数は補間を始めた測定の中で
 * 増やすため、それを読むコンポジションは高さが動き始める前に反映される。
 */
@Stable
internal class KsHeightAnimationTracker {
    private var activeCount by mutableIntStateOf(0)

    /** 高さの補間が 1 つでも進行中かどうか。 */
    val isAnimating: Boolean
        get() = activeCount > 0

    fun onStart() {
        activeCount += 1
    }

    fun onEnd() {
        activeCount = (activeCount - 1).coerceAtLeast(0)
    }
}

private data class KsAnimatedHeightElement(
    private val horizontalAlignment: Alignment.Horizontal,
    private val tracker: KsHeightAnimationTracker?,
) : ModifierNodeElement<KsAnimatedHeightNode>() {
    override fun create(): KsAnimatedHeightNode = KsAnimatedHeightNode(horizontalAlignment, tracker)

    override fun update(node: KsAnimatedHeightNode) {
        node.horizontalAlignment = horizontalAlignment
        node.tracker = tracker
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "ksAnimatedHeight"
        properties["horizontalAlignment"] = horizontalAlignment
    }
}

private class KsAnimatedHeightNode(
    var horizontalAlignment: Alignment.Horizontal,
    var tracker: KsHeightAnimationTracker?,
) : Modifier.Node(), LayoutModifierNode, DrawModifierNode {

    /** 現在の高さ。目標へ向けて補間する。 */
    private var height: Animatable<Int, AnimationVector1D>? = null

    /** 直近に測った自然高。補間の目標であり、この値が変わったときだけ補間を始める。 */
    private var targetHeight: Int = KsUnspecifiedHeight

    /** 描画を箱の高さで切り取るかどうか。補間している間だけ切り取る。 */
    private var clipsContent: Boolean = false

    /** 進行中の補間。項目の再利用・切り離しのときに打ち切る。 */
    private var animationJob: Job? = null

    override fun onDetach() {
        reset()
    }

    override fun onReset() {
        reset()
    }

    override fun MeasureScope.measure(
        measurable: Measurable,
        constraints: Constraints,
    ): MeasureResult {
        // 目標にする自然高は、高さを無制約にして測って得る。
        val naturalPlaceable = measurable.measure(
            constraints.copy(minWidth = 0, minHeight = 0, maxHeight = Constraints.Infinity),
        )
        val currentHeight = updateAnimation(constraints.constrainHeight(naturalPlaceable.height))
        val isInterpolating = currentHeight != naturalPlaceable.height
        // 補間中だけ content を現在の高さで測り直す。補間していないときは 1 回の測定で済む。
        val placeable = if (isInterpolating) {
            measurable.measure(
                constraints.copy(
                    minWidth = 0,
                    minHeight = currentHeight,
                    maxHeight = currentHeight,
                ),
            )
        } else {
            naturalPlaceable
        }
        val width = constraints.constrainWidth(maxOf(placeable.width, constraints.minWidth))
        // 測り直した content の高さは制約へ丸められた値であり、渡した制約に従わない content が
        // どれだけはみ出すかは測定結果から分からない。補間中は一律に切り取る。
        clipsContent = isInterpolating
        return layout(width, currentHeight) {
            placeable.place(
                x = horizontalAlignment.align(placeable.width, width, layoutDirection),
                y = 0,
            )
        }
    }

    override fun ContentDrawScope.draw() {
        if (clipsContent) {
            // 箱からはみ出す content を切り取る。描画時の切り取りで済ませ、
            // 合成レイヤは作らない (大量件数のスクロールへの上乗せを避けるため)。
            clipRect(right = size.width, bottom = size.height) { this@draw.drawContent() }
        } else {
            drawContent()
        }
    }

    /**
     * 固有サイズの問い合わせは content へそのまま渡す。ただし補間している間の高さは、
     * 実際に測る高さと食い違わないよう補間中の値を返す。問い合わせだけで補間が始まらない
     * ようにするため、いずれも [updateAnimation] を経由しない。
     */
    override fun IntrinsicMeasureScope.minIntrinsicHeight(
        measurable: IntrinsicMeasurable,
        width: Int,
    ): Int = interpolatingHeight() ?: measurable.minIntrinsicHeight(width)

    override fun IntrinsicMeasureScope.maxIntrinsicHeight(
        measurable: IntrinsicMeasurable,
        width: Int,
    ): Int = interpolatingHeight() ?: measurable.maxIntrinsicHeight(width)

    override fun IntrinsicMeasureScope.minIntrinsicWidth(
        measurable: IntrinsicMeasurable,
        height: Int,
    ): Int = measurable.minIntrinsicWidth(height)

    override fun IntrinsicMeasureScope.maxIntrinsicWidth(
        measurable: IntrinsicMeasurable,
        height: Int,
    ): Int = measurable.maxIntrinsicWidth(height)

    /** 補間している間の現在の高さ。補間していなければ null。 */
    private fun interpolatingHeight(): Int? = height?.takeIf { it.isRunning }?.value

    /**
     * 自然高の変化を補間へ反映し、この測定で使う高さを返す。
     *
     * 補間中の高さは snapshot state であり、測定の中で読むことで値が動くたびに測定が
     * やり直される。
     */
    private fun updateAnimation(naturalHeight: Int): Int {
        val current = height
        if (current == null) {
            height = Animatable(naturalHeight, Int.VectorConverter, visibilityThreshold = 1)
            targetHeight = naturalHeight
            return naturalHeight
        }
        if (targetHeight != naturalHeight) {
            targetHeight = naturalHeight
            // 実行中の補間は打ち切り、現在の高さから新しい目標へ向け直す。
            animationJob?.cancel()
            val job = coroutineScope.launch {
                current.animateTo(naturalHeight, KsHeightAnimationSpec)
            }
            // 始まる前に打ち切られた補間でも数を戻せるよう、終わりは完了の通知で数える。
            tracker?.let { counter ->
                counter.onStart()
                job.invokeOnCompletion { counter.onEnd() }
            }
            animationJob = job
        }
        return current.value
    }

    private fun reset() {
        animationJob?.cancel()
        animationJob = null
        height = null
        targetHeight = KsUnspecifiedHeight
        clipsContent = false
    }
}
