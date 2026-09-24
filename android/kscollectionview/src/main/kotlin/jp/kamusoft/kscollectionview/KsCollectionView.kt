package jp.kamusoft.kscollectionview

import androidx.compose.foundation.Indication
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** テンプレートが宣言されていないキーの要素に使う、最小高の空項目の高さ。 */
private val KsEmptyItemHeight = 1.dp

/** ヘッダー / フッターの再利用種別。項目のテンプレートキーと混ざらないようにする。 */
private object KsHeaderContentType

private object KsFooterContentType

/** テストからタップのフィードバックの発火を観測するための差し替え口。 */
internal object KsTapFeedback {
    internal var indicationOverride: Indication? = null
}

/**
 * 配列をそのまま並べて表示するコレクションコンポーネントです。
 *
 * リストとグリッドは [layout] の値 1 つで切り替えます。要素の描画内容は末尾のブロックで
 * `template` を使って宣言します。
 *
 * ```
 * KsCollectionView(items = fruits, key = { it.id }) {
 *     template { fruit -> Text(fruit.name) }
 * }
 * ```
 *
 * 行の高さが変わったときは、その変化をアニメーションで見せます。アニメーションの間はテンプレートの
 * いちばん外側の要素に行の高さが制約として渡るため、外側の要素が高さの制約を受け取らずに内側だけで
 * 背景を塗っていると、折りたたみの途中で背景の隙間が見えます。外側の要素で背景を塗るか、
 * 外側が `Box` なら `propagateMinConstraints = true` を付けて内側へ高さを渡してください。
 *
 * @param items 表示する要素の配列
 * @param key 要素の安定 ID を返すラムダ。戻り値は同じ配列の中で一意で、かつ
 *   文字列・数値・enum・`Serializable`・`Parcelable` のいずれか (状態保存に載せられる型) にする
 * @param modifier このコンポーネントに適用する修飾
 * @param template 要素からテンプレートのキー値を返すラムダ。省略すると単一テンプレート形になる
 * @param layout 表示形態 (リスト / グリッド) と行間・列間
 * @param contentPadding コンポーネント本体とスクロールするコンテンツの間の内側余白
 * @param header コンテンツ全体の先頭に置く内容。グリッドでは全幅を占める
 * @param footer コンテンツ全体の末尾に置く内容。グリッドでは全幅を占める
 * @param onItemTap 要素がタップされたときに呼ばれるラムダ
 * @param onItemLongTap 要素が長押しされたときに呼ばれるラムダ
 * @param touchFeedbackColor タップ中のフィードバックの色。省略すると標準の色を使う
 * @param listSeparators リストの区切り線を表示するかどうか。グリッドでは表示しない
 * @param listSeparatorColor 区切り線の色。省略するとライブラリ既定の色を使う
 * @param scrollController 外からスクロールさせるためのコントローラ
 * @param prefetchResources もうすぐ表示される要素の画像を、表示より前に取得しておくための宣言。
 *   要素を受け取り、その要素の表示に必要なリモート画像を [KsResource] の配列で返す。先読みする
 *   画像が無い要素では空の配列を返す。省略すると画像の先読みは一切行わない。先読みした画像は、
 *   同じ画像を [KsImage] で表示するときに再ダウンロードなしで使われる。[KsResource] に表示の
 *   おおよその幅を添えると、到達点がメモリのときその幅に縮小した画像をメモリに載せる。このラムダは
 *   表示中に差し替えない前提の宣言で、差し替えた場合は以後に始まる取得にだけ反映される
 * @param prefetchDestination 先読みした画像をどこまで用意しておくか。[KsPrefetchDestination.Memory]
 *   を指定すると、ディスクへの保存に加えてデコード済みの画像をメモリにも載せる
 * @param content テンプレートを宣言するブロック
 */
