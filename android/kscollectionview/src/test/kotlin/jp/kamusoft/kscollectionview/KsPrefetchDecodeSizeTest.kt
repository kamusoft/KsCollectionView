package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.DelicateCoilApi
import coil3.annotation.ExperimentalCoilApi
import coil3.memory.MemoryCache
import coil3.network.ConnectivityChecker
import coil3.network.NetworkClient
import coil3.network.NetworkFetcher
import coil3.network.NetworkRequest
import coil3.network.NetworkResponse
import coil3.network.NetworkResponseBody
import okio.Buffer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.ByteArrayOutputStream

/**
 * 到達点 memory の先読みがメモリへ載せる画像の寸法を、ローダー本来のデコードで確かめる。
 *
 * 幅の宣言が「幅の正方形を覆う最小の大きさ (元が小さければ拡大しない)」になるかは、ローダーの
 * 縮小の指定 (寸法の一致を求めない指定) の解釈に依存するため、実際の画像データをデコードして見る。
 * 実デコードを動かすため描画は実 Skia (NATIVE) にする。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalCoilApi::class, DelicateCoilApi::class)
internal class KsPrefetchDecodeSizeTest {

    /** URL の末尾の「幅x高さ」の大きさの PNG を返すネットワーク層。 */
    private class SizedImageClient : NetworkClient {
        override suspend fun <T> executeRequest(
            request: NetworkRequest,
            block: suspend (NetworkResponse) -> T,
        ): T {
            val (width, height) = request.url.substringAfterLast('/').substringBefore('.')
                .split('x').map { it.toInt() }
            val body = NetworkResponseBody(Buffer().write(png(width, height)))
            return body.use { block(NetworkResponse(body = it)) }
        }

        private fun png(width: Int, height: Int): ByteArray {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(Color.GRAY)
            return ByteArrayOutputStream().use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                it.toByteArray()
            }
        }
    }

    private lateinit var context: Context
    private lateinit var loader: ImageLoader

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        loader = ImageLoader.Builder(context)
            .memoryCache { MemoryCache.Builder().maxSizeBytes(16L * 1024 * 1024).build() }
            .diskCache(null)
            .components {
                add(
                    NetworkFetcher.Factory(
                        networkClient = { SizedImageClient() },
                        connectivityChecker = { ConnectivityChecker.ONLINE },
                    ),
                )
            }
            .build()
        SingletonImageLoader.setUnsafe(loader)
        KsImageMemoryIndex.shared.removeAll()
    }

    @After
    fun tearDown() {
        loader.shutdown()
        SingletonImageLoader.reset()
        KsImageMemoryIndex.shared.removeAll()
    }

    private fun url(width: Int, height: Int): String = "https://images.example.com/${width}x$height.png"

    /** 先読みを出し、その要求が載せる項目の画像の寸法を待って返す。 */
    private fun prefetch(request: KsPrefetchRequest): Pair<Int, Int> {
        KsCoilImageLoading(context).enqueue(request, KsPrefetchDestination.Memory)
        val deadline = System.nanoTime() + 10_000_000_000L
        while (true) {
            loader.memoryCache?.get(request.memoryKey)?.image?.let { return it.width to it.height }
            if (System.nanoTime() > deadline) {
                fail("先読みの項目がメモリに載らない (鍵: ${loader.memoryCache?.keys})")
            }
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(1)
        }
    }

    /** 幅のある要素は、幅の正方形を覆う最小の大きさに縮小して載り、元の大きさの項目は載らない。 */
    @Test
    fun widthDeclarationCoversTheSquare() {
        val source = url(400, 200)

        val size = prefetch(KsPrefetchRequest(source, widthPixels = 100))

        // 高さを 100 に揃える縮小 (0.5 倍) で幅は 200 になる。
        assertEquals(200 to 100, size)
        assertTrue(
            "元の大きさの項目が載りました",
            loader.memoryCache?.keys?.none { it.key == source && it.extras.isEmpty() } == true,
        )
    }

    /** 元の大きさが宣言した幅より小さい画像は、拡大せず元の大きさのまま載る。 */
    @Test
    fun smallerOriginalIsNotUpscaled() {
        assertEquals(40 to 30, prefetch(KsPrefetchRequest(url(40, 30), widthPixels = 100)))
    }

    /** 幅の無い要素は元の大きさのまま載る。 */
    @Test
    fun declarationWithoutWidthKeepsTheOriginalSize() {
        assertEquals(400 to 200, prefetch(KsPrefetchRequest(url(400, 200))))
    }

    /** 幅あり・幅なしを混ぜた宣言は、それぞれの寸法で載る。 */
    @Test
    fun mixedDeclarationsStoreTheirOwnSizes() {
        assertEquals(150 to 150, prefetch(KsPrefetchRequest(url(600, 600), widthPixels = 150)))
        assertEquals(300 to 900, prefetch(KsPrefetchRequest(url(300, 900))))
    }
}
