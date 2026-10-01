package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.saveable.SaverScope
import jp.kamusoft.kscollectionview.KsPagingState
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「ページング」画面のモデルの状態の遷移を確かめる。
 *
 * 期待値は iOS Sample の `PagingDemoModel` と同じ規則から求めた値。取得は手で返す偽物に差し替え、
 * 取得の途中 (追加読み込み中・取り直し中) の状態と、取得を返す順を決めて確かめる。
 */
class PagingDemoModelTest {

    /** 呼ばれた取得を控え、テストが結果を返すまで待たせる取得。 */
    private class ControlledFetch {
        /** 呼ばれた取得 1 回分。 */
        class Call(val page: Int, val fails: Boolean, val isEmpty: Boolean) {
            val result = CompletableDeferred<PagingDemoPage>()

            /** 偽の取得元と同じ規則で結果を返す (失敗させる設定なら失敗)。 */
            fun respond() {
                if (fails) result.completeExceptionally(PagingDemoFailure()) else result.complete(PagingDemoSource.page(page, isEmpty))
            }
        }

        val calls = mutableListOf<Call>()

        val fetch: PagingDemoFetch = { page, fails, isEmpty ->
            val call = Call(page, fails, isEmpty)
            calls += call
            call.result.await()
        }
    }

    /**
     * テストの本体を実行し、最後にまだ結果を待っている取得を取り消す。取り消さないと、返さずに残した取得を
     * 待つ処理のせいでテストが終わらない。
     */
    private fun runModelTest(body: suspend CoroutineScope.() -> Unit) = runBlocking {
        body()
        coroutineContext.cancelChildren()
    }

    /** 起動した処理が次の待ち (取得の結果) まで進むのを待つ。 */
    private suspend fun settle() = repeat(10) { yield() }

    private fun PagingDemoModel.ids(): List<Int> = items.map { it.id }

    /**
     * 項目があるときの取り直しを 1 回失敗させ、「更新できませんでした」を出した状態にする (消えるのは待たない)。
     * モデルの取得は、失敗させる設定ならすぐ失敗を返すものであること。
     */
    private fun PagingDemoModel.refreshFailedForTest() = runBlocking {
        val previous = failsNextLoad
        failsNextLoad = true
        refresh()
        failsNextLoad = previous
    }

    /** 失敗させる設定ならすぐ失敗し、そうでなければすぐ 1 ページを返す取得。 */
    private val immediateFetch: PagingDemoFetch = { page, fails, isEmpty ->
        if (fails) throw PagingDemoFailure()
        PagingDemoSource.page(page, isEmpty)
    }

    /** 取得を 1 回返して、モデルに反映させる。 */
    private suspend fun ControlledFetch.respondLast() {
        calls.last().respond()
        settle()
    }

    private fun CoroutineScope.startLoad(model: PagingDemoModel) = launch { model.loadNextPage() }

    private fun CoroutineScope.startRefresh(model: PagingDemoModel) = launch { model.refresh() }