@Composable
public fun <Item> KsCollectionView(
    items: List<Item>,
    key: (Item) -> Any,
    modifier: Modifier = Modifier,
    template: ((Item) -> Any)? = null,
    layout: KsLayout = KsLayout.List,
    contentPadding: PaddingValues = PaddingValues(0.dp),
    header: (@Composable () -> Unit)? = null,
    footer: (@Composable () -> Unit)? = null,
    onItemTap: ((Item) -> Unit)? = null,
    onItemLongTap: ((Item) -> Unit)? = null,
    touchFeedbackColor: Color? = null,
    listSeparators: Boolean = true,
    listSeparatorColor: Color? = null,
    scrollController: KsScrollController? = null,
    prefetchResources: ((Item) -> List<KsResource>)? = null,
    prefetchDestination: KsPrefetchDestination = KsPrefetchDestination.Disk,
    content: KsCollectionViewScope<Item>.() -> Unit,
) {
    val context = LocalContext.current

    // テンプレートの宣言は毎コンポジションで評価する。テンプレートが親の状態を読む書き方を
    // 成立させるため、初回だけの評価にはしない。
    val scope = KsCollectionViewScope<Item>().apply(content)
    val templates = scope.templates

    // 配列の検査は配列が変わったときだけ行う。セレクタと登録集合を表示中に差し替えないことは
    // 利用契約のため、ラムダの同一性は検査の条件に含めない。
    val plan = remember(items) { resolveItems(items, key, template, context) }
    val displayedItems = plan.items

    // 検査結果は純粋な値として組み立て、停止 (debug) と警告 (release) に分けて扱う。
    // 突き合わせるのはテンプレートキーの種類だけなので、毎コンポジションの手間は件数に依らない。
    val diagnostics = buildList {
        if (scope.duplicatedKeys.isNotEmpty()) {
            add(
                "同じキーに複数のテンプレートが宣言されています: ${scope.duplicatedKeys}。" +
                    "後の宣言を採用して表示を継続します",
            )
        }
        addAll(layout.invalidValueMessages())
        addAll(plan.diagnostics)
        val missingKeys = plan.templateKeys.filterNot { templates.containsKey(it) }
        if (missingKeys.isNotEmpty()) {
            add("テンプレートが宣言されていないキーがあります: $missingKeys。空の項目を表示して継続します")
        }
    }
    KsDiagnostics.assertValid(context, diagnostics)
    KsDiagnostics.WarnOnce(diagnostics)

    val gridState = rememberLazyGridState()

    val receiver = remember(context) { KsScrollCommandReceiver(context) }
    DisposableEffect(scrollController, receiver) {
        scrollController?.attach(receiver)
        onDispose { scrollController?.detach(receiver) }
    }

    // 命令の解決に使う最新の値。配列やヘッダーの有無が変わっても消費側の effect は作り直さない
    // (作り直すと実行中のアニメーションが切れ、キューに残った命令が消えるため)。
    val latestItems by rememberUpdatedState(displayedItems)
    val latestKey by rememberUpdatedState(key)
    val latestLeadingCount by rememberUpdatedState(if (header != null) 1 else 0)
    val latestTotalCount by rememberUpdatedState(
        displayedItems.size + (if (header != null) 1 else 0) + (if (footer != null) 1 else 0),
    )
    // lazy 側の index から再利用種別を引く。対象が可視でないときの高さの推定に使う。
    val latestContentTypeAt by rememberUpdatedState<(Int) -> Any?> { lazyIndex ->
        val itemIndex = lazyIndex - (if (header != null) 1 else 0)
        when {
            itemIndex in displayedItems.indices ->
                template?.invoke(displayedItems[itemIndex]) ?: KsSingleTemplateKey

            itemIndex < 0 -> KsHeaderContentType
            else -> KsFooterContentType
        }
    }
    // 位置合わせの残差を詰める閾値。これ以下のずれは目に見えないため詰めない。
    val alignmentTolerancePx = with(LocalDensity.current) { KsScrollAlignmentTolerance.roundToPx() }

    LaunchedEffect(receiver) {
        // 消費側はコンポジションの生存期間に 1 本だけ立てる。命令は発行順に取り出し、
        // 取り出した時点の最新の配列で解決する。
        var running: Job? = null
        snapshotFlow { receiver.enqueuedCount }.collect {
            // 命令はコンポジションを 1 フレーム待ってから解決する。配列の差し替えと同じ処理で
            // 出された命令も、差し替えが表示へ反映された後の配列で解決される (core/ADR-0007)。
            withFrameNanos { }
            while (true) {
                val command = receiver.dequeue() ?: break
                val target = resolveScrollTarget(
                    command = command,
                    // ID の照合は命令を処理する時点の配列に対して行う。事前に ID の一覧を
                    // 作り置きしないため、保持する情報が件数に比例しない。
                    indexOfId = { id -> latestItems.indexOfFirst { latestKey(it) == id } },
                    leadingItemCount = latestLeadingCount,
                    totalLazyItemCount = latestTotalCount,
                    contentTypeAt = latestContentTypeAt,
                    context = context,
                )
                if (target == null) {
                    // 存在しない ID・削除済みの対象は何もせず後続の命令へ進む。
                    receiver.markProcessed()
                    continue
                }
                // 後から届いた命令は先行する命令のアニメーションを中断して優先する。
                running?.cancel()
                // UNDISPATCHED で始める。次の命令が届くまでに 1 度も動かないままだと、
                // 中断された命令が処理済みとして数えられない。
                running = launch(start = CoroutineStart.UNDISPATCHED) {
                    // 中断された命令も処理済みとして数える (処理完了を待てるようにするため)。
                    try {
                        gridState.performScroll(target, alignmentTolerancePx)
                    } finally {
                        receiver.markProcessed()
                    }
                }
            }
        }
    }

    val separatorColor = listSeparatorColor ?: KsListSeparatorDefaults.color
    val showsSeparators = listSeparators && layout.isList

    // タップのフィードバックはハンドラを宣言した場合だけ出す。色の指定がなければ標準の ripple。
    val hasTapHandler = onItemTap != null || onItemLongTap != null
    val defaultIndication = remember(touchFeedbackColor) {
        if (touchFeedbackColor != null) ripple(color = touchFeedbackColor) else ripple()
    }
    val tapIndication = KsTapFeedback.indicationOverride ?: defaultIndication

    BoxWithConstraints(modifier = modifier) {
        // 向きの判定はコンポーネント自身のコンテナの縦横比で行う (端末の物理向きでは判定しない)。
        val isPortrait = maxHeight > maxWidth
        val cells = resolveGridCells(layout, isPortrait)

        // プリフェッチは宣言があるときだけ組み立てる。宣言が無いコレクションでは可視範囲の
        // 観測も先読みも一切起きない。列の幅はコンテナの幅から解くため、この入れ物の中で組み立てる。
        if (prefetchResources != null) {
            val density = LocalDensity.current
            val layoutDirection = LocalLayoutDirection.current
            val containerWidthPx = if (constraints.hasBoundedWidth) constraints.maxWidth else 0
            val metrics = remember(layout, contentPadding, containerWidthPx, isPortrait, density, layoutDirection) {
                KsPrefetchMetrics(
                    columnWidthPx = resolveColumnWidthPx(
                        layout = layout,
                        containerWidthPx = containerWidthPx,
                        isPortrait = isPortrait,
                        contentPadding = contentPadding,
                        layoutDirection = layoutDirection,
                        density = density,
                    ),
                    density = density.density,
                )
            }
            KsPrefetchWindowEffect(
                gridState = gridState,
                items = displayedItems,
                key = key,
                leadingItemCount = if (header != null) 1 else 0,
                resources = prefetchResources,
                destination = prefetchDestination,
                metrics = metrics,
            )
        }

        LazyVerticalGrid(
            columns = cells,
            state = gridState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = contentPadding,
            verticalArrangement = Arrangement.spacedBy(layout.effectiveRowSpacing),
            horizontalArrangement = Arrangement.spacedBy(layout.effectiveColumnSpacing),
        ) {
            if (header != null) {
                item(
                    span = { GridItemSpan(maxLineSpan) },
                    contentType = KsHeaderContentType,
                ) {
                    // 項目と同じく、高さの変化をアニメーションする。
                    Box(
                        modifier = Modifier.fillMaxWidth().ksAnimatedHeight(),
                        // 高さの制約を content までそのまま渡す (ksAnimatedHeight の前提)。
                        propagateMinConstraints = true,
                    ) {
                        header()
                    }
                }
            }

            items(
                count = displayedItems.size,
                // 安定 ID と再利用種別は表示する要素の分だけその場で解決する。
                key = { index -> key(displayedItems[index]) },
                contentType = { index ->
                    template?.invoke(displayedItems[index]) ?: KsSingleTemplateKey
                },
            ) { index ->
                val item = displayedItems[index]
                val templateKey = template?.invoke(item) ?: KsSingleTemplateKey
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .ksListSeparator(
                            isVisible = showsSeparators,
                            isFirst = index == 0,
                            color = separatorColor,
                        )
                        // 項目内の操作要素が先にタッチを消費するため、そこでは項目のタップも
                        // フィードバックも起きない。スクロールが始まったタッチも取り消される。
                        .then(
                            if (hasTapHandler) {
                                Modifier.combinedClickable(
                                    interactionSource = null,
                                    indication = tapIndication,
                                    onLongClick = onItemLongTap?.let { { it(item) } },
                                    onClick = { onItemTap?.invoke(item) },
                                )
                            } else {
                                Modifier
                            },
                        )
                        // content の高さが変わったときは、項目の高さをその値へ動かして追従する。
                        // 区切り線とタップ領域を動いている途中の高さに合わせるため、それらより
                        // 内側 (content 寄り) に置く。content 自身も途中の高さで測り直されるため、
                        // 中身と区切り線の間に何も描かれない帯はできない。
                        //
                        // content は自然高のまま項目の上端に置き、幅に余りがあれば水平中央に置く
                        // (ios/ADR-0007 と同じ配置規則)。
                        .ksAnimatedHeight(horizontalAlignment = Alignment.CenterHorizontally),
                    // 高さの制約を content までそのまま渡す (ksAnimatedHeight の前提)。
                    propagateMinConstraints = true,
                ) {
                    val itemContent = templates[templateKey]
                    if (itemContent != null) {
                        itemContent(item)
                    } else {
                        // 未登録キーの要素は黙って消さず、最小高の空項目として件数を保つ。
                        Box(Modifier.fillMaxWidth().height(KsEmptyItemHeight))
                    }
                }
            }

            if (footer != null) {
                item(
                    span = { GridItemSpan(maxLineSpan) },
                    contentType = KsFooterContentType,
                ) {
                    Box(
                        modifier = Modifier.fillMaxWidth().ksAnimatedHeight(),
                        propagateMinConstraints = true,
                    ) {
                        footer()
                    }
                }
            }
        }
    }
}

/** layout 値とコンテナの向きから `LazyVerticalGrid` の列指定を作る。list は 1 列グリッド。 */
private fun resolveGridCells(layout: KsLayout, isPortrait: Boolean): GridCells = when (layout) {
    is KsLayout.List -> GridCells.Fixed(1)
    is KsLayout.Grid -> when (val columns = layout.columns) {
        is KsColumns.Fixed -> GridCells.Fixed(columns.resolveCount(isPortrait))
        is KsColumns.Adaptive -> GridCells.Adaptive(columns.minItemWidth.coerceAtLeast(1.dp))
    }
}
