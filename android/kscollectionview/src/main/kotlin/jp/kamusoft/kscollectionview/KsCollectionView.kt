package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VisibilityThreshold
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Indication
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/** テンプレートが宣言されていないキーの要素に使う、最小高の空項目の高さ。 */
private val KsEmptyItemHeight = 1.dp

/** ヘッダー / フッターの再利用種別。項目のテンプレートキーと混ざらないようにする。 */
private object KsHeaderContentType

private object KsFooterContentType

/** グループの見出しの再利用種別。項目のテンプレートキーやルートのヘッダーと混ざらないようにする。 */
internal object KsGroupHeaderContentType

/** テストから、グループの構成を新しく適用した回数を観測するための計数。 */
internal object KsGroupingProbe {
    internal var appliedPlanCount = 0
}

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
 * @param groups 項目をグループに分け、各グループの先頭に見出しを表示するための宣言。省略すると
 *   配列全体を 1 続きで表示する。グループの値の型と見出しの書き方は [KsGroups] を参照
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
    groups: KsGroups<Item, *>? = null,
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

    // グループの構成は、配列・宣言の有無・グループの値のラムダのいずれかが変わったときに求め直す
    // (宣言の型 `KsGroups` は呼び出しのたびに作られるため、ラムダそのものの同一性で比べる)。
    // ラムダが差し替わっても、求め直したグループの構成が適用中と等しければ適用中の構成をそのまま使い、
    // 構成に依存する表 (行の数え方など) を作り直さない。見出しの内容は毎コンポジションで最新を使う。
    val hasGroupHeaders = groups?.header != null
    val pinsGroupHeaders = groups?.pinnedHeaders ?: false
    val groupValueOf = groups?.by
    val resolvedGrouping = remember(
        displayedItems,
        groupValueOf,
        hasGroupHeaders,
        pinsGroupHeaders,
        header != null,
        footer != null,
    ) {
        resolveGroups(
            items = displayedItems,
            groupValueOf = groupValueOf,
            hasHeaders = hasGroupHeaders,
            pinsHeaders = pinsGroupHeaders,
            hasRootHeader = header != null,
            hasRootFooter = footer != null,
        )
    }
    // 構成が等しい間は、最初に求めた構成を保ち続ける (キーの比較は構成の等しさで行う)。行の数え方・
    // index の写像など構成にだけ依存する計算はこちらを使う。構成の等しさはグループの値の等しさで
    // 比べるため、保った構成のグループの値は古いオブジェクトのことがある。見出しへ渡すグループの値は
    // 必ず最新の結果 (`latestGroupPlan`) から取る。
    val groupPlan = remember(resolvedGrouping.plan) {
        KsGroupingProbe.appliedPlanCount++
        resolvedGrouping.plan
    }
    val latestGroupPlan = resolvedGrouping.plan
    val groupHeader = groups?.erasedHeader

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
        addAll(resolvedGrouping.diagnostics)
        val missingKeys = plan.templateKeys.filterNot { templates.containsKey(it) }
        if (missingKeys.isNotEmpty()) {
            add("テンプレートが宣言されていないキーがあります: $missingKeys。空の項目を表示して継続します")
        }
    }
    KsDiagnostics.assertValid(context, diagnostics)
    KsDiagnostics.WarnOnce(diagnostics)

    val gridState = rememberLazyGridState()
    val density = LocalDensity.current
    // 上端の安全領域に重なって置かれたときに、固定中の見出しを止める境目。
    val topSafeArea = rememberKsTopSafeArea()
    val spacing = KsGroupSpacing.of(layout)

    // 命令の解決と位置の保持に使う、最新の列数。列数はコンテナの幅から解くため、下の
    // BoxWithConstraints の中で書き込む。
    val resolvedColumns = remember { KsResolvedColumns() }

    val receiver = remember(context) { KsScrollCommandReceiver(context) }
    DisposableEffect(scrollController, receiver) {
        scrollController?.attach(receiver)
        onDispose { scrollController?.detach(receiver) }
    }

    // 項目の lazy 上の置き場所 (lazy の index と上下の間隔)。命令の解決と位置の保持に使う。
    val placementOf: (Int) -> KsItemPlacement = { itemIndex ->
        placementOfItem(groupPlan, itemIndex, resolvedColumns.count, spacing, density)
    }

    // 命令の解決に使う最新の値。配列やヘッダーの有無が変わっても消費側の effect は作り直さない
    // (作り直すと実行中のアニメーションが切れ、キューに残った命令が消えるため)。
    val latestItems by rememberUpdatedState(displayedItems)
    val latestKey by rememberUpdatedState(key)
    val latestPlan by rememberUpdatedState(groupPlan)
    val latestPlacementOf by rememberUpdatedState(placementOf)
    // lazy 側の index から再利用種別を引く。対象が可視でないときの高さの推定に使う。
    val latestContentTypeAt by rememberUpdatedState<(Int) -> Any?> { lazyIndex ->
        val itemIndex = groupPlan.itemIndexOfLazy(lazyIndex)
        when {
            itemIndex >= 0 -> template?.invoke(displayedItems[itemIndex]) ?: KsSingleTemplateKey
            groupPlan.groupOfHeaderLazy(lazyIndex) >= 0 -> KsGroupHeaderContentType
            groupPlan.isRootHeader(lazyIndex) -> KsHeaderContentType
            else -> KsFooterContentType
        }
    }
    // 位置合わせの残差を詰める閾値。これ以下のずれは目に見えないため詰めない。
    val alignmentTolerancePx = with(density) { KsScrollAlignmentTolerance.roundToPx() }

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
                    placementOfItem = latestPlacementOf,
                    totalLazyItemCount = latestPlan.totalLazyCount,
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
                        gridState.performScroll(target, alignmentTolerancePx, topSafeArea::overlapPx)
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

    // 縦スクロールインジケータ。表示の濃さとスクロール位置は描画フェーズでだけ読む。
    val scrollIndicatorVisibility = rememberKsScrollIndicatorVisibility(gridState)
    val scrollIndicatorColor = KsScrollIndicatorDefaults.color(isSystemInDarkTheme())

    val positionKeeper = remember { KsPositionKeeper<Item>() }
    val appearing = positionKeeper.appearing
    val heightTracker = remember { KsHeightAnimationTracker() }

    // 末尾を表示中の末尾への挿入で、挿入を反映した次のフレームから表示範囲を末尾まで送る。
    // 続けて挿入されたときは、送っている途中から新しい末尾へ送り直す。
    LaunchedEffect(positionKeeper, gridState) {
        var handled = positionKeeper.endFollowRequestCount
        snapshotFlow { positionKeeper.endFollowRequestCount }.collectLatest { count ->
            if (count == handled) return@collectLatest
            handled = count
            // 挿入を反映した測定を待つ。
            withFrameNanos { }
            positionKeeper.followEnd(gridState)
        }
    }

    BoxWithConstraints(modifier = modifier.then(topSafeArea.modifier)) {
        // 向きの判定はコンポーネント自身のコンテナの縦横比で行う (端末の物理向きでは判定しない)。
        val isPortrait = maxHeight > maxWidth
        val cells = resolveGridCells(layout, isPortrait)
        val layoutDirection = LocalLayoutDirection.current
        val containerWidthPx = if (constraints.hasBoundedWidth) constraints.maxWidth else 0
        // 行の数え方・項目の上下の間隔・行末の埋め方に使う列数。`LazyVerticalGrid` と同じ規則で解く。
        val columns = resolveColumnCount(layout, containerWidthPx, isPortrait, contentPadding, layoutDirection, density)
        val rows = remember(groupPlan, columns) { groupPlan.rows(columns) }

        // 位置の保持は、新しい配置を測る前 (直前の配置が残っている間) に判定して要求する。
        SideEffect {
            resolvedColumns.count = columns
            positionKeeper.onUpdate(
                state = gridState,
                items = displayedItems,
                key = key,
                plan = groupPlan,
                columns = columns,
                placementOf = { itemIndex -> placementOfItem(groupPlan, itemIndex, columns, spacing, density) },
                safeTopPx = topSafeArea.overlapPx(),
            )
        }

        // プリフェッチは宣言があるときだけ組み立てる。宣言が無いコレクションでは可視範囲の
        // 観測も先読みも一切起きない。列の幅はコンテナの幅から解くため、この入れ物の中で組み立てる。
        if (prefetchResources != null) {
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
                plan = groupPlan,
                resources = prefetchResources,
                destination = prefetchDestination,
                metrics = metrics,
            )
        }

        // 見出しのないグループの最後の項目が行の残りを占めるときの、content の幅 (1 列分)。
        val cellWidths = if (groupPlan.groupCount > 1 && !groupPlan.hasHeaders && columns > 1) {
            resolveCellWidthsPx(layout, containerWidthPx, columns, contentPadding, layoutDirection, density)
        } else {
            null
        }

        LazyVerticalGrid(
            columns = cells,
            state = gridState,
            modifier = Modifier
                .fillMaxSize()
                .ksScrollIndicator(gridState, scrollIndicatorVisibility, scrollIndicatorColor, rows),
            contentPadding = contentPadding,
            // 行間は項目の上下の余白として置く (KsGroupSpacing)。ここで一律に入れると、見出しと
            // ヘッダー / フッターの前後にも入ってしまう。
            verticalArrangement = Arrangement.Top,
            horizontalArrangement = Arrangement.spacedBy(layout.effectiveColumnSpacing),
        ) {
            if (header != null) {
                item(
                    key = KsRootSlotKey.Header,
                    span = { GridItemSpan(maxLineSpan) },
                    contentType = KsHeaderContentType,
                ) {
                    KsFullSpanBox(heightTracker, animatesPlacement = true) { header() }
                }
            }

            for (group in 0 until groupPlan.groupCount) {
                val start = groupPlan.groupStart(group)
                val count = groupPlan.groupEnd(group) - start
                if (groupHeader != null && groupPlan.hasHeaders) {
                    // 見出しも項目と同じく、グループの並べ替え・消滅・出現をアニメーションで見せる
                    // (固定中の見出しを含む)。見出しのキーはグループの値で決まるため、並べ替えでは
                    // グループの項目と一緒に動く。
                    // 構成が等しければ境目も等しいので、同じ番号のグループの最新の値を引ける。
                    val value = latestGroupPlan.groupValue(group)
                    val groupItems = displayedItems.subList(start, start + count)
                    val headerKey = groupPlan.headerKey(group)
                    if (groupPlan.pinsHeaders) {
                        stickyHeader(
                            key = headerKey,
                            contentType = KsGroupHeaderContentType,
                        ) {
                            KsFullSpanBox(
                                heightTracker,
                                animatesPlacement = true,
                                appearance = Modifier
                                    .ksAppearance(headerKey, appearing)
                                    .ksPinnedHeaderSafeArea(headerKey, gridState, topSafeArea),
                            ) { groupHeader(value, groupItems) }
                        }
                    } else {
                        item(
                            key = headerKey,
                            span = { GridItemSpan(maxLineSpan) },
                            contentType = KsGroupHeaderContentType,
                        ) {
                            KsFullSpanBox(
                                heightTracker,
                                animatesPlacement = true,
                                appearance = Modifier.ksAppearance(headerKey, appearing),
                            ) { groupHeader(value, groupItems) }
                        }
                    }
                }

                // 見出しのないグループが行の途中で終わるときは、最後の項目に行の残りを占めさせ、
                // 次のグループを行頭から始める。
                val fillsLastLine = cellWidths != null && group < groupPlan.groupCount - 1 && count % columns != 0
                items(
                    count = count,
                    // 安定 ID と再利用種別は表示する要素の分だけその場で解決する。
                    key = { local -> key(displayedItems[start + local]) },
                    span = if (fillsLastLine) {
                        { local -> GridItemSpan(if (local == count - 1) maxCurrentLineSpan else 1) }
                    } else {
                        null
                    },
                    contentType = { local ->
                        template?.invoke(displayedItems[start + local]) ?: KsSingleTemplateKey
                    },
                ) { local ->
                    val item = displayedItems[start + local]
                    val templateKey = template?.invoke(item) ?: KsSingleTemplateKey
                    val cellWidth = if (fillsLastLine && local == count - 1) {
                        cellWidths?.getOrNull(local % columns)
                    } else {
                        null
                    }
                    KsAnimatedItemBox(
                        tracker = heightTracker,
                        modifier = Modifier
                            .ksAppearance(key(item), appearing)
                            .fillMaxWidth()
                            .then(
                                if (cellWidth != null) {
                                    Modifier
                                        .wrapContentWidth(Alignment.Start)
                                        .width(with(density) { cellWidth.toDp() })
                                } else {
                                    Modifier
                                },
                            )
                            // 行間・見出しの下の間隔・グループ間の間隔は項目の外側の余白として置く。
                            // 区切り線・タップ領域・高さの補間はその内側 (content の範囲) に効かせる。
                            .ksItemSpacing(
                                top = groupPlan.topSpacing(local, columns, spacing),
                                bottom = groupPlan.bottomSpacing(group, local, columns, spacing),
                            )
                            .ksListSeparator(
                                isVisible = showsSeparators,
                                // 上端の線はグループの先頭行に引く。見出しが無いときは最初のグループだけ
                                // (グループの境目に線が 2 本並ばないように。core/ADR-0016)。
                                isFirst = local / columns == 0 && (groupPlan.hasHeaders || group == 0),
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
                            .ksAnimatedHeight(Alignment.CenterHorizontally, heightTracker),
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
            }

            if (footer != null) {
                // フッターも項目と一緒に動かす。項目だけが配置のアニメーションで動くと、項目の挿入・
                // 削除の間にフッターが先に飛び、項目と重なったり隙間が空いたりする。
                item(
                    key = KsRootSlotKey.Footer,
                    span = { GridItemSpan(maxLineSpan) },
                    contentType = KsFooterContentType,
                ) {
                    KsFullSpanBox(heightTracker, animatesPlacement = true) { footer() }
                }
            }
        }
    }
}

/**
 * 全幅の項目 (ルートのヘッダー / フッター・グループの見出し) の入れ物。
 *
 * 項目と同じく、中身の高さの変化をアニメーションする。
 *
 * @param tracker 同じコレクションの高さの補間の状態
 * @param animatesPlacement 配列の差し替えによる配置の変化をアニメーションさせるかどうか
 * @param appearance 配置のアニメーションの内側に付ける、出現のフェードの修飾
 */
@Composable
private fun LazyGridItemScope.KsFullSpanBox(
    tracker: KsHeightAnimationTracker,
    animatesPlacement: Boolean = false,
    appearance: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .then(if (animatesPlacement) ksAnimateItem(tracker) else Modifier)
            .then(appearance)
            .fillMaxWidth()
            .ksAnimatedHeight(tracker = tracker),
        // 高さの制約を content までそのまま渡す (ksAnimatedHeight の前提)。
        propagateMinConstraints = true,
    ) {
        content()
    }
}

