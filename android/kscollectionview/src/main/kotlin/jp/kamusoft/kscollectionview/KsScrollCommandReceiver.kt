package jp.kamusoft.kscollectionview

import android.content.Context
import android.os.Looper
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * コレクション 1 つ分のスクロール命令の受け口。
 *
 * 命令は snapshot state のキューへ積み、コンポジション後に動く単一の consumer が発行順に
 * 取り出す。取り出しの時点で最新の配列を使って ID を index へ解決するため、配列の差し替えと
 * 同じ処理内で発行された命令も差し替え後の配列で解決される (core/ADR-0007)。
 */
internal class KsScrollCommandReceiver(context: Context) {

    /** debug 判定にだけ使う。コントローラの寿命が画面より長い場合に備えて application を持つ。 */
    val context: Context = context.applicationContext ?: context

    private val queue = mutableStateListOf<KsScrollCommand>()

    /**
     * 処理済みの命令の件数。
     *
     * 何も表示を変えない命令 (存在しない ID など) でも処理が済んだ時点をこの値の変化で
     * 観測できるようにするための計数。
     */
    var processedCommandCount: Int = 0
        private set

    /**
     * これまでに積まれた命令の延べ件数。consumer はこの値の変化を待つ。
     *
     * 残件数ではなく単調増加の延べ件数を観測する。残件数は「積む → 消費し切る → また積む」で
     * 同じ値に戻り、変化として観測されないことがあるため。
     */
    var enqueuedCount: Int by mutableIntStateOf(0)
        private set

    fun enqueue(command: KsScrollCommand) {
        assertMainThread()
        queue.add(command)
        enqueuedCount++
    }

    /** 先頭の命令を取り出す。空なら null。 */
    fun dequeue(): KsScrollCommand? = queue.removeFirstOrNull()

    fun markProcessed() {
        processedCommandCount++
    }

    private fun assertMainThread() {
        if (Looper.myLooper() == Looper.getMainLooper()) return
        KsDiagnostics.invalidInput(
            context,
            "KsScrollController の命令はメインスレッドから呼んでください",
        )
    }
}

/** 位置合わせが済んだとみなす残差の既定の閾値。これ以下のずれは目に見えないため詰めない。 */
internal val KsScrollAlignmentTolerance: Dp = 4.dp

/**
 * 項目 1 件の lazy 上の置き場所。スクロール命令の解決と、列数の変化での位置の保持に使う。
 *
 * @param lazyIndex 項目の lazy の index
 * @param leadingInsetPx 項目の上側に置いた間隔 (行間・見出しの下の間隔)。content はこの下から始まる
 * @param trailingInsetPx 項目の下側に置いた間隔 (グループ間の間隔)
 * @param pinnedHeaderKey 項目のグループの見出しが上端に固定される場合の、その見出しのキー
 */
internal class KsItemPlacement(
    val lazyIndex: Int,
    val leadingInsetPx: Int = 0,
    val trailingInsetPx: Int = 0,
    val pinnedHeaderKey: Any? = null,
)

/**
 * 命令の解決結果。lazy 側の index と、その index に対して要求された配置。
 *
 * @param contentType 対象の再利用種別。対象が可視でないときの高さの推定に使う
 * @param leadingInsetPx 対象の上側の間隔。配置は間隔を除いた content の範囲で合わせる
 * @param trailingInsetPx 対象の下側の間隔
 * @param pinnedHeaderKey 対象のグループの見出しが上端に固定される場合の見出しのキー。先頭へ送る
 *   命令は対象をこの見出しのすぐ下に置く
 */
internal class KsScrollTarget(
    val index: Int,
    val position: KsScrollPosition,
    val animated: Boolean,
    val contentType: Any?,
    val leadingInsetPx: Int = 0,
    val trailingInsetPx: Int = 0,
    val pinnedHeaderKey: Any? = null,
)

/**
 * 命令を lazy 側の index へ解決する。
 *
 * 対象が見つからない場合 (存在しない ID・実行前に削除された要素・項目もヘッダーも無い) は
 * null を返し、呼び出し元は何もせず次の命令へ進む。
 *
 * @param indexOfId 安定 ID を表示中の配列での位置に変換する。見つからなければ負の値を返す
 * @param placementOfItem 配列での位置から lazy 上の置き場所を求める (ヘッダー・見出しの分のずれ込み)
 * @param totalLazyItemCount ヘッダー・見出し・フッターを含む lazy 項目の総数
 */
