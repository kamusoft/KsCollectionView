package jp.kamusoft.kscollectionview

import android.content.Context
import android.content.res.Resources
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.State
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import coil3.SingletonImageLoader
import coil3.request.ErrorResult
import coil3.request.SuccessResult
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.geometry.isUnspecified
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.invalidateDraw
import androidx.compose.ui.node.LayoutModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import coil3.Image
import kotlin.math.roundToInt
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import coil3.asImage
import coil3.compose.AsyncImagePainter
import coil3.compose.asPainter
import coil3.compose.rememberAsyncImagePainter
import kotlin.math.min

/**
 * 画像を表示するコンポーネントです。
 *
 * ネットワーク上の画像・端末内のファイル・アプリに同梱したリソースを表示します。
 * ネットワークとファイルの画像は非同期に読み込み、読み込み中と失敗の表示を差し替えられます。
 *
 * ```kotlin
 * KsImage(KsImageSource.Remote(url), modifier = Modifier.fillMaxWidth().aspectRatio(1f))
 * ```
 *
 * メモリに表示枠と大きく違わない大きさの同じ画像があれば、デコードし直さずにそれで表示します
 * (読み込み中の表示を経由しません)。無ければ表示枠の大きさに縮小してデコードするため、表示のために
 * 元の大きさの画像をメモリに置きません。表示枠の大きさが決まるまでは読み込みを始めません。
 *
 * 表示枠の大きさは modifier で与えてください (`Modifier.size(...)` や
 * `Modifier.fillMaxWidth().aspectRatio(...)` など)。与えない場合は高さが 0 になり、画像が
 * 見えません。
 *
 * ```kotlin
 * Row {
 *     KsImage(KsImageSource.Remote(url), modifier = Modifier.size(44.dp))
 *     Text(title)
 * }
 * ```
 *
 * @param source 画像の取得元
 * @param modifier このコンポーネントに適用する modifier
 * @param contentDescription アクセシビリティのための画像の説明
 * @param contentMode 画像を表示枠にどう当てはめるか
 * @param loading 読み込み中の表示。未指定なら既定の表示になります
 * @param failure 失敗したときの表示。未指定なら既定の表示になります
 */
@Composable
public fun KsImage(
    source: KsImageSource,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    contentMode: KsImageContentMode = KsImageContentMode.Fill,
    loading: (@Composable () -> Unit)? = null,
    failure: (@Composable () -> Unit)? = null,
) {
    val contentScale = contentMode.toContentScale()
    // 画像の説明は状態によらず同じ位置 (根) に置く。状態ごとに付けると、読み込み中や失敗の
    // 間だけ読み上げの対象から消えてしまう。
    Box(modifier = modifier.clipToBounds().imageSemantics(contentDescription)) {
        when (source) {
            // 同梱したリソースは同期で読めるため、ローダーを通さず読み込み中の状態も経由しない。
            is KsImageSource.Resource ->
                KsResourceImageContent(source, contentScale, failure)

            else ->
                KsLoaderImageContent(
                    source,
                    contentMode,
                    contentScale,
                    loading,
                    failure,
                )
        }
    }
}

/**
 * 画像としての意味づけを与える。説明が無いときは飾りの画像として読み上げの対象にしない。
 */
private fun Modifier.imageSemantics(contentDescription: String?): Modifier =
    if (contentDescription == null) {
        this
    } else {
        semantics {
            this.contentDescription = contentDescription
            role = Role.Image
        }
    }

/**
 * ネットワーク上の画像を URL で指定して表示します。
 *
 * `KsImage(KsImageSource.Remote(url, key))` と同じ動きになります。
 *
 * ```kotlin
 * KsImage(photo.signedUrl, key = photo.id)   // 取得のたびに URL が変わる画像はキーで見分ける
 * ```
 *
 * @param url 画像を取得する URL
 * @param modifier このコンポーネントに適用する modifier
 * @param contentDescription アクセシビリティのための画像の説明
 * @param contentMode 画像を表示枠にどう当てはめるか
 * @param key 画像を見分けるキー。[KsImageSource.Remote] の `key` と同じ意味です。省略すると URL で
 *   見分けます。名前を付けて渡してください
 * @param loading 読み込み中の表示。未指定なら既定の表示になります
 * @param failure 失敗したときの表示。未指定なら既定の表示になります
 */
