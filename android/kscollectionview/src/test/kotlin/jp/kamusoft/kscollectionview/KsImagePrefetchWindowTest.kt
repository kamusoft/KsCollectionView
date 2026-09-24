package jp.kamusoft.kscollectionview

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 先読み窓の作り方と、台帳 (アイテム ID → 宣言と取得単位 / 取得単位 → 参照数と始めたときの要求) の
 * 寿命を確かめる。
 */
internal class KsImagePrefetchWindowTest {

    /** 受け口へ届いた開始・取り消しをそのまま記録する。 */
    private class LoadingRecorder : KsImageLoading {
        data class Start(val request: KsPrefetchRequest, val destination: KsPrefetchDestination) {
            val url: String get() = request.url
        }

        val starts = mutableListOf<Start>()
        val disposedRequests = mutableListOf<KsPrefetchRequest>()

        val startedUrls: List<String> get() = starts.map { it.url }
        val disposed: List<String> get() = disposedRequests.map { it.url }

        override fun enqueue(
            request: KsPrefetchRequest,
            destination: KsPrefetchDestination,
        ): KsImageRequestHandle {
            starts.add(Start(request, destination))
            return KsImageRequestHandle { disposedRequests.add(request) }
        }

        fun clear() {
            starts.clear()
            disposedRequests.clear()
        }
    }

    private val items: List<Int> = (0 until 40).toList()

    /** 3 列の縦向きを想定した列の幅 (ピクセル)。 */
    private val portrait = KsPrefetchMetrics(columnWidthPx = 300, density = 2f)

    /** 横向きに変わった後の列の幅 (ピクセル)。 */
    private val landscape = KsPrefetchMetrics(columnWidthPx = 500, density = 2f)

    private fun KsImagePrefetchWindow.update(
        visible: IntRange,
        items: List<Int> = this@KsImagePrefetchWindowTest.items,
        destination: KsPrefetchDestination = KsPrefetchDestination.Disk,
        metrics: KsPrefetchMetrics = portrait,
        resources: (Int) -> List<KsResource> = { listOf(KsResource("u$it")) },
    ) = update(
        visible = visible,
        items = items,
        key = { it },
        resources = resources,
        destination = destination,
        metrics = metrics,
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
        recorder.clear()

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
        resources = { listOf(KsResource(it.url)) },
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
        val shared = listOf(KsResource("shared.jpg"))

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

        window.update(visible = 0..0, resources = { listOf(KsResource("u$it"), KsResource("u$it")) })
        assertEquals(listOf("u1"), recorder.startedUrls)

        window.disposeAll()
        assertEquals(listOf("u1"), recorder.disposed)
    }

    /** 1 項目に複数の URL を宣言すると、そのすべての取得が始まる。 */
    @Test
    fun multipleUrlsPerItemAreAllStarted() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(visible = 0..0, resources = { listOf(KsResource("$it-a.jpg"), KsResource("$it-b.jpg")) })

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

    // MARK: 幅つきの宣言と 2 段の台帳

    /** 到達点 memory では、列幅の宣言は解いた列の幅 (ピクセル) を持つ要求になる。 */
    @Test
    fun columnWidthIsResolvedToPixelsForMemory() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(
            visible = 0..0,
            destination = KsPrefetchDestination.Memory,
            resources = { listOf(KsResource("u$it", width = KsWidth.Column)) },
        )

