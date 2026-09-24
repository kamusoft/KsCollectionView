package jp.kamusoft.kscollectionview

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import coil3.BitmapImage
import coil3.EventListener
import coil3.Image
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.DelicateCoilApi
import coil3.decode.Decoder
import coil3.memory.MemoryCache
import coil3.request.ImageRequest
import coil3.request.Options
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * 端末のデコードが選ぶ画素の構成に依存する経路を、実機の上で確かめる。
 *
 * 実機のデコードは通常、画像の画素をグラフィックス側に置く (画素を読み出せない)。表示の引き当ては
 * 画素を読まずに寸法だけで判定するため、その画像もそのまま表示に使える。確かめるのはこの契約 —
 * 先読みが載せたグラフィックス側の画像が引き当てられ読み込み中を経由しないこと、幅を宣言した先読みが
 * その幅の項目を載せること、許容範囲の外なら枠の大きさの縮小デコードに落ちること、表示のために
 * 元の大きさの画像をメモリに置かないこと。
 *
 * JVM 上のテスト環境では画素は常にソフトウェア側に置かれるため、グラフィックス側の画像での成立は
 * 実機で走るこのテストでしか検証層に載らない。
 *
 * 画素がグラフィックス側に置かれるかどうかは端末とローダーの判断であり、実機でも常には成立しない
 * (ローダーは端末の資源が逼迫すると自ら止める)。グラフィックス側であることを前提にする確認は
 * 契約のアサーションではなく前提 ([org.junit.Assume]) として書き、満たさない実行は skip として残す。
 *
 * 取得元は端末内に書き出したファイルにする。ネットワークを使うと、回線状態で結果が変わる。
 * デコードの回数を数えるため、共有インスタンスを観測付きのローダーに差し替えるが、要求を出す経路は
 * 本番のまま ([KsCoilImageLoading] と [KsImageRequestFactory]) にする。
 */
