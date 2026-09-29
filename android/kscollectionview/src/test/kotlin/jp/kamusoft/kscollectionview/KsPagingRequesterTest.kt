package jp.kamusoft.kscollectionview

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 次ページ要求の判定の式と、頼んだ後の待ち方・再試行・取り消しを、画面の部品なしで確かめる。
 *
 * 処理は呼び出しの場で走らせる (Unconfined) ため、門を開けた時点で処理の終わりまで進む。
 */
internal class KsPagingRequesterTest {
    private val scope = CoroutineScope(Job() + Dispatchers.Unconfined)
    private var callCount = 0

    @After
    fun tearDown() {
        scope.cancel()
    }

    // ---- 発火の式 ----

    /** 100 件・画面に 10 件なら、いちばん後ろが 88 番目までは頼まず、89 番目で頼む。 */
    @Test
    fun defaultThresholdRequestsOneScreenBeforeEnd() {
        for (last in 0..88) {
            assertFalse(
                "いちばん後ろが $last 番目で頼んでいる",
                KsPagingRequester.isNearEnd(itemCount = 100, visibleItemCount = 10, lastVisibleIndex = last, threshold = 1f),
            )
        }
        assertTrue(KsPagingRequester.isNearEnd(100, 10, 89, 1f))

        val requester = KsPagingRequester()
        assertFalse(request(requester, lastVisibleIndex = 88))
        assertTrue(request(requester, lastVisibleIndex = 89))
        assertEquals(1, requester.requestCount)
    }

    /** しきい値 2 では 79 番目で頼む。 */
    @Test
    fun thresholdTwoRequestsTwoScreensBeforeEnd() {
        assertFalse(KsPagingRequester.isNearEnd(100, 10, 78, 2f))
        assertTrue(KsPagingRequester.isNearEnd(100, 10, 79, 2f))
    }

    /** しきい値 0 では最後の項目が画面に入ったときだけ頼む。 */
    @Test
    fun thresholdZeroRequestsOnlyWhenLastItemIsVisible() {
        assertFalse(KsPagingRequester.isNearEnd(100, 10, 98, 0f))
        assertTrue(KsPagingRequester.isNearEnd(100, 10, 99, 0f))
    }

    /** しきい値 × 画面に出ている項目の数の端数は切り上げる。 */
    @Test
    fun allowanceIsRoundedUp() {
        // 0.25 × 10 = 2.5 → 3 件まで。
        assertTrue(KsPagingRequester.isNearEnd(100, 10, 96, 0.25f))
        assertFalse(KsPagingRequester.isNearEnd(100, 10, 95, 0.25f))
        // 0.1 × 10 は 1 件 (単精度の誤差で 2 件に切り上げない)。
        assertTrue(KsPagingRequester.isNearEnd(100, 10, 98, 0.1f))
        assertFalse(KsPagingRequester.isNearEnd(100, 10, 97, 0.1f))
    }

    /** 項目が 0 件で待機なら、しきい値によらず頼む。 */
    @Test
    fun emptyIdleRequestsRegardlessOfThreshold() {
        val requester = KsPagingRequester()
        assertTrue(
            requester.requestIfNeeded(
                scope = scope,
                state = KsPagingState.Idle,
                itemsVersion = 0,
                itemCount = 0,
                visibleItemCount = 0,
                lastVisibleIndex = null,
                threshold = 0f,
                action = countingAction(),
            ),
        )
        assertEquals(1, requester.requestCount)
        assertEquals(1, callCount)
    }

    /** 項目があるのに画面に項目が 1 つも出ていなければ頼まない。 */
    @Test
    fun noVisibleItemMeansNoRequest() {
        val requester = KsPagingRequester()
        assertFalse(
            requester.requestIfNeeded(
                scope = scope,
                state = KsPagingState.Idle,
                itemsVersion = 0,
                itemCount = 3,
                visibleItemCount = 0,
                lastVisibleIndex = null,
                threshold = 1f,
                action = countingAction(),
            ),
        )
    }

    // ---- 待機のときだけ自動で頼む ----