/**
 * 項目の入れ物。配列の差し替えによる移動・挿入・削除をアニメーションで見せる (出入りはフェード)。
 *
 * 配置のアニメーションは修飾のいちばん外側に付け、間隔・区切り線・タップ領域を含む項目全体を
 * 一緒に動かす (android/ADR-0006)。高さの補間の状態はこの関数の中でだけ読み、補間の開始と終了で
 * 項目の中身 (テンプレート) まで作り直さないようにする。
 *
 * @param modifier 配置のアニメーションの内側に付ける修飾
 */
@Composable
private fun LazyGridItemScope.KsAnimatedItemBox(
    tracker: KsHeightAnimationTracker,
    modifier: Modifier,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = ksAnimateItem(tracker).then(modifier),
        // 高さの制約を content までそのまま渡す (ksAnimatedHeight の前提)。
        propagateMinConstraints = true,
    ) {
        content()
    }
}

/** 配置のアニメーションの既定 (`animateItem` の既定と同じばね)。 */
private val KsItemPlacementSpec = spring(
    stiffness = Spring.StiffnessMediumLow,
    visibilityThreshold = IntOffset.VisibilityThreshold,
)

/**
 * 配列の差し替えによる配置の変化をアニメーションさせる。
 *
 * 行の高さの補間が進行中の間は、配置の変化をアニメーションさせない。補間で押し出される行は
 * 毎フレーム少しずつ動くため、アニメーションで追いかけると高さの変化に遅れ、行の間に何も
 * 描かれない帯ができる。出入りのフェードは補間の間も保つ。
 *
 * 補間の状態はコンポジションの中で読む (補間の開始と終了で呼び出し元が作り直される)。
 */
