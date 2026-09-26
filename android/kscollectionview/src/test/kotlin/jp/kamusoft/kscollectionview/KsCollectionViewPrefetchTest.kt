package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * プリフェッチの宣言が先読み窓を通して受け口へどう伝わるかを、記録用の受け口で確かめる。
 *
 * 表示範囲は 600dp、要素の高さは 100dp なので可視件数は 6 件になる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsCollectionViewPrefetchTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 受け口へ届いた開始・取り消しをそのまま記録する。 */
    private class LoadingRecorder : KsImageLoading {
        data class Start(val request: KsPrefetchRequest, val destination: KsPrefetchDestination) {
            val url: String get() = request.url
        }

        val starts = mutableListOf<Start>()
        val disposed = mutableListOf<String>()

        val startedUrls: List<String> get() = starts.map { it.url }

        override fun enqueue(
            request: KsPrefetchRequest,
            destination: KsPrefetchDestination,
        ): KsImageRequestHandle {
            starts.add(Start(request, destination))
            return KsImageRequestHandle { disposed.add(request.url) }
        }
    }

    private val containerWidth = 300.dp
    private val containerHeight = 600.dp
    private val itemHeight = 100.dp
    private val visibleCount = 6

    private fun url(index: Int): String = "https://images.example.com/$index.jpg"

    private fun urls(range: IntRange): List<String> = range.map { url(it) }

    /** 要素の安定 ID から決定的に URL を作る宣言。 */
    private val itemResources: (TestItem) -> List<KsResource> =
        { listOf(KsResource(url(it.id.removePrefix("item-").toInt()))) }

    /** 期待が満たされるまで実時間の上限つきで待ち、届かなければ実測値を添えて失敗させる。 */
    private fun awaitCondition(description: String, actual: () -> Any?, condition: () -> Boolean) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (!condition()) {
            if (System.nanoTime() > deadline) {
                fail("$description (実測: ${actual()})")
            }
            composeTestRule.waitForIdle()
            composeTestRule.mainClock.advanceTimeByFrame()
        }
        composeTestRule.waitForIdle()
    }

    private fun awaitStarted(recorder: LoadingRecorder, expected: List<String>) {
        awaitCondition(
            description = "開始された URL が期待に届かない (期待 $expected)",
            actual = { recorder.startedUrls },
        ) { recorder.startedUrls.containsAll(expected) }
    }

    private fun awaitCommands(controller: KsScrollController, count: Int) {
        awaitCondition(
            description = "スクロール命令が処理されない (期待 $count 件)",
            actual = { controller.processedCommandCount },
        ) { controller.processedCommandCount >= count }
    }

    private fun setContent(
        recorder: LoadingRecorder,
        items: List<TestItem>,
        controller: KsScrollController? = null,
        destination: KsPrefetchDestination = KsPrefetchDestination.Disk,
        prefetchResources: ((TestItem) -> List<KsResource>)? = itemResources,
        layout: KsLayout = KsLayout.List,
        contentPadding: PaddingValues = PaddingValues(0.dp),
        groups: KsGroups<TestItem, *>? = null,
    ) {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalKsImageLoading provides recorder) {
                TestContainer(containerWidth, containerHeight) {
                    KsCollectionView(
                        items = items,
                        key = { it.id },
                        layout = layout,
                        contentPadding = contentPadding,
                        scrollController = controller,
                        prefetchResources = prefetchResources,
                        prefetchDestination = destination,
                        groups = groups,
                    ) {
                        template { item -> PrefetchRow(item) }
                    }
                }
            }
        }
    }

    /** 初期表示では可視範囲の直後に可視件数と同数の取得が始まる。 */
    @Test
    fun initialWindowPrefetchesVisibleCountAhead() {
        val recorder = LoadingRecorder()
        setContent(recorder, testItems(40))

        awaitStarted(recorder, urls(visibleCount until visibleCount * 2))

        assertEquals(urls(visibleCount until visibleCount * 2), recorder.startedUrls)
        assertTrue("可視範囲の要素は先読みしない", recorder.disposed.isEmpty())
    }

    /**
     * グループの見出しは先読み窓の件数に数えない。見出しと項目の lazy の index のずれは、グループの
     * 構成から項目の位置へ写し直して窓を作る。
     *
     * 5 件ずつのグループに高さ 100dp の見出しが付くと、表示範囲 600dp には見出し 1 つと項目 5 件が
     * 入る。窓は項目 5..9 になる (見出しの分だけ項目の位置がずれた添字では 4..8 になる)。
     */
    @Test
    fun groupHeadersAreNotCountedInWindow() {
        val recorder = LoadingRecorder()
        setContent(
            recorder,
            testItems(40),
            groups = KsGroups(by = { it.id.removePrefix("item-").toInt() / 5 }) { _, _ ->
                PrefetchRow(TestItem("header", "header"))
            },
        )

        awaitStarted(recorder, urls(5..9))

        assertEquals(urls(5..9), recorder.startedUrls)
    }

    /** 末尾方向へ 1 要素分進むと窓が 1 つ進み、可視範囲に入った要素は取り消されない。 */
    @Test
    fun scrollingForwardAdvancesWindow() {
        val recorder = LoadingRecorder()
        val controller = KsScrollController()
        setContent(recorder, testItems(40), controller = controller)
        awaitStarted(recorder, urls(6..11))
        recorder.starts.clear()

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-1", position = KsScrollPosition.Start, animated = false)
        }
        awaitCommands(controller, 1)
        awaitStarted(recorder, listOf(url(12)))

        assertEquals(listOf(url(12)), recorder.startedUrls)
        assertTrue("可視範囲へ移った要素は取り消さない", recorder.disposed.isEmpty())
    }

    /** 進行方向を反転すると、前方の窓が取り消され後方の窓が始まる。 */
    @Test
    fun reversingDirectionCancelsAndRestarts() {
        val recorder = LoadingRecorder()
        val controller = KsScrollController()
        setContent(recorder, testItems(40), controller = controller)
        awaitStarted(recorder, urls(6..11))

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-15", position = KsScrollPosition.Start, animated = false)
        }
        awaitCommands(controller, 1)
        awaitStarted(recorder, urls(21..26))
        recorder.starts.clear()
        recorder.disposed.clear()

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-10", position = KsScrollPosition.Start, animated = false)
        }
        awaitCommands(controller, 2)
        awaitStarted(recorder, urls(4..9))

        assertEquals(urls(4..9), recorder.startedUrls)
        assertEquals(urls(21..26), recorder.disposed.sorted())
    }

    /** 配列の差し替えで消えた要素の取得は取り消される。 */
    @Test
    fun replacingItemsCancelsRemovedItem() {
        val recorder = LoadingRecorder()
        var items by mutableStateOf(testItems(40))

        composeTestRule.setContent {
            CompositionLocalProvider(LocalKsImageLoading provides recorder) {
                TestContainer(containerWidth, containerHeight) {
                    KsCollectionView(
                        items = items,
                        key = { it.id },
                        prefetchResources = itemResources,
                    ) {
                        template { item -> PrefetchRow(item) }
                    }
                }
            }
        }
        awaitStarted(recorder, urls(6..11))

        composeTestRule.runOnUiThread { items = items.filterNot { it.id == "item-7" } }
        awaitCondition(
            description = "消えた要素の取得が取り消されない",
            actual = { recorder.disposed },
        ) { recorder.disposed.contains(url(7)) }

        assertEquals(listOf(url(7)), recorder.disposed)
    }

    /** 宣言が無いコレクションではローダーへの要求が一切起きない。 */
    @Test
    fun noDeclarationStartsNothing() {
        val recorder = LoadingRecorder()
        val controller = KsScrollController()
        setContent(recorder, testItems(40), controller = controller, prefetchResources = null)

        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-20", position = KsScrollPosition.Start, animated = false)
        }
        awaitCommands(controller, 1)

        assertTrue("宣言が無ければ取得は起きない: ${recorder.startedUrls}", recorder.starts.isEmpty())
    }

    /** 宣言した到達点がそのまま受け口へ届く。 */
    @Test
    fun destinationReachesLoader() {
        val recorder = LoadingRecorder()
        setContent(recorder, testItems(40), destination = KsPrefetchDestination.Memory)

        awaitStarted(recorder, urls(6..11))

        assertEquals(
            List(visibleCount) { KsPrefetchDestination.Memory },
            recorder.starts.map { it.destination },
        )
    }

    /** コレクションがコンポジションから外れると未完了の取得はすべて取り消される。 */
    @Test
    fun leavingCompositionDisposesAll() {
        val recorder = LoadingRecorder()
        var isVisible by mutableStateOf(true)

        composeTestRule.setContent {
            CompositionLocalProvider(LocalKsImageLoading provides recorder) {
                TestContainer(containerWidth, containerHeight) {
                    if (isVisible) {
                        KsCollectionView(
                            items = testItems(40),
                            key = { it.id },
                            prefetchResources = itemResources,
                        ) {
                            template { item -> PrefetchRow(item) }
                        }
                    }
                }
            }
        }
        awaitStarted(recorder, urls(6..11))

        composeTestRule.runOnUiThread { isVisible = false }
        awaitCondition(
            description = "画面から消えても取得が残っている",
            actual = { recorder.disposed },
        ) { recorder.disposed.size == recorder.starts.size }

        assertEquals(recorder.startedUrls.toSet(), recorder.disposed.toSet())
    }

    /**
     * 列幅で宣言した要素は、コンテナの幅・列数・余白・列間隔から解いた 1 列分の幅 (ピクセル) で
     * 先読みされる。
     */
    @Test
    fun columnWidthIsResolvedFromTheLayout() {
        val recorder = LoadingRecorder()
        // 300dp のコンテナ (Robolectric の表示倍率は 1)。余白 10 × 2、列間隔 5 × 2 → (300 - 20 - 10) / 3 = 90。
        setContent(
            recorder,
            testItems(60),
            destination = KsPrefetchDestination.Memory,
            prefetchResources = { listOf(KsResource(url(it.id.removePrefix("item-").toInt()), width = KsWidth.Column)) },
            layout = KsLayout.Grid(columns = KsColumns.Fixed(3), columnSpacing = 5.dp),
            contentPadding = PaddingValues(horizontal = 10.dp),
        )

        awaitCondition(
            description = "列幅の先読みが始まらない",
            actual = { recorder.starts },
        ) { recorder.starts.isNotEmpty() }

        assertTrue(
            "列の幅で先読みされていません: ${recorder.starts.map { it.request.widthPixels }}",
            recorder.starts.all { it.request.widthPixels == 90 },
        )
    }

    /** コンテナの向きが変わった後に始まる先読みは、新しい向きの列幅で行われ、既存の取得は触らない。 */
    @Test
    fun orientationChangeUsesTheNewColumnWidthForNewPrefetches() {
        val recorder = LoadingRecorder()
        val controller = KsScrollController()
        // 縦長 (300 × 600) で始め、横長 (400 × 300) へ変える。
        var container by mutableStateOf(300.dp to 600.dp)
        composeTestRule.setContent {
            CompositionLocalProvider(LocalKsImageLoading provides recorder) {
                TestContainer(container.first, container.second) {
                    KsCollectionView(
                        items = testItems(200),
                        key = { it.id },
                        layout = KsLayout.Grid(columns = KsColumns.Fixed(portrait = 3, landscape = 5)),
                        scrollController = controller,
                        prefetchResources = {
                            listOf(KsResource(url(it.id.removePrefix("item-").toInt()), width = KsWidth.Column))
                        },
                        prefetchDestination = KsPrefetchDestination.Memory,
                    ) {
                        template { item -> PrefetchRow(item) }
                    }
                }
            }
        }
        awaitCondition(
            description = "縦向きの先読みが始まらない",
            actual = { recorder.starts },
        ) { recorder.starts.isNotEmpty() }
        val portraitStarts = recorder.starts.toList()
        assertTrue(portraitStarts.all { it.request.widthPixels == 100 })

        // 横長のコンテナへ変えると 5 列になり、列の幅は 400 / 5 = 80 になる。
        composeTestRule.runOnUiThread { container = 400.dp to 300.dp }
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread {
            controller.scrollTo(id = "item-100", position = KsScrollPosition.Start, animated = false)
        }
        awaitCommands(controller, 1)
        awaitCondition(
            description = "横向きの列幅で新しい先読みが始まらない",
            actual = { recorder.starts.map { it.request.widthPixels } },
        ) { recorder.starts.any { it.request.widthPixels == 80 } }

        assertTrue(
            "向きの変化の前の取得が出し直されました",
            recorder.starts.count { it.request.widthPixels == 100 } == portraitStarts.size,
        )
    }

    @Composable
    private fun PrefetchRow(item: TestItem) {
        Text(
            text = item.text,
            modifier = Modifier.fillMaxWidth().height(itemHeight).testTag(item.id),
        )
    }
}
