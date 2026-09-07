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
import coil3.Image
import coil3.SingletonImageLoader
import coil3.asImage
import coil3.memory.MemoryCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 端末のデコードが選ぶ画素の構成に依存する分岐を、実機の上で確かめる。
 *
 * 端末はデコードした画像の画素をグラフィックス側に置くことがあり、その画像は読み出せない。
 * 表示側は先読みが載せた元寸をその場で縮小するため、読み出せるかどうかで挙動が分かれる。
 * この分岐は JVM 上のテスト環境 (画素は常にソフトウェア側) では現れないため、実機で走る
 * このテストでしか検証層に載らない。
 *
 * 取得元は端末内に書き出したファイルにする。ネットワークを使うと、回線状態で結果が変わる。
 */
@RunWith(AndroidJUnit4::class)
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
     * 到達点メモリの先読みが載せる元寸は、その場で縮小できる (画素を読み出せる) 画像である。
     */
    @Test
    fun memoryPrefetchStoresPixelReadableImage() {
        prefetchToMemory()

        val stored = awaitMemoryImage()
        assertTrue(
            "先読みが載せた画像がビットマップではありません: $stored",
            stored is BitmapImage,
        )
        val config = (stored as BitmapImage).bitmap.config
        assertTrue(
            "先読みが載せた画像の画素を読み出せません (構成: $config)。" +
                "表示側はこの画像をその場で枠の大きさへ縮小するため、読み出せる構成が要ります",
            config != Bitmap.Config.HARDWARE,
        )
    }

    /**
     * 先読みが載せた元寸から、枠を超えない大きさの画像がその場で作られる。
     */
    @Test
    fun preparedImageFitsInsideFrame() {
        prefetchToMemory()
        awaitMemoryImage()

        val prepared = KsImageRequestFactory.prepare(
            context = context,
            source = KsImageSource.File(sourceFile),
            width = FrameSide,
            height = FrameSide,
            contentMode = KsImageContentMode.Fill,
        )

        assertNotNull("表示の組み立てが要求を作れませんでした", prepared)
        val image = prepared!!.cachedImage
        assertNotNull("先読みが載せた元寸から初回の描画に使う画像が作られていません", image)
        assertEquals("枠を覆う最小の幅になっていません", FrameSide, image!!.width)
        assertEquals("枠を覆う最小の高さになっていません", FrameSide, image.height)
    }

    /**
     * 画素を読み出せない元寸がメモリにあっても落ちず、枠を超えた画像も描かない。
     *
     * 利用者が同じ取得元を自分でローダーに要求すると、ライブラリの先読みを通らずに
     * 読み出せない元寸が同じ鍵へ載る。その状態でも表示の組み立てが成立することを見る。
     */
    @Test
    fun preparedImageSkipsUnreadableOriginal() {
        val hardware = decodeAsHardware()
        assertEquals(
            "この端末では画素をグラフィックス側に置くデコードが起きず、分岐を確かめられません",
            Bitmap.Config.HARDWARE,
            hardware.config,
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
