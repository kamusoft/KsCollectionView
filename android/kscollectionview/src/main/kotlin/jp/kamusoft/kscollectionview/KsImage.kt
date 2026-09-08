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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
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
 * 画像は表示枠の大きさに合わせて縮小してデコードするため、元の大きさの画像をメモリに置きません。
 * 表示枠の大きさが決まるまでは読み込みを始めません。
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
 * `KsImage(KsImageSource.Remote(url))` と同じ動きになります。
 */
@Composable
public fun KsImage(
    url: String,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    contentMode: KsImageContentMode = KsImageContentMode.Fill,
    loading: (@Composable () -> Unit)? = null,
    failure: (@Composable () -> Unit)? = null,
) {
    KsImage(
        source = KsImageSource.Remote(url),
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
    val cacheKey = source.cacheKey.orEmpty()
    // 世代が進むと読み込みが最初からやり直しになる。キャッシュを消したときに表示中の画像を
    // 読み込み中へ戻すのはこの経路。
    val reloadToken = "${KsImageInvalidation.globalGeneration}:${KsImageInvalidation.generation(cacheKey)}"

    key(source, reloadToken) {
        // 要求の縮小指定にも、メモリにある元寸をその場で縮小するのにも表示枠の大きさが要る。
        // どちらも最初の構成で済ませないと読み込み中の表示が一瞬挟まるため、制約をその場で
        // 読める入れ物で受ける。
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val width = if (constraints.hasBoundedWidth) constraints.maxWidth else 0
            val height = if (constraints.hasBoundedHeight) constraints.maxHeight else 0
            val prepared = remember(source, context, width, height, contentMode) {
                KsImageRequestFactory.prepare(context, source, width, height, contentMode)
            }

            if (prepared == null) {
                // 表示枠の大きさが決まるまでは読み込みを始めない。
                if (loading != null) loading() else KsImageDefaultLoading()
            } else {
                KsPreparedImageContent(
                    prepared = prepared,
                    contentScale = contentScale,
                    loading = loading,
                    failure = failure,
                )
            }
        }
    }
}

@Composable
private fun KsPreparedImageContent(
    prepared: KsPreparedImageRequest,
    contentScale: ContentScale,
    loading: (@Composable () -> Unit)?,
    failure: (@Composable () -> Unit)?,
) {
    val context = LocalContext.current
    val painter = rememberAsyncImagePainter(model = prepared.request, contentScale = contentScale)
    val state by painter.state.collectAsState()
    // ローダーの描画状態は最初の構成では必ず「未開始」になり、メモリキャッシュにある画像でも
    // 状態が決まるまで一拍ある。読み込み中の表示を挟まないよう、その間はメモリから同期で
    // 引いておいた画像を描く。
    // 同期で引ける画像が無い場合 (メモリに何も無いか、載っている元寸の画素を読み出せず
    // その場で縮小できない場合) は読み込み中の表示から始まる。実機で到達点メモリの先読みが
    // 載せた元寸は後者に当たり、初回の表示が読み込み中を一瞬経由する。
    val cachedHolder = remember(prepared, context) {
        mutableStateOf(prepared.cachedImage?.asPainter(context))
    }
    val settled = state is AsyncImagePainter.State.Success || state is AsyncImagePainter.State.Error
    // ローダーの表示が決まったら手放す。表示のために抱え続けると、キャッシュから追い出された
    // 後も残ってしまう。
    LaunchedEffect(settled) {
        if (settled) cachedHolder.value = null
    }
    val cachedPainter = cachedHolder.value

    Box(modifier = Modifier.fillMaxSize()) {
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
                if (cachedPainter != null) {
                    Image(
                        painter = cachedPainter,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = contentScale,
                    )
                } else {
                    if (loading != null) loading() else KsImageDefaultLoading()
                }
        }
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
private val KsImageDefaultLoadingColor = Color(0xFFE0E0E0)
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
