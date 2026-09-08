package jp.kamusoft.kscollectionview

import android.graphics.Bitmap
import android.graphics.BitmapFactory
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
import coil3.asImage
import coil3.decode.Decoder
import coil3.memory.MemoryCache
import coil3.request.ImageRequest
import coil3.request.Options
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * 端末のデコードが選ぶ画素の構成に依存する分岐を、実機の上で確かめる。
 *
 * 実機のデコードは通常、画像の画素をグラフィックス側に置くため、到達点メモリの先読みが載せる
 * 元寸は読み出せない。表示側はその元寸をその場で縮小できないので、初回の描画には使わずローダーの
 * 縮小デコードを待つ。確かめるのはこの契約 — 落ちないこと、表示に使う画像が枠を超えないこと、
 * そのデコードが 1 回で済むこと。
 *
 * この分岐は JVM 上のテスト環境 (画素は常にソフトウェア側) では現れず、そちらでは元寸を
 * その場で縮小して即座に描く経路が通る。実機で走るこのテストでしか検証層に載らない。
 *
 * 画素がグラフィックス側に置かれるかどうかは端末とローダーの判断であり、実機でも常には
 * 成立しない (ローダーは端末の資源が逼迫すると自ら止める)。そのため構成の確認は契約の
 * アサーションではなく前提 ([org.junit.Assume]) として書く。満たさない端末では、確かめたい
 * 経路を踏めないことがレポートに skip として残る。
 *
 * 取得元は端末内に書き出したファイルにする。ネットワークを使うと、回線状態で結果が変わる。
 */
