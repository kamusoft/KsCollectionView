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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.layout.SubcomposeLayoutState
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.ColorImage
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
import coil3.request.SuccessResult
import coil3.size.Precision
import coil3.size.Scale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
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

    // ローダーが受け付けた要求の数。引き当てで表示した画像が要求を出さないことを数える。
    private val loaderStarts = AtomicInteger(0)

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
            .eventListener(object : EventListener() {
                override fun onStart(request: ImageRequest) {
                    loaderStarts.incrementAndGet()
                }
            })
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
        KsImageMemoryIndex.shared.removeAll()
        loaderStarts.set(0)
    }

    @After
    fun tearDown() {
        loader.shutdown()
        SingletonImageLoader.reset()
        KsImageInvalidation.reset()
        KsImageMemoryIndex.shared.removeAll()
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

    /** 表示の要求は枠の実サイズへ縮小してデコードする指定を持ち、当てはめ方は縮小の基準にだけ効く。 */
    @Test
    fun displayRequestDecodesToTheFrameSize() {
        val source = KsImageSource.Remote("https://example.com/large.jpg")

        val fit = requireNotNull(
            KsImageRequestFactory.prepare(context, source, 100, 100, KsImageContentMode.Fit),
        )
        val fill = requireNotNull(
            KsImageRequestFactory.prepare(context, source, 100, 100, KsImageContentMode.Fill),
        )

        // 元データからデコードする経路でも枠を超えないよう、要求は寸法の一致を求める。
        assertEquals(Precision.EXACT, fit.request.precision)
        assertEquals(Scale.FIT, fit.request.scale)
        assertEquals(Scale.FILL, fill.request.scale)
        assertNull("メモリに何も無いのに引き当てました", fit.matchedImage)
    }

    /**
     * キーの無い画像の鍵は、メモリは「URL + 表示サイズ + 当てはめ方」、ディスクはローダーの既定 (URL)
     * のまま。ローダー付属のビューとディスクの項目を共有できる形を保つ。
     */
    @Test
    fun keylessRequestsKeepTheUrlBasedKeys() {
        val url = "https://example.com/keyless.jpg"
        val prepared = requireNotNull(
            KsImageRequestFactory.prepare(context, KsImageSource.Remote(url), 50, 60, KsImageContentMode.Fill),
        )

        assertEquals(url, prepared.request.memoryCacheKey)
        assertEquals(
            mapOf("coil#size" to coil3.size.Size(50, 60).toString(), "ks#scale" to "fill"),
            prepared.request.memoryCacheKeyExtras,
        )
        assertNull("キーの無い画像のディスクの鍵を変えました", prepared.request.diskCacheKey)
    }

    /**
     * 表示の要求の鍵は当てはめ方で分かれ、幅を宣言した先読みの鍵 (寸法だけ) とも重ならない。
     * 重なると、引き当てで退けた項目をローダーがメモリからそのまま返してしまう。
     */
    @Test
    fun displayKeysAreSeparatedByContentModeAndFromPrefetchKeys() {
        val source = KsImageSource.Remote("https://example.com/modes.jpg")
        val identifier = requireNotNull(source.identifier)

        val fit = KsImageIdentity.displayKey(identifier, coil3.size.Size(100, 100), KsImageContentMode.Fit)
        val fill = KsImageIdentity.displayKey(identifier, coil3.size.Size(100, 100), KsImageContentMode.Fill)
        val prefetched = KsPrefetchRequest(source.url, widthPixels = 100).memoryKey

        assertNotEquals(fit, fill)
        assertNotEquals(fit, prefetched)
        assertNotEquals(fill, prefetched)
        // 本体は識別子のままなので、ソース単位の削除 (本体の完全一致) で表示の項目も消える。
        assertEquals(identifier, fit.key)
    }

    /** キーのある画像は、メモリとディスクの鍵の本体がキーの識別子になり、URL とは別の名前空間に置かれる。 */
    @Test
    fun keyedRequestsUseTheKeyIdentifier() {
        val url = "https://example.com/signed.jpg?sig=1"
        val prepared = requireNotNull(
            KsImageRequestFactory.prepare(
                context,
                KsImageSource.Remote(url, key = "p1"),
                50,
                50,
                KsImageContentMode.Fill,
            ),
        )

        assertEquals("ks-key p1", prepared.request.memoryCacheKey)
        assertEquals("ks-key p1", prepared.request.diskCacheKey)
        assertEquals("取得は URL で行う", url, prepared.request.data)
        // キーの文字列が URL と同じでも、URL の識別子とは重ならない。
        assertNotEquals(
            KsImageSource.Remote(url).identifier,
            KsImageSource.Remote("https://example.com/other.jpg", key = url).identifier,
        )
    }

    // MARK: メモリ項目の引き当て

    /** 識別子の項目を寸法つきの鍵でメモリへ載せ、索引に覚えさせる (先読みや表示が載せた項目の代わり)。 */
    private fun putInMemory(
        source: KsImageSource,
        width: Int,
        height: Int,
        sized: Boolean = true,
    ): coil3.memory.MemoryCache.Key {
        val identifier = requireNotNull(source.identifier)
        val key = if (sized) {
            KsImageIdentity.sizedKey(identifier, coil3.size.Size(width, height))
        } else {
            KsImageIdentity.originalKey(identifier)
        }
        requireNotNull(loader.memoryCache).set(
            key,
            MemoryCache.Value(Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).asImage()),
        )
        KsImageMemoryIndex.shared.register(key)
        return key
    }

    private fun prepare(source: KsImageSource, width: Int, height: Int, mode: KsImageContentMode = KsImageContentMode.Fill) =
        requireNotNull(KsImageRequestFactory.prepare(context, source, width, height, mode))

    /** 先読みが列幅に縮小して載せた項目は、同じ幅の枠でそのまま使われる。 */
    @Test
    fun prefetchedDownscaledItemIsUsed() {
        val source = KsImageSource.Remote("https://example.com/column.jpg")
        putInMemory(source, 300, 450)

        val prepared = prepare(source, 300, 300)

        assertEquals(300 to 450, prepared.matchedImage?.let { it.width to it.height })
    }

    /** 元の大きさの項目も、枠の上限倍以下なら縮小せずにそのまま使われる。 */
    @Test
    fun originalItemWithinTheUpperBoundIsUsed() {
        val source = KsImageSource.Remote("https://example.com/original.jpg")
        putInMemory(source, 1000, 800, sized = false)

        val prepared = prepare(source, 300, 300)

        // fill で必要な拡大率は 300 / 800 = 0.375 (上限 4 倍 = 0.25 以上)。縮小していないこと。
        assertEquals(1000 to 800, prepared.matchedImage?.let { it.width to it.height })
    }

    /** 枠の下限倍未満の項目は使わず、枠の実サイズで縮小デコードする要求になる。 */
    @Test
    fun tooSmallItemIsNotUsed() {
        val source = KsImageSource.Remote("https://example.com/small.jpg")
        putInMemory(source, 140, 140)

        val prepared = prepare(source, 300, 300)

        assertNull(prepared.matchedImage)
        assertEquals(coil3.size.Size(300, 300).toString(), prepared.request.memoryCacheKeyExtras["coil#size"])
    }

    /** 枠の上限倍を超える項目は使わない。 */
    @Test
    fun tooLargeItemIsNotUsed() {
        val source = KsImageSource.Remote("https://example.com/huge.jpg")
        putInMemory(source, 1300, 1300, sized = false)

        assertNull(prepare(source, 300, 300).matchedImage)
    }

    /** 縦長の枠に fill するときは高さで判定し、高さの足りない横長の項目は使わない。 */
    @Test
    fun fillIntoATallFrameIsJudgedByHeight() {
        val source = KsImageSource.Remote("https://example.com/wide.jpg")
        // 幅は枠と同じだが、高さは枠の 0.5 倍未満。
        putInMemory(source, 300, 250)

        assertNull(prepare(source, 300, 600).matchedImage)
        // 同じ項目でも fit なら収まる (必要な拡大率は 1)。
        assertEquals(300, prepare(source, 300, 600, KsImageContentMode.Fit).matchedImage?.width)
    }

    /**
     * 列幅 w で先読みした横長の画像 (縦横比 4:1 超) を w × w の枠に fit で表示すると、先読みの項目は
     * 大きすぎて退けられ、表示の要求もその項目をメモリから受け取らずに枠の大きさで取り直す。
     */
    @Test
    fun tooLargePrefetchedItemIsNotReturnedByTheDisplayRequestForFit() {
        val source = KsImageSource.Remote("https://example.com/panorama.jpg")
        // 幅 100 の先読みは正方形 100 × 100 を覆う大きさで載せる。5:1 の画像なら 500 × 100 になる。
        val prefetchedKey = KsPrefetchRequest(source.url, widthPixels = 100).memoryKey
        requireNotNull(loader.memoryCache).set(
            prefetchedKey,
            MemoryCache.Value(Bitmap.createBitmap(500, 100, Bitmap.Config.ARGB_8888).asImage()),
        )
        KsImageMemoryIndex.shared.register(prefetchedKey)

        // fit で必要な拡大率は 100 / 500 = 0.2 (上限 4 倍 = 0.25 未満) なので引き当てない。
        val prepared = prepare(source, 100, 100, KsImageContentMode.Fit)
        assertNull("大きすぎる先読みの項目を引き当てました", prepared.matchedImage)

        val result = runBlocking { loader.execute(prepared.request) }

        assertTrue("表示の要求が失敗しました: $result", result is SuccessResult)
        assertNotEquals(
            "範囲外の先読みの項目をメモリから受け取りました",
            DataSource.MEMORY_CACHE,
            (result as SuccessResult).dataSource,
        )
        assertEquals("枠の大きさで取り直していません", 1, fetchCount)
    }

    /**
     * 同じ URL を同じ枠で fit と fill の両方に使うとき、fit で載せた小さい項目を fill の表示が
     * メモリから受け取らずに取り直す (拡大してぼやけない)。
     */
    @Test
    fun smallerItemLoadedForFitIsNotReturnedByTheDisplayRequestForFill() {
        val source = KsImageSource.Remote("https://example.com/banner.jpg")

        // 取得層は 80 × 40 (2:1) を返す。fit では 100 × 100 の枠に拡大率 1.25 で収まる。
        val fit = prepare(source, 100, 100, KsImageContentMode.Fit)
        runBlocking { loader.execute(fit.request) }
        assertEquals(1, fetchCount)
        assertNotNull("fit で載せた項目を fit で引き当てません", prepare(source, 100, 100, KsImageContentMode.Fit).matchedImage)

        // fill で必要な拡大率は 100 / 40 = 2.5 (下限 0.5 倍 = 2 を超える) なので引き当てない。
        val fill = prepare(source, 100, 100, KsImageContentMode.Fill)
        assertNull("小さすぎる項目を引き当てました", fill.matchedImage)

        val result = runBlocking { loader.execute(fill.request) }

        assertTrue("表示の要求が失敗しました: $result", result is SuccessResult)
        assertNotEquals(
            "fit で載せた小さい項目をメモリから受け取りました",
            DataSource.MEMORY_CACHE,
            (result as SuccessResult).dataSource,
        )
        assertEquals("fill の枠で取り直していません", 2, fetchCount)
    }

    /** 範囲内の項目が複数あれば、必要な寸法に最も近い項目を使う。 */
    @Test
    fun closestItemIsChosenAmongCandidates() {
        val source = KsImageSource.Remote("https://example.com/many.jpg")
        putInMemory(source, 1000, 1000, sized = false)
        putInMemory(source, 320, 320)
        putInMemory(source, 200, 200)

        assertEquals(320, prepare(source, 300, 300).matchedImage?.width)
    }

    /** 先読みの完了前に表示が照会しても、先読みが完了した後の次の照会ではその項目を引き当てる。 */
    @Test
    fun prefetchCompletedAfterAnEarlierQueryIsMatchedNextTime() {
        val source = KsImageSource.Remote("https://example.com/pending.jpg")
        // 要求は出したがまだ完了していない先読みの鍵 (登録は要求を出した時点の 1 回だけ)。
        val pending = KsImageIdentity.sizedKey(requireNotNull(source.identifier), coil3.size.Size(300, 450))
        KsImageMemoryIndex.shared.register(pending)

        assertNull("完了していない鍵が候補になりました", prepare(source, 300, 300).matchedImage)

        requireNotNull(loader.memoryCache).set(
            pending,
            MemoryCache.Value(Bitmap.createBitmap(300, 450, Bitmap.Config.ARGB_8888).asImage()),
        )

        assertEquals(
            "完了した先読みの項目を引き当てませんでした",
            300 to 450,
            prepare(source, 300, 300).matchedImage?.let { it.width to it.height },
        )
    }

    /** ソース単位で消した項目は引き当てず、取得をやり直す要求になる。 */
    @Test
    fun removedItemIsNotMatched() {
        val source = KsImageSource.Remote("https://example.com/removed.jpg")
        putInMemory(source, 300, 300)
        assertNotNull("前提の引き当てが成立していません", prepare(source, 300, 300).matchedImage)

        KsImageCache.remove(source)

        assertNull(prepare(source, 300, 300).matchedImage)
    }

    /** 範囲消去の後も引き当てない (索引も消える)。 */
    @Test
    fun clearedItemIsNotMatched() {
        val source = KsImageSource.Remote("https://example.com/cleared.jpg")
        putInMemory(source, 300, 300)

        KsImageCache.clear(KsImageCacheScope.Memory)

        assertEquals("索引が残っています", 0, KsImageMemoryIndex.shared.count)
        assertNull(prepare(source, 300, 300).matchedImage)
    }

    /** ローダー付属のビューが載せた項目 (索引に無い項目) は引き当ての対象にならない。 */
    @Test
    fun itemsLoadedOutsideTheLibraryAreNotMatched() {
        val url = "https://example.com/outside.jpg"
        runBlocking { loader.execute(ImageRequest.Builder(context).data(url).build()) }
        assertNotNull("前提のメモリ項目が作られていません", loader.memoryCache?.get(MemoryCache.Key(url)))

        assertNull(prepare(KsImageSource.Remote(url), 50, 50).matchedImage)
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
     * 到達点 memory の先読みが載せた画像の表示は、読み込み中のスロットを一度も構成せず、
     * ローダーへ要求も出さない。
     *
     * 一瞬だけ挟まる読み込み中は最終状態を見るだけでは捉えられないため、スロットが構成された
     * 回数そのものを数える。
     */
    @Test
    fun loadingSlotIsNeverComposedWhenThePrefetchedImageIsInMemory() {
        val url = "https://example.com/warm.jpg"
        // 先読みの到達点 memory と同じ経路でメモリキャッシュへ載せる (幅なし = 取得した大きさのまま)。
        KsCoilImageLoading(context).enqueue(KsPrefetchRequest(url), KsPrefetchDestination.Memory)
        awaitCondition("先読みの項目がメモリに載らない") {
            loader.memoryCache?.get(MemoryCache.Key(url)) != null
        }
        val startsBeforeDisplay = loaderStarts.get()

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
        composeTestRule.waitForIdle()
        assertEquals("読み込み中の表示を経由しました", 0, loadingCompositions.get())
        assertEquals("引き当てた表示がローダーへ要求を出しました", startsBeforeDisplay, loaderStarts.get())
        assertEquals("取得をやり直しました", 1, fetchCount)
    }

    /**
     * 画面に出る前に組み立てられた表示 (遅延グリッドの先行合成) は、その時点でメモリに項目が
     * 無く先読みが未完了なら要求を出さず、画面に出る時点でもう一度引き当てる。その間に先読みが
     * 完了していれば、要求を出さず読み込み中も経由せずにその項目で表示する。
     *
     * 遅延グリッドは画面外のアイテムを先に組み立て、測るところまで済ませておく。組み立ての時点で
     * 1 度だけ引き当てて外れた表示がその場で要求を出すと、画面に出る時点で先読みが完了していても
     * 読み込み中を経由し、取得も先読みと二重になる (Pixel 4a のフリングで観測した形)。ここでは
     * 先行合成と先行測定を [SubcomposeLayoutState] で直接起こし、その後に項目を載せてから画面に出す。
     *
     * 読み込み中のスロットは画面に出る前の表示の中身として組み立てておく (画面に出た最初の描画から
     * 描けるようにするため)。確かめるのは、画面に出た後に組み立てが増えないことと、描かれないこと
     * (描画は [KsImageShownFrameTest])。
     */
    @Test
    fun precomposedDisplayMatchesTheItemThatArrivedBeforeItWasShown() {
        val source = KsImageSource.Remote("https://example.com/precomposed.jpg")
        registerPendingPrefetch(source, 100, 100)
        val loadingCompositions = AtomicInteger(0)
        val content: @Composable () -> Unit = {
            KsImage(
                source = source,
                modifier = Modifier.size(100.dp),
                contentDescription = "precomposed",
                loading = {
                    loadingCompositions.incrementAndGet()
                    Box(Modifier.testTag("loading"))
                },
            )
        }
        val shown = precomposeThenShow(content)

        composeTestRule.waitForIdle()
        assertEquals("画面に出る前に要求を出しました", 0, loaderStarts.get())
        val compositionsBeforeShown = loadingCompositions.get()

        // 画面に出る前に先読みが完了した (列幅の項目が載った) 状態にする。
        putInMemory(source, 100, 100)
        composeTestRule.runOnIdle { shown.value = true }

        awaitCondition("画面に出た表示が組み上がらない") {
            composeTestRule.onAllNodesWithContentDescription("precomposed").fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.waitForIdle()
        assertEquals("画面に出た後に読み込み中を組み立てました", compositionsBeforeShown, loadingCompositions.get())
        assertEquals("引き当てられる項目があるのに要求を出しました", 0, loaderStarts.get())
        assertEquals("取得をやり直しました", 0, fetchCount)
        assertEquals("読み込み中の表示が残っています", 0, composeTestRule.countNodesWithTag("loading"))
    }

    /**
     * 先読みが未完了のまま画面に出る前に組み立てられた表示は、画面に出る時点でも項目が無ければ、
     * そこで要求を出して読み込み中から成功へ進む。画面に出るまでは要求を出さない。
     */
    @Test
    fun precomposedDisplayRequestsOnlyWhenShownWithoutAnItem() {
        val source = KsImageSource.Remote("https://example.com/precomposed-miss.jpg")
        registerPendingPrefetch(source, 100, 100)
        val loadingCompositions = AtomicInteger(0)
        val content: @Composable () -> Unit = {
            KsImage(
                source = source,
                modifier = Modifier.size(100.dp),
                contentDescription = "precomposed-miss",
                loading = {
                    loadingCompositions.incrementAndGet()
                    Box(Modifier.testTag("loading"))
                },
            )
        }
        val shown = precomposeThenShow(content)

        composeTestRule.waitForIdle()
        assertEquals("画面に出る前に要求を出しました", 0, loaderStarts.get())

        composeTestRule.runOnIdle { shown.value = true }

        awaitCondition("画面に出た時点で要求が出ない") { loaderStarts.get() >= 1 }
        awaitCondition("取得が完了しない") { fetchCount >= 1 && composeTestRule.countNodesWithTag("loading") == 0 }
        assertTrue("読み込み中を経由していません", loadingCompositions.get() >= 1)
        assertEquals("要求が二重に出ました", 1, loaderStarts.get())
    }

    /**
     * 先読みの要求を出さずにいる画像は、画面に出る前に組み立てられた時点で要求を出す。待っても
     * 引き当てられる見込みが無いので、画面に出る前の時間を取得の先回りに使う。
     */
    @Test
    fun precomposedDisplayWithoutPrefetchRequestsBeforeItIsShown() {
        val source = KsImageSource.Remote("https://example.com/precomposed-unprefetched.jpg")
        val content: @Composable () -> Unit = {
            KsImage(source = source, modifier = Modifier.size(100.dp))
        }
        precomposeThenShow(content)

        awaitCondition("画面に出る前に要求が出ない", { "starts=${loaderStarts.get()}" }) {
            loaderStarts.get() >= 1
        }
    }

    /**
     * 先読みの項目が既にメモリにある (完了した) 画像は、未完了の先読みが無いので、枠に合わない
     * ときは画面に出る前に組み立てられた時点で要求を出す。
     */
    @Test
    fun precomposedDisplayWithCompletedButUnusablePrefetchRequestsBeforeItIsShown() {
        val source = KsImageSource.Remote("https://example.com/precomposed-too-small.jpg")
        // 100dp の枠に対して小さすぎる、完了済みの先読みの項目。
        putInMemory(source, 8, 8)
        val content: @Composable () -> Unit = {
            KsImage(source = source, modifier = Modifier.size(100.dp))
        }
        precomposeThenShow(content)

        awaitCondition("画面に出る前に要求が出ない", { "starts=${loaderStarts.get()}" }) {
            loaderStarts.get() >= 1
        }
    }

    /**
     * 先読みで遅らせない画像は、画面に出る前に組み立てられた時点で要求を出す。索引に先読みの鍵が
     * あっても、その取得が終わっている (完了して追い出された・失敗した・取り消された) なら、待っても
     * 引き当てられる見込みが無いので遅らせない。
     */
    @Test
    fun precomposedDisplayWithEndedPrefetchRequestsBeforeItIsShown() {
        val source = KsImageSource.Remote("https://example.com/precomposed-ended.jpg")
        val endFetch = registerPendingPrefetch(source, 100, 100)
        // 取得が終わった (項目はメモリに無いまま) 状態にする。
        endFetch()
        val content: @Composable () -> Unit = {
            KsImage(source = source, modifier = Modifier.size(100.dp))
        }
        precomposeThenShow(content)

        awaitCondition("画面に出る前に要求が出ない", { "starts=${loaderStarts.get()}" }) {
            loaderStarts.get() >= 1
        }
    }

    /**
     * 画面に出た時点の引き当てが当たったとき、既定の読み込み中の表示なら組み立て直しを 1 度も起こさずに
     * 画像を出す (画面に出る時点の処理を部品の中で終え、描画の無効化だけで済ませる)。
     */
    @Test
    fun shownLookupMatchDoesNotRecompose() {
        val source = KsImageSource.Remote("https://example.com/shown-no-recompose.jpg")
        registerPendingPrefetch(source, 100, 100)
        val shown = precomposeThenShow { KsImage(source = source, modifier = Modifier.size(100.dp)) }
        composeTestRule.waitForIdle()
        putInMemory(source, 100, 100)

        val changes = recomposerChanges { composeTestRule.runOnIdle { shown.value = true } }

        assertEquals("画面に出た時点の引き当てで組み立て直しが起きました", 0L, changes)
        assertEquals("引き当てられる項目があるのに要求を出しました", 0, loaderStarts.get())
    }

    /**
     * 画面に出た時点の引き当てが外れたとき、既定の読み込み中の表示なら、要求の開始から成功の描画まで
     * 組み立て直しを起こさない。要求は画面に出た時点で出る。
     */
    @Test
    fun shownLookupMissLoadsWithoutRecomposition() {
        val source = KsImageSource.Remote("https://example.com/shown-miss-no-recompose.jpg")
        registerPendingPrefetch(source, 100, 100)
        val shown = precomposeThenShow { KsImage(source = source, modifier = Modifier.size(100.dp)) }
        composeTestRule.waitForIdle()
        assertEquals("画面に出る前に要求を出しました", 0, loaderStarts.get())

        val changes = recomposerChanges {
            composeTestRule.runOnIdle { shown.value = true }
            awaitCondition("画面に出た時点で取得されない") { fetchCount >= 1 }
        }

        assertEquals("要求が 1 度だけ出ていません", 1, loaderStarts.get())
        assertEquals("画面に出た時点の要求と成功の描画で組み立て直しが起きました", 0L, changes)
    }

    /** 画面に出た時点で出した要求が失敗したら、失敗の表示 (スロット) に切り替わる。 */
    @Test
    fun shownLookupMissShowsTheFailureSlotWhenLoadingFails() {
        behavior = ScriptedFetcher.Behavior.Fail
        val source = KsImageSource.Remote("https://example.com/shown-miss-fail.jpg")
        registerPendingPrefetch(source, 100, 100)
        val shown = precomposeThenShow {
            KsImage(
                source = source,
                modifier = Modifier.size(100.dp),
                loading = { Box(Modifier.testTag("loading")) },
                failure = { Box(Modifier.testTag("failure")) },
            )
        }
        composeTestRule.waitForIdle()
        composeTestRule.runOnIdle { shown.value = true }

        awaitCondition("失敗の表示に切り替わらない") { composeTestRule.countNodesWithTag("failure") == 1 }
        assertEquals("読み込み中の表示が残っています", 0, composeTestRule.countNodesWithTag("loading"))
        assertEquals("自動で再試行しました", 1, fetchCount)
    }

    /** [block] の間にコンポジションの組み立て直しが適用された回数。 */
    private fun recomposerChanges(block: () -> Unit): Long {
        composeTestRule.waitForIdle()
        val before = totalRecomposerChanges()
        block()
        composeTestRule.waitForIdle()
        return totalRecomposerChanges() - before
    }

    private fun totalRecomposerChanges(): Long =
        androidx.compose.runtime.Recomposer.runningRecomposers.value.sumOf { it.changeCount }

    /**
     * 識別子の先読みの要求を索引に覚えさせ、項目はまだメモリに無く取得中の状態 (先読みが未完了) に
     * する。返す関数を呼ぶと、その取得が終わった状態になる。
     */
    private fun registerPendingPrefetch(source: KsImageSource, width: Int, height: Int): () -> Unit {
        val identifier = requireNotNull(source.identifier)
        val key = KsImageIdentity.sizedKey(identifier, coil3.size.Size(width, height))
        KsImageMemoryIndex.shared.register(key)
        return KsImageMemoryIndex.shared.beginFetch(key)
    }

    /**
     * 遅延グリッドの先行合成と同じ形で [content] を画面外に組み立てて測り、返した値を true に
     * すると同じ組み立てを画面に置く。
     */
    private fun precomposeThenShow(content: @Composable () -> Unit): androidx.compose.runtime.MutableState<Boolean> {
        val state = SubcomposeLayoutState()
        val shown = mutableStateOf(false)
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
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
        return shown
    }

    /** ローダー付属のビューが載せた項目は引き当てず、表示は読み込み中を経由して取得する。 */
    @Test
    fun itemsLoadedByTheLoaderDirectlyGoThroughLoading() {
        val url = "https://example.com/direct.jpg"
        runBlocking { loader.execute(ImageRequest.Builder(context).data(url).build()) }

        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = KsImageSource.Remote(url),
                    modifier = Modifier.size(50.dp),
                    loading = { Box(Modifier.testTag("loading")) },
                )
            }
        }

        awaitCondition("表示の要求が出ない") { loaderStarts.get() >= 2 }
    }

    /**
     * 枠の大きさが変わっても、引き当てた項目が新しい枠に対して許容範囲の内側なら、デコードし直さず
     * 同じ項目で表示を続ける。範囲の外になったときだけ新しい大きさで要求を出す。
     */
    @Test
    fun resizingWithinTheRangeKeepsTheSameItem() {
        val source = KsImageSource.Remote("https://example.com/resized.jpg")
        putInMemory(source, 100, 100)
        var side by mutableIntStateOf(100)
        val loadingCompositions = AtomicInteger(0)
        composeTestRule.setContent {
            Box(Modifier.size(1000.dp, 1000.dp)) {
                KsImage(
                    source = source,
                    // Robolectric の既定の表示倍率は 1 なので、dp とピクセルが一致する。
                    modifier = Modifier.size(side.dp),
                    contentDescription = "resized",
                    loading = {
                        loadingCompositions.incrementAndGet()
                        Box(Modifier.testTag("loading"))
                    },
                )
            }
        }
        composeTestRule.waitForIdle()

        // 100 → 150 (必要な拡大率 1.5、下限 0.5 倍の内側)。
        composeTestRule.runOnIdle { side = 150 }
        composeTestRule.waitForIdle()
        assertEquals("範囲内の枠の変化で読み込み中を経由しました", 0, loadingCompositions.get())
        assertEquals("範囲内の枠の変化で要求を出しました", 0, loaderStarts.get())

        // 100 → 400 (必要な拡大率 4、範囲の外) では新しい大きさで要求を出す。
        composeTestRule.runOnIdle { side = 400 }
        awaitCondition("範囲の外の枠で要求が出ない") { loaderStarts.get() >= 1 }
    }

    /**
     * メモリから引き当てて表示中の画像は、メモリのみの消去の後に親の状態変化で組み立て直されても、
     * 別のソースの削除で組み立て直されても、読み込み中の表示へ戻らず要求も出さない。
     * iOS の `test引き当てて表示中の画像はメモリのみ消去の後に親が組み立て直されても置き換わらない` と対になる。
     */
    @Test
    fun matchedImageIsKeptAcrossRecompositionAfterClearingMemory() {
        val source = KsImageSource.Remote("https://example.com/kept.jpg")
        putInMemory(source, 50, 50)
        var tick by mutableIntStateOf(0)
        val parentCompositions = AtomicInteger(0)
        val loadingCompositions = AtomicInteger(0)
        composeTestRule.setContent {
            // 親の状態を読む。値が変わると親と、その値に依存する子が組み立て直される。
            val current = tick
            parentCompositions.incrementAndGet()
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = source,
                    // Robolectric の既定の表示倍率は 1 なので、dp とピクセルが一致する。
                    modifier = Modifier.size(50.dp),
                    contentDescription = "kept",
                    // 読み込み中の表示が親の状態に依存する、よくある形。
                    loading = {
                        loadingCompositions.incrementAndGet()
                        Box(Modifier.testTag("loading-$current"))
                    },
                )
            }
        }
        composeTestRule.waitForIdle()
        assertEquals("引き当てで表示されていません", 0, loadingCompositions.get())

        composeTestRule.runOnIdle { KsImageCache.clear(KsImageCacheScope.Memory) }
        val before = parentCompositions.get()
        composeTestRule.runOnIdle { tick += 1 }
        awaitCondition("親が組み立て直されない", { "parent=${parentCompositions.get()}" }) {
            parentCompositions.get() > before
        }
        // 別のソースの削除は世代の台帳を書き換え、表示中のすべての KsImage を組み立て直させる。
        composeTestRule.runOnIdle { KsImageCache.remove(KsImageSource.Remote("https://example.com/other.jpg")) }
        composeTestRule.waitForIdle()

        assertEquals("メモリのみ消去の後に読み込み中の表示へ戻りました", 0, loadingCompositions.get())
        assertEquals("メモリのみ消去の後に要求を出しました", 0, loaderStarts.get())
        assertEquals(
            "表示中の画像が消えました",
            1,
            composeTestRule.onAllNodesWithContentDescription("kept").fetchSemanticsNodes().size,
        )
    }

    /**
     * メモリのみの消去を挟んで表示するソースをリソースへ切り替えて戻したとき、切り替える前に引き当てて
     * いた画像は使わず、引き当てをやり直す (メモリは空なので要求を出して取り直す)。
     * iOS の `test引き当てたソースからアセットへ切り替えてメモリのみ消去の後に戻すとディスクから再デコードする` と対になる。
     */
    @Test
    fun switchingBackAfterClearingMemoryDoesNotReuseThePreviouslyMatchedImage() {
        val remote = KsImageSource.Remote("https://example.com/switched.jpg")
        putInMemory(remote, 50, 50)
        var source: KsImageSource by mutableStateOf(remote)
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(
                    source = source,
                    // Robolectric の既定の表示倍率は 1 なので、dp とピクセルが一致する。
                    modifier = Modifier.size(50.dp),
                    contentDescription = "switched",
                )
            }
        }
        composeTestRule.waitForIdle()
        assertEquals("引き当てで表示されていません", 0, loaderStarts.get())

        composeTestRule.runOnIdle { source = KsImageSource.Resource(android.R.drawable.ic_menu_gallery) }
        composeTestRule.waitForIdle()
        composeTestRule.runOnIdle { KsImageCache.clear(KsImageCacheScope.Memory) }
        composeTestRule.runOnIdle { source = remote }

        awaitCondition("戻したソースで要求が出ない", { "starts=${loaderStarts.get()}" }) { loaderStarts.get() >= 1 }
    }

    // MARK: 任意キー

    /** 便宜形のキーはリモートのソースのキーと同じ意味になる。 */
    @Test
    fun convenienceFormPassesTheKey() {
        val url = "https://example.com/convenience-key.jpg?sig=1"
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(url = url, key = "c1", modifier = Modifier.size(50.dp), contentDescription = "keyed")
            }
        }

        awaitCondition("キー付きの便宜形の画像がメモリに載らない") {
            loader.memoryCache?.keys?.any { it.key == "ks-key c1" } == true
        }
        assertTrue(
            "URL の鍵で載りました",
            loader.memoryCache?.keys?.none { it.key == url } == true,
        )
    }

    /** 空文字のキーは release では警告してキーなし (URL) として表示する。 */
    @Test
    fun emptyKeyIsWarnedAndTreatedAsKeyless() {
        val url = "https://example.com/empty-key.jpg"
        composeTestRule.setContent {
            Box(Modifier.size(300.dp, 600.dp)) {
                KsImage(source = KsImageSource.Remote(url, key = ""), modifier = Modifier.size(50.dp))
            }
        }

        awaitCondition("空文字のキーの画像が URL の鍵で載らない") {
            loader.memoryCache?.keys?.any { it.key == url } == true
        }
        assertWarned("空文字", "空文字のキーを黙って受け入れています")
    }

    /** 空文字のキーは debug ビルドでは停止する。 */
    @Test
    fun emptyKeyStopsInDebug() {
        KsDiagnostics.debugOverride = true

        assertThrows(IllegalStateException::class.java) {
            composeTestRule.setContent {
                Box(Modifier.size(300.dp, 600.dp)) {
                    KsImage(source = KsImageSource.Remote("https://example.com/k.jpg", key = ""), modifier = Modifier.size(50.dp))
                }
            }
        }
    }

    /**
     * 先読みを使わずに一度表示した画像は、表示を作り直しても読み込み中のスロットを構成しない。
     *
     * [loadingSlotIsNeverComposedWhenThePrefetchedImageIsInMemory] が見ているのは「先読みが載せた
     * 項目を表示が引き当てられるか」であり、ここで見るのは「表示要求が自分で書いた鍵を、次の
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
        assertTrue(KsImageSource.Resource(1).identifier == null)
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

    private companion object {
        /** 先行合成の試験で使う枠の識別子。 */
        const val PrecomposedSlot = "precomposed"
    }
}