internal fun resolveScrollTarget(
    command: KsScrollCommand,
    indexOfId: (Any) -> Int,
    placementOfItem: (Int) -> KsItemPlacement,
    totalLazyItemCount: Int,
    contentTypeAt: (Int) -> Any?,
    context: Context,
): KsScrollTarget? {
    if (totalLazyItemCount == 0) return null
    return when (command) {
        is KsScrollCommand.ToStart -> KsScrollTarget(
            index = 0,
            position = KsScrollPosition.Start,
            animated = command.animated,
            contentType = contentTypeAt(0),
        )

        is KsScrollCommand.ToEnd -> KsScrollTarget(
            index = totalLazyItemCount - 1,
            position = KsScrollPosition.End,
            animated = command.animated,
            contentType = contentTypeAt(totalLazyItemCount - 1),
        )

        is KsScrollCommand.ToItem -> {
            val itemIndex = indexOfId(command.id)
            if (itemIndex < 0) {
                if (KsDiagnostics.isDebugBuild(context)) {
                    KsDiagnostics.warn(
                        "scrollTo に指定された id が配列にありません: ${command.id}。何もしません",
                    )
                }
                null
            } else {
                val placement = placementOfItem(itemIndex)
                KsScrollTarget(
                    index = placement.lazyIndex,
                    position = command.position,
                    animated = command.animated,
                    contentType = contentTypeAt(placement.lazyIndex),
                    leadingInsetPx = placement.leadingInsetPx,
                    trailingInsetPx = placement.trailingInsetPx,
                    pinnedHeaderKey = placement.pinnedHeaderKey,
                )
            }
        }
    }
}

/**
 * 解決済みの対象までスクロールする。
 *
 * Center / End も 1 回のスクロールで着地させる。要求する配置に必要な「表示範囲の先頭からの
 * ずれ」を、対象の高さの推定値から先に求めて index 指定のスクロールへ渡すため、対象がいったん
 * 表示範囲の先頭まで動いてから戻る動きにはならない。
 *
 * 推定した高さが実測とずれた分は到着後に詰める。アニメーション時は進行方向と同じ向きの残差だけを
 * 詰め、逆向きのわずかなずれや [tolerancePx] 以下のずれは残す。逆向きに詰めると、それが
 * 利用者には「行き過ぎて戻る」動きとして見えるため。
 *
 * 中央・末尾に置けない対象 (先頭・末尾付近の項目、表示範囲より大きい項目) は、スクロール可能
 * 範囲の端で止まるか、対象の先頭が表示範囲の先頭に合う位置で止まる。
 *
 * @param tolerancePx 位置合わせが済んだとみなす残差の大きさ
 * @param safeTopPx 表示範囲の上端から、固定中の見出しを止める安全領域の境目までの長さ
 */
internal suspend fun LazyGridState.performScroll(target: KsScrollTarget, tolerancePx: Int, safeTopPx: () -> Int = { 0 }) {
    val scrollOffset = initialScrollOffset(target, safeTopPx())
    // 進行方向はスクロールを始める前に決める。到着後の補正はこの向きにだけ掛ける。
    val isForward = isForwardScroll(target.index, scrollOffset)

    if (target.animated) {
        animateScrollToItem(target.index, scrollOffset)
    } else {
        scrollToItem(target.index, scrollOffset)
    }
    // 先頭合わせは、固定される見出しの下へ置く場合だけ到着後の位置を確かめる (見出しの高さは
    // 見出しが表示されるまで推定の値のため)。それ以外は index 指定のスクロールで位置が決まる。
    if (target.position == KsScrollPosition.Start && target.pinnedHeaderKey == null) return

    val residual = alignmentDelta(target, safeTopPx()) ?: return
    if (residual == 0) return
    if (!target.animated) {
        // アニメーションしない命令に「戻り」は見えないため、残差はそのまま詰めて位置を合わせる。
        scrollBy(residual.toFloat())
        return
    }
    if (kotlin.math.abs(residual) <= tolerancePx) return
    if (isForward != (residual > 0)) return
    animateScrollBy(residual.toFloat())
}

/**
 * 要求された配置にするために index 指定のスクロールへ渡すオフセットを求める。
 *
 * index 指定のスクロールは、オフセット 0 で対象の lazy 項目の先頭を contentPadding の内側の先頭に
 * 合わせ、正のオフセットほど対象を上へ送る。配置は対象の上下の間隔を除いた content の範囲で合わせる
 * ため、上側の間隔の分だけ上へ送る。対象の content が表示範囲より大きい場合は content の先頭を
 * 表示範囲の先頭に合わせる。先頭合わせで対象のグループの見出しが上端に固定される場合は、content を
 * 見出しの下端に置く (見出しの高さは表示中の見出しから見積もる)。安全領域に重なって置かれたときは、
 * 見出しは安全領域の境目で止まるため、その分だけ下に置く。
 */