    /** 取り直し中・追加読み込み中・失敗・終端では、条件を満たしても (0 件でも) 頼まない。 */
    @Test
    fun nonIdleStatesNeverRequestAutomatically() {
        for (state in listOf(KsPagingState.Refreshing, KsPagingState.Appending, KsPagingState.Failed, KsPagingState.EndReached)) {
            val requester = KsPagingRequester()
            assertFalse("$state で頼んでいる", request(requester, state = state, lastVisibleIndex = 99))
            assertFalse(
                "0 件の $state で頼んでいる",
                requester.requestIfNeeded(scope, state, 0, 0, 0, null, 1f, countingAction()),
            )
        }
        assertEquals(0, callCount)
    }

    // ---- 頼んだ後の待ち方 ----

    /** 処理がすぐ戻り、状態が待機のままの間は、スクロールを続けても 2 回目を頼まない。 */
    @Test
    fun delayedStateChangeDoesNotCauseDoubleRequest() {
        val requester = KsPagingRequester()
        assertTrue(request(requester, lastVisibleIndex = 95))
        assertFalse("処理はすぐ戻っている", requester.isRunning)
        for (last in 95..99) {
            assertFalse(request(requester, lastVisibleIndex = last))
        }
        // 少し後で状態が追加読み込み中になり、待機に戻った (配列は同じ)。状態が変わったので次を頼める。
        requester.observe(KsPagingState.Appending, itemsVersion = 0)
        assertTrue(request(requester, lastVisibleIndex = 99))
        assertEquals(2, requester.requestCount)
    }

    /** 処理の中で待つ VM は、処理が終わるまで (配列が変わっても) 次を頼まない。 */
    @Test
    fun waitingActionBlocksUntilFinished() {
        val requester = KsPagingRequester()
        val gate = CompletableDeferred<Unit>()
        assertTrue(request(requester, lastVisibleIndex = 95, action = { gate.await() }))
        assertTrue(requester.isRunning)
        assertFalse(request(requester, itemsVersion = 1, itemCount = 150, lastVisibleIndex = 149))
        gate.complete(Unit)
        assertFalse(requester.isRunning)
        // 処理が終わり、配列の版が進んでいるので頼める。
        assertTrue(request(requester, itemsVersion = 1, itemCount = 150, lastVisibleIndex = 149))
        assertEquals(2, requester.requestCount)
    }

    /** 判定を挟まずに知らせた状態の往復 (待機 → 追加読み込み中 → 待機) でも控えは捨てられ、次を頼める。 */
    @Test
    fun observedRoundTripWithoutEvaluationReleasesLatch() {
        val requester = KsPagingRequester()
        assertTrue(request(requester, lastVisibleIndex = 99))
        requester.observe(KsPagingState.Appending, itemsVersion = 0)
        requester.observe(KsPagingState.Idle, itemsVersion = 0)
        assertTrue("往復の後に頼めない", request(requester, lastVisibleIndex = 99))
    }

    /** 状態も配列も変えずに戻った頼みは、状態か配列が変わるまで繰り返さない。 */
    @Test
    fun ignoredRequestWaitsForStateOrItemsChange() {
        val requester = KsPagingRequester()
        assertTrue(request(requester, lastVisibleIndex = 95))
        repeat(5) { assertFalse(request(requester, lastVisibleIndex = 99)) }
        assertTrue("配列が変わったのに頼まない", request(requester, itemsVersion = 1, lastVisibleIndex = 99))
    }

    // ---- 再試行 ----

    /** 状態が失敗なら、待ち方の控えによらず再試行で頼め、失敗のまま戻ってもまた頼める。 */
    @Test
    fun retryRequestsWhenFailedRegardlessOfLatch() {
        val requester = KsPagingRequester()
        assertTrue(request(requester, lastVisibleIndex = 99))
        // 状態が失敗になった。自動では頼まない。
        assertFalse(request(requester, state = KsPagingState.Failed, lastVisibleIndex = 99))
        assertTrue(requester.retry(scope, KsPagingState.Failed, 0, countingAction()))
        assertTrue(requester.retry(scope, KsPagingState.Failed, 0, countingAction()))
        assertEquals(3, requester.requestCount)
    }

    /** 失敗以外の状態では、再試行は何もしない。 */
    @Test
    fun retryDoesNothingUnlessFailed() {
        for (state in listOf(KsPagingState.Idle, KsPagingState.Refreshing, KsPagingState.Appending, KsPagingState.EndReached)) {
            val requester = KsPagingRequester()
            assertFalse("$state", requester.retry(scope, state, 0, countingAction()))
        }
        assertEquals(0, callCount)
    }

