package jp.kamusoft.kscollectionview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.unit.Dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.fail

/**
 * ページングの試験で、利用者の VM の代わりに状態と配列を持ち、一覧から呼ばれた処理を数える。
 *
 * 状態と配列は Compose の状態で持ち、試験の側から書き換える。次ページ要求の処理と取り直しの処理は、
 * 門 ([loadMoreGate] / [refreshGate]) を置くとそれが開くまで戻らない。
 */
internal class KsPagingProbeVm(items: List<TestItem>, state: KsPagingState = KsPagingState.Idle) {
    var items: List<TestItem> by mutableStateOf(items)
    var state: KsPagingState by mutableStateOf(state)

    var loadMoreCount = 0
        private set
    var refreshCount = 0
        private set
    var loadMoreCancelled = false
        private set

    /** 次ページ要求の処理で待つ門。null ならすぐ戻る。 */
    var loadMoreGate: CompletableDeferred<Unit>? = null

    /** 取り直しの処理で待つ門。null ならすぐ戻る。 */
    var refreshGate: CompletableDeferred<Unit>? = null

    /** 次ページ要求の処理の中で行う書き換え (門を待つ前)。 */
    var onLoadMore: (KsPagingProbeVm.() -> Unit)? = null

    /** 取り直しの処理の中で行う書き換え (門を待つ前)。 */
    var onRefresh: (KsPagingProbeVm.() -> Unit)? = null

    val loadMore: suspend () -> Unit = {
        loadMoreCount += 1
        onLoadMore?.invoke(this)
        try {
            loadMoreGate?.await()
        } catch (e: CancellationException) {
            loadMoreCancelled = true
            throw e
        }
    }

    val refresh: suspend () -> Unit = {
        refreshCount += 1
        onRefresh?.invoke(this)
        refreshGate?.await()
    }
}

/** 標準の不定の読み込み中の表示 (読み上げでは読み込み中の要素になる)。 */
internal val isIndeterminateProgress: SemanticsMatcher =
    SemanticsMatcher.expectValue(SemanticsProperties.ProgressBarRangeInfo, ProgressBarRangeInfo.Indeterminate)

/** 不定の読み込み中の表示の数。 */
internal fun ComposeContentTestRule.countIndeterminateProgress(): Int =
    onAllNodes(isIndeterminateProgress).fetchSemanticsNodes().size

/**
 * [condition] が真になるまで、実時間の期限つきでコンポジションとフレームを進めて待つ。期限を過ぎたら
 * そのときの実測を載せて失敗させる。
 */
internal fun ComposeContentTestRule.awaitCondition(
    label: String,
    timeoutMillis: Long = 5_000,
    observed: () -> Any? = { null },
    condition: () -> Boolean,
) {
    val deadline = System.nanoTime() + timeoutMillis * 1_000_000
    while (true) {
        waitForIdle()
        if (runOnIdle { condition() }) return
        if (System.nanoTime() > deadline) {
            fail("$label が期限内に起きない (実測 ${runOnIdle { observed() }})")
        }
        mainClock.advanceTimeByFrame()
        Thread.sleep(1)
    }
}

/** 数フレーム進めても [value] が変わらないことを確かめる。 */
internal fun ComposeContentTestRule.assertStaysFor(label: String, frames: Int = 20, value: () -> Any?) {
    waitForIdle()
    val initial = runOnIdle { value() }
    repeat(frames) {
        mainClock.advanceTimeByFrame()
        waitForIdle()
        val current = runOnIdle { value() }
        if (current != initial) fail("$label (はじめ $initial / 変化後 $current)")
    }
}

/** 一覧を lazy の index [index] が先頭に来るまで送る。 */
internal fun ComposeContentTestRule.scrollListToIndex(index: Int) {
    onNode(hasScrollAction()).performScrollToIndex(index)
    waitForIdle()
}

/** タグの節点の上端。 */
internal fun ComposeContentTestRule.topOfTag(tag: String): Dp = onNodeWithTag(tag).getUnclippedBoundsInRoot().top

/** タグの節点の下端。 */
internal fun ComposeContentTestRule.bottomOfTag(tag: String): Dp = onNodeWithTag(tag).getUnclippedBoundsInRoot().bottom
