package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue

/**
 * 配列の差し替えと列数の変化で、`LazyGridState` の既定の位置の保ち方を補う。
 *
 * `LazyGridState` は、表示範囲の先頭の項目のキーでスクロール位置を保つ。これには次の 2 つの
 * 食い違いがあり、ここで補う。
 *
 * - 先頭を表示中に配列の先頭へ項目を挿入すると、元の先頭の項目を表示範囲の先頭に保つため、
 *   挿入した項目が表示範囲の上に外れて見えない。末尾を表示中に配列の末尾へ挿入したときも、
 *   挿入した項目が表示範囲の下に外れる。端を表示中の端への挿入は、表示範囲を端に留める。
 *   先頭では表示範囲を先頭に要求し直す (挿入した項目がフェードで現れ、元の項目は配置の
 *   アニメーションで後ろへずれる)。末尾では、挿入を反映した次のフレームから表示範囲を末尾まで
 *   なめらかに送り ([followEnd])、挿入した項目はフェードで現れる
 * - 見出しを上端に固定しているとき、表示範囲の先頭の項目は固定中の見出しの裏に隠れた項目になる。
 *   列数が変わるとその項目が先頭に保たれ、見出しの下に見えていた項目が動く。列数が変わったときは、
 *   見出しのすぐ下に見えていた項目を見出しのすぐ下に戻す
 *
 * 判定には差し替え・変化の直前の配置 ([LazyGridState.layoutInfo]) を使うため、新しい配置を測る
 * 前 (コンポジションの反映時) に呼ぶ。位置の要求は同じフレームの配置に反映される。
 */
internal class KsPositionKeeper<Item> {
    private var items: List<Item>? = null
    private var columns: Int = 0

    /** 末尾への挿入で、最初に配置されたときにフェードで出す項目・見出しのキー。 */
    val appearing = KsAppearingItems()

    /**
     * 表示範囲を末尾へ送る要求の延べ回数。値が変わったら、挿入を反映した後に [followEnd] を呼ぶ。
     *
     * 残件数ではなく延べ回数にするのは、続けて要求されたときも変化として観測できるようにするため。
     */
    var endFollowRequestCount: Int by mutableIntStateOf(0)
        private set

    /**
     * 配列と列数の変化を受け取り、必要なら位置を要求する。
     *
     * @param placementOf 配列での位置から、新しい配列と列数での lazy 上の置き場所を求める
     * @param safeTopPx 表示範囲の上端から、固定中の見出しを止める安全領域の境目までの長さ
     */
    fun onUpdate(
        state: LazyGridState,
        items: List<Item>,
        key: (Item) -> Any,
        plan: KsGroupPlan,
        columns: Int,
        placementOf: (Int) -> KsItemPlacement,
        safeTopPx: Int = 0,
    ) {
        val previousItems = this.items
        val previousColumns = this.columns
        this.items = items
        this.columns = columns
        if (previousItems == null) return
        if (previousItems !== items && keepEdge(state, previousItems, items, key, plan)) return
        if (previousColumns != columns && plan.pinsHeaders) {
            keepBelowPinnedHeader(state, items, key, placementOf, safeTopPx)
        }
    }

    /**
     * 端を表示中の端への挿入なら、表示範囲をその端に留める。留めたら true。
     *
     * 挿入は「新しい端の項目の ID が差し替え前の配列に無い」ことで判定する。端の項目の入れ替え
     * (移動・削除) は挿入ではないため、既定の位置の保ち方のままにする。
     */
    private fun keepEdge(
        state: LazyGridState,
        previousItems: List<Item>,
        items: List<Item>,
        key: (Item) -> Any,
        plan: KsGroupPlan,
    ): Boolean {
        if (previousItems.isEmpty() || items.isEmpty()) return false
        val atStart = !state.canScrollBackward
        val atEnd = !state.canScrollForward
        if (atStart && isInsertion(key(items.first()), key(previousItems.first()), previousItems, key)) {
            state.requestScrollToItem(0)
            return true
        }
        if (atEnd && isInsertion(key(items.last()), key(previousItems.last()), previousItems, key)) {
            // ここでは位置を要求しない。index を変える位置の要求は配置のアニメーションを打ち切り、
            // 表示範囲が一瞬で末尾へ飛ぶため。既定の位置の保ち方 (見えている先頭の項目を保つ) のまま
            // 挿入を反映させ、次のフレームから末尾までなめらかに送る。
            appearing.replace(appendedKeys(previousItems, items, key, plan))
            endFollowRequestCount += 1
            return true
        }
        return false
    }