@Composable
public fun KsImage(
    url: String,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    contentMode: KsImageContentMode = KsImageContentMode.Fill,
    key: String? = null,
    loading: (@Composable () -> Unit)? = null,
    failure: (@Composable () -> Unit)? = null,
) {
    KsImage(
        source = KsImageSource.Remote(url, key),
        modifier = modifier,
        contentDescription = contentDescription,
        contentMode = contentMode,
        loading = loading,
        failure = failure,
    )
}

@Composable
private fun KsLoaderImageContent(
    source: KsImageSource,
    contentMode: KsImageContentMode,
    contentScale: ContentScale,
    loading: (@Composable () -> Unit)?,
    failure: (@Composable () -> Unit)?,
) {
    val context = LocalContext.current
    // 空文字のキーは誤り。落とさない構成ではキーなし (URL) として表示を続ける (core/ADR-0011)。
    val diagnostics = remember(source) { listOfNotNull(source.emptyKeyMessage) }
    KsDiagnostics.assertValid(context, diagnostics)
    KsDiagnostics.WarnOnce(diagnostics)

    val identifier = source.identifier.orEmpty()
    // 世代が進むと読み込みが最初からやり直しになる。キャッシュを消したときに表示中の画像を
    // 読み込み中へ戻すのはこの経路。
    val reloadToken = "${KsImageInvalidation.globalGeneration}:${KsImageInvalidation.generation(identifier)}"

    key(source, reloadToken) {
        // 引き当ても要求の縮小指定も表示枠の大きさで決まる。最初の構成で済ませないと読み込み中の
        // 表示が一瞬挟まるため、制約をその場で読める入れ物で受ける。
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val width = if (constraints.hasBoundedWidth) constraints.maxWidth else 0
            val height = if (constraints.hasBoundedHeight) constraints.maxHeight else 0
            // 枠の大きさが変わったときも引き当てからやり直す。新しい枠に対して許容範囲の内側に
            // ある項目なら、同じ項目で表示を続ける (デコードし直さない)。ここでは引き当てを試す
            // だけで、要求を出す (索引に覚えさせる) のは要求を出すと決めた時点である。
            val prepared = remember(source, context, width, height, contentMode) {
                KsImageRequestFactory.lookup(context, source, width, height, contentMode)
            }
            val matched = prepared?.matchedImage

            when {
                // 表示枠の大きさが決まるまでは読み込みを始めない。
                prepared == null ->
                    if (loading != null) loading() else KsImageDefaultLoading()

                // 引き当てた項目で表示を完了する。ローダーへは要求を出さないので読み込み中の表示も
                // 挟まらない。項目への参照は表示している間だけ持ち、この表示が破棄されると手放す。
                matched != null -> {
                    val painter = remember(matched, context) { matched.asPainter(context) }
                    Image(
                        painter = painter,
                        // 画像の説明は根に付いているため、ここでは重ねて付けない。
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = contentScale,
                    )
                }

                // 引き当てられず、この画像の先読みがまだ取得中。ここで要求を出すと、画面に出るまでに
                // 先読みが完了しても読み込み中を経由し、取得も先読みと二重になる。画面に出る時点まで
                // 待ち、そこでもう一度引き当てる。取得中の先読みが無い画像は待っても引き当てられる
                // 見込みが無いので、待たずに次の分岐で要求を出す (画面に出る前の先行合成の時間を取得の
                // 先回りに使う)。
                prepared.prefetchPending ->
                    // 枠が変わったら、画面に出た後でも引き当てと要求を最初からやり直す。
                    key(prepared) {
                        KsDeferredImageContent(
                            prepared = prepared,
                            contentScale = contentScale,
                            loading = loading,
                            failure = failure,
                            lookupOnShown = {
                                KsImageRequestFactory
                                    .lookup(context, source, width, height, contentMode)
                                    ?.matchedImage
                            },
                        )
                    }

                else ->
                    KsRequestedImageContent(
                        prepared = prepared,
                        contentScale = contentScale,
                        loading = loading,
                        failure = failure,
                    )
            }
        }
    }
}

