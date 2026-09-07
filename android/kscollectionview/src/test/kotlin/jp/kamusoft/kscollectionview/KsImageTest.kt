package jp.kamusoft.kscollectionview

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.ColorImage
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
import coil3.size.Precision
import coil3.size.Scale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

/** [KsImage] の経路・スロット・キャッシュ操作との関係を確かめる。 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
// 共有インスタンスの差し替えは Coil で delicate 扱い。検証に必要なのでテスト側で受け入れる。
@OptIn(DelicateCoilApi::class)
internal class KsImageTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** 取得の回数を数え、指示された結果を返す取得層。 */
    private class ScriptedFetcher(
        private val behavior: () -> Behavior,
        private val delayMillis: () -> Long,
        private val onFetch: () -> Unit,
    ) : Fetcher {
        enum class Behavior { Succeed, Fail, Hang }

        override suspend fun fetch(): FetchResult? {
            onFetch()
            // 取得の開始と完了の間に幅を作るための遅延。開始しか見ていない待機は、この幅が
            // あると収束前に戻ってしまう。
            delay(delayMillis())
            return when (behavior()) {
                Behavior.Succeed ->
                    ImageFetchResult(
                        image = ColorImage(color = 0, width = 80, height = 40),
                        isSampled = false,
                        dataSource = DataSource.MEMORY,
                    )

                Behavior.Fail -> throw IllegalStateException("取得できません")
                Behavior.Hang -> awaitCancellation()
            }
        }

        class Factory(
            private val behavior: () -> Behavior,
            private val delayMillis: () -> Long,
            private val onFetch: () -> Unit,
        ) : Fetcher.Factory<Any> {
            override fun create(data: Any, options: Options, imageLoader: ImageLoader): Fetcher =
                ScriptedFetcher(behavior, delayMillis, onFetch)
        }
    }

    private lateinit var context: Context
    private lateinit var loader: ImageLoader
    private var behavior = ScriptedFetcher.Behavior.Succeed
    private var fetchDelayMillis = 0L

    // 取得は取得用のスレッドで走るため、数え上げはスレッド間で見える形にする。
    private val fetches = AtomicInteger(0)
    private val fetchCount: Int get() = fetches.get()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        installKsAppContext(context)
        behavior = ScriptedFetcher.Behavior.Succeed
        fetchDelayMillis = 0L
        fetches.set(0)
        // 既定は release 相当。debug の停止を確かめるテストだけが個別に切り替える。
        KsDiagnostics.debugOverride = false
        ShadowLog.clear()
        loader = ImageLoader.Builder(context)
            .memoryCache { MemoryCache.Builder().maxSizeBytes(4L * 1024 * 1024).build() }
            .components {
                add(
                    ScriptedFetcher.Factory(
                        behavior = { behavior },
                        delayMillis = { fetchDelayMillis },
                        onFetch = { fetches.incrementAndGet() },
                    ),
                    Any::class,
                )
            }
            .build()
        SingletonImageLoader.setUnsafe(loader)
        KsImageInvalidation.reset()
    }

    @After
    fun tearDown() {
        loader.shutdown()
        SingletonImageLoader.reset()
        KsImageInvalidation.reset()
        KsDiagnostics.debugOverride = null
    }

    // MARK: 経路と当てはめ方

    /** ソース種別ごとにローダーへ渡す取得元が決まる。 */
    @Test
    fun loaderModelIsResolvedPerSourceKind() {
        val file = File("/tmp/local.jpg")

        assertEquals("https://example.com/1.jpg", KsImageSource.Remote("https://example.com/1.jpg").loaderModel())
        assertEquals(file, KsImageSource.File(file).loaderModel())
        assertEquals(42, KsImageSource.Resource(42).loaderModel())
    }

    /** 当てはめ方は Compose の当てはめ方へ写像される。 */
    @Test
    fun contentModeMapsToContentScale() {
        assertEquals(ContentScale.Fit, KsImageContentMode.Fit.toContentScale())
        assertEquals(ContentScale.Crop, KsImageContentMode.Fill.toContentScale())
    }

    // MARK: 縮小デコード

    /** 表示枠の大きさが決まるまでは要求を組み立てない。 */
    @Test
    fun noRequestIsBuiltBeforeTheFrameSizeIsSettled() {
        val source = KsImageSource.Remote("https://example.com/sized.jpg")

        for ((width, height) in listOf(0 to 0, 100 to 0, 0 to 100)) {
            assertNull(
                "$width x $height で要求が組み立てられました",
                KsImageRequestFactory.prepare(context, source, width, height, KsImageContentMode.Fill),
            )
        }
        assertNotNull(
            KsImageRequestFactory.prepare(context, source, 100, 100, KsImageContentMode.Fill),
        )
    }

    /**
     * 枠より大きい画像は、当てはめ方に応じた寸法へ縮小してから表示に使う。
     *
     * 到達点をメモリまでにした先読みは寸法を付けない鍵で元寸を載せるため、表示側が縮小を
     * 引き受けないと元寸のまま描かれてしまう。
     */
    @Test
    fun imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed() {
        val url = "https://example.com/large.jpg"
        val memory = requireNotNull(loader.memoryCache)
        // 先読みが載せる、寸法を付けない鍵の元寸 (1000x500) の項目。
        memory.set(
            MemoryCache.Key(url),
            MemoryCache.Value(Bitmap.createBitmap(1000, 500, Bitmap.Config.ARGB_8888).asImage()),
        )
        val source = KsImageSource.Remote(url)

        val fit = requireNotNull(
            KsImageRequestFactory.prepare(context, source, 100, 100, KsImageContentMode.Fit),
        )
        val fill = requireNotNull(
            KsImageRequestFactory.prepare(context, source, 100, 100, KsImageContentMode.Fill),
        )

        // fit は枠に収まる最大 (100x50)、fill は枠を覆う最小 (200x100)。
        val fitImage = requireNotNull(fit.cachedImage)
        val fillImage = requireNotNull(fill.cachedImage)
        assertEquals(100, fitImage.width)
        assertEquals(50, fitImage.height)
        assertEquals(200, fillImage.width)
        assertEquals(100, fillImage.height)

        // 縮小した画像は表示サイズ付きの鍵へ載り、2 回目以降の表示がそれに当たる。
        assertEquals(
            fitImage,
            KsImageRequestFactory.prepare(context, source, 100, 100, KsImageContentMode.Fit)?.cachedImage,
        )
        // 元データからデコードし直す経路でも枠を超えないよう、要求は寸法の一致を求める。
        assertEquals(Precision.EXACT, fit.request.precision)
        assertEquals(Scale.FIT, fit.request.scale)
        assertEquals(Scale.FILL, fill.request.scale)
    }

    /**
     * リモート・ファイル・リソースの 3 種がいずれも表示される。
     *
     * 画像の説明は状態によらずコンポーネントの根に付くため、説明の有無だけでは成功したことに
     * ならない。読み込み中と失敗のスロットがどちらも残っていないところまで見て成功と判定する。
     */
    @Test
    fun threeSourceKindsAreDisplayed() {
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                for ((description, source) in sourcesOfEveryKind()) {
                    KsImage(
                        source = source,
                        modifier = Modifier.size(50.dp),
                        contentDescription = description,
                        loading = { Box(Modifier.testTag("$description-loading")) },
                        failure = { Box(Modifier.testTag("$description-failure")) },
                    )
                }
            }
        }

        for ((description, _) in sourcesOfEveryKind()) {
            awaitCondition("$description の画像が表示されない") {
                composeTestRule.onAllNodesWithContentDescription(description)
                    .fetchSemanticsNodes().isNotEmpty() &&
                    composeTestRule.countNodesWithTag("$description-loading") == 0 &&
                    composeTestRule.countNodesWithTag("$description-failure") == 0
            }
        }
    }

    /** 3 種のソースの見本。同じ組を宣言と検証の両方で使う。 */
    private fun sourcesOfEveryKind(): List<Pair<String, KsImageSource>> = listOf(
        "remote" to KsImageSource.Remote("https://example.com/1.jpg"),
        "file" to KsImageSource.File(File("/tmp/local.jpg")),
        "resource" to KsImageSource.Resource(android.R.drawable.ic_menu_gallery),
    )

    // MARK: 同梱リソースの描画

    /**
     * ベクター以外の XML のリソースも表示され、アプリを止めない。
     *
     * リソース ID をそのまま描画に渡す経路が扱えるのはベクター画像と PNG / JPEG / WebP だけで、
     * 状態リストや重ね合わせのような XML は例外になる。これらも描画リソースの ID としては
     * 正当なため、止まってしまうのは受け付ける入力の範囲に反する (core/ADR-0011)。
     */
    @Test
    fun xmlDrawablesThatAreNotVectorsAreDisplayed() {
        val resources = listOf(
            "selector" to android.R.drawable.list_selector_background,
            "layered" to android.R.drawable.progress_horizontal,
        )
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                for ((description, id) in resources) {
                    KsImage(
                        source = KsImageSource.Resource(id),
                        modifier = Modifier.size(50.dp),
                        contentDescription = description,
                        failure = { Box(Modifier.testTag("$description-failure")) },
                    )
                }
            }
        }

        composeTestRule.waitForIdle()
        for ((description, _) in resources) {
            assertEquals(
                "$description のリソースが失敗の表示になりました",
                0,
                composeTestRule.countNodesWithTag("$description-failure"),
            )
            assertTrue(
                "$description のリソースが表示されていません",
                composeTestRule.onAllNodesWithContentDescription(description)
                    .fetchSemanticsNodes().isNotEmpty(),
            )
        }
    }

    /** 描画リソースとして読めない ID は、止まらずに失敗の表示と警告ログになる。 */
    @Test
    fun resourcesThatCannotBeDrawnFallBackToTheFailureSlot() {
        val resources = listOf(
            // 描画リソースではない ID。
            "text" to android.R.string.ok,
            // どのリソースも指さない ID。
            "missing" to 0,
        )
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                for ((description, id) in resources) {
                    KsImage(
                        source = KsImageSource.Resource(id),
                        modifier = Modifier.size(50.dp),
                        contentDescription = description,
                        failure = { Box(Modifier.testTag("$description-failure")) },
                    )
                }
            }
        }

        composeTestRule.waitForIdle()
        for ((description, _) in resources) {
            assertEquals(
                "$description の ID が失敗の表示になりません",
                1,
                composeTestRule.countNodesWithTag("$description-failure"),
            )
        }
        assertWarned("画像リソース", "読めないリソースを黙って捨てています")
    }

    /** 描画リソースとして読めない ID は debug ビルドでは停止する。 */
    @Test
    fun resourcesThatCannotBeDrawnStopInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            composeTestRule.setContent {
                Box(Modifier.size(300.dp, 600.dp)) {
                    KsImage(
                        source = KsImageSource.Resource(0),
                        modifier = Modifier.size(50.dp),
                    )
                }
            }
        }
    }

    // MARK: アクセシビリティ

    /** 読み込み中でも画像の説明は読み上げに残る。 */
    @Test
    fun contentDescriptionSurvivesTheLoadingState() {
        behavior = ScriptedFetcher.Behavior.Hang
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote("https://example.com/pending.jpg"),
                    modifier = Modifier.size(50.dp),
                    contentDescription = "pending",
                    loading = { Box(Modifier.testTag("loading")) },
                )
            }
        }

        awaitCondition("読み込み中の表示が現れない") {
            composeTestRule.countNodesWithTag("loading") > 0
        }
        assertTrue(
            "読み込み中に画像の説明が失われています",
            composeTestRule.onAllNodesWithContentDescription("pending")
                .fetchSemanticsNodes().isNotEmpty(),
        )
    }

    /** 失敗の表示でも画像の説明は読み上げに残る。 */
    @Test
    fun contentDescriptionSurvivesTheFailureState() {
        behavior = ScriptedFetcher.Behavior.Fail
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote("https://example.com/broken.jpg"),
                    modifier = Modifier.size(50.dp),
                    contentDescription = "broken",
                    failure = { Box(Modifier.testTag("failure")) },
                )
            }
        }

        awaitCondition("失敗の表示が現れない") {
            composeTestRule.countNodesWithTag("failure") > 0
        }
        assertTrue(
            "失敗の表示で画像の説明が失われています",
            composeTestRule.onAllNodesWithContentDescription("broken")
                .fetchSemanticsNodes().isNotEmpty(),
        )
    }

    /** 説明を与えなければ読み上げの対象にしない (飾りの画像を読み上げさせない)。 */
    @Test
    fun noSemanticsAreAddedWithoutAContentDescription() {
        behavior = ScriptedFetcher.Behavior.Hang
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote("https://example.com/decoration.jpg"),
                    modifier = Modifier.size(50.dp).testTag("decoration"),
                )
            }
        }

        awaitCondition("既定の表示で取得が始まらない") { fetchCount >= 1 }
        assertTrue(
            "説明を与えていないのに読み上げの対象になっています",
            composeTestRule.onAllNodesWithContentDescription("decoration")
                .fetchSemanticsNodes().isEmpty(),
        )
    }

    /** 便宜形は同じ URL のリモートのソースと同じ表示になる。 */
    @Test
    fun urlConvenienceFormBehavesLikeRemoteSource() {
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    url = "https://example.com/1.jpg",
                    modifier = Modifier.size(50.dp),
                    contentDescription = "convenience",
                )
            }
        }

        awaitCondition("便宜形の画像が表示されない") {
            composeTestRule.onAllNodesWithContentDescription("convenience")
                .fetchSemanticsNodes().isNotEmpty()
        }
        assertTrue("取得が走っていません", fetchCount >= 1)
    }

    // MARK: スロット

    /** 読み込み中と失敗のスロットは指定した内容に差し替わる。 */
    @Test
    fun slotsAreSubstituted() {
        behavior = ScriptedFetcher.Behavior.Hang
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote("https://example.com/slot.jpg"),
                    modifier = Modifier.size(50.dp),
                    loading = { Box(Modifier.testTag("loading")) },
                    failure = { Box(Modifier.testTag("failure")) },
                )
            }
        }

        awaitCondition("読み込み中のスロットが現れない") {
            composeTestRule.countNodesWithTag("loading") > 0
        }
        assertEquals(0, composeTestRule.countNodesWithTag("failure"))
    }

    /**
     * メモリキャッシュに画像がある表示は、読み込み中のスロットを一度も構成しない。
     *
     * 一瞬だけ挟まる読み込み中は最終状態を見るだけでは捉えられないため、スロットが構成された
     * 回数そのものを数える。
     */
    @Test
    fun loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory() {
        val url = "https://example.com/warm.jpg"
        // 先読みの到達点 memory と同じ形の要求でメモリキャッシュへ載せる。
        runBlocking { loader.execute(ImageRequest.Builder(context).data(url).build()) }
        assertNotNull(
            "前提のメモリ項目が作られていません",
            loader.memoryCache?.get(MemoryCache.Key(url)),
        )

        val loadingCompositions = AtomicInteger(0)
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote(url),
                    modifier = Modifier.size(50.dp),
                    contentDescription = "warm",
                    loading = {
                        loadingCompositions.incrementAndGet()
                        Box(Modifier.testTag("loading"))
                    },
                )
            }
        }

        awaitCondition("メモリにある画像が表示されない") {
            composeTestRule.onAllNodesWithContentDescription("warm").fetchSemanticsNodes().isNotEmpty()
        }
        assertEquals(
            "読み込み中の表示を経由しました",
            0,
            loadingCompositions.get(),
        )
    }

    /**
     * 先読みを使わずに一度表示した画像は、表示を作り直しても読み込み中のスロットを構成しない。
     *
     * [loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory] が見ているのは「先読みが載せた
     * 元寸を表示が引き当てられるか」であり、ここで見るのは「表示要求が自分で書いた鍵を、次の
     * 表示が引き当てられるか」である。発行する鍵と引き当てる鍵が食い違うと、セルの再利用や
     * 画面への再入場のたびに読み込み中を経由する (iOS ではこの継ぎ目が実際に壊れていた)。
     * iOS の `test一度表示した画像は表示を作り直しても読み込み中を経由しない` と対になる。
     */
    @Test
    fun loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt() {
        val url = "https://example.com/rebuilt.jpg"
        var recreation by mutableIntStateOf(0)
        // 作り直した後の構成だけを数える。1 回目は取得を待つので必ず読み込み中を経由する。
        val loadingCompositionsAfterRebuild = AtomicInteger(0)
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                key(recreation) {
                    KsImage(
                        source = KsImageSource.Remote(url),
                        modifier = Modifier.size(50.dp).testTag("image-$recreation"),
                        contentDescription = "rebuilt",
                        loading = {
                            if (recreation > 0) loadingCompositionsAfterRebuild.incrementAndGet()
                            Box(Modifier.testTag("loading"))
                        },
                    )
                }
            }
        }

        // 1 回目の表示が「表示用の鍵」でメモリの項目になるまで待つ。先読みは使わないので、
        // この項目を書けるのは表示要求だけである。
        awaitCondition("1 回目の表示が表示用の鍵でメモリの項目にならない", {
            "displayKeys=${displayMemoryKeys(url)}"
        }) {
            displayMemoryKeys(url) > 0
        }
        val fetchesBeforeRebuild = fetchCount

        // セルの再利用・画面への再入場に相当する作り直し。
        composeTestRule.runOnIdle { recreation += 1 }

        awaitCondition("作り直した表示が組み上がらない") {
            composeTestRule.countNodesWithTag("image-1") > 0
        }
        assertEquals(
            "読み込み中の表示を経由しました",
            0,
            loadingCompositionsAfterRebuild.get(),
        )
        assertEquals(
            "作り直した表示で取得をやり直しました",
            fetchesBeforeRebuild,
            fetchCount,
        )
    }

    /** 取得に失敗すると失敗のスロットへ切り替わる。 */
    @Test
    fun failureSlotIsShownWhenLoadingFails() {
        behavior = ScriptedFetcher.Behavior.Fail
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote("https://example.com/broken.jpg"),
                    modifier = Modifier.size(50.dp),
                    loading = { Box(Modifier.testTag("loading")) },
                    failure = { Box(Modifier.testTag("failure")) },
                )
            }
        }

        awaitCondition("失敗のスロットが現れない") {
            composeTestRule.countNodesWithTag("failure") > 0
        }
    }

    /** スロットを指定しなければ既定の表示になる (指定した内容は現れない)。 */
    @Test
    fun defaultDisplayIsUsedWithoutSlots() {
        behavior = ScriptedFetcher.Behavior.Hang
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote("https://example.com/default.jpg"),
                    modifier = Modifier.size(50.dp).testTag("image"),
                )
            }
        }

        awaitCondition("既定の表示で取得が始まらない") { fetchCount >= 1 }
        assertEquals(1, composeTestRule.countNodesWithTag("image"))
        assertEquals(0, composeTestRule.countNodesWithTag("loading"))
    }

    // MARK: 失敗後の再試行

    /** 失敗した表示は、ビューが作り直されると再び取得を試みる。 */
    @Test
    fun failedImageIsRetriedWhenTheViewIsRecreated() {
        behavior = ScriptedFetcher.Behavior.Fail
        var recreation by mutableIntStateOf(0)
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                key(recreation) {
                    KsImage(
                        source = KsImageSource.Remote("https://example.com/retry.jpg"),
                        modifier = Modifier.size(50.dp),
                    )
                }
            }
        }

        awaitCondition("1 回目の取得が走らない") { fetchCount >= 1 }

        // セルの再利用・画面への再入場に相当する作り直し。
        composeTestRule.runOnIdle { recreation += 1 }

        awaitCondition("作り直しの後に取得をやり直さない") { fetchCount >= 2 }
    }

    // MARK: キャッシュ操作

    /** 範囲消去はローダーのキャッシュ操作へ写像され、メモリのみの消去では世代が進まない。 */
    @Test
    fun clearMapsToLoaderCachesAndAdvancesGenerationExceptForMemory() {
        val memory = requireNotNull(loader.memoryCache)
        val key = MemoryCache.Key("https://example.com/clear.jpg")
        memory.set(key, MemoryCache.Value(ColorImage(color = 0, width = 10, height = 10)))
        assertNotNull(memory.get(key))

        KsImageCache.clear(KsImageCacheScope.Memory)

        assertNull("メモリの項目が残っています", memory.get(key))
        assertEquals("メモリのみ消去で世代が進みました", 0, KsImageInvalidation.globalGeneration)

        KsImageCache.clear(KsImageCacheScope.All)
        assertEquals(1, KsImageInvalidation.globalGeneration)
    }

    /** ソース単位の削除は対象のソースの項目と世代だけを動かす。 */
    @Test
    fun removeAffectsOnlyTheTargetSource() {
        val memory = requireNotNull(loader.memoryCache)
        val target = "https://example.com/a.jpg"
        val other = "https://example.com/b.jpg"
        val targetKey = MemoryCache.Key(target)
        // 表示サイズなどの付随情報を持つ鍵も同じソースの項目として扱う。
        val targetSizedKey = MemoryCache.Key(target, mapOf("coil#size" to "100x100"))
        val otherKey = MemoryCache.Key(other)
        for (key in listOf(targetKey, targetSizedKey, otherKey)) {
            memory.set(key, MemoryCache.Value(ColorImage(color = 0, width = 10, height = 10)))
        }

        KsImageCache.remove(KsImageSource.Remote(target))

        assertNull(memory.get(targetKey))
        assertNull(memory.get(targetSizedKey))
        assertNotNull("他のソースの項目まで消えました", memory.get(otherKey))
        assertEquals(1, KsImageInvalidation.generation(target))
        assertEquals(0, KsImageInvalidation.generation(other))
        assertEquals("範囲消去の世代が進みました", 0, KsImageInvalidation.globalGeneration)
    }

    /** 同梱リソースに対する削除は何もしない。 */
    @Test
    fun removeDoesNothingForBundledResources() {
        KsImageCache.remove(KsImageSource.Resource(android.R.drawable.ic_menu_gallery))

        assertEquals(0, KsImageInvalidation.globalGeneration)
        assertTrue(KsImageSource.Resource(1).cacheKey == null)
    }

    /**
     * 削除で世代が進むと、表示中の画像は取得をやり直す。
     *
     * 1 回目を待つ条件は「取得が始まった」ではなく「取得が終わってメモリの項目になった」に
     * する。表示に使う鍵には世代が入らないため、飛行中の 1 回目が削除をまたいで書き戻すと
     * 組み立て直しがその項目に当たってしまい、2 回目の取得が起きない。取得に幅を持たせて
     * あるので、開始で戻る待機に書き換えるとこのテストは落ちる。
     */
    @Test
    fun removeMakesTheDisplayedImageReload() {
        val url = "https://example.com/reload.jpg"
        fetchDelayMillis = 200L
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote(url),
                    modifier = Modifier.size(50.dp),
                    contentDescription = "reload",
                )
            }
        }

        awaitCondition("1 回目の取得がメモリの項目にならない", { "memory=${memoryKeys(url)}" }) {
            memoryKeys(url) > 0
        }
        val before = fetchCount

        composeTestRule.runOnIdle { KsImageCache.remove(KsImageSource.Remote(url)) }

        awaitCondition("削除の後に取得をやり直さない", { "memory=${memoryKeys(url)}" }) {
            fetchCount > before
        }
        assertFalse("世代が進んでいません", KsImageInvalidation.generation(url) == 0)
    }

    /** ローダーのメモリキャッシュにある、その取得元の項目の数。 */
    private fun memoryKeys(url: String): Int =
        loader.memoryCache?.keys?.count { it.key == url } ?: 0

    /**
     * その取得元の項目のうち、表示要求が書く「表示サイズ付きの鍵」の数。
     * 先読みが書く元寸の鍵は付随情報を持たないため数に入らない。
     */
    private fun displayMemoryKeys(url: String): Int =
        loader.memoryCache?.keys?.count { it.key == url && it.extras.isNotEmpty() } ?: 0

    /**
     * 条件が満たされるまで実時間の上限つきで待つ。待つ間はコンポジションと副作用に実行機会を
     * 譲り、期限を過ぎたら実測値を添えて失敗させる。
     *
     * @param detail 期限切れのときに添える、待っていた条件そのものの実測値
     */
    private fun awaitCondition(
        description: String,
        detail: (() -> String)? = null,
        condition: () -> Boolean,
    ) {
        val deadline = System.nanoTime() + 10_000_000_000L
        while (!condition()) {
            if (System.nanoTime() > deadline) {
                val observed = listOfNotNull("fetch=$fetchCount", detail?.invoke()).joinToString(", ")
                fail("$description (実測: $observed)")
            }
            composeTestRule.waitForIdle()
            Thread.sleep(1)
        }
    }

    /** ライブラリのタグで警告ログが出ていることを確かめる。 */
    private fun assertWarned(fragment: String, message: String) {
        composeTestRule.waitForIdle()
        val warnings = ShadowLog.getLogsForTag("KsCollectionView")
            .filter { it.type == Log.WARN }
            .map { it.msg }
        assertTrue("$message (実測 $warnings)", warnings.any { it.contains(fragment) })
    }
}