    /** 処理の実行中は、再試行は何もしない。 */
    @Test
    fun retryDoesNothingWhileRunning() {
        val requester = KsPagingRequester()
        val gate = CompletableDeferred<Unit>()
        assertTrue(requester.retry(scope, KsPagingState.Failed, 0) { gate.await() })
        assertFalse(requester.retry(scope, KsPagingState.Failed, 0, countingAction()))
        assertEquals(1, requester.requestCount)
        gate.complete(Unit)
        assertFalse(requester.isRunning)
    }

    // ---- 取り消し ----

    /** 取り消すと実行中の処理が取り消され、後から戻っても終わりの知らせ (実行中の印の変化) を出さない。 */
    @Test
    fun cancelCancelsRunningActionWithoutReportingFinish() {
        val requester = KsPagingRequester()
        var cancelled = false
        val gate = CompletableDeferred<Unit>()
        assertTrue(
            request(requester, lastVisibleIndex = 99, action = {
                try {
                    gate.await()
                } catch (e: CancellationException) {
                    cancelled = true
                    throw e
                }
            }),
        )
        requester.cancel()
        assertTrue("処理が取り消されていない", cancelled)
        assertFalse(requester.isRunning)

        // 取り消した処理が取り消しを握りつぶして戻っても、後から始めた処理の実行中の印を下ろさない。
        val swallowing = CompletableDeferred<Unit>()
        val next = CompletableDeferred<Unit>()
        val requester2 = KsPagingRequester()
        requester2.retry(scope, KsPagingState.Failed, 0) {
            try {
                swallowing.await()
            } catch (_: CancellationException) {
                // 取り消しを握りつぶして戻る VM
            }
        }
        requester2.cancel()
        assertTrue(requester2.retry(scope, KsPagingState.Failed, 0) { next.await() })
        assertTrue("後の処理が実行中のまま", requester2.isRunning)
        next.complete(Unit)
        assertFalse(requester2.isRunning)
    }

    // ---- 不正なしきい値 ----

    /** 負の数と有限でない数は不正で、0 として判定する (最後の項目が画面に入ったときにだけ頼む)。 */
    @Test
    fun invalidThresholdIsTreatedAsZero() {
        for (value in listOf(-1f, -0.5f, Float.NaN, Float.POSITIVE_INFINITY, Float.NEGATIVE_INFINITY)) {
            assertFalse("$value", KsPagingRequester.isValidThreshold(value))
            assertEquals(0f, KsPagingRequester.effectiveThreshold(value))
        }
        assertTrue(KsPagingRequester.isValidThreshold(0f))
        assertTrue(KsPagingRequester.isValidThreshold(2.5f))
        val requester = KsPagingRequester()
        assertFalse(request(requester, lastVisibleIndex = 98, threshold = -3f))
        assertTrue(request(requester, lastVisibleIndex = 99, threshold = -3f))
    }

    // ---- 配列の版 ----

    /** 配列の版は、中身が変わったときだけ進み、同じ中身の配列を渡し直しても進まない。 */
    @Test
    fun itemsVersionAdvancesOnlyWhenContentsChange() {
        val version = KsPagingItemsVersion()
        val first = listOf(1, 2, 3)
        assertEquals(0, version.versionOf(first))
        assertEquals(0, version.versionOf(first))
        assertEquals("同じ中身の別の配列", 0, version.versionOf(listOf(1, 2, 3)))
        assertEquals(1, version.versionOf(listOf(1, 2, 3, 4)))
        version.reset()
        assertEquals("付け直した直後は進めない", 1, version.versionOf(listOf(9)))
    }

    // ---- 部品 ----

    private fun countingAction(): suspend () -> Unit = { callCount += 1 }

    /** 100 件・画面に 10 件の一覧として判定する。 */
    private fun request(
        requester: KsPagingRequester,
        state: KsPagingState = KsPagingState.Idle,
        itemsVersion: Int = 0,
        itemCount: Int = 100,
        lastVisibleIndex: Int,
        threshold: Float = 1f,
        action: (suspend () -> Unit)? = null,
    ): Boolean = requester.requestIfNeeded(
        scope = scope,
        state = state,
        itemsVersion = itemsVersion,
        itemCount = itemCount,
        visibleItemCount = 10,
        lastVisibleIndex = lastVisibleIndex,
        threshold = threshold,
        action = action ?: countingAction(),
    )
}