/**
 * 画面に出る時点まで要求を遅らせる表示。画面に置かれた最初の時点で [lookupOnShown] で引き当てを
 * やり直し、当たればその項目を、外れればそこで出した要求の結果を描く。
 *
 * 画面に出た時点の処理は部品 ([KsDeferredNode]) の中で終え、組み立て直しを起こさない。遅延グリッドの
 * フリングでは画面に出るセルが毎フレーム入れ替わるため、ここで組み立て直すと表示中のフレームの主
 * スレッドの処理が増える。画像は部品が直接描き、描画の無効化だけで済ませる。
 *
 * 組み立て直しが起きるのは次の 2 つだけで、どちらも範囲を小さくしてある。
 * - 利用者の読み込み中の表示 ([loading]) があり、画像を描けるようになったとき: その表示だけを外す
 *   (外さないと、描かれないまま動き続けたり読み上げの対象に残ったりする)
 * - 取得に失敗したとき: 失敗の表示に切り替える
 *
 * 読み込み中の表示は、利用者の指定があれば中身として組み立てておき、画面に出た最初の描画から描く。
 * 指定が無ければ部品が既定の表示を直接描く (組み立てるものが無いので外す組み立て直しも要らない)。
 */
@Composable
private fun KsDeferredImageContent(
    prepared: KsPreparedImageRequest,
    contentScale: ContentScale,
    loading: (@Composable () -> Unit)?,
    failure: (@Composable () -> Unit)?,
    lookupOnShown: () -> Image?,
) {
    val context = LocalContext.current
    val failed = remember { mutableStateOf(false) }
    // 利用者の読み込み中の表示を外すかどうか。読むのは下の小さな組み立ての中だけにして、書き換えで
    // 組み立て直す範囲をその表示に限る。
    val imageReady = remember { mutableStateOf(false) }
    if (failed.value) {
        if (failure != null) failure() else KsImageDefaultFailure()
    } else {
        KsDeferredImageBody(prepared, context, contentScale, loading, lookupOnShown, imageReady, failed)
    }
}

@Composable
private fun KsDeferredImageBody(
    prepared: KsPreparedImageRequest,
    context: Context,
    contentScale: ContentScale,
    loading: (@Composable () -> Unit)?,
    lookupOnShown: () -> Image?,
    imageReady: MutableState<Boolean>,
    failed: MutableState<Boolean>,
) {
    val element = remember(prepared, context, contentScale, loading == null) {
        KsDeferredElement(
            prepared = prepared,
            context = context,
            contentScale = contentScale,
            drawsDefaultLoading = loading == null,
            lookupOnShown = lookupOnShown,
            onImageReady = { if (!imageReady.value) imageReady.value = true },
            onFailure = { failed.value = true },
        )
    }
    Box(modifier = Modifier.fillMaxSize().then(element)) {
        if (loading != null) KsLoadingSlotUntilReady(imageReady, loading)
    }
}

/** 画像を描けるようになるまで利用者の読み込み中の表示を組み立てる。 */
@Composable
private fun KsLoadingSlotUntilReady(
    imageReady: State<Boolean>,
    loading: @Composable () -> Unit,
) {
    if (!imageReady.value) loading()
}

private class KsDeferredElement(
    val prepared: KsPreparedImageRequest,
    val context: Context,
    val contentScale: ContentScale,
    val drawsDefaultLoading: Boolean,
    val lookupOnShown: () -> Image?,
    val onImageReady: () -> Unit,
    val onFailure: () -> Unit,
) : ModifierNodeElement<KsDeferredNode>() {
    override fun create(): KsDeferredNode = KsDeferredNode(this)

    override fun update(node: KsDeferredNode) {
        node.element = this
        node.invalidateDraw()
    }

    // 組み立ての中で覚えた 1 つの値だけを使うため、同一性で比べる。
    override fun equals(other: Any?): Boolean = this === other

    override fun hashCode(): Int = System.identityHashCode(this)
}

/**
 * 最初に置かれた時点を画面に出た時点として捉え、引き当てか要求をそこで行って結果を描く部品。
 *
 * 測るだけ (先に組み立てただけ) では配置の処理は走らないため、画面に出るまでは何もしない。要求は
 * この部品の寿命に結び付け、部品が外れる (セルが画面外へ出て破棄・再利用される) と取り消す。
 */
