package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.node.LayoutModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.invalidatePlacement
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Constraints
import kotlinx.coroutines.launch

/**
 * 出現をフェードで見せる、挿入されたばかりの項目・見出しのキーの集合。
 *
 * 配置のアニメーション (`animateItem`) は、配列を差し替えたその測定で表示範囲に配置された項目
 * だけをフェードで出す。末尾を表示中の末尾への挿入では、挿入した項目は表示範囲のすぐ外に足され、
 * 表示範囲を末尾へ送るスクロールで次のフレーム以降に現れるため、そのままではフェードせずに
 * 表示範囲の端から滑り込むだけになる。そうした項目のキーをここへ登録し、最初に配置されたときに
 * [ksAppearance] がフェードで出す。
 *
 * 集合はコンポジションでは読まない (読み書きは配置と命令の処理の中だけで行う)。
 */
internal class KsAppearingItems {
    private val keys = HashSet<Any>()

    /** 最初に配置されたときにフェードで出すキーを登録する。前の登録は捨てる。 */
    fun replace(newKeys: Collection<Any>) {
        keys.clear()
        keys.addAll(newKeys)
    }

    /** 登録を取り消す。すでに表示範囲に配置されてフェードが済んだキーに使う。 */
    fun removeAll(consumed: Collection<Any>) {
        keys.removeAll(consumed.toSet())
    }

    fun clear() {
        keys.clear()
    }

    /** [key] が登録されていれば取り除いて true を返す。フェードは 1 度だけ行う。 */
    fun consume(key: Any): Boolean = keys.remove(key)
}

/** 出現のフェードの速さ。`animateItem` の既定の出現のフェードと同じばね。 */
private val KsAppearanceSpec = spring<Float>(stiffness = Spring.StiffnessMediumLow)

/**
 * [appearing] に [key] が登録されていれば、最初に配置されたときに透明から不透明へフェードさせる。
 *
 * 登録されていない項目は層を作らずにそのまま置く (大量件数のスクロールへの上乗せを避けるため)。
 */
internal fun Modifier.ksAppearance(key: Any, appearing: KsAppearingItems): Modifier =
    this then KsAppearanceElement(key, appearing)

private data class KsAppearanceElement(
    private val key: Any,
    private val appearing: KsAppearingItems,
) : ModifierNodeElement<KsAppearanceNode>() {
    override fun create(): KsAppearanceNode = KsAppearanceNode(key, appearing)

    override fun update(node: KsAppearanceNode) {
        if (node.key != key) node.reset()
        node.key = key
        node.appearing = appearing
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "ksAppearance"
        properties["key"] = key
    }
}

private class KsAppearanceNode(
    var key: Any,
    var appearing: KsAppearingItems,
) : Modifier.Node(), LayoutModifierNode {

    /** 最初の配置で、フェードさせるかを判定済みかどうか。 */
    private var decided = false

    /** フェードの透明度。フェードさせないときは null。 */
    private var alpha: Animatable<Float, *>? = null

    override fun onReset() {
        reset()
    }

    override fun onDetach() {
        reset()
    }

    fun reset() {
        decided = false
        alpha = null
    }

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        val placeable = measurable.measure(constraints)
        return layout(placeable.width, placeable.height) {
            if (!decided) {
                decided = true
                if (appearing.consume(key)) {
                    val animation = Animatable(0f)
                    alpha = animation
                    coroutineScope.launch {
                        animation.animateTo(1f, KsAppearanceSpec)
                        // 出し終えたら層を外す。
                        alpha = null
                        requestRelayoutAfterFade()
                    }
                }
            }
            val fading = alpha
            if (fading != null) {
                // 透明度は snapshot state で、層の設定の中で読むため、値が動くたびに層だけが更新される。
                placeable.placeWithLayer(0, 0) { this.alpha = fading.value }
            } else {
                placeable.place(0, 0)
            }
        }
    }

    private fun requestRelayoutAfterFade() {
        if (isAttached) {
            invalidatePlacement()
        }
    }
}
