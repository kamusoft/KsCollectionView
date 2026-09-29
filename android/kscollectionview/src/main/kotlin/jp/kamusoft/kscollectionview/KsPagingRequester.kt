package jp.kamusoft.kscollectionview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.ceil

/**
 * 次ページ要求を頼むかどうかの判定と、頼んだ後の待ち方を持つ。画面の部品から切り離し、判定の材料
 * (件数・画面に出ている項目・状態・しきい値) を受け取って決める。材料の取り方は一覧の側が持つ。
 *
 * 判定 (core/ADR-0020):
 * - 項目が 0 件で状態が待機なら頼む (最初の読み込み。しきい値によらない)
 * - 項目が 1 件以上あるのに画面に出ている項目が 1 つも無いなら頼まない
 * - それ以外は、状態が待機で「件数 - 1 - いちばん後ろの位置 <= ceil(しきい値 * 画面に出ている項目の数)」なら頼む
 *
 * 待ち方 (core/ADR-0022): 頼んだら、処理が終わり、かつ頼んだ時点から状態か配列の版が変わるまで次を頼まない。
 * 再試行 (core/ADR-0019): 状態が失敗のとき、処理が実行中でなければ頼む (待ち方の控えによらない)。
 *
 * メインスレッドからだけ使う。
 */
internal class KsPagingRequester {
    /**
     * 次ページ要求の処理を実行中か。snapshot state のため、処理の終わりを観測して判定し直せる。
     */
    var isRunning: Boolean by mutableStateOf(false)
        private set

    /** 頼んだ回数。判定の結果を観測するために読む。 */
    var requestCount: Int = 0
        private set

    /** 最後に頼んだ時点の状態と配列の版。状態か版が変わったのを見たら捨てる。 */
    private var latch: Latch? = null
    private var job: Job? = null

    /** 起動した処理の世代。取り消した処理が後から終わっても、後の処理の実行中の印を下ろさないために使う。 */
    private var generation = 0

    private class Latch(val state: KsPagingState, val itemsVersion: Int)

    /** 状態と配列の版を知らせる。頼んだ時点から変わっていれば、待ち方の控えを捨てる。 */
    fun observe(state: KsPagingState, itemsVersion: Int) {
        val current = latch ?: return
        if (current.state != state || current.itemsVersion != itemsVersion) latch = null
    }

    /**
     * 判定して、条件を満たせば次ページ要求の処理を [scope] で起動する。起動したら true。
     *
     * @param lastVisibleIndex 画面に出ている項目のうち、いちばん後ろの項目の配列上の位置。画面に項目が
     *   出ていないときは null
     */
    fun requestIfNeeded(
        scope: CoroutineScope,
        state: KsPagingState,
        itemsVersion: Int,
        itemCount: Int,
        visibleItemCount: Int,
        lastVisibleIndex: Int?,
        threshold: Float,
        action: suspend () -> Unit,
    ): Boolean {
        observe(state, itemsVersion)
        if (state != KsPagingState.Idle || isRunning || latch != null) return false
        val shouldRequest = when {
            itemCount == 0 -> true
            lastVisibleIndex != null && visibleItemCount > 0 -> isNearEnd(
                itemCount = itemCount,
                visibleItemCount = visibleItemCount,
                lastVisibleIndex = lastVisibleIndex,
                threshold = effectiveThreshold(threshold),
            )
            else -> false
        }
        if (!shouldRequest) return false
        start(scope, state, itemsVersion, action)
        return true
    }

    /** 失敗の表示の再試行。状態が失敗で、処理が実行中でなければ頼む。頼んだら true。 */
    fun retry(
        scope: CoroutineScope,
        state: KsPagingState,
        itemsVersion: Int,
        action: suspend () -> Unit,
    ): Boolean {
        if (state != KsPagingState.Failed || isRunning) return false
        start(scope, state, itemsVersion, action)
        return true
    }

    /** 実行中の処理を取り消す。一覧がコンポジションを離れたときに呼ぶ。 */
    fun cancel() {
        generation += 1
        job?.cancel()
        job = null
        isRunning = false
    }

    private fun start(scope: CoroutineScope, state: KsPagingState, itemsVersion: Int, action: suspend () -> Unit) {
        latch = Latch(state, itemsVersion)
        isRunning = true
        requestCount += 1
        generation += 1
        val startedGeneration = generation
        job = scope.launch {
            action()
            // 取り消した処理が後から終わっても (取り消しを握りつぶして戻った場合を含む)、終わりの知らせは出さない。
            if (!isActive || startedGeneration != generation) return@launch
            job = null
            isRunning = false
        }
    }

    internal companion object {
        /**
         * 残りの項目の数がしきい値以内か (発火の式そのもの)。
         *
         * @param itemCount 配列の件数
         * @param visibleItemCount 画面に出ている項目の数
         * @param lastVisibleIndex 画面に出ている項目のうち、いちばん後ろの項目の配列上の位置 (0 始まり)
         * @param threshold 有効なしきい値 (0 以上の有限の数)
         */
        fun isNearEnd(itemCount: Int, visibleItemCount: Int, lastVisibleIndex: Int, threshold: Float): Boolean {
            val remaining = itemCount - 1 - lastVisibleIndex
            val allowance = ceil(threshold * visibleItemCount.toFloat())
            return remaining.toDouble() <= allowance.toDouble()
        }

        /** しきい値が有効か。負の数と有限でない数は不正入力で、0 として扱う (core/ADR-0011)。 */
        fun isValidThreshold(threshold: Float): Boolean = threshold.isFinite() && threshold >= 0f

        /** 判定に使うしきい値。不正な値は 0 に置き換える。 */
        fun effectiveThreshold(threshold: Float): Float = if (isValidThreshold(threshold)) threshold else 0f
    }
}

/**
 * 配列の版。ページングを付けた一覧で、配列の中身が変わるたびに 1 進む。頼んだ後の待ち方に使う。
 *
 * 配列の参照が変わった回だけ中身を比べ、同じ中身の配列を渡し直しただけでは進めない。
 */
internal class KsPagingItemsVersion {
    private var items: List<*>? = null
    private var version = 0

    /** [items] を受け取ったときの版。コンポジションのたびに呼んでよい。 */
    fun versionOf(items: List<*>): Int {
        val previous = this.items
        if (previous !== items) {
            if (previous != null && previous != items) version += 1
            this.items = items
        }
        return version
    }

    /** 控えを捨てる。ページングが外れたときに呼び、付け直したときに最初から数える。 */
    fun reset() {
        items = null
    }
}
