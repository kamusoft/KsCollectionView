package jp.kamusoft.kscollectionview

import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.ColorImage
import coil3.EventListener
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.DelicateCoilApi
import coil3.annotation.ExperimentalCoilApi
import coil3.decode.DecodeResult
import coil3.decode.Decoder
import coil3.disk.DiskCache
import coil3.fetch.SourceFetchResult
import coil3.memory.MemoryCache
import coil3.network.ConnectivityChecker
import coil3.network.NetworkClient
import coil3.network.NetworkFetcher
import coil3.network.NetworkRequest
import coil3.network.NetworkResponse
import coil3.network.NetworkResponseBody
import coil3.request.ImageRequest
import coil3.request.Options
import coil3.request.allowHardware
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import okio.Buffer
import okio.Path.Companion.toOkioPath
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicInteger

/**
 * 到達点ごとのキャッシュ契約を、取得回数とデコード回数を数えられるローダーで確かめる。
 *
 * 取得層は Coil のネットワーク取得の差し替え口 (NetworkClient) をスタブに置き換えるため、
 * ネットワークアクセスは起きない。ディスクキャッシュの読み書きは Coil 本来の経路を通る。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
// ディスクキャッシュの直接参照・共有インスタンスの差し替え・ネットワーク取得の差し替え口は
// Coil で experimental / delicate 扱い。契約の検証に必要なのでテスト側で受け入れる。
@OptIn(ExperimentalCoilApi::class, DelicateCoilApi::class)
internal class KsImageCacheContractTest {

    /** 取得の回数を数え、常に同じ 1 枚分のデータを返すネットワーク層。 */
    private class CountingNetworkClient : NetworkClient {
        // 取得は取得用のスレッドで走るため、数え上げはスレッド間で見える形にする。
        private val count = AtomicInteger(0)

        /** true の間は応答を保留する。取り消しと完了が競る順序を作るための口。 */
        @Volatile
        var isHeld: Boolean = false

        val requestCount: Int get() = count.get()

        override suspend fun <T> executeRequest(
            request: NetworkRequest,
            block: suspend (NetworkResponse) -> T,
        ): T {
            count.incrementAndGet()
            while (isHeld) {
                delay(1)
            }
            val body = NetworkResponseBody(Buffer().write(ByteArray(64) { it.toByte() }))
            return body.use { block(NetworkResponse(body = it)) }
        }
    }

    /** デコードの回数を数える。実際の画像形式は解釈せず、決まった大きさの画像を返す。 */
    private class CountingDecoder(private val counter: () -> Unit) : Decoder {
        override suspend fun decode(): DecodeResult {
            counter()
            return DecodeResult(
                image = ColorImage(color = 0, width = 100, height = 100),
                isSampled = false,
            )
        }

        class Factory(private val counter: () -> Unit) : Decoder.Factory {
            override fun create(
                result: SourceFetchResult,
                options: Options,
                imageLoader: ImageLoader,
            ): Decoder {
                result.source.source().readByteArray()
                return CountingDecoder(counter)
            }
        }
    }

    private lateinit var context: Context
    private lateinit var cacheDirectory: File
    private lateinit var network: CountingNetworkClient
    private lateinit var loader: ImageLoader
    // デコードも取得用のスレッドで走るため、数え上げはスレッド間で見える形にする。
    private val decodes = AtomicInteger(0)
    private val decodeCount: Int get() = decodes.get()

    /**
     * ローダーが受け取った要求。要求そのものに付いた指定を検証するために記録する。
     * 記録は取得用のスレッドから行われるため、スレッド間で見える入れ物にする。
     */
    private val startedRequests = CopyOnWriteArrayList<ImageRequest>()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        installKsAppContext(context)
        cacheDirectory = File(context.cacheDir, "ks-image-${UUID.randomUUID()}")
        network = CountingNetworkClient()
        decodes.set(0)
        startedRequests.clear()
        loader = ImageLoader.Builder(context)
            .eventListener(object : EventListener() {
                override fun onStart(request: ImageRequest) {
                    startedRequests += request
                }
            })
            .memoryCache { MemoryCache.Builder().maxSizeBytes(4L * 1024 * 1024).build() }
            .diskCache { DiskCache.Builder().directory(cacheDirectory.toOkioPath()).build() }
            .components {
                add(CountingDecoder.Factory { decodes.incrementAndGet() })
                add(
                    NetworkFetcher.Factory(
                        networkClient = { network },
                        connectivityChecker = { ConnectivityChecker.ONLINE },
                    ),
                )
            }
            .build()
        SingletonImageLoader.setUnsafe(loader)
    }

    @After
    fun tearDown() {
        loader.shutdown()
        SingletonImageLoader.reset()
        cacheDirectory.deleteRecursively()
    }

    private fun url(name: String): String = "https://images.example.com/$name.jpg"

    /** 期待が満たされるまで実時間の上限つきで待ち、届かなければ実測値を添えて失敗させる。 */
    private fun awaitCondition(description: String, actual: () -> Any?, condition: () -> Boolean) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (!condition()) {
            if (System.nanoTime() > deadline) {
                fail("$description (実測: ${actual()})")
            }
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(1)
        }
    }

    private fun awaitDiskEntry(url: String) {
        awaitCondition(
            description = "ディスクキャッシュに元データが残らない",
            actual = { "network=${network.requestCount} decode=$decodeCount" },
        ) { loader.diskCache?.openSnapshot(url)?.also { it.close() } != null }
    }

    /**
     * 表示を本番と同じ段取りで 1 回行う。要求の組み立ても、メモリにある元寸をその場で
     * 縮小して表示用の鍵へ載せる段取りも [KsImageRequestFactory] を通す。
     */
    private fun display(url: String, width: Int = 50, height: Int = 50) {
        val prepared = requireNotNull(
            KsImageRequestFactory.prepare(
                context = context,
                source = KsImageSource.Remote(url),
                width = width,
                height = height,
                contentMode = KsImageContentMode.Fill,
            ),
        )
        runBlocking {
            loader.execute(prepared.request)
        }
    }

    /** 到達点 disk は元データだけを残し、デコードせず、表示時に取得をやり直さない。 */
    @Test
    fun diskDestinationStoresDataWithoutDecodingOrRefetching() {
        val target = url("disk")

        KsCoilImageLoading(context).enqueue(target, KsPrefetchDestination.Disk)
        awaitDiskEntry(target)

        assertEquals("取得は 1 度だけ走る", 1, network.requestCount)
        assertEquals("ディスク到達点ではデコードしない", 0, decodeCount)

        display(target)

        assertEquals("表示でネットワークをやり直さない", 1, network.requestCount)
        assertEquals("表示で初めてデコードする", 1, decodeCount)
    }

    /**
     * 先読みが載せた元寸の画素を読み出せる場合、到達点 memory は表示時に再デコードしない。
     *
     * ここで使うデコーダは画素を読み出せる画像を返すため、表示側は元寸をその場で縮小して
     * 表示用の鍵へ載せ直せる。この結果が言えるのはその条件の下だけで、到達点 memory が常に
     * 再デコードを避けることは意味しない。実機の元寸は通常グラフィックス側に画素を置いて
     * 読み出せないため、表示はローダーの縮小デコードを 1 回待つ — そちらは実機で走る
     * [KsImageDeviceDecodeTest] が押さえる。
     */
    @Test
    fun memoryDestinationAvoidsSecondDecodeWhenPrefetchedPixelsAreReadable() {
        val target = url("memory")

        KsCoilImageLoading(context).enqueue(target, KsPrefetchDestination.Memory)
        awaitCondition(
            description = "メモリ到達点でデコードが走らない",
            actual = { "network=${network.requestCount} decode=$decodeCount" },
        ) { decodeCount >= 1 }

        assertEquals(1, network.requestCount)

        display(target)

        assertEquals("表示でネットワークをやり直さない", 1, network.requestCount)
        assertEquals("表示で再デコードしない", 1, decodeCount)
    }

    /**
     * 到達点 memory の先読みは、画素の置き場をローダーと端末の判断に委ねる。
     *
     * ハードウェア支援を切ると画素がソフトウェア側に置かれ、描画のたびに転送費用が乗って
     * スクロールの滑らかさを損なう。読み出せない元寸は表示側が初回の描画に使わない作りで
     * 受け止めるため、先読み側で切る必要は無い。
     */
    @Test
    fun memoryDestinationKeepsHardwareBitmapsAllowed() {
        val target = url("hardware")

        KsCoilImageLoading(context).enqueue(target, KsPrefetchDestination.Memory)
        awaitCondition(
            description = "先読みの要求がローダーに届かない",
            actual = { "started=${startedRequests.size}" },
        ) { startedRequests.isNotEmpty() }

        assertTrue(
            "先読みの要求がハードウェア支援を切っています",
            startedRequests.first().allowHardware,
        )
    }

    private fun memoryEntryExists(url: String): Boolean =
        loader.memoryCache?.keys?.any { it.key == url } == true

    private fun diskEntryExists(url: String): Boolean =
        loader.diskCache?.openSnapshot(url)?.also { it.close() } != null

    /** ソース単位の削除は対象のソースだけを消し、他のソースはキャッシュから表示され続ける。 */
    @Test
    fun removeDeletesOnlyTheTargetSource() {
        val target = url("removed")
        val other = url("kept")
        val loading = KsCoilImageLoading(context)
        loading.enqueue(target, KsPrefetchDestination.Memory)
        loading.enqueue(other, KsPrefetchDestination.Memory)

        awaitCondition(
            description = "2 件が両方のキャッシュに載らない",
            actual = { "network=${network.requestCount} decode=$decodeCount" },
        ) {
            memoryEntryExists(target) && diskEntryExists(target) &&
                memoryEntryExists(other) && diskEntryExists(other)
        }
        assertEquals(2, network.requestCount)

        KsImageCache.remove(KsImageSource.Remote(target))

        assertFalse("対象のメモリの項目が残っています", memoryEntryExists(target))
        assertFalse("対象の元データが残っています", diskEntryExists(target))
        assertTrue("他のソースのメモリの項目まで消えました", memoryEntryExists(other))
        assertTrue("他のソースの元データまで消えました", diskEntryExists(other))

        // 削除したソースは取得からやり直しになる。
        display(target)
        assertEquals("削除したソースが取り直されていません", 3, network.requestCount)

        // 残したソースは取得も再デコードもやり直さない。
        val decodesBefore = decodeCount
        display(other)
        assertEquals("残したソースが取り直されました", 3, network.requestCount)
        assertEquals("残したソースが再デコードされました", decodesBefore, decodeCount)
    }

    /** メモリのみの消去では元データが残り、次の表示はディスクからの再デコードで済む。 */
    @Test
    fun clearingMemoryKeepsDiskDataForRedecoding() {
        val target = url("memory-only")
        KsCoilImageLoading(context).enqueue(target, KsPrefetchDestination.Memory)

        awaitCondition(
            description = "メモリとディスクの両方に載らない",
            actual = { "network=${network.requestCount} decode=$decodeCount" },
        ) { memoryEntryExists(target) && diskEntryExists(target) }
        assertEquals(1, network.requestCount)
        assertEquals(1, decodeCount)

        KsImageCache.clear(KsImageCacheScope.Memory)

        assertFalse("メモリの項目が残っています", memoryEntryExists(target))
        assertTrue("元データまで消えました", diskEntryExists(target))

        display(target)

        assertEquals("再ダウンロードが起きました", 1, network.requestCount)
        assertEquals("ディスクからの再デコードが起きていません", 2, decodeCount)
    }

    /** 全消去の後は、メモリに残っていた画像にも当たらず取得からやり直す。 */
    @Test
    fun clearingAllAlsoInvalidatesTheDecodedMemoryImage() {
        val target = url("all-cleared")
        KsCoilImageLoading(context).enqueue(target, KsPrefetchDestination.Memory)

        awaitCondition(
            description = "メモリとディスクの両方に載らない",
            actual = { "network=${network.requestCount} decode=$decodeCount" },
        ) { memoryEntryExists(target) && diskEntryExists(target) }
        assertEquals(1, network.requestCount)

        KsImageCache.clear(KsImageCacheScope.All)

        assertFalse("メモリの項目が残っています", memoryEntryExists(target))
        assertFalse("元データが残っています", diskEntryExists(target))

        display(target)

        assertEquals("全消去の後に取り直されていません", 2, network.requestCount)
    }

    /** ソース単位の削除は、鍵の接頭辞が一致するだけの別のソースを巻き添えにしない。 */
    @Test
    fun removeKeepsAnotherSourceWhoseKeySharesThePrefix() {
        // 鍵の一方がもう一方の接頭辞になる 2 つのソース。
        val target = "https://images.example.com/a"
        val neighbour = "https://images.example.com/a-preview"
        val loading = KsCoilImageLoading(context)
        loading.enqueue(target, KsPrefetchDestination.Memory)
        loading.enqueue(neighbour, KsPrefetchDestination.Memory)

        awaitCondition(
            description = "2 件がメモリに載らない",
            actual = { "network=${network.requestCount} decode=$decodeCount" },
        ) { memoryEntryExists(target) && memoryEntryExists(neighbour) }

        KsImageCache.remove(KsImageSource.Remote(target))

        assertFalse("対象のメモリの項目が残っています", memoryEntryExists(target))
        assertTrue("接頭辞が一致するだけの別のソースまで消えました", memoryEntryExists(neighbour))
        assertTrue("接頭辞が一致するだけの別のソースの元データまで消えました", diskEntryExists(neighbour))
    }

    /** 消去より前に始まった先読みは、完了してもキャッシュへ書き戻さない。 */
    @Test
    fun prefetchesStartedBeforeAClearDoNotRepopulateTheCache() {
        val target = url("in-flight")
        val control = url("after-clear")
        val window = KsImagePrefetchWindow(KsCoilImageLoading(context))
        network.isHeld = true

        window.update(
            visible = 0..0,
            // 可視範囲 (先頭 1 件) の次に並ぶ 1 件が先読みの対象になる。
            items = listOf("visible", target, control),
            key = { it },
            resources = { if (it == target) listOf(target) else emptyList() },
            destination = KsPrefetchDestination.Memory,
        )
        awaitCondition(
            description = "先読みが始まらない",
            actual = { "network=${network.requestCount}" },
        ) { network.requestCount >= 1 }

        KsImageCache.clear(KsImageCacheScope.All)

        // 消去の後に始めた別のソースの取得を、保留していた分と一緒に進める。
        network.isHeld = false
        KsCoilImageLoading(context).enqueue(control, KsPrefetchDestination.Memory)
        awaitCondition(
            description = "後から始めた取得が載らない",
            actual = { "network=${network.requestCount}" },
        ) { memoryEntryExists(control) }

        assertFalse("消去より前に始まった取得がメモリへ書き戻しました", memoryEntryExists(target))
        assertFalse("消去より前に始まった取得が元データを書き戻しました", diskEntryExists(target))
    }

    /** ソース単位の削除は、対象の進行中の先読みだけを止める。 */
    @Test
    fun removeFencesOnlyTheTargetSourcePrefetch() {
        val recorder = RecordingLoading()
        val window = KsImagePrefetchWindow(recorder)
        // 可視範囲 (先頭 2 件) の次に並ぶ 2 件が先読みの対象になる。
        window.update(
            visible = 0..1,
            items = listOf("a", "b", "c", "d"),
            key = { it },
            resources = { listOf(url(it)) },
            destination = KsPrefetchDestination.Disk,
        )
        assertEquals(listOf(url("c"), url("d")), recorder.started)

        KsImageCache.remove(KsImageSource.Remote(url("c")))

        assertEquals("対象以外の先読みまで止めました", listOf(url("c")), recorder.disposed)
        assertFalse("止めた先読みが台帳に残っています", window.trackedItemIds.contains("c"))
        assertTrue("止めていない先読みが台帳から消えました", window.trackedItemIds.contains("d"))
    }

    /** 範囲が全部の消去は、進行中の先読みをすべて止めて台帳を空にする。 */
    @Test
    fun clearFencesEveryPrefetchInFlight() {
        val recorder = RecordingLoading()
        val window = KsImagePrefetchWindow(recorder)
        // 可視範囲 (先頭 2 件) の次に並ぶ 2 件が先読みの対象になる。
        window.update(
            visible = 0..1,
            items = listOf("a", "b", "c", "d"),
            key = { it },
            resources = { listOf(url(it)) },
            destination = KsPrefetchDestination.Disk,
        )
        assertEquals(listOf(url("c"), url("d")), recorder.started)

        KsImageCache.clear(KsImageCacheScope.All)

        assertEquals(listOf(url("c"), url("d")), recorder.disposed)
        assertTrue("台帳が空になっていません", window.trackedItemIds.isEmpty())
    }

    /**
     * 範囲がメモリだけの消去も、進行中の先読みをすべて止めて台帳を空にする。到達点をメモリまでに
     * した先読みはデコード済みの画像をメモリへ載せるため、止めないと消した直後に埋め戻せる。
     */
    @Test
    fun clearingMemoryFencesEveryPrefetchInFlight() {
        val recorder = RecordingLoading()
        val window = KsImagePrefetchWindow(recorder)
        // 可視範囲 (先頭 2 件) の次に並ぶ 2 件が先読みの対象になる。
        window.update(
            visible = 0..1,
            items = listOf("a", "b", "c", "d"),
            key = { it },
            resources = { listOf(url(it)) },
            destination = KsPrefetchDestination.Memory,
        )
        assertEquals(listOf(url("c"), url("d")), recorder.started)

        KsImageCache.clear(KsImageCacheScope.Memory)

        assertEquals(listOf(url("c"), url("d")), recorder.disposed)
        assertTrue("台帳が空になっていません", window.trackedItemIds.isEmpty())
    }

    /** 範囲がメモリだけの消去でも、消去より前に始まった先読みはメモリへ書き戻さない。 */
    @Test
    fun prefetchesStartedBeforeAMemoryClearDoNotRepopulateTheMemoryCache() {
        val target = url("in-flight-memory")
        val control = url("after-memory-clear")
        val window = KsImagePrefetchWindow(KsCoilImageLoading(context))
        network.isHeld = true

        window.update(
            visible = 0..0,
            // 可視範囲 (先頭 1 件) の次に並ぶ 1 件が先読みの対象になる。
            items = listOf("visible", target, control),
            key = { it },
            resources = { if (it == target) listOf(target) else emptyList() },
            destination = KsPrefetchDestination.Memory,
        )
        awaitCondition(
            description = "先読みが始まらない",
            actual = { "network=${network.requestCount}" },
        ) { network.requestCount >= 1 }

        KsImageCache.clear(KsImageCacheScope.Memory)

        // 消去の後に始めた別のソースの取得を、保留していた分と一緒に進める。
        network.isHeld = false
        KsCoilImageLoading(context).enqueue(control, KsPrefetchDestination.Memory)
        awaitCondition(
            description = "後から始めた取得が載らない",
            actual = { "network=${network.requestCount}" },
        ) { memoryEntryExists(control) }

        assertFalse("消去より前に始まった先読みがメモリへ書き戻しました", memoryEntryExists(target))
    }

    /** 受け口へ届いた開始・取り消しをそのまま記録する。 */
    private class RecordingLoading : KsImageLoading {
        val started = mutableListOf<String>()
        val disposed = mutableListOf<String>()

        override fun enqueue(
            url: String,
            destination: KsPrefetchDestination,
        ): KsImageRequestHandle {
            started.add(url)
            return KsImageRequestHandle { disposed.add(url) }
        }
    }

    /** プリフェッチはローダーの共有インスタンスに出るため、それを直接使う表示と同じ項目を見る。 */
    @Test
    fun requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData() {
        val target = url("shared")
        assertSame("共有インスタンスを使う", loader, SingletonImageLoader.get(context))

        KsCoilImageLoading(context).enqueue(target, KsPrefetchDestination.Disk)
        awaitDiskEntry(target)

        // ローダー付属のビューが出す要求と同じ形 (ライブラリ独自の鍵を付けない) で、
        // 共有インスタンスから直接取得する。
        runBlocking {
            SingletonImageLoader.get(context).execute(
                ImageRequest.Builder(context).data(target).size(80, 80).build(),
            )
        }

        assertEquals("再ダウンロードは起きない", 1, network.requestCount)
    }
}
