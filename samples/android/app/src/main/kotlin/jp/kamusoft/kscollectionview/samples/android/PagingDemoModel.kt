package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import jp.kamusoft.kscollectionview.KsPagingState
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** 「ページング」画面が項目を取得する処理 (ページの番号・失敗させるか・0 件にするか)。 */
typealias PagingDemoFetch = suspend (page: Int, fails: Boolean, isEmpty: Boolean) -> PagingDemoPage

/**
 * 「ページング」画面の項目・ページングの状態と、読み込み・取り直しの規則。
 *
 * iOS Sample の同名の定義と同じ規則にし、同じ操作の順で同じ状態と並びになる。状態は Compose の
 * 状態で持ち、メインスレッドからだけ操作する。
 *
 * - 次のページの読み込み ([loadNextPage]): 状態が待機か失敗のときだけ受け付ける (失敗からの
 *   再試行を含む)。受け付けたら同じ回に状態を追加読み込み中にし、取得できたら項目を末尾に足すのと
 *   同じ回に、最後のページなら終端・そうでなければ待機にする。失敗したら失敗にする
 * - 取り直し ([refresh]。Pull to Refresh と「再読み込み」): いつでも受け付け、世代を 1 つ進めて
 *   状態を取り直し中にし、「更新できませんでした」を消す。1 ページ目を取得できたら項目を置き換えるのと
 *   同じ回に、終端か待機にする。失敗したとき、項目があれば状態を取り直しの前に戻して
 *   「更新できませんでした」を出し、項目が 0 件なら失敗にする。取り直しの前が追加読み込み中か
 *   取り直し中なら、その読み込みの結果は捨てられて戻る先が無いため待機に戻す
 * - 世代: 読み込みと取り直しは始めたときの世代を控え、取得から戻ったときに世代が進んでいたら
 *   結果を捨てて何も書き換えない (取り直しより前に始めた読み込みのページが後から混ざらないようにする)
 * - 「更新できませんでした」の知らせ ([refreshFailed]): 出してから [SamplePanelMetrics.BannerDurationMillis]
 *   (3 秒) たったら消す。その間に次の取り直しを始めたら、その時点で消す。もう一度失敗したら、また 3 秒出す
 * - 「次の読み込みを失敗させる」: 次の取得から効き、切り替えただけでは読み込み直さない
 * - 「中身を 0 件にする」: 切り替えたら、その場で取り直す
 * - 取り直し中の届け方: 取り直しは、状態を取り直し中にしたら、その状態が一覧に届いてから取得する。
 *   取得がすぐ返る (遅延 0) と、取り直し中への書き換えと結果の差し替えが同じ描画の回にまとまり、一覧が
 *   取り直し中を一度も見ないまま差し替えを受け取って、先頭から表示し直さない (一覧は差し替えの直前に
 *   受け取った状態で置き方を決めるため)。一覧に届いたことは、画面が一覧を描いた回に
 *   [onDisplayed] で知らせる。画面が一度も知らせていないモデル (画面につないでいない単体の検証) は待たない
 *
 * @param fetch 項目を取得する処理
 * @param noticeScope 「更新できませんでした」を決まった時間の後に消す処理を実行するスコープ。画面を
 *   離れたら取り消される
 * @param initialItemCount 最初に並べておく項目の数 (構成変更をまたいで戻すとき。ID 1 から順に並べる)
 * @param initialState 最初の状態
 * @param awaitFrame 次の描画の回まで待つ処理。一覧が状態を受け取る処理は、画面が [onDisplayed] で
 *   知らせた回の配置の中で行われるため、知らせを受けた後にもう 1 回待ってから取得する
 * @param awaitNoticeTimeout 「更新できませんでした」を出してから消すまで待つ処理
 */