private class KsDeferredNode(
    var element: KsDeferredElement,
) : Modifier.Node(), LayoutModifierNode, DrawModifierNode {

    private var hasBeenPlaced = false
    private var painter: Painter? = null
    private var request: Job? = null

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        val placeable = measurable.measure(constraints)
        return layout(placeable.width, placeable.height) {
            if (!hasBeenPlaced) {
                hasBeenPlaced = true
                onShown()
            }
            placeable.place(0, 0)
        }
    }

    private fun onShown() {
        val current = element
        val matched = current.lookupOnShown()
        if (matched != null) {
            // 置かれた同じ描画でこの項目を描く (描画は配置の後に走る)。
            painter = matched.asPainter(current.context)
            current.onImageReady()
            return
        }
        KsImageRequestFactory.markRequested(current.prepared)
        // 要求は配置の中ですぐに始める (次のフレームまで待たない)。取得の待ちに入った時点で戻る。
        request = coroutineScope.launch(start = CoroutineStart.UNDISPATCHED) {
            val result = SingletonImageLoader.get(current.context).execute(current.prepared.request)
            request = null
            when (result) {
                is SuccessResult -> {
                    painter = result.image.asPainter(current.context)
                    invalidateDraw()
                    current.onImageReady()
                }

                is ErrorResult -> current.onFailure()
            }
        }
    }

    override fun ContentDrawScope.draw() {
        val current = painter
        when {
            // 画像を描けるなら、中身 (利用者の読み込み中の表示) は描かない。
            current != null -> drawScaled(current, element.contentScale)
            element.drawsDefaultLoading -> drawRect(KsImageDefaultLoadingColor)
            else -> drawContent()
        }
    }

    override fun onDetach() {
        // 取得の途中で外れたら、次に置かれたときに引き当てからやり直す (要求は部品の寿命で取り消される)。
        if (request != null) {
            request = null
            hasBeenPlaced = false
        }
    }

    override fun onReset() {
        // 再利用のときは組み立ての状態も作り直されるので、部品も最初の状態に戻す。
        request?.cancel()
        request = null
        painter = null
        hasBeenPlaced = false
    }
}

/** 画像を当てはめ方に従って枠の中央へ描く。はみ出た分は根の切り抜きで落ちる。 */
private fun DrawScope.drawScaled(painter: Painter, contentScale: ContentScale) {
    val source = painter.intrinsicSize
    if (source.isUnspecified || source.width <= 0f || source.height <= 0f) {
        with(painter) { draw(size) }
        return
    }
    val scale = contentScale.computeScaleFactor(source, size)
    val target = Size(source.width * scale.scaleX, source.height * scale.scaleY)
    val offset = Alignment.Center.align(
        IntSize(target.width.roundToInt(), target.height.roundToInt()),
        IntSize(size.width.roundToInt(), size.height.roundToInt()),
        layoutDirection,
    )
    translate(offset.x.toFloat(), offset.y.toFloat()) {
        with(painter) { draw(target) }
    }
}

/** 引き当てに失敗したとき、枠の実サイズへ縮小してデコードする要求をローダーへ出して描く。 */
@Composable
private fun KsRequestedImageContent(
    prepared: KsPreparedImageRequest,
    contentScale: ContentScale,
    loading: (@Composable () -> Unit)?,
    failure: (@Composable () -> Unit)?,
) {
    // 要求を出す時点で、その要求が載せる項目の鍵を索引に覚えさせる。完了は待たない。
    remember(prepared) { KsImageRequestFactory.markRequested(prepared) }
    val painter = rememberAsyncImagePainter(model = prepared.request, contentScale = contentScale)
    val state by painter.state.collectAsState()

    when (state) {
        is AsyncImagePainter.State.Success ->
            Image(
                painter = painter,
                // 画像の説明は根に付いているため、ここでは重ねて付けない。
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = contentScale,
            )

        is AsyncImagePainter.State.Error ->
            if (failure != null) failure() else KsImageDefaultFailure()

        else ->
            if (loading != null) loading() else KsImageDefaultLoading()
    }
}