    /**
     * 末尾に足された項目と、それらと一緒に現れたグループの見出しのキーを返す。
     *
     * 足された範囲は、末尾から数えて差し替え前の配列に無い項目が続く範囲とする。
     */
    private fun appendedKeys(
        previousItems: List<Item>,
        items: List<Item>,
        key: (Item) -> Any,
        plan: KsGroupPlan,
    ): List<Any> {
        val previousKeys = previousItems.mapTo(HashSet(previousItems.size)) { key(it) }
        var firstAppended = items.size
        while (firstAppended > 0 && key(items[firstAppended - 1]) !in previousKeys) {
            firstAppended -= 1
        }
        if (firstAppended == items.size) return emptyList()
        val keys = ArrayList<Any>(items.size - firstAppended)
        if (plan.hasHeaders) {
            for (group in plan.groupOfItem(firstAppended) until plan.groupCount) {
                if (plan.groupStart(group) >= firstAppended) keys += plan.headerKey(group)
            }
        }
        for (index in firstAppended until items.size) keys += key(items[index])
        return keys
    }

    /**
     * 末尾への挿入を反映した後に、表示範囲を末尾までなめらかに送る。
     *
     * 挿入を反映した測定ですでに表示範囲に配置された項目は、配置のアニメーションがフェードで出して
     * いるため、[appearing] の登録から外す。残りの項目は、送る途中で最初に配置されたときにフェードする。
     * 送る距離は、足された項目を表示範囲の端に配置させてから実測する。
     */
    suspend fun followEnd(state: LazyGridState) {
        appearing.removeAll(state.layoutInfo.visibleItemsInfo.map { it.key })
        try {
            if (!state.canScrollForward) return
            // 1 px 送って、表示範囲のすぐ外に足された項目を配置させる (距離を実測するため)。
            state.scrollBy(1f)
            val remaining = state.distanceToEnd()
            if (remaining == null) {
                // 足された項目が多く、最後の項目がまだ配置されていない。
                state.animateScrollToItem(state.layoutInfo.totalItemsCount - 1)
            } else if (remaining > 0) {
                state.animateScrollBy(remaining.toFloat(), KsEndFollowSpec)
            }
        } finally {
            appearing.clear()
        }
    }

    private fun isInsertion(newId: Any, previousId: Any, previousItems: List<Item>, key: (Item) -> Any): Boolean =
        newId != previousId && previousItems.none { key(it) == newId }

    /**
     * 固定中の見出しが上端を覆っていたなら、見出しの下に見えていた先頭の項目を、新しい列数でも
     * 見出しのすぐ下に置く。
     */
    private fun keepBelowPinnedHeader(
        state: LazyGridState,
        items: List<Item>,
        key: (Item) -> Any,
        placementOf: (Int) -> KsItemPlacement,
        safeTopPx: Int,
    ) {
        val info = state.layoutInfo
        val visible = info.visibleItemsInfo
        // 安全領域に重なって置かれたときは、見出しは安全領域の境目で止まり、覆う範囲もその分だけ下へ延びる。
        val coveredEnd = info.ksPinnedHeaderCoverageEnd(safeTopPx) ?: return
        val leading = visible
            .filter { it.contentType != KsGroupHeaderContentType }
            .sortedBy { it.index }
            .firstOrNull { it.offset.y + it.size.height > coveredEnd }
            ?: return
        val leadingKey = leading.key
        val itemIndex = items.indexOfFirst { key(it) == leadingKey }
        if (itemIndex < 0) return
        val placement = placementOf(itemIndex)
        // content の上端を見出しの下端 (上側の余白の内側より上なら余白の内側) に置く。
        val headerHeight = coveredEnd - info.viewportStartOffset
        val offset = placement.leadingInsetPx - (headerHeight - info.beforeContentPadding).coerceAtLeast(0)
        state.requestScrollToItem(placement.lazyIndex, offset)
    }
}

/** 末尾への挿入で表示範囲を末尾へ送る動きの速さ。配置のアニメーションの既定と同じばね。 */
private val KsEndFollowSpec = spring<Float>(stiffness = Spring.StiffnessMediumLow)

/**
 * コンテンツの末尾 (下側の余白を含む) を表示範囲の下端に合わせるのに必要な前方へのスクロール量。
 * 最後の lazy 項目が配置されていなければ null。
 */
private fun LazyGridState.distanceToEnd(): Int? {
    val info = layoutInfo
    val last = info.visibleItemsInfo.lastOrNull { it.index == info.totalItemsCount - 1 } ?: return null
    return last.offset.y + last.size.height + info.afterContentPadding - info.viewportEndOffset
}