    @Test
    fun `最初の読み込みで Item 1 から 50 が並び 待機に戻る`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this)
        assertEquals(KsPagingState.Idle, model.state)

        startLoad(model)
        settle()
        assertEquals(KsPagingState.Appending, model.state)
        assertEquals(0, fetch.calls.single().page)

        fetch.respondLast()
        assertEquals((1..50).toList(), model.ids())
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `次のページは今の件数から数えたページを読み 末尾に足す`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 100)

        startLoad(model)
        settle()
        assertEquals(2, fetch.calls.single().page)
        fetch.respondLast()
        assertEquals((1..150).toList(), model.ids())
    }

    @Test
    fun `次ページ要求は待機か失敗のときだけ受け付ける`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this)

        // 追加読み込み中はもう 1 度頼まれても取得しない。
        startLoad(model)
        settle()
        startLoad(model)
        settle()
        assertEquals(1, fetch.calls.size)
        fetch.respondLast()

        // 取り直し中も受け付けない。
        startRefresh(model)
        settle()
        startLoad(model)
        settle()
        assertEquals(2, fetch.calls.size)
        fetch.respondLast()

        // 終端も受け付けない。
        val ended = PagingDemoModel(fetch.fetch, this, initialItemCount = 10_000, initialState = KsPagingState.EndReached)
        startLoad(ended)
        settle()
        assertEquals(2, fetch.calls.size)
        assertEquals(KsPagingState.EndReached, ended.state)
    }

    @Test
    fun `最後のページを読むと終端になる`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 9_950)

        startLoad(model)
        settle()
        fetch.respondLast()
        assertEquals(10_000, model.items.size)
        assertEquals("Item 10000", model.items.last().title)
        assertEquals(KsPagingState.EndReached, model.state)
    }

    @Test
    fun `次のページの失敗は失敗になり 再試行で同じページを読み直す`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50)
        model.failsNextLoad = true

        startLoad(model)
        settle()
        fetch.respondLast()
        assertEquals(KsPagingState.Failed, model.state)
        assertEquals(50, model.items.size)

        // 切り替えをオフにして再試行 (失敗の状態からの次ページ要求) すると、次のページが読まれる。
        model.failsNextLoad = false
        startLoad(model)
        settle()
        assertEquals(KsPagingState.Appending, model.state)
        assertEquals(1, fetch.calls.last().page)
        fetch.respondLast()
        assertEquals((1..100).toList(), model.ids())
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `失敗させる切り替えは次の取得から効き 切り替えただけでは読み込み直さない`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50)

        model.failsNextLoad = true
        settle()
        assertTrue("切り替えだけで取得が ${fetch.calls.size} 回呼ばれた", fetch.calls.isEmpty())
        assertEquals(KsPagingState.Idle, model.state)

        startLoad(model)
        settle()
        assertTrue(fetch.calls.single().fails)
    }

    @Test
    fun `取り直しは状態を取り直し中にし 項目を 1 ページ目に置き換える`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 200)

        startRefresh(model)
        settle()
        assertEquals(KsPagingState.Refreshing, model.state)
        // 取り直しの間は項目が並んだまま。
        assertEquals(200, model.items.size)
        assertEquals(0, fetch.calls.single().page)

        fetch.respondLast()
        assertEquals((1..50).toList(), model.ids())
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `項目があるときの取り直しの失敗は 前の状態に戻して更新できませんでしたを出す`() = runModelTest {
        listOf(KsPagingState.Idle, KsPagingState.Failed, KsPagingState.EndReached).forEach { previous ->
            val fetch = ControlledFetch()
            val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 100, initialState = previous)
            model.failsNextLoad = true

            startRefresh(model)
            settle()
            fetch.respondLast()
            assertEquals("前が $previous", previous, model.state)
            assertEquals(100, model.items.size)
            assertTrue(model.refreshFailed)
        }
    }

    @Test
    fun `次の取り直しを始めると更新できませんでしたは消える`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50)
        model.failsNextLoad = true
        startRefresh(model)
        settle()
        fetch.respondLast()
        assertTrue(model.refreshFailed)

        model.failsNextLoad = false
        startRefresh(model)
        settle()
        assertFalse(model.refreshFailed)
        fetch.respondLast()
        assertFalse(model.refreshFailed)
    }

    /** 知らせを消すまでの待ちを、テストが開くまで待たせる門にしたモデル。 */
    private fun CoroutineScope.modelWithNoticeGates(fetch: ControlledFetch, gates: MutableList<CompletableDeferred<Unit>>) =
        PagingDemoModel(
            fetch.fetch,
            this,
            initialItemCount = 50,
            awaitNoticeTimeout = { CompletableDeferred<Unit>().also { gates += it }.await() },
        )

    @Test
    fun `更新できませんでしたは決まった時間がたつと消える`() = runModelTest {
        val fetch = ControlledFetch()
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        val model = modelWithNoticeGates(fetch, gates)
        model.failsNextLoad = true
        startRefresh(model)
        settle()
        fetch.respondLast()
        assertTrue(model.refreshFailed)
        assertEquals(1, gates.size)

        gates.single().complete(Unit)
        settle()
        assertFalse(model.refreshFailed)
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `更新できませんでしたの間に取り直しを始めると その時点で消える`() = runModelTest {
        val fetch = ControlledFetch()
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        val model = modelWithNoticeGates(fetch, gates)
        model.failsNextLoad = true
        startRefresh(model)
        settle()
        fetch.respondLast()
        assertTrue(model.refreshFailed)

        startRefresh(model)
        settle()
        assertFalse(model.refreshFailed)
        // 先の時間切れが後から来ても、何も起きない (次の知らせを消さない)。
        fetch.respondLast()
        assertTrue("もう一度失敗して出し直す", model.refreshFailed)
        gates.first().complete(Unit)
        settle()
        assertTrue("先の時間切れで消えた", model.refreshFailed)
    }

    @Test
    fun `もう一度失敗したら 時間を数え直してまた出す`() = runModelTest {
        val fetch = ControlledFetch()
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        val model = modelWithNoticeGates(fetch, gates)
        model.failsNextLoad = true
        repeat(2) {
            startRefresh(model)
            settle()
            fetch.respondLast()
        }
        assertTrue(model.refreshFailed)
        assertEquals(2, gates.size)

        // 1 回目の時間は取り消されていて、2 回目の時間がたって初めて消える。
        gates[0].complete(Unit)
        settle()
        assertTrue(model.refreshFailed)
        gates[1].complete(Unit)
        settle()
        assertFalse(model.refreshFailed)
    }

    @Test
    fun `知らせを消すまでの既定の時間は 3 秒`() {
        assertEquals(3_000L, SamplePanelMetrics.BannerDurationMillis)
        assertEquals(200, SamplePanelMetrics.BannerFadeMillis)
    }

    @Test
    fun `項目が 0 件のときの取り直しの失敗は失敗の状態にする`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialState = KsPagingState.EndReached)
        model.failsNextLoad = true

        startRefresh(model)
        settle()
        fetch.respondLast()
        assertEquals(KsPagingState.Failed, model.state)
        assertFalse(model.refreshFailed)
    }

    @Test
    fun `追加読み込み中の取り直しは 先に始めた読み込みの結果を捨てる`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50)

        startLoad(model)
        settle()
        val append = fetch.calls.last()
        startRefresh(model)
        settle()
        val refresh = fetch.calls.last()
        assertEquals(KsPagingState.Refreshing, model.state)

        // 取り直しが先に返る。
        refresh.respond()
        settle()
        assertEquals((1..50).toList(), model.ids())
        assertEquals(KsPagingState.Idle, model.state)

        // 後から返った先の読み込み (Item 51 以降) は混ざらない。
        append.respond()
        settle()
        assertEquals((1..50).toList(), model.ids())
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `取り直しの途中で先の読み込みが返っても 状態は取り直し中のまま`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50)

        startLoad(model)
        settle()
        val append = fetch.calls.last()
        startRefresh(model)
        settle()
        append.respond()
        settle()
        assertEquals(KsPagingState.Refreshing, model.state)
        assertEquals(50, model.items.size)
    }

    @Test
    fun `追加読み込み中に始めた取り直しが失敗したら 待機に戻す`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50)

        startLoad(model)
        settle()
        val append = fetch.calls.last()
        model.failsNextLoad = true
        startRefresh(model)
        settle()
        fetch.respondLast()
        assertEquals(KsPagingState.Idle, model.state)
        assertTrue(model.refreshFailed)
        append.respond()
        settle()
        assertEquals(50, model.items.size)
    }

    @Test
    fun `取り直し中に始めた取り直しが失敗したら 待機に戻す`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50, initialState = KsPagingState.EndReached)

        startRefresh(model)
        settle()
        val first = fetch.calls.last()
        model.failsNextLoad = true
        startRefresh(model)
        settle()
        fetch.respondLast()
        // 前の状態 (取り直し中) の結果は捨てられて戻る先が無いため、取り直しより前の終端ではなく待機に戻す。
        assertEquals(KsPagingState.Idle, model.state)
        assertTrue(model.refreshFailed)
        // 先の取り直しが後から返っても、項目も状態も変わらない。
        first.respond()
        settle()
        assertEquals(KsPagingState.Idle, model.state)
        assertEquals(50, model.items.size)
    }

    @Test
    fun `画面につないだモデルの取り直しは 取り直し中が一覧に届いてから取得する`() = runModelTest {
        val fetch = ControlledFetch()
        var frames = 0
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 100, awaitFrame = { frames += 1 })
        model.onDisplayed(KsPagingState.Idle)

        startRefresh(model)
        settle()
        // 取り直し中にはしたが、まだ一覧に届いていないため取得しない。
        assertEquals(KsPagingState.Refreshing, model.state)
        assertTrue("届く前に取得が ${fetch.calls.size} 回呼ばれた", fetch.calls.isEmpty())

        // 一覧が取り直し中を描いたら、もう 1 回の描画を待ってから取得する。
        model.onDisplayed(KsPagingState.Refreshing)
        settle()
        assertEquals(1, frames)
        assertEquals(0, fetch.calls.single().page)
        fetch.respondLast()
        assertEquals((1..50).toList(), model.ids())
    }

    @Test
    fun `取り直し中にもう一度取り直すときは 届いている取り直し中を待たない`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 50, awaitFrame = {})
        model.onDisplayed(KsPagingState.Idle)
        startRefresh(model)
        settle()
        model.onDisplayed(KsPagingState.Refreshing)
        settle()
        assertEquals(1, fetch.calls.size)

        // 状態は取り直し中のまま変わらず描き直しが起きないため、待たずに取得する。
        startRefresh(model)
        settle()
        assertEquals(2, fetch.calls.size)
        fetch.respondLast()
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `中身を 0 件にする切り替えは その場で取り直す`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this, initialItemCount = 100)

        model.setEmpty(true, this)
        settle()
        val call = fetch.calls.single()
        assertEquals(0, call.page)
        assertTrue(call.isEmpty)
        assertEquals(KsPagingState.Refreshing, model.state)
        fetch.respondLast()
        assertEquals(emptyList<DemoItem>(), model.items)
        assertEquals(KsPagingState.EndReached, model.state)

        // 同じ値への切り替えでは取り直さない。
        model.setEmpty(true, this)
        settle()
        assertEquals(1, fetch.calls.size)

        // 戻すと取り直して 1 ページ目が並ぶ。
        model.setEmpty(false, this)
        settle()
        fetch.respondLast()
        assertEquals((1..50).toList(), model.ids())
    }

    @Test
    fun `0 件で失敗した後 両方の切り替えを戻すと 1 ページ目が並ぶ`() = runModelTest {
        val fetch = ControlledFetch()
        val model = PagingDemoModel(fetch.fetch, this)
        model.setEmpty(true, this)
        settle()
        fetch.respondLast()
        model.failsNextLoad = true
        model.reload(this)
        settle()
        fetch.respondLast()
        assertEquals(KsPagingState.Failed, model.state)

        // 失敗させる切り替えをオフにし、0 件にする切り替えも戻すと、その場の取り直しで 1 ページ目が並ぶ。
        model.failsNextLoad = false
        model.setEmpty(false, this)
        settle()
        fetch.respondLast()
        assertEquals((1..50).toList(), model.ids())
        assertEquals(KsPagingState.Idle, model.state)
    }

    @Test
    fun `構成変更をまたいで件数と切り替えを保ち 実行中の読み込みは待機に 知らせは消えた状態に戻す`() {
        val fetch = ControlledFetch()
        val noticeScope = CoroutineScope(Job())
        val saver = PagingDemoModel.saver(immediateFetch, noticeScope)
        val scope = SaverScope { true }
        val model = PagingDemoModel(immediateFetch, noticeScope, initialItemCount = 150, initialState = KsPagingState.Appending)
        model.failsNextLoad = true
        model.refreshFailedForTest()

        val restored = saver.restore(with(saver) { scope.save(model) }!!)!!
        assertEquals((1..150).toList(), restored.ids())
        assertEquals(KsPagingState.Idle, restored.state)
        assertTrue(restored.failsNextLoad)
        assertFalse(restored.isEmpty)
        // 「更新できませんでした」の知らせは保存せず、消えた状態で戻す。
        assertTrue(model.refreshFailed)
        assertFalse(restored.refreshFailed)

        val ended = PagingDemoModel(fetch.fetch, noticeScope, initialItemCount = 10_000, initialState = KsPagingState.EndReached)
        assertEquals(KsPagingState.EndReached, saver.restore(with(saver) { scope.save(ended) }!!)!!.state)
    }
}