private fun LazyGridItemScope.ksAnimateItem(tracker: KsHeightAnimationTracker): Modifier =
    Modifier.animateItem(placementSpec = if (tracker.isAnimating) null else KsItemPlacementSpec)

/**
 * 固定中の見出しを、上端の安全領域の境目より上へ行かせない。
 *
 * コレクションが安全領域に重なって置かれたとき (edge-to-edge で画面の上端まで広げたとき) だけ
 * 見出しを動かす。行はバーの裏を流れたまま、固定中の見出しだけがバーのすぐ下で止まり、次の見出しに
 * 押し上げられるときもその境目から押し上げられる。重なりが無ければ何もしない。
 *
 * 見出しは行より前面に描く。Compose が固定するのは 1 つの見出しだけで、次の見出しが境目より上に
 * 来た間はふつうの項目として並ぶ。その見出しを境目まで下げると自分のグループの行と重なるため、
 * 行の裏に隠れないようにする。
 */
private fun Modifier.ksPinnedHeaderSafeArea(
    headerKey: Any,
    gridState: LazyGridState,
    topSafeArea: KsTopSafeArea,
): Modifier = zIndex(1f).layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    layout(placeable.width, placeable.height) {
        // 安全領域の重なりと配置は配置の中で読み、スクロールのたびの見直しを配置だけに留める。
        val safeTopPx = topSafeArea.overlapPx()
        val shift = if (safeTopPx > 0) {
            val info = gridState.layoutInfo
            info.visibleItemsInfo.firstOrNull { it.key == headerKey }
                ?.let { info.ksPinnedHeaderOffset(it, safeTopPx) - it.offset.y }
                ?: 0
        } else {
            0
        }
        placeable.place(0, shift)
    }
}

