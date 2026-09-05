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
 * 命令の解決結果。lazy 側の index と、その index に対して要求された配置。
 *
 * @param contentType 対象の再利用種別。対象が可視でないときの高さの推定に使う
 */
internal class KsScrollTarget(
    val index: Int,
    val position: KsScrollPosition,
    val animated: Boolean,
    val contentType: Any?,
)

/**
 * 命令を lazy 側の index へ解決する。
 *
 * 対象が見つからない場合 (存在しない ID・実行前に削除された要素・項目もヘッダーも無い) は
 * null を返し、呼び出し元は何もせず次の命令へ進む。
 *
 * @param indexOfId 安定 ID を表示中の配列での位置に変換する。見つからなければ負の値を返す
 * @param leadingItemCount 要素より前に置かれた lazy 項目の数 (ヘッダーがあれば 1)
 * @param totalLazyItemCount ヘッダー・フッターを含む lazy 項目の総数
 */
internal fun resolveScrollTarget(
    command: KsScrollCommand,
    indexOfId: (Any) -> Int,
    leadingItemCount: Int,
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
                val lazyIndex = leadingItemCount + itemIndex
                KsScrollTarget(
                    index = lazyIndex,
                    position = command.position,
                    animated = command.animated,
                    contentType = contentTypeAt(lazyIndex),
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
 */
internal suspend fun LazyGridState.performScroll(target: KsScrollTarget, tolerancePx: Int) {
    val scrollOffset = initialScrollOffset(target)
    // 進行方向はスクロールを始める前に決める。到着後の補正はこの向きにだけ掛ける。
    val isForward = isForwardScroll(target.index, scrollOffset)

    if (target.animated) {
        animateScrollToItem(target.index, scrollOffset)
    } else {
        scrollToItem(target.index, scrollOffset)
    }
    if (target.position == KsScrollPosition.Start) return

    val residual = alignmentDelta(target.index, target.position) ?: return
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
 * 戻り値は負またはゼロで、対象の先頭を表示範囲の先頭からどれだけ内側へ置くかを表す
 * (index 指定のスクロールは、オフセット 0 で対象の先頭を contentPadding の内側の先頭に合わせる)。
 * 対象が表示範囲より大きい場合は 0 とし、対象の先頭を表示範囲の先頭に合わせる。
 */
private fun LazyGridState.initialScrollOffset(target: KsScrollTarget): Int {
    if (target.position == KsScrollPosition.Start) return 0
    val info = layoutInfo
    val innerSize = (info.viewportEndOffset - info.afterContentPadding) -
        (info.viewportStartOffset + info.beforeContentPadding)
    if (innerSize <= 0) return 0
    val itemSize = estimateItemHeight(target) ?: return 0
    val leading = when (target.position) {
        KsScrollPosition.Start -> 0
        KsScrollPosition.Center -> (innerSize - itemSize) / 2
        KsScrollPosition.End -> innerSize - itemSize
    }
    return -leading.coerceAtLeast(0)
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
 * 基準にする表示範囲は contentPadding の内側とする。対象が可視でなければ補正しない。
 */
private fun LazyGridState.alignmentDelta(index: Int, position: KsScrollPosition): Int? {
    val info = layoutInfo
    val item = info.visibleItemsInfo.firstOrNull { it.index == index } ?: return null
    val innerStart = info.viewportStartOffset + info.beforeContentPadding
    val innerEnd = info.viewportEndOffset - info.afterContentPadding
    val innerSize = innerEnd - innerStart
    val itemStart = item.offset.y
    val itemSize = item.size.height
    return when (position) {
        KsScrollPosition.Start -> 0
        KsScrollPosition.Center -> (itemStart - innerStart) - (innerSize - itemSize) / 2
        KsScrollPosition.End -> (itemStart + itemSize) - innerEnd
    }
}