        assertEquals(listOf(KsPrefetchRequest("u1", widthPixels = 300)), recorder.starts.map { it.request })
    }

    /** 固定の幅は表示倍率を掛けて四捨五入したピクセルになる。 */
    @Test
    fun fixedWidthIsScaledByDensity() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(
            visible = 0..0,
            destination = KsPrefetchDestination.Memory,
            metrics = KsPrefetchMetrics(columnWidthPx = 300, density = 2.625f),
            resources = { listOf(KsResource("u$it", width = KsWidth.Fixed(40.dp))) },
        )

        // 40 × 2.625 = 105
        assertEquals(listOf(105), recorder.starts.map { it.request.widthPixels })
    }

    /**
     * 有限かつ正の大きすぎる固定値は有効な宣言で、ピクセルへ直すと幅の上限 (iOS と同じ 16384) で
     * 頭打ちになり停止しない。不正入力としても報告しない。
     * iOS の `test大きすぎる固定値は停止せず幅のピクセルの上限で始まる` と対になる。
     */
    @Test
    fun hugeFixedWidthsAreCappedAtTheMaximumPixels() {
        val recorder = LoadingRecorder()
        val reported = mutableListOf<String>()
        val window = KsImagePrefetchWindow(recorder) { reported.add(it) }
        val widths = listOf(1e19f.dp, Float.MAX_VALUE.dp)

        window.update(
            visible = 0..1,
            destination = KsPrefetchDestination.Memory,
            metrics = KsPrefetchMetrics(columnWidthPx = 300, density = 3f),
            resources = { listOf(KsResource("u$it", width = KsWidth.Fixed(widths[it % 2]))) },
        )

        assertEquals(
            listOf(KsPrefetchMetrics.MaximumPixels, KsPrefetchMetrics.MaximumPixels),
            recorder.starts.map { it.request.widthPixels },
        )
        assertEquals("有効な固定値を不正入力として報告しました", emptyList<String>(), reported)
    }

    /** 幅のピクセルは上限の境界で頭打ちになり、列の幅も同じ上限に丸める。下限は 1。 */
    @Test
    fun widthPixelsAreCappedAtTheBoundary() {
        val limit = KsPrefetchMetrics.MaximumPixels
        val metrics = KsPrefetchMetrics(columnWidthPx = limit + 1, density = 2f)

        assertEquals(limit - 1, metrics.pixels((limit / 2f - 0.5f).dp))
        assertEquals(limit, metrics.pixels((limit / 2f).dp))
        assertEquals(limit, metrics.pixels((limit / 2f + 0.5f).dp))
        assertEquals(limit, metrics.pixels(Float.MAX_VALUE.dp))
        assertEquals(1, metrics.pixels(0.1f.dp))
        assertEquals(limit, metrics.columnWidthPixels)
        assertEquals(null, KsPrefetchMetrics.Unresolved.columnWidthPixels)
    }

    /** 幅あり・幅なしを混ぜた宣言は、それぞれの形の要求になる。 */
    @Test
    fun mixedDeclarationsProduceTheirOwnRequests() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(
            visible = 0..0,
            destination = KsPrefetchDestination.Memory,
            resources = {
                listOf(KsResource("thumb$it", width = KsWidth.Column), KsResource("banner$it"))
            },
        )

        assertEquals(
            listOf(
                KsPrefetchRequest("thumb1", widthPixels = 300),
                KsPrefetchRequest("banner1", widthPixels = null),
            ),
            recorder.starts.map { it.request },
        )
    }

    /** 到達点 disk では幅を使わない。 */
    @Test
    fun diskDestinationIgnoresWidth() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.update(
            visible = 0..0,
            destination = KsPrefetchDestination.Disk,
            resources = { listOf(KsResource("u$it", width = KsWidth.Fixed(40.dp))) },
        )

        assertEquals(listOf(KsPrefetchRequest("u1")), recorder.starts.map { it.request })
    }

    /** 到達点 memory では、同じ URL でも幅が違えば別の取得として数え、一方の取り消しが他方に及ばない。 */
    @Test
    fun differentWidthsAreIndependentForMemory() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        // 1 は固定の 40 (表示倍率 2 で 80 ピクセル)、2 は列幅で同じ URL を返す。
        val resources: (Int) -> List<KsResource> = {
            when (it) {
                1 -> listOf(KsResource("shared", width = KsWidth.Fixed(40.dp)))
                2 -> listOf(KsResource("shared", width = KsWidth.Column))
                else -> emptyList()
            }
        }
        // 可視範囲 (先頭 1 件) の次の 1 件 (1) が窓に入る。
        window.update(visible = 0..0, destination = KsPrefetchDestination.Memory, resources = resources)
        assertEquals(
            listOf(KsPrefetchRequest("shared", widthPixels = 80)),
            recorder.starts.map { it.request },
        )
        // 窓を 1 件進めると、1 が可視範囲へ移り 2 が窓に入る。
        window.update(visible = 0..1, destination = KsPrefetchDestination.Memory, resources = resources)
        assertEquals(
            listOf(KsPrefetchRequest("shared", widthPixels = 80), KsPrefetchRequest("shared", widthPixels = 300)),
            recorder.starts.map { it.request },
        )

        // 1 だけが外れる (可視範囲からも窓からも消える)。
        window.update(visible = 2..3, destination = KsPrefetchDestination.Memory, resources = resources)

        assertEquals(
            "40 の取得だけが取り消されるはず",
            listOf(KsPrefetchRequest("shared", widthPixels = 80)),
            recorder.disposedRequests,
        )
    }

    /** 到達点 disk では、幅違いの宣言も 1 つの取得にまとめ、最後のアイテムが外れるまで取り消さない。 */
    @Test
    fun differentWidthsShareOneRequestForDisk() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val resources: (Int) -> List<KsResource> = {
            when (it) {
                1 -> listOf(KsResource("shared", width = KsWidth.Fixed(40.dp)))
                2 -> listOf(KsResource("shared", width = KsWidth.Column))
                else -> emptyList()
            }
        }
        // 窓 1..2 に両方が入る。
        window.update(visible = 0..0, destination = KsPrefetchDestination.Disk, resources = resources)
        window.update(visible = 0..1, destination = KsPrefetchDestination.Disk, resources = resources)
        assertEquals("disk は幅違いも 1 つの取得", listOf("shared"), recorder.startedUrls)

        // 1 だけが外れても取得は続く。
        window.update(visible = 2..3, destination = KsPrefetchDestination.Disk, resources = resources)
        assertTrue("残るアイテムがあるのに取り消しました", recorder.disposed.isEmpty())

        // 2 も外れた時点で取り消す。
        window.update(visible = 10..11, destination = KsPrefetchDestination.Disk, resources = resources)
        assertEquals(listOf("shared"), recorder.disposed)
    }

    /** 列の幅が変わっただけでは、進行中の取得を取り消さず、出し直しもしない。 */
    @Test
    fun rotationAloneDoesNotTouchRequestsInFlight() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val column: (Int) -> List<KsResource> = { listOf(KsResource("u$it", width = KsWidth.Column)) }

        window.update(visible = 0..5, destination = KsPrefetchDestination.Memory, metrics = portrait, resources = column)
        val startsBefore = recorder.starts.size

        // 同じ可視範囲のまま、列の幅だけが変わった寸法で評価し直す。
        window.update(visible = 0..5, destination = KsPrefetchDestination.Memory, metrics = landscape, resources = column)

        assertEquals("回転だけで取得を出し直しました", startsBefore, recorder.starts.size)
        assertTrue("回転だけで取得を取り消しました", recorder.disposed.isEmpty())

        // その後に新しく窓へ入ったアイテムは、新しい列の幅で始まる。
        window.update(visible = 1..6, destination = KsPrefetchDestination.Memory, metrics = landscape, resources = column)
        assertEquals(KsPrefetchRequest("u12", widthPixels = 500), recorder.starts.last().request)
    }

    /** 列の幅が変わった後の取り消しは、始めたときの幅の要求に対して行う。 */
    @Test
    fun cancellationAfterRotationTargetsTheRequestStartedBefore() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val column: (Int) -> List<KsResource> = { listOf(KsResource("u$it", width = KsWidth.Column)) }

        window.update(visible = 0..5, destination = KsPrefetchDestination.Memory, metrics = portrait, resources = column)

        // 横向きに変わってから、方向の反転で窓のアイテムが外れる。
        window.update(visible = 0..5, destination = KsPrefetchDestination.Memory, metrics = landscape, resources = column)
        window.disposeAll()

        assertEquals(
            (6..11).map { KsPrefetchRequest("u$it", widthPixels = 300) },
            recorder.disposedRequests.sortedBy { it.url.removePrefix("u").toInt() },
        )
    }

    /** 列の幅が 0 以下に解ける間は、列幅で宣言した画像の取得を始めない (到達点に関わらない)。 */
    @Test
    fun columnWidthDeclarationsWaitUntilTheWidthResolves() {
        for (destination in KsPrefetchDestination.entries) {
            val recorder = LoadingRecorder()
            val window = KsImagePrefetchWindow(recorder)
            val resources: (Int) -> List<KsResource> = {
                listOf(KsResource("col$it", width = KsWidth.Column), KsResource("raw$it"))
            }

            window.update(
                visible = 0..0,
                destination = destination,
                metrics = KsPrefetchMetrics(columnWidthPx = 0, density = 2f),
                resources = resources,
            )
            assertEquals("$destination: 列幅の要素が始まりました", listOf("raw1"), recorder.startedUrls)

            // 列の幅が正になった後の評価で始まり、既に始めた取得は出し直さない。
            window.update(visible = 0..0, destination = destination, metrics = portrait, resources = resources)
            assertEquals(listOf("raw1", "col1"), recorder.startedUrls)
            assertTrue(recorder.disposed.isEmpty())
        }
    }

    /** 誤った固定の幅は誤りとして知らせ、幅なし (元の大きさ) として扱う。同じ誤りは 1 度だけ知らせる。 */
    @Test
    fun invalidFixedWidthsAreReportedAndTreatedAsOriginal() {
        val invalid = listOf(0.dp, (-1).dp, Dp(Float.NaN), Dp(Float.POSITIVE_INFINITY), Dp.Unspecified)
        for (width in invalid) {
            val recorder = LoadingRecorder()
            val reports = mutableListOf<String>()
            val window = KsImagePrefetchWindow(recorder) { reports.add(it) }

            window.update(
                visible = 0..0,
                destination = KsPrefetchDestination.Memory,
                resources = { listOf(KsResource("u$it", width = KsWidth.Fixed(width))) },
            )
            window.update(
                visible = 0..0,
                destination = KsPrefetchDestination.Memory,
                resources = { listOf(KsResource("u$it", width = KsWidth.Fixed(width))) },
            )

            assertEquals("$width: 元の大きさで先読みされない", listOf(KsPrefetchRequest("u1")), recorder.starts.map { it.request })
            // 評価されるのは可視範囲の 0 と窓の 1 の 2 件。2 回評価しても報告は 1 件ずつ。
            assertEquals("$width: 同じ誤りを重ねて報告しました", 2, reports.size)
        }
    }

    /** 誤りの報告が停止 (debug) を選ぶと、窓の更新はそこで止まる。 */
    @Test
    fun reportingCanStopTheUpdate() {
        val window = KsImagePrefetchWindow(LoadingRecorder()) { error(it) }

        assertThrows(IllegalStateException::class.java) {
            window.update(
                visible = 0..0,
                destination = KsPrefetchDestination.Memory,
                resources = { listOf(KsResource("u$it", key = "")) },
            )
        }
    }

    // MARK: 任意キー

    /** キーを付けた要素は、キーを持つ要求になる。空文字のキーは誤りとしてキーなしで扱う。 */
    @Test
    fun keysArePassedAndEmptyKeysAreReported() {
        val recorder = LoadingRecorder()
        val reports = mutableListOf<String>()
        val window = KsImagePrefetchWindow(recorder) { reports.add(it) }

        window.update(
            visible = 0..0,
            destination = KsPrefetchDestination.Memory,
            resources = { listOf(KsResource("a$it", key = "p$it"), KsResource("b$it", key = "")) },
        )

        assertEquals(
            listOf(KsPrefetchRequest("a1", key = "p1"), KsPrefetchRequest("b1", key = null)),
            recorder.starts.map { it.request },
        )
        // 評価されるのは可視範囲の 0 と窓の 1 の 2 件。
        assertEquals(2, reports.size)
        assertTrue(reports.any { it.contains("b1") })
    }

    /** キーが同じで URL だけが変わった配列に差し替えると、古い URL の取得を止めて新しい URL で出し直す。 */
    @Test
    fun changingOnlyTheSignedUrlRestartsWithTheNewUrl() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val before = listOf(Photo(0, "u0"), Photo(1, "https://cdn/p1?sig=old"))
        val after = listOf(Photo(0, "u0"), Photo(1, "https://cdn/p1?sig=new"))
        val keyed: (Photo) -> List<KsResource> = { listOf(KsResource(it.url, width = KsWidth.Column, key = "p${it.id}")) }

        window.update(visible = 0..0, items = before, key = { it.id }, resources = keyed, destination = KsPrefetchDestination.Memory, metrics = portrait)
        window.update(visible = 0..0, items = after, key = { it.id }, resources = keyed, destination = KsPrefetchDestination.Memory, metrics = portrait)

        assertEquals(listOf("https://cdn/p1?sig=old"), recorder.disposed)
        assertEquals(
            listOf("https://cdn/p1?sig=old", "https://cdn/p1?sig=new"),
            recorder.startedUrls,
        )
        assertEquals(listOf("p1", "p1"), recorder.starts.map { it.request.key })
    }

    /**
     * 同じキー・同じ幅の取得を 2 件のアイテムが共有しているとき、片方の URL (署名) だけが変わっても
     * 古い URL の取得を止めて新しい URL で始め直す。もう片方が後から同じ URL に変わっても積み増さない。
     */
    @Test
    fun changingTheSignedUrlOfOneSharingItemRestartsTheSharedRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val old = "https://cdn/p?sig=old"
        val new = "https://cdn/p?sig=new"

        window.updateShared(listOf(old, old))
        assertEquals(listOf(old), recorder.startedUrls)

        // 片方だけが新しい署名に変わる。参照数は 0 にならないが、取得は新しい URL に移る。
        window.updateShared(listOf(old, new))
        assertEquals(listOf(old), recorder.disposed)
        assertEquals(listOf(old, new), recorder.startedUrls)
        assertEquals(listOf(new), window.activeRequests.map { it.url })

        // もう片方も同じ新しい署名に変わる。取得は既に新しい URL なので触らない。
        window.updateShared(listOf(new, new))
        assertEquals(listOf(old), recorder.disposed)
        assertEquals(listOf(old, new), recorder.startedUrls)

        // 片方が対象から外れても、残るアイテムが必要とする限り取り消さない。
        window.updateShared(listOf(new))
        assertEquals(listOf(old), recorder.disposed)
        assertEquals(listOf(new), window.activeRequests.map { it.url })
    }

    /** 共有しているアイテムの両方の URL が同時に変わっても、古い URL を止めて新しい URL で 1 回だけ始める。 */
    @Test
    fun changingTheSignedUrlsOfAllSharingItemsRestartsOnce() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val old = "https://cdn/p?sig=old"
        val new = "https://cdn/p?sig=new"

        window.updateShared(listOf(old, old))
        window.updateShared(listOf(new, new))

        assertEquals(listOf(old), recorder.disposed)
        assertEquals(listOf(old, new), recorder.startedUrls)
        assertEquals(listOf("p", "p"), recorder.starts.map { it.request.key })
        assertEquals(
            listOf(KsPrefetchRequest(new, key = "p", widthPixels = portrait.columnWidthPx)),
            window.activeRequests,
        )
    }

    /**
     * 別のアイテムが同じキーを違う署名の URL で共有しても、進行中の取得は始め直さない。始め直すのは、
     * 進行中の取得の URL を宣言していたアイテムが URL を変えたとき、または URL の変更で進行中の URL を
     * どのアイテムも宣言しなくなったときである。
     * iOS の `test別のアイテムが同じキーを違う署名で共有しても進行中の取得を始め直さない` と対になる。
     */
    @Test
    fun anotherItemJoiningWithADifferentSignedUrlDoesNotRestartTheSharedRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val a = "https://cdn/p?sig=a"
        val b = "https://cdn/p?sig=b"
        val c = "https://cdn/p?sig=c"

        window.updateShared(listOf(a))
        // 別のアイテムが違う署名で加わる。進行中の取得をそのまま共有する。
        window.updateShared(listOf(a, b))
        assertEquals("別のアイテムが加わっただけで取得を止めました", emptyList<String>(), recorder.disposed)
        assertEquals(listOf(a), recorder.startedUrls)

        // 後から加わったアイテムの署名が変わっても、進行中の取得はそのアイテムの URL ではないので触らない。
        window.updateShared(listOf(a, c))
        assertEquals("進行中の取得と関係のない署名の変化で取得を止めました", emptyList<String>(), recorder.disposed)
        assertEquals(listOf(a), recorder.startedUrls)

        // 取得を始めたアイテム自身の署名が変わったら、古い URL を止めて新しい URL で始め直す。
        window.updateShared(listOf(b, c))
        assertEquals(listOf(a), recorder.disposed)
        assertEquals(listOf(a, b), recorder.startedUrls)

        // 共有するアイテムが残る間は取り消さず、最後の 1 件が外れたら進行中の取得を取り消す。
        window.updateShared(listOf(b))
        assertEquals(listOf(a), recorder.disposed)
        window.updateShared(emptyList())
        assertEquals(listOf(a, b), recorder.disposed)
    }

    /** 同じ更新の中で共有する取得の署名が食い違っても、先のアイテムの URL で 1 回だけ始める。 */
    @Test
    fun mismatchedSignedUrlsInOneUpdateStartTheSharedRequestOnce() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val a = "https://cdn/p?sig=a"
        val b = "https://cdn/p?sig=b"

        window.updateShared(listOf(a, b))

        assertEquals("始めた取得を取り消しました", emptyList<String>(), recorder.disposed)
        assertEquals(listOf(a), recorder.startedUrls)
    }

    /**
     * 進行中の取得の URL を持つアイテムが URL を変えていなければ、別のアイテムの署名が変わっても始め直さない。
     * iOS の `test進行中の取得のURLを持つアイテムが変わらなければ別のアイテムの署名が変わっても始め直さない` と対になる。
     */
    @Test
    fun anotherItemChangingItsSignedUrlDoesNotRestartWhileTheRunningUrlIsUnchanged() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.updateTrio(visible = 0..2, signatures = mapOf(3 to "a", 4 to "b"))
        assertEquals(listOf(signed("a")), recorder.signedStarts())

        // B の署名だけが変わる。進行中の URL は変わっていない A のものなので触らない。
        window.updateTrio(visible = 0..2, signatures = mapOf(3 to "a", 4 to "b2"))
        assertEquals("URL を変えていないアイテムの取得を止めました", emptyList<String>(), recorder.signedDisposals())
        assertEquals(listOf(signed("a")), recorder.signedStarts())
    }

    /** 取得を始めたアイテムが対象から外れるだけでは、共有中の取得を始め直さない。 */
    @Test
    fun theStarterLeavingAloneDoesNotRestartTheSharedRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.updateTrio(visible = 0..2, signatures = mapOf(3 to "a", 4 to "b", 5 to "c"))
        window.updateTrio(visible = 0..2, signatures = mapOf(4 to "b", 5 to "c"))

        assertEquals("アイテムが外れただけで取得をやり直しました", emptyList<String>(), recorder.signedDisposals())
        assertEquals(listOf(signed("a")), recorder.signedStarts())
        assertEquals(listOf(signed("a")), window.activeRequests.map { it.url }.filter { it.startsWith(SignedBase) })
    }

    /**
     * 同じキーを 3 件が違う署名で共有し、取得を始めたアイテムが対象から外れた後に残る 2 件の署名が
     * 一斉に変わると、どのアイテムも宣言していない古い URL を止めて新しい URL で始め直す。
     * iOS の `test取得を始めたアイテムが外れた後に残りのアイテムの署名が変わると新しいURLで出し直す` と対になる。
     */
    @Test
    fun remainingItemsChangingTheirSignedUrlsAfterTheStarterLeftRestartTheSharedRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        // 可視範囲 0..2 の後ろの窓 3..5 に、同じキーの A (sig=a)・B (sig=b)・C (sig=c) を並べる。
        window.updateTrio(visible = 0..2, signatures = mapOf(3 to "a", 4 to "b", 5 to "c"))
        assertEquals(listOf(signed("a")), recorder.signedStarts())

        // 取得を始めた A が配列から消える。アイテムが外れるだけでは始め直さない。
        window.updateTrio(visible = 0..2, signatures = mapOf(4 to "b", 5 to "c"))
        assertEquals(emptyList<String>(), recorder.signedDisposals())

        // 残る B・C の署名が一斉に変わる。どのアイテムも宣言していない URL の取得を止め、直近に変わった
        // C の新しい URL で 1 回だけ始め直す。
        window.updateTrio(visible = 0..2, signatures = mapOf(4 to "b2", 5 to "c2"))
        assertEquals(
            "どのアイテムも宣言していない URL の取得が続いています",
            listOf(signed("a")),
            recorder.signedDisposals(),
        )
        assertEquals(listOf(signed("a"), signed("c2")), recorder.signedStarts())
        assertEquals(listOf(signed("c2")), window.activeRequests.map { it.url }.filter { it.startsWith(SignedBase) })
    }

    /**
     * 取得を始めたアイテムが可視範囲へ移った後に 3 件すべての署名が変わっても、古い URL の取得を
     * 続けない。可視範囲のアイテムは古い宣言を手放すだけで新しい宣言は確保しないが、窓の中の
     * アイテムが新しい URL を宣言しているので、その URL で始め直す。
     */
    @Test
    fun allSignedUrlsChangingAfterTheStarterMovedIntoTheViewportRestartTheSharedRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.updateTrio(visible = 0..2, signatures = mapOf(3 to "a", 4 to "b", 5 to "c"))
        assertEquals(listOf(signed("a")), recorder.signedStarts())

        // 1 行進んで A (添字 3) が可視範囲へ入る。A は台帳に残り、取得は続く。
        window.updateTrio(visible = 1..3, signatures = mapOf(3 to "a", 4 to "b", 5 to "c"))
        assertEquals(emptyList<String>(), recorder.signedDisposals())

        // 3 件すべての署名が変わる。
        window.updateTrio(visible = 1..3, signatures = mapOf(3 to "a2", 4 to "b2", 5 to "c2"))
        assertEquals(
            "どのアイテムも宣言していない URL の取得が続いています",
            listOf(signed("a")),
            recorder.signedDisposals(),
        )
        assertEquals(listOf(signed("a"), signed("c2")), recorder.signedStarts())
        assertEquals(listOf(signed("c2")), window.activeRequests.map { it.url }.filter { it.startsWith(SignedBase) })
    }

    /**
     * 同じキー・列幅を 2 件が違う署名で共有し、取得を始めた後に列幅が変わってから、取得を始めたアイテムの
     * 署名だけが変わると、古い幅の取得も URL を変えたアイテムの直前の URL のままにしない。古い幅の単位は
     * 残るアイテムが持ち続けるので残し、その URL で古い幅のまま始め直す。
     * iOS の `test列幅が変わった後に取得を始めたアイテムの署名が変わると古い幅の共有中の取得も出し直す` と対になる。
     */
    @Test
    fun theStarterChangingItsSignedUrlAfterAWidthChangeRestartsTheOldWidthRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val a = "https://cdn/p?sig=a"
        val b = "https://cdn/p?sig=b"
        val a2 = "https://cdn/p?sig=a2"

        window.updateShared(listOf(a, b))
        assertEquals(listOf(a), recorder.startedUrls)

        // 回転などで列幅が変わった後に、取得を始めた A の署名だけが変わる。
        window.updateShared(listOf(a2, b), metrics = landscape)

        assertEquals(
            "URL を変えたアイテムの直前の URL で古い幅の取得が続いています",
            listOf(KsPrefetchRequest(a, key = "p", widthPixels = portrait.columnWidthPx)),
            recorder.disposedRequests,
        )
        assertEquals(
            setOf(
                KsPrefetchRequest(a2, key = "p", widthPixels = landscape.columnWidthPx),
                KsPrefetchRequest(b, key = "p", widthPixels = portrait.columnWidthPx),
            ),
            window.activeRequests.toSet(),
        )
    }

    /** 列幅が変わった後でも、取得を始めていないアイテムの署名が変わるだけなら古い幅の取得は始め直さない。 */
    @Test
    fun anotherItemChangingItsSignedUrlAfterAWidthChangeDoesNotRestartTheOldWidthRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        val a = "https://cdn/p?sig=a"

        window.updateShared(listOf(a, "https://cdn/p?sig=b"))
        window.updateShared(listOf(a, "https://cdn/p?sig=b2"), metrics = landscape)

        assertEquals("URL を変えていないアイテムの取得を止めました", emptyList<String>(), recorder.disposed)
        assertEquals(listOf(a, "https://cdn/p?sig=b2"), recorder.startedUrls)
    }

    /**
     * 取得を始めたアイテムが可視範囲へ移り、列幅が変わった後にその署名だけが変わっても、古い幅の取得を
     * その直前の URL のままにしない。可視範囲のアイテムは新しい宣言を確保しないが、URL の変更としては
     * 数え、窓の中に残るアイテムの URL で古い幅のまま始め直す。
     */
    @Test
    fun theStarterInTheViewportChangingItsSignedUrlAfterAWidthChangeRestartsTheOldWidthRequest() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)

        window.updateTrio(visible = 0..2, signatures = mapOf(3 to "a", 4 to "b", 5 to "c"))
        // 1 行進んで A (添字 3) が可視範囲へ入る。
        window.updateTrio(visible = 1..3, signatures = mapOf(3 to "a", 4 to "b", 5 to "c"))
        assertEquals(listOf(signed("a")), recorder.signedStarts())

        // 列幅が変わった後に、A の署名だけが変わる。
        window.updateTrio(visible = 1..3, signatures = mapOf(3 to "a2", 4 to "b", 5 to "c"), metrics = landscape)

        assertEquals(
            "URL を変えたアイテムの直前の URL で古い幅の取得が続いています",
            listOf(signed("a")),
            recorder.signedDisposals(),
        )
        val active = window.activeRequests.filter { it.url.startsWith(SignedBase) }
        assertEquals(listOf(portrait.columnWidthPx), active.map { it.widthPixels })
        assertTrue("宣言されていない URL で始め直しました", active.single().url in setOf(signed("b"), signed("c")))
    }

    private fun signed(signature: String): String = "$SignedBase$signature"

    private fun LoadingRecorder.signedStarts(): List<String> = startedUrls.filter { it.startsWith(SignedBase) }

    private fun LoadingRecorder.signedDisposals(): List<String> = disposed.filter { it.startsWith(SignedBase) }

    /**
     * 添字 0..7 のアイテムを並べて窓を作る。[signatures] にある添字は同じキー "p"・列幅で、その署名の URL を
     * 宣言する。それ以外は署名の無い別の画像を宣言する。[signatures] に無く 3..5 の添字は配列から除く。
     */
    private fun KsImagePrefetchWindow.updateTrio(
        visible: IntRange,
        signatures: Map<Int, String>,
        metrics: KsPrefetchMetrics = portrait,
    ) {
        val photos = (0..7).mapNotNull { index ->
            val signature = signatures[index]
            when {
                signature != null -> Photo(index, signed(signature))
                index in 3..5 -> null
                else -> Photo(index, "u$index")
            }
        }
        update(
            visible = visible,
            items = photos,
            key = { it.id },
            resources = { photo ->
                if (photo.url.startsWith(SignedBase)) {
                    listOf(KsResource(photo.url, width = KsWidth.Column, key = "p"))
                } else {
                    listOf(KsResource(photo.url))
                }
            },
            destination = KsPrefetchDestination.Memory,
            metrics = metrics,
        )
    }

    /**
     * 可視範囲の 2 件 (0, 1) の後ろに、同じキー "p"・列幅で宣言した [urls] のアイテムを並べて窓を作る。
     * 窓は可視件数と同数なので、[urls] が 2 件までなら全件が窓に入る。
     */
    private fun KsImagePrefetchWindow.updateShared(urls: List<String>, metrics: KsPrefetchMetrics = portrait) {
        val photos = listOf(Photo(0, "u0"), Photo(1, "u1")) +
            urls.mapIndexed { index, url -> Photo(index + 2, url) }
        update(
            visible = 0..1,
            items = photos,
            key = { it.id },
            resources = { photo ->
                if (photo.id < 2) {
                    listOf(KsResource(photo.url))
                } else {
                    listOf(KsResource(photo.url, width = KsWidth.Column, key = "p"))
                }
            },
            destination = KsPrefetchDestination.Memory,
            metrics = metrics,
        )
    }

    /** 削除の停止は識別子で行い、幅に関わらずその画像の取得をすべて止める。 */
    @Test
    fun fenceStopsEveryWidthOfTheIdentifier() {
        val recorder = LoadingRecorder()
        val window = KsImagePrefetchWindow(recorder)
        window.update(
            visible = 0..0,
            destination = KsPrefetchDestination.Memory,
            resources = {
                listOf(
                    KsResource("a$it", width = KsWidth.Column, key = "p"),
                    KsResource("b$it", width = KsWidth.Fixed(40.dp), key = "p"),
                    KsResource("p"),
                )
            },
        )
        assertEquals(3, recorder.starts.size)

        // キー "p" の識別子で止める。同じ文字列の URL (キーなし) の取得は止めない。
        window.fence(KsImageIdentity.identifier("ignored", "p"))

        assertEquals(listOf("a1", "b1"), recorder.disposed.sorted())
        assertEquals(listOf(KsPrefetchRequest("p")), window.activeRequests)
    }

    private companion object {
        /** 同じキーを共有する画像の、署名を除いた URL。 */
        const val SignedBase = "https://cdn/p?sig="
    }
}