private fun LazyGridState.initialScrollOffset(target: KsScrollTarget, safeTopPx: Int): Int {
    val info = layoutInfo
    if (target.position == KsScrollPosition.Start) {
        val covered = target.pinnedHeaderKey?.let { estimateHeaderHeight(it) + safeTopPx } ?: 0
        return target.leadingInsetPx - (covered - info.beforeContentPadding).coerceAtLeast(0)
    }
    val innerSize = (info.viewportEndOffset - info.afterContentPadding) -
        (info.viewportStartOffset + info.beforeContentPadding)
    if (innerSize <= 0) return target.leadingInsetPx
    val itemSize = estimateItemHeight(target) ?: return target.leadingInsetPx
    val contentSize = (itemSize - target.leadingInsetPx - target.trailingInsetPx).coerceAtLeast(0)
    val leading = when (target.position) {
        KsScrollPosition.Start -> 0
        KsScrollPosition.Center -> (innerSize - contentSize) / 2
        KsScrollPosition.End -> innerSize - contentSize
    }
    return target.leadingInsetPx - leading.coerceAtLeast(0)
}

/**
 * 固定される見出しの高さを見積もる。その見出しが表示中なら実測値を、無ければ表示中の別の見出しの
 * 高さを使う。見出しが 1 つも表示されていなければ 0 (到着後に詰める)。
 */
private fun LazyGridState.estimateHeaderHeight(headerKey: Any): Int {
    val visible = layoutInfo.visibleItemsInfo
    visible.firstOrNull { it.key == headerKey }?.let { return it.size.height }
    return visible.firstOrNull { it.contentType == KsGroupHeaderContentType }?.size?.height ?: 0
}

/**
 * 対象の高さを見積もる。可視項目が 1 つも無ければ null。
 *
 * 対象が可視ならその実測値を、そうでなければ同じ再利用種別の可視項目の平均高を使う。
 * 同じ種別が無ければ可視項目全体の平均高で代用する。
 */
private fun LazyGridState.estimateItemHeight(target: KsScrollTarget): Int? {
    val visible = layoutInfo.visibleItemsInfo
    if (visible.isEmpty()) return null
    visible.firstOrNull { it.index == target.index }?.let { return it.size.height }
    val sameType = visible.filter { it.contentType == target.contentType }
    val samples = if (sameType.isEmpty()) visible else sameType
    return samples.sumOf { it.size.height } / samples.size
}

/**
 * これから行うスクロールが前方 (コンテンツの末尾へ向かう向き) かどうか。
 *
 * 対象が今の先頭可視項目と同じときは、対象の上端が今より上へ動くかどうかで決める。上端の位置は
 * どちらも「表示範囲の先頭からどれだけ下か」で表してから比べる。[scrollOffset] は下へ置くほど
 * 小さくなる向き (負が表示範囲の内側)、[LazyGridState.firstVisibleItemScrollOffset] は上へ
 * 隠れた量 (正) で、そのままでは基準が逆向きになるため。
 *
 * @param index スクロール先の lazy 側の index
 * @param scrollOffset その index に対して要求するオフセット
 */
internal fun LazyGridState.isForwardScroll(index: Int, scrollOffset: Int): Boolean {
    if (index != firstVisibleItemIndex) return index > firstVisibleItemIndex
    val currentTop = -firstVisibleItemScrollOffset
    val requestedTop = -scrollOffset
    return requestedTop < currentTop
}

/**
 * 要求された配置にするために必要なスクロール量 (正で前方へ) を求める。
 *
 * 基準にする表示範囲は contentPadding の内側とし、対象は上下の間隔を除いた content の範囲で
 * 合わせる。先頭合わせで対象のグループの見出しが上端を覆っているときは、見出しの下端を基準にする
 * (安全領域に重なって置かれたときは、安全領域の境目で止めた見出しの下端)。
 * 対象が可視でなければ補正しない。
 */
private fun LazyGridState.alignmentDelta(target: KsScrollTarget, safeTopPx: Int): Int? {
    val info = layoutInfo
    val item = info.visibleItemsInfo.firstOrNull { it.index == target.index } ?: return null
    val innerStart = info.viewportStartOffset + info.beforeContentPadding
    val innerEnd = info.viewportEndOffset - info.afterContentPadding
    val innerSize = innerEnd - innerStart
    val contentStart = item.offset.y + target.leadingInsetPx
    val contentSize = (item.size.height - target.leadingInsetPx - target.trailingInsetPx).coerceAtLeast(0)
    return when (target.position) {
        KsScrollPosition.Start -> {
            val header = target.pinnedHeaderKey?.let { key ->
                info.visibleItemsInfo.firstOrNull { it.key == key && it.offset.y < contentStart }
            }
            val coveredEnd = header?.let { info.ksPinnedHeaderOffset(it, safeTopPx) + it.size.height } ?: innerStart
            contentStart - maxOf(innerStart, coveredEnd)
        }

        KsScrollPosition.Center -> (contentStart - innerStart) - (innerSize - contentSize) / 2
        KsScrollPosition.End -> (contentStart + contentSize) - innerEnd
    }
}
