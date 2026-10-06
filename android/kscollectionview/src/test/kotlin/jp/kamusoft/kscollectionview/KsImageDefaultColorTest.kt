package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.layout.SubcomposeLayoutState
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
import coil3.decode.DataSource
import coil3.fetch.FetchResult
import coil3.fetch.Fetcher
import coil3.fetch.ImageFetchResult
import coil3.memory.MemoryCache
import coil3.request.ImageRequest
import coil3.request.Options
import kotlinx.coroutines.CompletableDeferred
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.util.concurrent.atomic.AtomicInteger

/**
 * 読み込み中・失敗の表示を差し替えていない [KsImage] の既定の表示が、表示モード (画面の構成の
 * 夜間モード) の側の色で描かれることを画素で確かめる。
 *
 * 既定の色の値は、両プラットフォームで共通の値をここに書いて固定する。表示モードの切り替えで取得を
 * 取り消したり取得し直したりしないことは、ローダーが受け付けた要求と取り消しの数で確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
// 共有インスタンスの差し替えは Coil で delicate 扱い。検証に必要なのでテスト側で受け入れる。
@OptIn(DelicateCoilApi::class)
internal class KsImageDefaultColorTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /**
     * 合図が届くまで取得を待たせる取得層。合図が true なら [ImageColor] の画像で成功し、false なら
     * 失敗する。
     */
    private class GatedFetcher(
        private val gate: CompletableDeferred<Boolean>,
        private val onFetch: () -> Unit,
    ) : Fetcher {
        override suspend fun fetch(): FetchResult {
            onFetch()
            if (!gate.await()) throw IllegalStateException("取得できません")
            val bitmap = Bitmap.createBitmap(ImageSide, ImageSide, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(ImageColor.toArgb())
            return ImageFetchResult(image = bitmap.asImage(), isSampled = false, dataSource = DataSource.NETWORK)
        }

        class Factory(
            private val gate: CompletableDeferred<Boolean>,
            private val onFetch: () -> Unit,
        ) : Fetcher.Factory<Any> {
            override fun create(data: Any, options: Options, imageLoader: ImageLoader): Fetcher =
                GatedFetcher(gate, onFetch)
        }
    }

    private lateinit var context: Context
    private lateinit var loader: ImageLoader

    // 取得を終わらせる合図。true で成功、false で失敗。
    private lateinit var gate: CompletableDeferred<Boolean>

    // 取得と要求の通知は別のスレッドから届くため、数え上げはスレッド間で見える形にする。
    private val fetches = AtomicInteger(0)
    private val loaderStarts = AtomicInteger(0)
    private val loaderCancels = AtomicInteger(0)

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        installKsAppContext(context)
        gate = CompletableDeferred()
        fetches.set(0)
        loaderStarts.set(0)
        loaderCancels.set(0)
        // release 相当にして、読めないリソースで止まらずに失敗の表示へ落ちるようにする。
        KsDiagnostics.debugOverride = false
        loader = ImageLoader.Builder(context)
            .eventListener(object : EventListener() {
                override fun onStart(request: ImageRequest) {
                    loaderStarts.incrementAndGet()
                }

                override fun onCancel(request: ImageRequest) {
                    loaderCancels.incrementAndGet()
                }
            })
            .memoryCache { MemoryCache.Builder().maxSizeBytes(4L * 1024 * 1024).build() }
            .components { add(GatedFetcher.Factory(gate) { fetches.incrementAndGet() }, Any::class) }
            .build()
        SingletonImageLoader.setUnsafe(loader)
        KsImageInvalidation.reset()
        KsImageMemoryIndex.shared.removeAll()
    }

    @After
    fun tearDown() {
        // 待たせたままの取得を残さない。
        gate.complete(false)
        loader.shutdown()
        SingletonImageLoader.reset()
        KsImageInvalidation.reset()
        KsImageMemoryIndex.shared.removeAll()
        KsDiagnostics.debugOverride = null
    }

    // ---- 値 ----

    /** 既定の表示の色の値は両プラットフォームで共通の値である。失敗の印はライトとダークで同じ値。 */
    @Test
    fun defaultColorsMatchTheSharedValues() {
        assertEquals(Color(0xFFE5E5EA), KsImageDefaults.loadingLightColor)
        assertEquals(Color(0xFF2C2C2E), KsImageDefaults.loadingDarkColor)
        assertEquals(Color(0xFFD1D1D6), KsImageDefaults.failureBackgroundLightColor)
        assertEquals(Color(0xFF3A3A3C), KsImageDefaults.failureBackgroundDarkColor)
        assertEquals(Color(0xFF8E8E93), KsImageDefaults.failureMarkLightColor)
        assertEquals(Color(0xFF8E8E93), KsImageDefaults.failureMarkDarkColor)

        assertEquals(KsImageDefaults.loadingLightColor, KsImageDefaults.loadingColor(isDarkTheme = false))
        assertEquals(KsImageDefaults.loadingDarkColor, KsImageDefaults.loadingColor(isDarkTheme = true))
        assertEquals(
            KsImageDefaults.failureBackgroundLightColor,
            KsImageDefaults.failureBackgroundColor(isDarkTheme = false),
        )
        assertEquals(
            KsImageDefaults.failureBackgroundDarkColor,
            KsImageDefaults.failureBackgroundColor(isDarkTheme = true),
        )
        assertEquals(KsImageDefaults.failureMarkLightColor, KsImageDefaults.failureMarkColor(isDarkTheme = false))
        assertEquals(KsImageDefaults.failureMarkDarkColor, KsImageDefaults.failureMarkColor(isDarkTheme = true))
    }

    // ---- 表示モードごとの既定の表示 (一覧の外に置いた KsImage) ----

    /** ライトでは、取得が終わるまで既定の読み込み中がライト用の色で描かれる。 */
    @Test
    fun lightModeDrawsTheLightDefaultLoading() {
        setImageContent { DefaultImage(remote("loading-light")) }

        awaitLoading(KsImageDefaults.loadingLightColor, "ライトの読み込み中")
    }

    /** ダークでは、取得が終わるまで既定の読み込み中がダーク用の色で描かれる。 */
    @Test
    fun darkModeDrawsTheDarkDefaultLoading() {
        RuntimeEnvironment.setQualifiers("+night")
        setImageContent { DefaultImage(remote("loading-dark")) }

        awaitLoading(KsImageDefaults.loadingDarkColor, "ダークの読み込み中")
    }

    /** ライトでは、既定の失敗の表示の下地と印がライト用の色で描かれる。 */
    @Test
    fun lightModeDrawsTheLightDefaultFailure() {
        gate.complete(false)
        setImageContent { DefaultImage(remote("failure-light")) }

        awaitFailure(
            background = KsImageDefaults.failureBackgroundLightColor,
            mark = KsImageDefaults.failureMarkLightColor,
            situation = "ライトの失敗",
        )
    }

    /** ダークでは、既定の失敗の表示の下地と印がダーク用の色で描かれる。 */
    @Test
    fun darkModeDrawsTheDarkDefaultFailure() {
        RuntimeEnvironment.setQualifiers("+night")
        gate.complete(false)
        setImageContent { DefaultImage(remote("failure-dark")) }

        awaitFailure(
            background = KsImageDefaults.failureBackgroundDarkColor,
            mark = KsImageDefaults.failureMarkDarkColor,
            situation = "ダークの失敗",
        )
    }

    /** 端末がライトのまま、KsImage に届く画面の構成の夜間モードだけをダークにすると、ダーク用の色で描かれる。 */
    @Test
    fun overriddenConfigurationNightModeIsUsed() {
        setImageContent {
            TestNightModeOverride(isNight = true) { DefaultImage(remote("override")) }
        }

        awaitLoading(KsImageDefaults.loadingDarkColor, "画面の構成だけをダークに上書き")
    }

    /** 同梱リソースを読めないときの既定の失敗の表示も、ダークではダーク用の色で描かれる。 */
    @Test
    fun unreadableResourceDrawsTheDarkDefaultFailure() {
        RuntimeEnvironment.setQualifiers("+night")
        setImageContent { DefaultImage(KsImageSource.Resource(0)) }

        awaitFailure(
            background = KsImageDefaults.failureBackgroundDarkColor,
            mark = KsImageDefaults.failureMarkDarkColor,
            situation = "読めないリソースの失敗",
        )
    }

    // ---- 表示中の切り替え ----

    /** 既定の読み込み中を出したまま表示モードを切り替えると、色が追随し、読み込み中のままである。 */
    @Test
    fun defaultLoadingFollowsTheDisplayModeWhileShown() {
        var isNight by mutableStateOf(false)
        setImageContent {
            TestNightModeOverride(isNight) { DefaultImage(remote("loading-switch")) }
        }
        awaitLoading(KsImageDefaults.loadingLightColor, "切り替える前のライト")

        composeTestRule.runOnIdle { isNight = true }
        awaitLoading(KsImageDefaults.loadingDarkColor, "ダークへ切り替えた後")

        composeTestRule.runOnIdle { isNight = false }
        awaitLoading(KsImageDefaults.loadingLightColor, "ライトへ戻した後")
    }

    /** 既定の失敗の表示を出したまま表示モードを切り替えると、色が追随し、失敗のままで再試行もしない。 */
    @Test
    fun defaultFailureFollowsTheDisplayModeWhileShown() {
        var isNight by mutableStateOf(false)
        gate.complete(false)
        setImageContent {
            TestNightModeOverride(isNight) { DefaultImage(remote("failure-switch")) }
        }
        awaitFailure(
            background = KsImageDefaults.failureBackgroundLightColor,
            mark = KsImageDefaults.failureMarkLightColor,
            situation = "切り替える前のライト",
        )

        composeTestRule.runOnIdle { isNight = true }
        awaitFailure(
            background = KsImageDefaults.failureBackgroundDarkColor,
            mark = KsImageDefaults.failureMarkDarkColor,
            situation = "ダークへ切り替えた後",
        )

        composeTestRule.runOnIdle { isNight = false }
        awaitFailure(
            background = KsImageDefaults.failureBackgroundLightColor,
            mark = KsImageDefaults.failureMarkLightColor,
            situation = "ライトへ戻した後",
        )
        assertEquals("表示モードの切り替えで取得し直しました", 1, loaderStarts.get())
    }

    // ---- 取得の途中の切り替え ----

    /**
     * 読み込みを始めてから出た既定の読み込み中の間に表示モードを切り替えても、取得は取り消されず、
     * 新しい取得も始まらない。取得が終わると、その結果の画像が表示される。
     */
    @Test
    fun switchingTheDisplayModeKeepsTheFetchStartedOnComposition() {
        var isNight by mutableStateOf(false)
        setImageContent {
            TestNightModeOverride(isNight) { DefaultImage(remote("fetch-requested")) }
        }
        awaitLoading(KsImageDefaults.loadingLightColor, "切り替える前のライト")

        assertTheFetchSurvivesTheSwitch(switchToNight = { isNight = true })
    }

    /**
     * 先読みの完了を待つ間に出た既定の読み込み中 (画面に出た時点で要求を出す経路) でも、表示モードを
     * 切り替えて取得は取り消されず、新しい取得も始まらない。取得が終わると、その結果の画像が表示される。
     */
    @Test
    fun switchingTheDisplayModeKeepsTheFetchStartedWhenShown() {
        val isNight = mutableStateOf(false)
        val source = remote("fetch-deferred")
        registerPendingPrefetch(source)
        val shown = precomposeThenShow(isNight) { DefaultImage(source) }
        assertEquals("画面に出る前に要求を出しました", 0, loaderStarts.get())

        composeTestRule.runOnIdle { shown.value = true }
        awaitLoading(KsImageDefaults.loadingLightColor, "切り替える前のライト")

        assertTheFetchSurvivesTheSwitch(switchToNight = { isNight.value = true })
    }

    // ---- 差し替えた表示 ----

    /** 読み込み中を差し替えた KsImage は、ライトでもダークでも利用者の表示のまま出る。 */
    @Test
    fun substitutedLoadingIsDrawnAsIsInBothDisplayModes() {
        var isNight by mutableStateOf(false)
        setImageContent {
            TestNightModeOverride(isNight) { SubstitutedImage(remote("slot-loading")) }
        }
        awaitCondition("取得が始まらない") { fetches.get() >= 1 }
        awaitCenter(LoadingSlotColor, "ライトの利用者の読み込み中")

        composeTestRule.runOnIdle { isNight = true }
        composeTestRule.waitForIdle()
        assertEquals("ダークの利用者の読み込み中", LoadingSlotColor.hex(), imagePixels()[Center, Center].hex())
    }

    /** 失敗を差し替えた KsImage は、ライトでもダークでも利用者の表示のまま出る。 */
    @Test
    fun substitutedFailureIsDrawnAsIsInBothDisplayModes() {
        var isNight by mutableStateOf(false)
        gate.complete(false)
        setImageContent {
            TestNightModeOverride(isNight) { SubstitutedImage(remote("slot-failure")) }
        }
        awaitCenter(FailureSlotColor, "ライトの利用者の失敗の表示")
        assertEquals("利用者の失敗の表示の隅", FailureSlotColor.hex(), imagePixels()[Corner, Corner].hex())

        composeTestRule.runOnIdle { isNight = true }
        composeTestRule.waitForIdle()
        val image = imagePixels()
        assertEquals("ダークの利用者の失敗の表示", FailureSlotColor.hex(), image[Center, Center].hex())
        assertEquals("ダークの利用者の失敗の表示の隅", FailureSlotColor.hex(), image[Corner, Corner].hex())
    }

    // ---- 一覧の中 ----

    /** 一覧の項目の中に置いた KsImage も、ダークでは既定の読み込み中がダーク用の色で描かれる。 */
    @Test
    fun imageInsideACollectionDrawsTheDarkDefaultLoading() {
        RuntimeEnvironment.setQualifiers("+night")
        val source = remote("in-collection")
        composeTestRule.setContent {
            TestContainer(width = 300.dp, height = 600.dp) {
                KsCollectionView(items = testItems(1), key = { it.id }, listSeparators = false) {
                    template { DefaultImage(source) }
                }
            }
        }

        awaitLoading(KsImageDefaults.loadingDarkColor, "一覧の中の読み込み中")
    }

    // ---- 補助 ----

    private fun remote(name: String) = KsImageSource.Remote("https://example.com/default-color-$name.jpg")

    private fun setImageContent(content: @Composable () -> Unit) {
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp).background(PageColor)) { content() }
        }
    }

    /** 読み込み中・失敗の表示を差し替えていない画像。 */
    @Composable
    private fun DefaultImage(source: KsImageSource) {
        KsImage(source = source, modifier = Modifier.size(ImageDp).testTag(ImageTag))
    }

    /** 読み込み中・失敗の表示を利用者の表示 (無地) に差し替えた画像。 */
    @Composable
    private fun SubstitutedImage(source: KsImageSource) {
        KsImage(
            source = source,
            modifier = Modifier.size(ImageDp).testTag(ImageTag),
            loading = { Box(Modifier.fillMaxSize().background(LoadingSlotColor)) },
            failure = { Box(Modifier.fillMaxSize().background(FailureSlotColor)) },
        )
    }

    /**
     * 取得を待たせて既定の読み込み中を出している状態から、表示モードをダークへ切り替え、取得の要求と
     * 取り消しの数が変わらないこと、取得を終わらせるとその結果の画像が出ることを確かめる。
     */
    private fun assertTheFetchSurvivesTheSwitch(switchToNight: () -> Unit) {
        awaitCondition("取得が始まらない") { fetches.get() >= 1 }
        assertEquals("切り替える前の要求の数", 1, loaderStarts.get())

        composeTestRule.runOnIdle(switchToNight)
        awaitLoading(KsImageDefaults.loadingDarkColor, "ダークへ切り替えた後")
        assertEquals("表示モードの切り替えで新しい要求を出しました", 1, loaderStarts.get())
        assertEquals("表示モードの切り替えで取得を取り消しました", 0, loaderCancels.get())

        gate.complete(true)
        awaitCenter(ImageColor, "取得の結果の画像")
        assertEquals("取得の完了までに新しい要求を出しました", 1, loaderStarts.get())
        assertEquals("取得が 1 度で済んでいません", 1, fetches.get())
        assertEquals("取得の完了までに取り消しがありました", 0, loaderCancels.get())
    }

    /** 識別子の先読みの要求を索引に覚えさせ、項目はまだメモリに無く取得中の状態 (先読みが未完了) にする。 */
    private fun registerPendingPrefetch(source: KsImageSource) {
        val identifier = requireNotNull(source.identifier)
        val key = KsImageIdentity.sizedKey(identifier, coil3.size.Size(ImageSide, ImageSide))
        KsImageMemoryIndex.shared.register(key)
        KsImageMemoryIndex.shared.beginFetch(key)
    }

    /**
     * 遅延グリッドの先行合成と同じ形で [content] を画面外に組み立てて測り、返した値を true にすると
     * 同じ組み立てを画面に置く。画面の構成の夜間モードは [isNight] で外側から差し替える。
     */
    private fun precomposeThenShow(
        isNight: MutableState<Boolean>,
        content: @Composable () -> Unit,
    ): MutableState<Boolean> {
        val state = SubcomposeLayoutState()
        val shown = mutableStateOf(false)
        setImageContent {
            TestNightModeOverride(isNight.value) {
                SubcomposeLayout(state) { constraints ->
                    if (!shown.value) return@SubcomposeLayout layout(0, 0) {}
                    val placeables = subcompose(PrecomposedSlot, content).map { it.measure(constraints) }
                    layout(constraints.maxWidth, constraints.maxHeight) {
                        placeables.forEach { it.place(0, 0) }
                    }
                }
            }
        }
        composeTestRule.runOnIdle {
            val handle = state.precompose(PrecomposedSlot, content)
            handle.premeasure(0, Constraints(maxWidth = 300, maxHeight = 600))
        }
        composeTestRule.waitForIdle()
        return shown
    }

    private fun imagePixels(): PixelMap = composeTestRule.onNodeWithTag(ImageTag).capturePixels()

    /** 既定の読み込み中 (枠全体の無地) が [expected] で描かれるまで待つ。 */
    private fun awaitLoading(expected: Color, situation: String) {
        awaitCenter(expected, situation)
        assertEquals("$situation: 枠の隅", expected.hex(), imagePixels()[Corner, Corner].hex())
    }

    /** 既定の失敗の表示が、下地 [background]・印 [mark] で描かれるまで待つ。 */
    private fun awaitFailure(background: Color, mark: Color, situation: String) {
        awaitPixel("$situation: 下地", background) { it[Corner, Corner] }
        val image = imagePixels()
        // 印は枠の中央に置いた、短辺の 30% の四角の線と、その内側の左上寄りの丸である。
        assertEquals("$situation: 印の四角の線", mark.hex(), image[MarkStrokeX, Center].hex())
        assertEquals("$situation: 印の丸", mark.hex(), image[MarkDot, MarkDot].hex())
        assertEquals("$situation: 印の四角の内側は下地", background.hex(), image[Center, Center].hex())
    }

    private fun awaitCenter(expected: Color, situation: String) {
        awaitPixel(situation, expected) { it[Center, Center] }
    }

    /** 画像の枠から読んだ画素が [expected] になるまで待つ。 */
    private fun awaitPixel(situation: String, expected: Color, read: (PixelMap) -> Color) {
        var observed = Color.Unspecified
        awaitCondition("$situation: ${expected.hex()} で描かれない", detail = { "画素=${observed.hex()}" }) {
            observed = read(imagePixels())
            observed == expected
        }
    }

    /**
     * 条件が満たされるまで実時間の上限つきで待つ。待つ間はコンポジションと副作用に実行機会を譲り、
     * 期限を過ぎたら実測値を添えて失敗させる。
     */
    private fun awaitCondition(
        description: String,
        detail: (() -> String)? = null,
        condition: () -> Boolean,
    ) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (!condition()) {
            if (System.nanoTime() > deadline) {
                val counts = "fetch=${fetches.get()}, start=${loaderStarts.get()}, cancel=${loaderCancels.get()}"
                fail("$description (実測: ${listOfNotNull(counts, detail?.invoke()).joinToString(", ")})")
            }
            composeTestRule.waitForIdle()
            Thread.sleep(1)
        }
    }

    private companion object {
        const val ImageTag = "image"
        const val PrecomposedSlot = "precomposed"

        /** 画像の枠の一辺。画面の密度は 1 なので、dp と画素が一致する。 */
        const val ImageSide = 100
        val ImageDp = ImageSide.dp

        /** 枠の中央と隅。 */
        const val Center = ImageSide / 2
        const val Corner = 5

        /** 失敗の印の四角の左辺の線の上 (四角は 35〜65、線の太さは 3)。 */
        const val MarkStrokeX = 35

        /** 失敗の印の丸の中 (中心は 44.6、半径は 3.6)。 */
        const val MarkDot = 44

        /** 画面の下地。既定の色・利用者の表示・画像のどれとも違う色にする。 */
        val PageColor = Color(0xFF0B1F3A)
        val LoadingSlotColor = Color(0xFFE23A2E)
        val FailureSlotColor = Color(0xFF7A3FB5)
        val ImageColor = Color(0xFF2EA043)
    }
}
