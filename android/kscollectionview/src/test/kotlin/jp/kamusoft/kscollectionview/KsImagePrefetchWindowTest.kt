package jp.kamusoft.kscollectionview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** 先読み窓の作り方と、台帳 (アイテム ID → URL / URL → 参照数) の寿命を確かめる。 */
internal class KsImagePrefetchWindowTest {

    /** 受け口へ届いた開始・取り消しをそのまま記録する。 */
    private class LoadingRecorder : KsImageLoading {
        data class Start(val url: String, val destination: KsPrefetchDestination)

        val starts = mutableListOf<Start>()
        val disposed = mutableListOf<String>()

        val startedUrls: List<String> get() = starts.map { it.url }

        override fun enqueue(
            url: String,
            destination: KsPrefetchDestination,
        ): KsImageRequestHandle {
            starts.add(Start(url, destination))
            return KsImageRequestHandle { disposed.add(url) }
        }
    }

    private val items: List<Int> = (0 until 40).toList()

    private fun KsImagePrefetchWindow.update(
        visible: IntRange,
        items: List<Int> = this@KsImagePrefetchWindowTest.items,
        destination: KsPrefetchDestination = KsPrefetchDestination.Disk,
        resources: (Int) -> List<String> = { listOf("u$it") },
    ) = update(
        visible = visible,
        items = items,
        key = { it },
        resources = resources,
        destination = destination,
    )