@Composable
private fun KsResourceImageContent(
    source: KsImageSource.Resource,
    contentScale: ContentScale,
    failure: (@Composable () -> Unit)?,
) {
    val context = LocalContext.current
    // リソース ID をそのまま描画へ渡す経路が扱えるのはベクター画像と PNG / JPEG / WebP だけで、
    // 図形・状態リストのような XML は例外になる。どの種類でも描ける drawable に一度起こして
    // から描き、起こせない ID は落とさずに失敗の表示へ落とす (core/ADR-0011)。
    val painter = remember(source.id, context) { context.drawablePainter(source.id) }
    val diagnostics = remember(painter, source.id) {
        if (painter != null) emptyList() else listOf(unreadableResourceMessage(source.id))
    }
    KsDiagnostics.assertValid(context, diagnostics)
    KsDiagnostics.WarnOnce(diagnostics)

    if (painter == null) {
        if (failure != null) failure() else KsImageDefaultFailure()
        return
    }
    Image(
        painter = painter,
        // 画像の説明はこのコンポーネントの根に付く。状態が変わっても読み上げから消えないよう、
        // ここでは重ねて付けない。
        contentDescription = null,
        modifier = Modifier.fillMaxSize(),
        contentScale = contentScale,
    )
}

/** 読み込み中の既定の表示。枠全体を無地で塗るだけで、文字や図形は置かない。 */
@Composable
internal fun KsImageDefaultLoading() {
    Box(modifier = Modifier.fillMaxSize().background(KsImageDefaultLoadingColor))
}

/** 失敗の既定の表示。無地の上に画像が無いことを示す小さな印だけを置く。 */
@Composable
internal fun KsImageDefaultFailure() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        drawRect(color = KsImageDefaultFailureColor)

        // 印は枠の短辺に対する割合で描き、どの大きさの枠でも同じ見え方にする。
        val shortSide = min(size.width, size.height)
        val markSide = shortSide * 0.3f
        val strokeWidth = (shortSide * 0.03f).coerceAtLeast(1f)
        val topLeft = Offset((size.width - markSide) / 2f, (size.height - markSide) / 2f)
        drawRect(
            color = KsImageDefaultMarkColor,
            topLeft = topLeft,
            size = Size(markSide, markSide),
            style = Stroke(width = strokeWidth),
        )
        drawCircle(
            color = KsImageDefaultMarkColor,
            radius = markSide * 0.12f,
            center = topLeft + Offset(markSide * 0.32f, markSide * 0.32f),
        )
    }
}

// 既定表示の無彩色。プラットフォーム標準の灰に寄せた固定値で、テーマには依存しない。
internal val KsImageDefaultLoadingColor = Color(0xFFE0E0E0)
private val KsImageDefaultFailureColor = Color(0xFFBDBDBD)
private val KsImageDefaultMarkColor = Color(0xFF757575)

/** ローダーへ渡す取得元。同梱リソースはローダーを通らないため、そのままの ID を返す。 */
internal fun KsImageSource.loaderModel(): Any = when (this) {
    is KsImageSource.Remote -> url
    is KsImageSource.File -> file
    is KsImageSource.Resource -> id
}

/** 当てはめ方を Compose の当てはめ方に対応させる。 */
internal fun KsImageContentMode.toContentScale(): ContentScale = when (this) {
    KsImageContentMode.Fit -> ContentScale.Fit
    KsImageContentMode.Fill -> ContentScale.Crop
}

/**
 * 同梱リソースを描ける painter にする。描画リソースとして読めない ID では null を返す。
 *
 * 状態リストや図形のような XML も含め、drawable として解決できるものはすべて描ける。
 */
private fun Context.drawablePainter(id: Int): Painter? {
    val drawable = try {
        getDrawable(id)
    } catch (_: Resources.NotFoundException) {
        // 存在しない ID、描画リソースではない ID、読み取りに失敗した XML はここに来る。
        null
    }
    return drawable?.asImage()?.asPainter(this)
}

private fun unreadableResourceMessage(id: Int): String =
    "画像リソース (id=$id) を読み込めません。失敗の表示に切り替えます。"
