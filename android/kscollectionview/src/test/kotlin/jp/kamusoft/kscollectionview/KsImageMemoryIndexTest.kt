package jp.kamusoft.kscollectionview

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.ColorImage
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.DelicateCoilApi
import coil3.memory.MemoryCache
import coil3.size.Size
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * 引き当ての索引 ([KsImageMemoryIndex]) の登録・上限・キャッシュとの突き合わせと、キャッシュ操作との
 * 同期を確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
// 共有インスタンスの差し替えは Coil で delicate 扱い。キャッシュ操作との同期の検証に必要なので受け入れる。
@OptIn(DelicateCoilApi::class)
internal class KsImageMemoryIndexTest {

    private lateinit var context: Context
    private lateinit var loader: ImageLoader
    private lateinit var memory: MemoryCache

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        installKsAppContext(context)
        memory = MemoryCache.Builder().maxSizeBytes(4L * 1024 * 1024).build()
        loader = ImageLoader.Builder(context).memoryCache { memory }.build()
        SingletonImageLoader.setUnsafe(loader)
        KsImageMemoryIndex.shared.removeAll()
        KsImageInvalidation.reset()
    }

    @After
    fun tearDown() {
        loader.shutdown()
        SingletonImageLoader.reset()
        KsImageMemoryIndex.shared.removeAll()
        KsImageInvalidation.reset()
    }

    private fun sized(identifier: String, side: Int): MemoryCache.Key =
        KsImageIdentity.sizedKey(identifier, Size(side, side))

    private fun put(key: MemoryCache.Key, side: Int = 10) {
        memory[key] = MemoryCache.Value(ColorImage(color = 0, width = side, height = side))
    }

    /** 登録した鍵のうち、キャッシュにある項目だけを候補として返す。 */
    @Test
    fun cachedEntriesReturnOnlyItemsInTheCache() {
        val index = KsImageMemoryIndex(capacity = 10)
        val present = sized("a", 100)
        val pending = sized("a", 200)
        put(present)
        index.register(present)
        index.register(pending)

        val entries = index.cachedEntries("a", memory)

        assertEquals(listOf(present), entries.map { it.first })
    }

    /** 未完了の鍵 (キャッシュに無い鍵) は候補にならないが、索引には残り、載った後の問い合わせで候補になる。 */
    @Test
    fun keysNotInTheCacheStayIndexedUntilTheItemArrives() {
        val index = KsImageMemoryIndex(capacity = 10)
        val pending = sized("a", 200)
        index.register(pending)

        assertTrue(index.cachedEntries("a", memory).isEmpty())
        assertEquals("問い合わせただけで鍵が索引から外れました", listOf(pending), index.keys("a"))

        put(pending)

        assertEquals(listOf(pending), index.cachedEntries("a", memory).map { it.first })
    }

    /**
     * 取得中の先読みがある画像は、取得が終わるまでその扱いになる。終わりの通知は何度届いても 1 度だけ
     * 数え、同じ鍵で始め直した取得の数を崩さない。項目がメモリに載った後は取得中として扱わない。
     */
    @Test
    fun fetchInFlightIsCountedPerFetch() {
        val index = KsImageMemoryIndex(capacity = 10)
        val key = sized("a", 100)
        index.register(key)
        assertFalse(index.hasFetchInFlight("a", memory))

        val endFirst = index.beginFetch(key)
        // 取り消して同じ鍵で始め直し、古い取得の終わりの通知が後から届く形。
        val endSecond = index.beginFetch(key)
        endFirst()
        endFirst()
        assertTrue("始め直した取得が取得中から外れました", index.hasFetchInFlight("a", memory))

        put(key)
        assertFalse("メモリに載った項目を取得中として扱いました", index.hasFetchInFlight("a", memory))

        endSecond()
        assertEquals(0, index.fetchesInFlightCount)
    }

    /** 索引から外れた鍵の取得は、待っても引き当てられないので取得中として扱わない。 */
    @Test
    fun fetchInFlightOfARemovedKeyIsIgnored() {
        val index = KsImageMemoryIndex(capacity = 10)
        val key = sized("a", 100)
        index.register(key)
        index.beginFetch(key)

        index.remove("a")

        assertFalse(index.hasFetchInFlight("a", memory))
    }

    /** 上限を超えると、最も長く使われていない鍵から外れる。使った鍵は新しい側へ移る。 */
    @Test
    fun capacityEvictsTheLeastRecentlyUsedKey() {
        val index = KsImageMemoryIndex(capacity = 2)
        val first = sized("a", 1)
        val second = sized("b", 1)
        val third = sized("c", 1)
        index.register(first)
        index.register(second)
        // first を使ったことにすると、次に外れるのは second になる。
        index.markUsed(first)

        index.register(third)

        assertEquals(2, index.count)
        assertEquals(listOf(first), index.keys("a"))
        assertEquals(emptyList<MemoryCache.Key>(), index.keys("b"))
        assertEquals(listOf(third), index.keys("c"))
    }

    /** 同じ鍵を重ねて登録しても 1 件として数える。 */
    @Test
    fun registeringTheSameKeyTwiceCountsOnce() {
        val index = KsImageMemoryIndex(capacity = 10)
        index.register(sized("a", 1))
        index.register(sized("a", 1))

        assertEquals(1, index.count)
    }

    /** 識別子単位の削除は、その識別子の鍵だけを外す。 */
    @Test
    fun removeDropsOnlyTheIdentifier() {
        val index = KsImageMemoryIndex(capacity = 10)
        index.register(sized("a", 1))
        index.register(KsImageIdentity.originalKey("a"))
        index.register(sized("b", 1))

        index.remove("a")

        assertEquals(emptyList<MemoryCache.Key>(), index.keys("a"))
        assertEquals(1, index.count)
    }

    /** 共有の索引の上限は、ローダーが保持できる項目数を十分に上回る 20,000 件。 */
    @Test
    fun sharedIndexCapacity() {
        assertEquals(20_000, KsImageMemoryIndex.shared.capacity)
    }

    /** 範囲消去から戻った時点で、キャッシュと索引の両方が空になっている。 */
    @Test
    fun clearInvalidatesCacheAndIndexOnReturn() {
        for (scope in KsImageCacheScope.entries) {
            val key = sized("https://example.com/clear.jpg", 10)
            put(key)
            KsImageMemoryIndex.shared.register(key)

            KsImageCache.clear(scope)

            assertNull("$scope: キャッシュの項目が残っています", memory[key])
            assertEquals("$scope: 索引が残っています", 0, KsImageMemoryIndex.shared.count)
        }
    }

    /** ソース単位の削除から戻った時点で、そのソースのキャッシュの項目と索引の鍵が消えている。 */
    @Test
    fun removeInvalidatesCacheAndIndexOnReturn() {
        val source = KsImageSource.Remote("https://example.com/p.jpg", key = "p")
        val identifier = requireNotNull(source.identifier)
        val key = sized(identifier, 10)
        val other = sized("https://example.com/p.jpg", 10)
        put(key)
        put(other)
        KsImageMemoryIndex.shared.register(key)
        KsImageMemoryIndex.shared.register(other)

        KsImageCache.remove(source)

        assertNull(memory[key])
        assertEquals(emptyList<MemoryCache.Key>(), KsImageMemoryIndex.shared.keys(identifier))
        assertEquals("キーなしの同じ URL の鍵まで外れました", listOf(other), KsImageMemoryIndex.shared.keys("https://example.com/p.jpg"))
    }

    /**
     * 登録と消去が競合しても、消去から戻った後の引き当てが削除前の項目を指さない。
     *
     * 別のスレッドが同じ鍵を登録し続ける間に削除する。索引に鍵が残っても、項目の実在の正は
     * ローダーのキャッシュにあるため、候補にはならない。
     */
    @Test
    fun concurrentRegistrationNeverPointsToRemovedItems() {
        val source = KsImageSource.Remote("https://example.com/race.jpg")
        val identifier = requireNotNull(source.identifier)
        val key = sized(identifier, 10)
        repeat(100) { round ->
            put(key)
            KsImageMemoryIndex.shared.register(key)
            val running = AtomicBoolean(true)
            val started = CountDownLatch(1)
            val registrar = thread {
                started.countDown()
                while (running.get()) {
                    KsImageMemoryIndex.shared.register(key)
                }
            }
            started.await()

            if (round % 2 == 0) KsImageCache.remove(source) else KsImageCache.clear(KsImageCacheScope.Memory)

            assertTrue(
                "round $round: 消去の後に削除前の項目を指しました",
                KsImageMemoryIndex.shared.cachedEntries(identifier, memory).isEmpty(),
            )
            running.set(false)
            registrar.join()
        }
    }
}