class PagingDemoModel(
    private val fetch: PagingDemoFetch,
    private val noticeScope: CoroutineScope,
    initialItemCount: Int = 0,
    initialState: KsPagingState = KsPagingState.Idle,
    private val awaitFrame: suspend () -> Unit = { withFrameNanos { } },
    private val awaitNoticeTimeout: suspend () -> Unit = { delay(SamplePanelMetrics.BannerDurationMillis) },
) {
    /** 表示している項目。 */
    var items: List<DemoItem> by mutableStateOf((1..initialItemCount).map(PagingDemoSource::item))
        private set

    /** ページングの状態。一覧はこれを読むだけで、書き換えるのはこのモデルだけ。 */
    var state: KsPagingState by mutableStateOf(initialState)
        private set

    /** 項目があるときの取り直しの失敗を知らせているか。画面の上に「更新できませんでした」の帯を出す。 */
    var refreshFailed: Boolean by mutableStateOf(false)
        private set

    /** 「次の読み込みを失敗させる」。 */
    var failsNextLoad: Boolean by mutableStateOf(false)

    /** 「中身を 0 件にする」。 */
    var isEmpty: Boolean by mutableStateOf(false)
        private set

    private var generation = 0

    /** 「更新できませんでした」を消すまで待っている処理。 */
    private var noticeJob: Job? = null

    /** 画面が最後に一覧へ渡したと知らせた状態。一度も知らせていなければ null で、状態が届くのを待たない。 */
    private var lastDisplayed: KsPagingState? = null

    /** 一覧に届くのを待っている状態と、届いたら完了させる印。 */
    private val displayWaiters = mutableListOf<Pair<KsPagingState, CompletableDeferred<Unit>>>()

    /**
     * 画面が、状態 [displayed] を渡した一覧を描いた。その状態が届くのを待っている取り直しを進める。
     * 画面の `SideEffect` から、描くたびに呼ぶ。
     */
    fun onDisplayed(displayed: KsPagingState) {
        lastDisplayed = displayed
        val reached = displayWaiters.filter { it.first == displayed }
        displayWaiters.removeAll(reached)
        reached.forEach { it.second.complete(Unit) }
    }

    /**
     * 状態 [target] が一覧に届くまで待つ。画面につないでいなければ待たない。すでに届いている (取り直し中の
     * 取り直しのように、書き換えても値が変わらない) なら、描き直しが起きないため待たない。
     */
    private suspend fun awaitDisplayed(target: KsPagingState) {
        val displayed = lastDisplayed ?: return
        if (displayed == target) return
        val waiter = CompletableDeferred<Unit>()
        val entry = target to waiter
        displayWaiters += entry
        try {
            waiter.await()
        } finally {
            displayWaiters.remove(entry)
        }
        awaitFrame()
    }

    /** 次のページを読み込む。一覧の次ページ要求と、失敗の表示の「再試行」から呼ばれる。 */
    suspend fun loadNextPage() {
        if (state != KsPagingState.Idle && state != KsPagingState.Failed) return
        val started = generation
        state = KsPagingState.Appending
        val page = items.size / PagingDemoSource.PageSize
        try {
            val result = fetch(page, failsNextLoad, isEmpty)
            if (started != generation) return
            items = items + result.items
            state = if (result.isLast) KsPagingState.EndReached else KsPagingState.Idle
        } catch (cancellation: CancellationException) {
            // 一覧が取り除かれて処理が取り消された。次に頼まれたら読み込めるよう待機に戻す。
            if (started == generation) state = KsPagingState.Idle
            throw cancellation
        } catch (_: PagingDemoFailure) {
            if (started != generation) return
            state = KsPagingState.Failed
        }
    }

    /** 1 ページ目から取り直す。Pull to Refresh の処理と、[reload] から呼ばれる。 */
    suspend fun refresh() {
        generation += 1
        val started = generation
        val previous = state
        state = KsPagingState.Refreshing
        hideRefreshFailedNotice()
        try {
            awaitDisplayed(KsPagingState.Refreshing)
            if (started != generation) return
            val result = fetch(0, failsNextLoad, isEmpty)
            if (started != generation) return
            items = result.items
            state = if (result.isLast) KsPagingState.EndReached else KsPagingState.Idle
        } catch (cancellation: CancellationException) {
            // 取り直しの処理が取り消された。失敗ではないため、知らせを出さずに前の状態へ戻す。
            if (started == generation) state = restoredState(previous)
            throw cancellation
        } catch (_: PagingDemoFailure) {
            if (started != generation) return
            if (items.isEmpty()) {
                state = KsPagingState.Failed
            } else {
                state = restoredState(previous)
                showRefreshFailedNotice()
            }
        }
    }

    /**
     * 引っ張らずに取り直す (「再読み込み」)。取り直しは一覧の外 (このモデル) で始める。
     *
     * @param scope 取り直しを実行するスコープ。画面を離れたら取り消される
     */
    fun reload(scope: CoroutineScope) {
        scope.launch { refresh() }
    }

    /**
     * 「中身を 0 件にする」を切り替え、その場で取り直す。
     *
     * @param value 新しい値
     * @param scope 取り直しを実行するスコープ
     */
    fun setEmpty(value: Boolean, scope: CoroutineScope) {
        if (value == isEmpty) return
        isEmpty = value
        reload(scope)
    }

    /** 「更新できませんでした」を出し、決まった時間の後に消す。出している間にもう一度呼ばれたら時間を数え直す。 */
    private fun showRefreshFailedNotice() {
        noticeJob?.cancel()
        refreshFailed = true
        noticeJob = noticeScope.launch {
            awaitNoticeTimeout()
            refreshFailed = false
        }
    }

    /** 「更新できませんでした」をすぐに消す。 */
    private fun hideRefreshFailedNotice() {
        noticeJob?.cancel()
        noticeJob = null
        refreshFailed = false
    }

    /** 項目があるときの取り直しに失敗したときに戻す状態。 */
    private fun restoredState(previous: KsPagingState): KsPagingState = when (previous) {
        KsPagingState.Appending, KsPagingState.Refreshing -> KsPagingState.Idle
        KsPagingState.Idle, KsPagingState.Failed, KsPagingState.EndReached -> previous
    }

    companion object {
        /**
         * 構成変更 (回転・外観の切り替え) をまたいで保つための保存の形。
         *
         * 項目はいつも ID 1 から続いて並ぶため、件数だけを保存する。実行中の読み込み・取り直しは
         * 構成変更で取り消されるため、追加読み込み中・取り直し中は待機として戻す (戻した後の次ページ要求で
         * 読み込み直す)。「更新できませんでした」の知らせは一時的なもののため保存せず、消えた状態で戻す。
         *
         * @param fetch 戻したモデルが項目を取得する処理
         * @param noticeScope 戻したモデルが知らせを消す処理を実行するスコープ
         */
        fun saver(fetch: PagingDemoFetch, noticeScope: CoroutineScope): Saver<PagingDemoModel, IntArray> = Saver(
            save = { model ->
                intArrayOf(
                    model.items.size,
                    model.state.ordinal,
                    if (model.failsNextLoad) 1 else 0,
                    if (model.isEmpty) 1 else 0,
                )
            },
            restore = { saved ->
                val state = KsPagingState.entries[saved[1]].let {
                    if (it == KsPagingState.Appending || it == KsPagingState.Refreshing) KsPagingState.Idle else it
                }
                PagingDemoModel(
                    fetch = fetch,
                    noticeScope = noticeScope,
                    initialItemCount = saved[0],
                    initialState = state,
                ).apply {
                    failsNextLoad = saved[2] == 1
                    isEmpty = saved[3] == 1
                }
            },
        )
    }
}