@RunWith(AndroidJUnit4::class)
// 共有インスタンスの差し替えは Coil で delicate 扱い。デコード回数を数えるために受け入れる。
@OptIn(DelicateCoilApi::class)
internal class KsImageDeviceDecodeTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    /** 枠より十分大きい元寸の画像。縮小が必ず走る大きさにする。 */
    private lateinit var sourceFile: File

    @Before
    fun setUp() {
        sourceFile = writeSourceImage()
        SingletonImageLoader.get(context).memoryCache?.clear()
    }

    /**
     * 到達点メモリの先読みは落ちずに元寸をメモリへ載せ、その画素はグラフィックス側に置かれる。
     *
     * 以降の 3 件が確かめる「読み出せない元寸を初回の描画に使わない」経路が、この実行機で
     * 実際に通ることの土台になる。ソフトウェア側に置かれた実行では、その経路は踏まれない。
     */
    @Test
    fun memoryPrefetchStoresGraphicsBackedImage() {
        prefetchToMemory()

        val stored = awaitMemoryImage()
        assertTrue(
            "先読みが載せた画像がビットマップではありません: $stored",
            stored is BitmapImage,
        )
        assumeGraphicsBacked(stored)
    }

    /**
     * 到達点メモリの先読みの後で表示を組み立てても落ちず、表示に使う画像は枠を超えない。
     *
     * 先読みが載せた元寸は読み出せないため初回の描画には使わない。表示はローダーの縮小
     * デコードを待ち、そこで枠の大きさに収まった画像が出る。
     */
    @Test
    fun preparedRequestDecodesInsideFrameAfterMemoryPrefetch() {
        prefetchToMemory()
        assumeGraphicsBacked(awaitMemoryImage())

        val prepared = KsImageRequestFactory.prepare(
            context = context,
            source = KsImageSource.File(sourceFile),
            width = FrameSide,
            height = FrameSide,
            contentMode = KsImageContentMode.Fill,
        )

        assertNotNull("表示の組み立てが要求を作れませんでした", prepared)
        assertNull(
            "読み出せない元寸を初回の描画に使っています (枠を超えた大きさで描かれます)",
            prepared!!.cachedImage,
        )

        val decoded = runBlocking { SingletonImageLoader.get(context).execute(prepared.request) }
        val image = decoded.image
            ?: throw AssertionError("ローダーが画像を返しませんでした: $decoded")
        assertEquals("枠を覆う最小の幅になっていません", FrameSide, image.width)
        assertEquals("枠を覆う最小の高さになっていません", FrameSide, image.height)
    }

    /**
     * 読み出せない元寸がメモリにあっても落ちず、枠を超えた画像も描かない。
     *
     * 先読み以外の経路 — 利用者が同じ取得元を自分でローダーに要求した場合 — でも、
     * 読み出せない元寸は同じ鍵へ載る。構成を直に指定して、その状態を作って確かめる。
     */
    @Test
    fun preparedImageSkipsUnreadableOriginal() {
        val hardware = decodeAsHardware()
        // 構成の指定は要求であって保証ではないため、前提として扱う。
        assumeTrue(
            "この実行機では画素をグラフィックス側に置くデコードが起きず、分岐を確かめられません " +
                "(構成: ${hardware.config})",
            hardware.config == Bitmap.Config.HARDWARE,
        )

        val cacheKey = KsImageSource.File(sourceFile).cacheKey!!
        SingletonImageLoader.get(context).memoryCache!!
            .set(MemoryCache.Key(cacheKey), MemoryCache.Value(hardware.asImage()))

        val prepared = KsImageRequestFactory.prepare(
            context = context,
            source = KsImageSource.File(sourceFile),
            width = FrameSide,
            height = FrameSide,
            contentMode = KsImageContentMode.Fill,
        )

        assertNotNull("表示の組み立てが要求を作れませんでした", prepared)
        assertNull(
            "縮小できない元寸を初回の描画に使っています (枠を超えた大きさで描かれます)",
            prepared!!.cachedImage,
        )
    }

    /**
     * 読み出せない元寸がメモリにある場合、表示はローダーのデコード 1 回で枠に収まる画像を得る。
     *
     * 表示側は元寸をその場で縮小できないため初回の描画には使わず (読み込み中の表示を経由し)、
     * ローダーの縮小デコードを待つ。その待ちがちょうど 1 回で済むことをここで固定する。
     * 元寸のデコードと合わせると、到達点メモリの初回表示は実機で 2 回デコードすることになる。
     *
     * 数え上げのため共有インスタンスを観測付きのローダーに差し替えるが、要求を出す経路は
     * 本番のまま ([KsCoilImageLoading] と [KsImageRequestFactory]) にする。
     */
    @Test
    fun displayAfterMemoryPrefetchDecodesOnceInLoader() {
        val decodes = AtomicInteger(0)
        val observed = ImageLoader.Builder(context)
            .eventListener(object : EventListener() {
                override fun decodeStart(
                    request: ImageRequest,
                    decoder: Decoder,
                    options: Options,
                ) {
                    decodes.incrementAndGet()
                }
            })
            .build()
        SingletonImageLoader.setUnsafe(observed)
        try {
            prefetchToMemory()
            assumeGraphicsBacked(awaitMemoryImage())
            val afterPrefetch = decodes.get()

            val prepared = KsImageRequestFactory.prepare(
                context = context,
                source = KsImageSource.File(sourceFile),
                width = FrameSide,
                height = FrameSide,
                contentMode = KsImageContentMode.Fill,
            )
            assertNotNull("表示の組み立てが要求を作れませんでした", prepared)
            assertNull(
                "読み出せない元寸を初回の描画に使っています (読み込み中を経由しません)",
                prepared!!.cachedImage,
            )

            val decoded = runBlocking { observed.execute(prepared.request) }
            val image = decoded.image
                ?: throw AssertionError("ローダーが画像を返しませんでした: $decoded")
            assertEquals("枠を覆う最小の幅になっていません", FrameSide, image.width)
            assertEquals(
                "表示のためのデコードが 1 回で済んでいません",
                afterPrefetch + 1,
                decodes.get(),
            )
        } finally {
            SingletonImageLoader.reset()
            observed.shutdown()
        }
    }

    /**
     * 元寸の画素がグラフィックス側に置かれたことを、確かめる契約ではなく前提として扱う。
     *
     * 置き場は端末とローダーの判断で、実機でもソフトウェア側になる実行がある。その実行では
     * 読み出せない元寸の経路を踏めないため、失敗ではなく skip にする。
     */
    private fun assumeGraphicsBacked(stored: Image) {
        val config = (stored as? BitmapImage)?.bitmap?.config
        assumeTrue(
            "先読みが載せた元寸の画素がグラフィックス側にありません (構成: $config)。" +
                "この実行では読み出せない元寸の経路を確かめられません",
            config == Bitmap.Config.HARDWARE,
        )
    }

    /** 到達点メモリで元寸を取り込む。 */
    private fun prefetchToMemory() {
        KsCoilImageLoading(context).enqueue(
            url = KsImageSource.File(sourceFile).cacheKey!!,
            destination = KsPrefetchDestination.Memory,
        )
    }

    /**
     * 先読みがメモリへ載せた元寸を待って返す。
     *
     * 取得は別のスレッドで進むため、載ったこと自体を条件に待つ。制限時間を超えたら、
     * その時点で読めた内容を添えて失敗させる。
     */
    private fun awaitMemoryImage(): Image {
        val memory = SingletonImageLoader.get(context).memoryCache
            ?: throw AssertionError("共有ローダーがメモリキャッシュを持っていません")
        val key = MemoryCache.Key(KsImageSource.File(sourceFile).cacheKey!!)
        val deadline = SystemClock.uptimeMillis() + AwaitTimeoutMillis
        while (SystemClock.uptimeMillis() < deadline) {
            memory.get(key)?.image?.let { return it }
            // 取得のスレッドへ実行機会を譲る。譲らないと、この待機が CPU を占有する。
            Thread.sleep(1)
        }
        throw AssertionError(
            "先読みの元寸が $AwaitTimeoutMillis ms 以内にメモリへ載りませんでした " +
                "(メモリの項目数: ${memory.keys.size})",
        )
    }

    /** 端末のデコードに画素をグラフィックス側へ置かせる。 */
    private fun decodeAsHardware(): Bitmap {
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.HARDWARE
        }
        return BitmapFactory.decodeFile(sourceFile.absolutePath, options)
            ?: throw AssertionError("元寸の画像を読み込めませんでした: ${sourceFile.absolutePath}")
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
        /** 元寸の一辺。枠より十分大きくして縮小を必ず走らせる。 */
        const val SourceSide = 900

        /** 表示枠の一辺。 */
        const val FrameSide = 200

        /** 先読みの完了を待つ上限。 */
        const val AwaitTimeoutMillis = 10_000L
    }
}