    /** 初期表示では末尾方向へ可視件数と同数の窓を張る。 */
    @Test
    fun initialWindowFollowsForwardWithVisibleCount() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..5)

        assertEquals(listOf("u6", "u7", "u8", "u9", "u10", "u11"), recorder.startedUrls)
        assertTrue("可視範囲の項目は先読みしない", recorder.startedUrls.none { it == "u0" })
    }

    /** 末尾方向へ進むと窓が進み、可視範囲に入った項目の取得は取り消さない。 */
    @Test
    fun forwardScrollAdvancesWindowWithoutCancellingItemsEnteringViewport() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..5)
        recorder.starts.clear()

        window.update(visible = 1..6)

        assertEquals(listOf("u12"), recorder.startedUrls)
        assertTrue("可視範囲へ移った項目は取り消さない", recorder.disposed.isEmpty())
    }

    /** 進行方向が反転すると、進行方向の先に無くなった項目を取り消して新しい窓を開始する。 */
    @Test
    fun reversingDirectionCancelsOldWindowAndStartsNewOne() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 15..20)
        assertEquals(listOf("u21", "u22", "u23", "u24", "u25", "u26"), recorder.startedUrls)
        recorder.starts.clear()

        window.update(visible = 10..15)

        assertEquals(listOf("u4", "u5", "u6", "u7", "u8", "u9"), recorder.startedUrls)
        assertEquals(
            listOf("u21", "u22", "u23", "u24", "u25", "u26"),
            recorder.disposed.sortedBy { it.removePrefix("u").toInt() },
        )
    }

    /** 可視範囲が変わらないときは直前の進行方向を保つ。 */
    @Test
    fun stationaryViewportKeepsPreviousDirection() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 15..20)
        window.update(visible = 10..15)
        recorder.starts.clear()
        recorder.disposed.clear()

        window.update(visible = 10..15)

        assertTrue("同じ可視範囲では窓を作り直さない", recorder.starts.isEmpty())
        assertTrue(recorder.disposed.isEmpty())
    }

    /** 配列の差し替えで消えた項目の取得は取り消される。 */
    @Test
    fun replacingItemsCancelsRequestsForRemovedItems() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..5)
        recorder.starts.clear()

        window.update(visible = 0..5, items = items.filterNot { it == 7 })

        assertEquals(listOf("u7"), recorder.disposed)
        assertEquals(listOf("u12"), recorder.startedUrls)
    }

    /** ID と画像を別々に持つ項目。ID を据え置いたまま画像だけを差し替える検証に使う。 */
    private data class Photo(val id: Int, val url: String)

    private fun KsImagePrefetchWindow.update(visible: IntRange, photos: List<Photo>) = update(
        visible = visible,
        items = photos,
        key = { it.id },
        resources = { listOf(it.url) },
        destination = KsPrefetchDestination.Disk,
    )

    /** ID を据え置いたまま項目の画像が変わったら、古い URL を止めて新しい URL を取りに行く。 */
    @Test
    fun changingTheUrlOfAnItemWithTheSameIdRestartsThePrefetch() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        // 可視範囲 (先頭 1 件) の次に並ぶ 1 件が先読みの対象になる。
        val before = listOf(Photo(0, "u0"), Photo(1, "old"))

        window.update(visible = 0..0, photos = before)
        assertEquals(listOf("old"), recorder.startedUrls)

        window.update(visible = 0..0, photos = listOf(Photo(0, "u0"), Photo(1, "new")))

        assertEquals("古い URL の取得が続いています", listOf("old"), recorder.disposed)
        assertEquals(listOf("old", "new"), recorder.startedUrls)
    }

    /** 画像の差し替えで手放した URL でも、他の項目が必要としている間は取り消さない。 */
    @Test
    fun changingTheUrlKeepsAUrlThatAnotherItemStillNeeds() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        // 可視範囲 (先頭 2 件) の次に並ぶ 2 件が窓に入り、その 2 件が同じ URL を共有する。
        val before = listOf(
            Photo(0, "u0"),
            Photo(1, "u1"),
            Photo(2, "shared"),
            Photo(3, "shared"),
            Photo(4, "u4"),
        )

        window.update(visible = 0..1, photos = before)
        assertEquals(listOf("shared"), recorder.startedUrls)

        window.update(
            visible = 0..1,
            photos = before.map { if (it.id == 2) Photo(2, "own") else it },
        )

        assertTrue("共有中の URL まで取り消しました", recorder.disposed.isEmpty())
        assertEquals(listOf("shared", "own"), recorder.startedUrls)
    }

    /** 同じ URL を複数の項目が返す場合、最後の項目が外れるまで取り消さない。 */
    @Test
    fun sharedUrlIsCancelledOnlyAfterLastItemLeaves() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val shared = listOf("shared.jpg")

        window.update(visible = 0..5, resources = { shared })
        assertEquals(listOf("shared.jpg"), recorder.startedUrls)

        // 窓の一部だけが外れる間は取り消さない。
        window.update(visible = 1..6, resources = { shared })
        assertTrue(recorder.disposed.isEmpty())

        // 台帳の全項目が外れた時点で 1 度だけ取り消す。
        window.disposeAll()
        assertEquals(listOf("shared.jpg"), recorder.disposed)
    }

    /** 1 項目が同じ URL を重ねて返しても参照数は 1 として数える。 */
    @Test
    fun duplicatedUrlsWithinOneItemCountAsOne() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..0, resources = { listOf("u$it", "u$it") })
        assertEquals(listOf("u1"), recorder.startedUrls)

        window.disposeAll()
        assertEquals(listOf("u1"), recorder.disposed)
    }

    /** 1 項目に複数の URL を宣言すると、そのすべての取得が始まる。 */
    @Test
    fun multipleUrlsPerItemAreAllStarted() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..0, resources = { listOf("$it-a.jpg", "$it-b.jpg") })

        assertEquals(listOf("1-a.jpg", "1-b.jpg"), recorder.startedUrls)
    }

    /** 空の配列を返した項目では何も取得しない。 */
    @Test
    fun itemsWithoutResourcesStartNothing() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..5, resources = { emptyList() })
        window.disposeAll()

        assertTrue(recorder.starts.isEmpty())
        assertTrue(recorder.disposed.isEmpty())
    }

    /** 到達点は要求ごとに受け口へそのまま伝わる。 */
    @Test
    fun destinationIsPassedThroughToLoader() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..0, destination = KsPrefetchDestination.Memory)

        assertEquals(
            listOf(KsPrefetchDestination.Memory),
            recorder.starts.map { it.destination },
        )
    }

    /** 台帳に残る要求は窓と可視範囲の分だけで、走査を続けても増え続けない。 */
    @Test
    fun ledgerStaysBoundedWhileScanning() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        for (first in 0..33) {
            window.update(visible = first..(first + 5))
        }

        assertTrue(
            "台帳が窓と可視範囲を超えて増えている: ${window.trackedItemIds.size}",
            window.trackedItemIds.size <= 12,
        )
    }

    /** 末尾では窓が配列の範囲を越えない。 */
    @Test
    fun windowStopsAtTheEndOfItems() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 34..39)

        assertTrue(recorder.starts.isEmpty())
    }
}