@RunWith(AndroidJUnit4::class)
// 共有インスタンスの差し替えは Coil で delicate 扱い。デコード回数を数えるために受け入れる。
@OptIn(DelicateCoilApi::class)
internal class KsImageDeviceDecodeTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    /** 枠より十分大きい元寸の画像。 */
    private lateinit var sourceFile: File

    private lateinit var loader: ImageLoader
    private val decodes = AtomicInteger(0)
    private val starts = AtomicInteger(0)

    /** 取得元のファイルを指す画像ソース。 */
    private val source: KsImageSource get() = KsImageSource.File(sourceFile)

    /** 先読みに渡す URL。画像ソースと同じ識別子になる。 */
    private val sourceUrl: String get() = requireNotNull(source.identifier)

    @Before
    fun setUp() {
        sourceFile = writeSourceImage()
        decodes.set(0)
        starts.set(0)
        loader = ImageLoader.Builder(context)
            .eventListener(object : EventListener() {
                override fun onStart(request: ImageRequest) {
                    starts.incrementAndGet()
                }

                override fun decodeStart(request: ImageRequest, decoder: Decoder, options: Options) {
                    decodes.incrementAndGet()
                }
            })
            .build()
        SingletonImageLoader.setUnsafe(loader)
        KsImageMemoryIndex.shared.removeAll()
    }

    @After
    fun tearDown() {
        SingletonImageLoader.reset()
        loader.shutdown()
        KsImageMemoryIndex.shared.removeAll()
    }

    /**
     * 幅の無い到達点メモリの先読みが載せた元寸は、画素がグラフィックス側にあっても引き当てられ、
     * 表示は読み込み中を経由しない (ローダーへ要求を出さず、デコードもやり直さない)。
     */
    @Test
    fun graphicsBackedOriginalIsMatchedWithoutLoading() {
        val request = KsPrefetchRequest(sourceUrl)
        prefetchToMemory(request)
        val stored = awaitMemoryImage(request.memoryKey)
        assumeGraphicsBacked(stored)
        val startsBefore = starts.get()
        val decodesBefore = decodes.get()

        // 元寸 900 に対して枠 300 (必要な拡大率 1/3。上限 4 倍 = 0.25 の内側)。
        val prepared = prepare(MatchedFrameSide)

        assertSame("先読みが載せたグラフィックス側の元寸を引き当てませんでした", stored, prepared.matchedImage)
        assertEquals("引き当てた表示がローダーへ要求を出しました", startsBefore, starts.get())
        assertEquals("引き当てた表示がデコードをやり直しました", decodesBefore, decodes.get())
    }

    /**
     * 幅を宣言した到達点メモリの先読みは、宣言した幅の正方形を覆う大きさの項目を載せ、元寸の項目は
     * 載せない。その項目は同じ幅の枠の表示で引き当てられる。
     */
    @Test
    fun widthPrefetchStoresTheDeclaredWidth() {
        val request = KsPrefetchRequest(sourceUrl, widthPixels = FrameSide)
        prefetchToMemory(request)
        val stored = awaitMemoryImage(request.memoryKey)

        assertEquals("宣言した幅の正方形を覆う幅になっていません", FrameSide, stored.width)
        assertEquals("宣言した幅の正方形を覆う高さになっていません", FrameSide, stored.height)
        assertNull(
            "元寸の項目がメモリに載りました",
            loader.memoryCache?.get(KsImageIdentity.originalKey(sourceUrl)),
        )
        assertSame("宣言した幅の項目を引き当てませんでした", stored, prepare(FrameSide).matchedImage)
    }

    /**
     * 許容範囲の外の項目しか無いときは引き当てず、枠の実サイズへ縮小してデコードする要求に落ちる。
     * そのデコードは 1 回で済み、枠を覆う最小の大きさになる。
     */
    @Test
    fun itemOutsideTheRangeFallsBackToDownscaledDecode() {
        val request = KsPrefetchRequest(sourceUrl)
        prefetchToMemory(request)
        awaitMemoryImage(request.memoryKey)
        val decodesBefore = decodes.get()

        // 元寸 900 に対して枠 200 (必要な拡大率 0.22。上限 4 倍 = 0.25 の外側)。
        val prepared = prepare(FrameSide)
        assertNull("許容範囲の外の元寸を引き当てました", prepared.matchedImage)

        val image = runBlocking { loader.execute(prepared.request) }.image
            ?: throw AssertionError("ローダーが画像を返しませんでした")
        assertEquals("枠を覆う最小の幅になっていません", FrameSide, image.width)
        assertEquals("枠を覆う最小の高さになっていません", FrameSide, image.height)
        assertEquals("表示のためのデコードが 1 回で済んでいません", decodesBefore + 1, decodes.get())
    }

    /** 先読みなしの表示は枠の大きさでデコードし、表示の後もメモリに元寸の画像を置かない。 */
    @Test
    fun displayDoesNotKeepTheOriginalInMemory() {
        val prepared = prepare(FrameSide)
        assertNull(prepared.matchedImage)

        runBlocking { loader.execute(prepared.request) }

        val memory = requireNotNull(loader.memoryCache)
        val entries = memory.keys.filter { it.key == sourceUrl }.mapNotNull { memory[it]?.image }
        assertTrue("表示の項目がメモリに載っていません", entries.isNotEmpty())
        assertTrue(
            "表示の後に元寸の画像がメモリにあります: ${entries.map { it.width to it.height }}",
            entries.none { it.width >= SourceSide || it.height >= SourceSide },
        )
        // 次の表示は、いま載った枠の大きさの項目を引き当てる。
        assertNotNull(prepare(FrameSide).matchedImage)
    }

    private fun prepare(side: Int): KsPreparedImageRequest = requireNotNull(
        KsImageRequestFactory.prepare(
            context = context,
            source = source,
            width = side,
            height = side,
            contentMode = KsImageContentMode.Fill,
        ),
    ) { "表示の組み立てが要求を作れませんでした" }

    /** 到達点メモリで取り込む。 */
    private fun prefetchToMemory(request: KsPrefetchRequest) {
        KsCoilImageLoading(context).enqueue(request, KsPrefetchDestination.Memory)
    }

    /**
     * 先読みの画素がグラフィックス側に置かれたことを、確かめる契約ではなく前提として扱う。
     *
     * 置き場は端末とローダーの判断で、実機でもソフトウェア側になる実行がある。その実行では
     * グラフィックス側の画像での引き当てを確かめられないため、失敗ではなく skip にする。
     */
    private fun assumeGraphicsBacked(stored: Image) {
        val config = (stored as? BitmapImage)?.bitmap?.config
        assumeTrue(
            "先読みが載せた元寸の画素がグラフィックス側にありません (構成: $config)。" +
                "この実行ではグラフィックス側の画像での引き当てを確かめられません",
            config == Bitmap.Config.HARDWARE,
        )
    }

    /**
     * 先読みがメモリへ載せた画像を待って返す。
     *
     * 取得は別のスレッドで進むため、載ったこと自体を条件に待つ。制限時間を超えたら、
     * その時点で読めた内容を添えて失敗させる。
     */
    private fun awaitMemoryImage(key: MemoryCache.Key): Image {
        val memory = loader.memoryCache
            ?: throw AssertionError("共有ローダーがメモリキャッシュを持っていません")
        val deadline = SystemClock.uptimeMillis() + AwaitTimeoutMillis
        while (SystemClock.uptimeMillis() < deadline) {
            memory[key]?.image?.let { return it }
            // 取得のスレッドへ実行機会を譲る。譲らないと、この待機が CPU を占有する。
            Thread.sleep(1)
        }
        throw AssertionError(
            "先読みの項目が $AwaitTimeoutMillis ms 以内にメモリへ載りませんでした " +
                "(メモリの鍵: ${memory.keys})",
        )
    }

    /** 元寸の画像を端末内に書き出す。 */
    private fun writeSourceImage(): File {
        val bitmap = Bitmap.createBitmap(SourceSide, SourceSide, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        // 一様な塗りは圧縮で潰れて縮小の検証にならないため、模様を置く。
        val paint = Paint().apply { color = Color.BLACK }
        for (offset in 0 until SourceSide step 40) {
            canvas.drawRect(
                offset.toFloat(),
                offset.toFloat(),
                (offset + 20).toFloat(),
                SourceSide.toFloat(),
                paint,
            )
        }
        val file = File(context.cacheDir, "ks-device-decode-source.png")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        return file
    }

    private companion object {
        /** 元寸の一辺。 */
        const val SourceSide = 900

        /** 縮小デコードに落ちる表示枠・幅の宣言の一辺。元寸に対して上限 4 倍の外側になる。 */
        const val FrameSide = 200

        /** 元寸を引き当てられる表示枠の一辺。元寸に対して上限 4 倍の内側になる。 */
        const val MatchedFrameSide = 300

        /** 先読みの完了を待つ上限。 */
        const val AwaitTimeoutMillis = 10_000L
    }
}
