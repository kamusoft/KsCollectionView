package jp.kamusoft.kscollectionview

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.node.LayoutModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp

/** 持ち上げた項目に付ける影の高さ。 */
private val KsReorderLiftElevation = 8.dp

/**
 * 並べ替えで持ち上げた項目を、指の下 (置いた後は置き場所への戻りの途中) に描く。
 *
 * 項目の修飾のいちばん外側 (配置のアニメーションの内側) に付け、間隔・区切り線・タップ領域を含む項目全体を
 * ずらす。持ち上げている間はほかの項目と固定中の見出しより手前に描く。影はここでは付けず、間隔の内側に付けた
 * [ksReorderLiftShadow] が付ける。持ち上げていない項目は層を作らずにそのまま置く。
 *
 * ずらす量は配置の中で求める (自分の配置された位置と指の位置を読むため、スクロールや置き場所の入れ替えと
 * 同じフレームで追従する)。持ち上げていない項目が読むのは持ち上げた項目のキーだけにする。
 */
internal fun Modifier.ksReorderLift(key: Any, controller: KsReorderController<*>): Modifier =
    this then KsReorderLiftElement(key, controller)

private class KsReorderLiftElement(
    private val key: Any,
    private val controller: KsReorderController<*>,
) : ModifierNodeElement<KsReorderLiftNode>() {
    override fun create(): KsReorderLiftNode = KsReorderLiftNode(key, controller)

    override fun update(node: KsReorderLiftNode) {
        node.key = key
        node.controller = controller
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "ksReorderLift"
        properties["key"] = key
    }

    override fun equals(other: Any?): Boolean =
        this === other || (other is KsReorderLiftElement && key == other.key && controller === other.controller)

    override fun hashCode(): Int = 31 * key.hashCode() + System.identityHashCode(controller)
}

private class KsReorderLiftNode(
    var key: Any,
    var controller: KsReorderController<*>,
) : Modifier.Node(), LayoutModifierNode {

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        val placeable = measurable.measure(constraints)
        return layout(placeable.width, placeable.height) {
            val lifted = controller.liftedKey == key
            // 配置された位置は、配置の中で自分の座標から読む。座標を読んだ配置は、一覧のスクロールや置き場所の
            // 入れ替えで項目が動くたびにやり直されるため、同じフレームで指の下に保てる。
            val placed = if (lifted) coordinates?.positionInParent() else null
            val offset = if (placed != null) controller.liftOffset(key, placed) else null
            if (offset == null) {
                placeable.place(0, 0)
            } else {
                // 固定中の見出し (手前に 1 で描く) より手前に描く。
                placeable.placeWithLayer(offset, zIndex = 2f)
            }
        }
    }
}

/**
 * 持ち上げた項目の影を、項目の間隔の内側 (content・区切り線・タップ領域の範囲) にだけ付ける。
 *
 * 項目の上下の間隔 (行間・見出しの下の間隔・グループ間の間隔) は何も描かない透明な範囲で、そこまで影の輪郭に
 * 含めると、影が透明な範囲を透けて見出しの帯のような灰色の板として描かれる (グループの最後の位置へ運ぶと
 * グループ間の間隔の分だけ出る)。このため影は [ksReorderLift] の層ではなく、間隔を置く修飾より内側の層に付ける。
 * 持ち上げていない項目は層を作らずにそのまま置く。
 */
internal fun Modifier.ksReorderLiftShadow(key: Any, controller: KsReorderController<*>): Modifier =
    this then KsReorderLiftShadowElement(key, controller)

private class KsReorderLiftShadowElement(
    private val key: Any,
    private val controller: KsReorderController<*>,
) : ModifierNodeElement<KsReorderLiftShadowNode>() {
    override fun create(): KsReorderLiftShadowNode = KsReorderLiftShadowNode(key, controller)

    override fun update(node: KsReorderLiftShadowNode) {
        node.key = key
        node.controller = controller
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "ksReorderLiftShadow"
        properties["key"] = key
    }

    override fun equals(other: Any?): Boolean =
        this === other || (other is KsReorderLiftShadowElement && key == other.key && controller === other.controller)

    override fun hashCode(): Int = 31 * key.hashCode() + System.identityHashCode(controller)
}

private class KsReorderLiftShadowNode(
    var key: Any,
    var controller: KsReorderController<*>,
) : Modifier.Node(), LayoutModifierNode {

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        val placeable = measurable.measure(constraints)
        return layout(placeable.width, placeable.height) {
            if (controller.liftedKey != key) {
                placeable.place(0, 0)
            } else {
                val elevation = KsReorderLiftElevation.toPx()
                placeable.placeWithLayer(0, 0) {
                    shadowElevation = elevation * controller.liftAmount(key)
                }
            }
        }
    }
}
