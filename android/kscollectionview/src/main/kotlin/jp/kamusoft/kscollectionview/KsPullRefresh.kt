package jp.kamusoft.kscollectionview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * 引っ張って始めた取り直しの進み具合と、インジケータを出すかどうか (core/ADR-0023)。
 *
 * インジケータは、引っ張ってから取り直しの処理が終わるまで出し、処理が終わった後はページングの状態が
 * 取り直し中の間だけ出し続ける。処理が終わった時点で取り直し中でなければ消す。引っ張っていないのに
 * 状態が取り直し中になっても出さない。
 *
 * メインスレッドからだけ使う。
 */
internal class KsPullRefresh {
    /** 引っ張って始めた取り直しのインジケータを出しているか。 */
    var isPullRefreshing: Boolean by mutableStateOf(false)
        private set

    /** 引っ張って取り直しの処理を呼んだ回数。 */
    var pullCount: Int = 0
        private set

    /**
     * 引っ張って始めた取り直しの処理を実行中か。コンポジションで読み、処理の終わりに判定し直させる。
     */
    private var isActionRunning: Boolean by mutableStateOf(false)

    /** 起動した取り直しの世代。外した後に前の処理が終わっても、後の取り直しの印を下ろさないために使う。 */
    private var generation = 0

    /**
     * 引っ張られた。取り直しの処理 [action] を [scope] で実行する。取り直しのインジケータを出している間は
     * 何もしない。
     *
     * 処理の終わりの時点ではまだ、処理の中で書き換えられた状態がコンポジションへ届いていない。インジケータを
     * 消すかどうかは、処理の終わりを反映したコンポジションで [finishIfDone] が決める。
     */
    fun start(scope: CoroutineScope, action: suspend () -> Unit) {
        if (isPullRefreshing) return
        isPullRefreshing = true
        isActionRunning = true
        pullCount += 1
        generation += 1
        val startedGeneration = generation
        scope.launch {
            action()
            if (!isActive || startedGeneration != generation) return@launch
            isActionRunning = false
        }
    }

    /**
     * インジケータを出すか。引っ張って始めた取り直しの処理の実行中か、処理が終わった後で状態が
     * 取り直し中のとき。
     *
     * @param pagingState ページングの状態 (ページングを付けていなければ null)
     */
    fun isIndicatorShown(pagingState: KsPagingState?): Boolean =
        isPullRefreshing && (isActionRunning || pagingState == KsPagingState.Refreshing)

    /** 処理が終わり、状態が取り直し中でなければインジケータを消す。コンポジションの反映のたびに呼ぶ。 */
    fun finishIfDone(pagingState: KsPagingState?) {
        if (isPullRefreshing && !isActionRunning && pagingState != KsPagingState.Refreshing) {
            isPullRefreshing = false
        }
    }

    /** 取り直しの処理が渡されなくなった。インジケータを消す (実行中の処理は取り消さない)。 */
    fun detach() {
        generation += 1
        isPullRefreshing = false
        isActionRunning = false
    }
}
