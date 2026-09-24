package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.SubcomposeLayoutState
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.EventListener
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.annotation.DelicateCoilApi
import coil3.asImage
import coil3.fetch.FetchResult
import coil3.fetch.Fetcher
import coil3.memory.MemoryCache
import coil3.request.ImageRequest
import coil3.request.Options
import kotlinx.coroutines.awaitCancellation
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.util.concurrent.atomic.AtomicInteger

/**
 * 先読みが未完了のまま画面に出る前に組み立てられた [KsImage] が、画面に出た最初の描画で何を描くかを
 * 画素で確かめる。
 *
 * 画面に出る時点の引き当ての結果は、組み立て直し (次の描画) を待たずに、画面に出た同じ描画へ
 * 反映される必要がある。外れたときは利用者の読み込み中のスロットを、当たったときはスロットを描かずに
 * 引き当てた項目を描く。画面に出た描画と次の組み立ての間を捉えるため、フレームを 1 つずつ進め、
 * 組み立て直しの前の状態を View から直接描く。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
// 共有インスタンスの差し替えは Coil で delicate 扱い。検証に必要なのでテスト側で受け入れる。
@OptIn(DelicateCoilApi::class)
internal class KsImageShownFrameTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 取得を完了させない取得層。表示の要求は読み込み中のまま残る。 */
    private class HangingFetcher : Fetcher {
        override suspend fun fetch(): FetchResult? = awaitCancellation()

        class Factory : Fetcher.Factory<Any> {
            override fun create(data: Any, options: Options, imageLoader: ImageLoader): Fetcher = HangingFetcher()
        }
    }

    private lateinit var context: Context
    private lateinit var loader: ImageLoader

    // 描画を読む View。フレームを止める前に取っておく。
    private lateinit var rootView: android.view.View

    // [KsImage] が画面に置かれたか。置かれたフレームの描画が「画面に出た最初の描画」になる。
    private val placed = java.util.concurrent.atomic.AtomicBoolean(false)

    // ローダーが受け付けた要求の数。
    private val loaderStarts = AtomicInteger(0)

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        installKsAppContext(context)
        loaderStarts.set(0)
        loader = ImageLoader.Builder(context)
            .eventListener(object : EventListener() {
                override fun onStart(request: ImageRequest) {
                    loaderStarts.incrementAndGet()
                }
            })
            .memoryCache { MemoryCache.Builder().maxSizeBytes(4L * 1024 * 1024).build() }
            .components { add(HangingFetcher.Factory(), Any::class) }
            .build()
        SingletonImageLoader.setUnsafe(loader)
        KsImageInvalidation.reset()
        KsImageMemoryIndex.shared.removeAll()
    }

    @After
    fun tearDown() {
        composeTestRule.mainClock.autoAdvance = true
        loader.shutdown()
        SingletonImageLoader.reset()
        KsImageInvalidation.reset()
        KsImageMemoryIndex.shared.removeAll()
    }

    /** 画面に出る時点の引き当てが外れたら、画面に出た最初の描画から利用者の読み込み中のスロットを描く。 */
    @Test
    fun loadingSlotIsDrawnInTheFirstFrameWhenTheShownLookupMisses() {
        val source = KsImageSource.Remote("https://example.com/shown-miss.jpg")
        registerPendingPrefetch(source)
        val slotDraws = AtomicInteger(0)
        val shown = precomposeThenShow(source, slotDraws)
        assertEquals("画面に出る前に要求を出しました", 0, loaderStarts.get())

        val firstFrame = showOneFrame(shown)

        assertEquals("画面に出た最初の描画で読み込み中のスロットを描いていません", SlotColor.toArgb(), firstFrame)
        assertEquals("画面に出た時点で要求を出していません", 1, loaderStarts.get())
    }

    /** 読み込み中の表示を指定していなければ、引き当てが外れた最初の描画から既定の読み込み中を描く。 */
    @Test
    fun defaultLoadingIsDrawnInTheFirstFrameWhenTheShownLookupMisses() {
        val source = KsImageSource.Remote("https://example.com/shown-miss-default.jpg")
        registerPendingPrefetch(source)
        val shown = precomposeThenShow(source, slotDraws = null)

        val firstFrame = showOneFrame(shown)

        assertEquals("画面に出た最初の描画で既定の読み込み中を描いていません", KsImageDefaultLoadingColor.toArgb(), firstFrame)
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()
        assertEquals("組み立て直しの後に既定の読み込み中を描いていません", KsImageDefaultLoadingColor.toArgb(), drawCenterPixel())
    }

    /** 読み込み中の表示を指定していなくても、引き当てが当たれば最初の描画からその項目を描く。 */
    @Test
    fun defaultLoadingIsNotDrawnWhenTheShownLookupMatches() {
        val source = KsImageSource.Remote("https://example.com/shown-match-default.jpg")
        val key = registerPendingPrefetch(source)
        val shown = precomposeThenShow(source, slotDraws = null)
        val bitmap = Bitmap.createBitmap(Side, Side, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(ImageColor.toArgb())
        requireNotNull(loader.memoryCache)[key] = MemoryCache.Value(bitmap.asImage())

        val firstFrame = showOneFrame(shown)

        assertEquals("画面に出た最初の描画で引き当てた項目を描いていません", ImageColor.toArgb(), firstFrame)
        assertEquals("引き当てられる項目があるのに要求を出しました", 0, loaderStarts.get())
    }

    /** 画面に出る時点の引き当てが当たったら、読み込み中のスロットを描かずに、最初の描画からその項目を描く。 */
    @Test
    fun loadingSlotIsNotDrawnWhenTheShownLookupMatches() {
        val source = KsImageSource.Remote("https://example.com/shown-match.jpg")
        val key = registerPendingPrefetch(source)
        val slotDraws = AtomicInteger(0)
        val shown = precomposeThenShow(source, slotDraws)

        // 画面に出る前に先読みが完了した状態にする。
        val bitmap = Bitmap.createBitmap(Side, Side, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(ImageColor.toArgb())
        requireNotNull(loader.memoryCache)[key] = MemoryCache.Value(bitmap.asImage())

        val firstFrame = showOneFrame(shown)
        assertEquals("画面に出た最初の描画で引き当てた項目を描いていません", ImageColor.toArgb(), firstFrame)

        // 組み立て直しの後も、読み込み中のスロットは描かれず要求も出ない。
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()
        assertEquals("組み立て直しの後に引き当てた項目を描いていません", ImageColor.toArgb(), drawCenterPixel())
        assertEquals("読み込み中のスロットを描きました", 0, slotDraws.get())
        assertEquals("引き当てられる項目があるのに要求を出しました", 0, loaderStarts.get())
    }

    /** 識別子の先読みの要求を索引に覚えさせ、項目はまだメモリに無く取得中の状態にする。 */
    private fun registerPendingPrefetch(source: KsImageSource): MemoryCache.Key {
        val identifier = requireNotNull(source.identifier)
        val key = KsImageIdentity.sizedKey(identifier, coil3.size.Size(Side, Side))
        KsImageMemoryIndex.shared.register(key)
        KsImageMemoryIndex.shared.beginFetch(key)
        return key
    }

    /**
     * 遅延グリッドの先行合成と同じ形で [KsImage] を画面外に組み立てて測る。返した値を true にすると
     * 同じ組み立てを画面に置く。背景は読み込み中のスロットとも画像とも違う色にし、何も描かない描画を
     * 見分けられるようにする。
     */
    private fun precomposeThenShow(source: KsImageSource, slotDraws: AtomicInteger?): MutableState<Boolean> {
        val state = SubcomposeLayoutState()
        val shown = mutableStateOf(false)
        // [slotDraws] が null なら読み込み中の表示を指定せず、既定の表示にする。
        val loading: (@Composable () -> Unit)? = slotDraws?.let { draws ->
            {
                Box(
                    Modifier
                        .fillMaxSize()
                        .drawBehind { draws.incrementAndGet() }
                        .background(SlotColor),
                )
            }
        }
        val content: @Composable () -> Unit = {
            KsImage(
                source = source,
                modifier = Modifier.size(ImageDp).onPlaced { placed.set(true) },
                loading = loading,
            )
        }
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp).background(PageColor).testTag("page")) {
                SubcomposeLayout(state) { constraints ->
                    if (!shown.value) return@SubcomposeLayout layout(0, 0) {}
                    val placeables = subcompose(Slot, content).map { it.measure(constraints) }
                    layout(constraints.maxWidth, constraints.maxHeight) {
                        placeables.forEach { it.place(0, 0) }
                    }
                }
            }
        }
        composeTestRule.runOnIdle {
            val handle = state.precompose(Slot, content)
            handle.premeasure(0, Constraints(maxWidth = 300, maxHeight = 600))
        }
        composeTestRule.waitForIdle()
        rootView = rootViewOf()
        return shown
    }

    @OptIn(androidx.compose.ui.InternalComposeUiApi::class)
    private fun rootViewOf(): android.view.View =
        (composeTestRule.onNodeWithTag("page").fetchSemanticsNode().root as ViewRootForTest).view

    /**
     * 自動でフレームを進めない状態で画面に出し、フレームを 1 つずつ進めては描いて、[KsImage] が初めて
     * 置かれた描画の枠の中心の色を返す。
     *
     * 配置は View を描くときの測定・配置で走るので、描いた時点で初めて置かれたなら、その描画が画面に
     * 出た最初の描画になる。画面に出る時点の引き当ての結果による組み立て直しは、その後のフレームまで
     * 起きない。
     */
    private fun showOneFrame(shown: MutableState<Boolean>): Int {
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.runOnUiThread { shown.value = true }
        repeat(MaxFramesUntilPlaced) {
            composeTestRule.mainClock.advanceTimeByFrame()
            val pixel = drawCenterPixel()
            if (placed.get()) return pixel
        }
        fail("$MaxFramesUntilPlaced フレーム進めても画面に置かれません")
        error("到達しない")
    }

    /** View を直接描き、[KsImage] の枠の中心の色を読む。待ちを挟まない同期の描画。 */
    private fun drawCenterPixel(): Int {
        var pixel = 0
        composeTestRule.runOnUiThread {
            val view = rootView
            val whole = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(whole))
            val center = with(composeTestRule.density) { (ImageDp / 2).roundToPx() }
            pixel = whole.getPixel(center, center)
        }
        return pixel
    }

    private companion object {
        const val Slot = "shown-frame"
        const val Side = 100
        const val MaxFramesUntilPlaced = 10
        val ImageDp = 50.dp
        val PageColor = Color(0xFF0B1F3A)
        val SlotColor = Color(0xFFE23A2E)
        val ImageColor = Color(0xFF2EA043)
    }
}
