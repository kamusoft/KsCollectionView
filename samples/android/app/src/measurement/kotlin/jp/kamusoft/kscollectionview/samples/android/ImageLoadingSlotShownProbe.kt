package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.GlobalPositionAwareModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.requireLayoutCoordinates
import androidx.compose.ui.platform.InspectorInfo

/**
 * 読み込み中の表示が実際に画面に出た最初の時点で、[onShown] を 1 度だけ呼ぶ。
 *
 * 読み込み中の表示は、組み立てられても画面に描かれないまま消えることがある。遅延グリッドは画面外の
 * アイテムを先に組み立てて測るが、測っただけのアイテムは置かれず描かれない。また
 * [jp.kamusoft.kscollectionview.KsImage] は、画面に出る前に組み立てた画像について読み込み中の表示を
 * 中身として組み立てておき、画面に置かれた時点で先読みの項目に当たれば、その中身を描かずに項目を
 * 描く。組み立ての回数ではこれらを画面に出た読み込み中と見分けられない。
 *
 * そこで、次の 2 つがそろった最初の時点を「画面に出た」とする。
 * - この表示の描画が 1 度でも走った (親が中身を描かない場合は走らない)
 * - 置かれた位置が、祖先の範囲で切り取っても見える範囲に少しでも掛かっている (画面外に置かれて
 *   描かれた分は、見える位置に来た時点で数える)
 *
 * 1 つの表示につき 1 回だけ呼ぶ。遅延グリッドが表示を別のアイテムに使い回すときは、呼んだ記録を
 * 捨てて数え直す。
 *
 * 計測用の画面 (この構成) と、数えることが要求された構成の計数 ([ImageLoadingSlotCounter]) の
 * 両方から使う。計数の実体はこの構成を含むビルド種別にしか入らないため、ここに置く。
 *
 * @param onShown 初めて画面に出たときに呼ぶ処理
 */
fun Modifier.onLoadingSlotShown(onShown: () -> Unit): Modifier =
    this then LoadingSlotShownElement(onShown)

private data class LoadingSlotShownElement(
    val onShown: () -> Unit,
) : ModifierNodeElement<LoadingSlotShownNode>() {
    override fun create(): LoadingSlotShownNode = LoadingSlotShownNode(onShown)

    override fun update(node: LoadingSlotShownNode) {
        node.onShown = onShown
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "onLoadingSlotShown"
    }
}

private class LoadingSlotShownNode(
    var onShown: () -> Unit,
) : Modifier.Node(), DrawModifierNode, GlobalPositionAwareModifierNode {

    // 描画が 1 度でも走ったか。親が中身を描かない限り、置かれた後の最初の描画で立つ。
    private var drawn = false

    // 画面に出たことを知らせ終えたか。
    private var reported = false

    override fun ContentDrawScope.draw() {
        drawContent()
        drawn = true
        reportIfVisible(requireLayoutCoordinates())
    }

    override fun onGloballyPositioned(coordinates: LayoutCoordinates) {
        // 描かれた後に見える位置へ動いた場合 (画面外で置かれて描かれ、スクロールで入ってきた
        // 場合) は、描画が走り直さないことがあるため、位置の変化でも確かめる。
        if (drawn) reportIfVisible(coordinates)
    }

    override fun onReset() {
        // 遅延グリッドが別のアイテムに使い回すときは、新しい表示として数え直す。
        drawn = false
        reported = false
    }

    private fun reportIfVisible(coordinates: LayoutCoordinates) {
        if (reported || !coordinates.isAttached) return
        // 祖先の範囲で切り取った見える範囲。画面外に置かれていれば空になる。
        val visible = coordinates.boundsInWindow()
        if (visible.width <= 0f || visible.height <= 0f) return
        reported = true
        onShown()
    }
}