/** 項目の上下に間隔を置く。間隔が無いときは修飾を足さない。 */
private fun Modifier.ksItemSpacing(top: Dp, bottom: Dp): Modifier =
    if (top > 0.dp || bottom > 0.dp) padding(top = top, bottom = bottom) else this

/** 命令の解決と位置の保持が読む、最後に解いた列数。 */
private class KsResolvedColumns {
    var count: Int = 1
}

/** 項目の位置から、lazy の index・上下の間隔 (ピクセル)・固定される見出しのキーを求める。 */
private fun placementOfItem(
    plan: KsGroupPlan,
    itemIndex: Int,
    columns: Int,
    spacing: KsGroupSpacing,
    density: Density,
): KsItemPlacement {
    val group = plan.groupOfItem(itemIndex)
    val position = itemIndex - plan.groupStart(group)
    val columnCount = columns.coerceAtLeast(1)
    return with(density) {
        KsItemPlacement(
            lazyIndex = plan.lazyIndexOfItem(itemIndex),
            leadingInsetPx = plan.topSpacing(position, columnCount, spacing).roundToPx(),
            trailingInsetPx = plan.bottomSpacing(group, position, columnCount, spacing).roundToPx(),
            pinnedHeaderKey = if (plan.pinsHeaders) plan.headerKey(group) else null,
        )
    }
}

