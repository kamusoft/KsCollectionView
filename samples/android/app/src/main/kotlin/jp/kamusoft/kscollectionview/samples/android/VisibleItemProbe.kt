package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.node.LayoutAwareModifierNode
import androidx.compose.ui.node.ModifierNodeElement

/**
 * 画面に表示中の項目を、操作したときにだけ読み取る。
 *
 * コレクションの公開 API は表示中の項目を知らせないため、Sample の操作 (表示中の項目を動かす) の
 * ためにここで読む。項目の行に [visibleItemProbe] を付けると、その行が作られている間だけ登録され、
 * [visibleItemIds] を呼んだ時点の表示範囲に重なっているものを返す。見え隠れのたびに知らせを
 * 受け取る形にすると、操作しないときにもスクロールの仕事が増えるため、判定はボタンを押したときの
 * 1 回だけにする。
 *
 * 呼び出しはメインスレッドに限る (登録と判定をコンポジションと同じスレッドで行う)。
 */
class VisibleItemProbe {
    private val nodes = LinkedHashSet<VisibleItemProbeNode>()

    /**
     * 表示範囲に重なっている項目の ID を返す。
     *
     * 一度も配置されていない行 (先読みで作られただけの行) は数えない。表示範囲は祖先の切り取りを
     * 反映した窓の上の矩形で判定するため、スクロールして見えなくなった行は幅か高さが 0 になる。
     */
    fun visibleItemIds(): List<Any> = nodes.mapNotNull { node ->
        val coordinates = node.coordinates?.takeIf { it.isAttached } ?: return@mapNotNull null
        if (coordinates.boundsInWindow().isEmpty) null else node.id
    }

    internal fun register(node: VisibleItemProbeNode) {
        nodes += node
    }

    internal fun unregister(node: VisibleItemProbeNode) {
        nodes -= node
    }
}

/**
 * この行を [probe] の判定の対象にする。
 *
 * @param probe 登録先
 * @param id この行の項目の ID
 */
fun Modifier.visibleItemProbe(probe: VisibleItemProbe, id: Any): Modifier =
    this then VisibleItemProbeElement(probe, id)

private data class VisibleItemProbeElement(
    val probe: VisibleItemProbe,
    val id: Any,
) : ModifierNodeElement<VisibleItemProbeNode>() {
    override fun create(): VisibleItemProbeNode = VisibleItemProbeNode(probe, id)

    override fun update(node: VisibleItemProbeNode) {
        if (node.probe !== probe) {
            node.probe.unregister(node)
            node.probe = probe
            if (node.isAttached) probe.register(node)
        }
        node.id = id
    }
}

/** 行の置き場所を最後に配置された時点のまま持つ。判定は [VisibleItemProbe] が行う。 */
internal class VisibleItemProbeNode(
    var probe: VisibleItemProbe,
    var id: Any,
) : Modifier.Node(), LayoutAwareModifierNode {
    /** 最後に配置されたときの座標。一度も配置されていなければ null。 */
    var coordinates: LayoutCoordinates? = null
        private set

    override fun onAttach() {
        probe.register(this)
    }

    override fun onDetach() {
        probe.unregister(this)
        coordinates = null
    }

    override fun onPlaced(coordinates: LayoutCoordinates) {
        this.coordinates = coordinates
    }
}