/**
 * 各列の幅 (ピクセル) を `LazyVerticalGrid` と同じ規則で求める。割り切れない余りは先頭の列から
 * 1 ピクセルずつ配る。
 */
private fun resolveCellWidthsPx(
    layout: KsLayout,
    containerWidthPx: Int,
    columns: Int,
    contentPadding: PaddingValues,
    layoutDirection: LayoutDirection,
    density: Density,
): IntArray? = with(density) {
    val horizontalPadding = contentPadding.calculateLeftPadding(layoutDirection).roundToPx() +
        contentPadding.calculateRightPadding(layoutDirection).roundToPx()
    val spacing = layout.effectiveColumnSpacing.roundToPx()
    val withoutSpacing = containerWidthPx - horizontalPadding - spacing * (columns - 1)
    if (withoutSpacing <= 0) return null
    val slot = withoutSpacing / columns
    val remainder = withoutSpacing % columns
    IntArray(columns) { column -> slot + if (column < remainder) 1 else 0 }
}

/** layout 値とコンテナの向きから `LazyVerticalGrid` の列指定を作る。list は 1 列グリッド。 */
private fun resolveGridCells(layout: KsLayout, isPortrait: Boolean): GridCells = when (layout) {
    is KsLayout.List -> GridCells.Fixed(1)
    is KsLayout.Grid -> when (val columns = layout.columns) {
        is KsColumns.Fixed -> GridCells.Fixed(columns.resolveCount(isPortrait))
        is KsColumns.Adaptive -> GridCells.Adaptive(columns.minItemWidth.coerceAtLeast(1.dp))
    }
}
