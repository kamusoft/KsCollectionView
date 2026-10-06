package jp.kamusoft.kscollectionview

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.VisibilityThreshold
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Indication
import androidx.compose.foundation.OverscrollEffect
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.rememberOverscrollEffect
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.ScrollableDefaults
import androidx.compose.foundation.gestures.scrollable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.foundation.lazy.grid.LazyGridLayoutInfo
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.pullToRefresh
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LocalPinnableContainer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Constraints
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

/**
 * ドラッグ中のグループの宣言の変化。
 *
 * @property plan ドラッグ中に元の並びを表示するときの構成
 * @property changed 宣言が変わったか (ドラッグを取りやめる)
 */
private class KsReorderGroupsChange(val plan: KsGroupPlan, val changed: Boolean)

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

/** テストから、次ページ要求の判定に使った画面に出ている項目の材料を観測するための控え。 */
internal object KsPagingProbe {
    internal var visibleItemCount = -1
    internal var lastVisibleIndex: Int? = null
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
 * @param onItemLongTap 要素が長押しされたときに呼ばれるラムダ。[reorder] のスイッチが有効の間は呼ばれない
 * @param touchFeedbackColor タップ中のフィードバック (波紋) の色。省略すると標準の色を使う。使われるのは
 *   渡した色の色みだけで、濃さは標準の波紋が決める (渡した色の不透明度は濃さに効かない)。iOS 版は渡した色を
 *   不透明度を含めてそのまま塗るため、両プラットフォームで近い見え方にするには半透明の色を渡す
 * @param listSeparators リストの区切り線を表示するかどうか。グリッドでは表示しない
 * @param listSeparatorColor 区切り線の色。指定した色はそのまま使う (表示モードで別の色に差し替えない)。
 *   省略するとライブラリ既定の色を使う。既定の色はライト用とダーク用の 2 つがあり、画面の構成の夜間モード
 *   (`isSystemInDarkTheme()` が返す値。通常は端末の表示モードに追随し、アプリが画面の構成を上書きした
 *   ときはその値) で選ばれ、表示中に切り替わるとその場で追随する。Material のテーマの配色は見ないため、
 *   画面の構成を変えずに Material の配色だけでダークにするアプリは色を指定する
 * @param scrollController 外からスクロールさせるためのコントローラ
 * @param prefetchResources もうすぐ表示される要素の画像を、表示より前に取得しておくための宣言。
 *   要素を受け取り、その要素の表示に必要なリモート画像を [KsResource] の配列で返す。先読みする
 *   画像が無い要素では空の配列を返す。省略すると画像の先読みは一切行わない。先読みした画像は、
 *   同じ画像を [KsImage] で表示するときに再ダウンロードなしで使われる。[KsResource] に表示の
 *   おおよその幅を添えると、到達点がメモリのときその幅に縮小した画像をメモリに載せる。このラムダは
 *   表示中に差し替えない前提の宣言で、差し替えた場合は以後に始まる取得にだけ反映される
 * @param prefetchDestination 先読みした画像をどこまで用意しておくか。[KsPrefetchDestination.Memory]
 *   を指定すると、ディスクへの保存に加えてデコード済みの画像をメモリにも載せる
 * @param paging ページング (無限スクロール) の設定。状態・次のページを読み込む処理・しきい値と、
 *   読み込み中・失敗・終端・空の表示を渡す。省略すると次のページを頼まず、ページングの表示も出さない。
 *   詳しくは [KsPaging] を参照
 * @param onRefresh Pull to Refresh で呼ぶ取り直しの処理。渡すと、一覧の先頭で引っ張って取り直せる
 *   (項目が 0 件でも引っ張れる)。インジケータは引っ張ってから処理が終わるまで出し、処理が終わった後は
 *   ページングの状態が [KsPagingState.Refreshing] の間だけ出し続ける。ページングの状態が
 *   [KsPagingState.Appending] の間と、次のページを読み込む処理の実行中は引っ張れない。引っ張ってから
 *   インジケータが消えるまでの間に届いた配列の差し替えは、ページングの有無によらず先頭から表示する。
 *   省略すると引っ張れない
 * @param reorder 項目を長押ししてドラッグで並べ替えられるようにする設定。スイッチ・置いたときの処理・
 *   動かせるかと置けるかの判定・読み上げの移動操作の文言を渡す。スイッチが有効の間は長押しが並べ替えの
 *   操作になり、[onItemLongTap] は呼ばれない。省略すると並べ替えはできない。詳しくは [KsReorder] を参照
 * @param loadingIndicatorColor 一覧が出す読み込み中の表示の色。[paging] の次のページの読み込み中と
 *   最初の読み込み中のうち差し替えていない標準の表示と、Pull to Refresh ([onRefresh]) のインジケータに
 *   同時に効く。ページングを付けない一覧でも Pull to Refresh のインジケータに効く。[KsPaging] の
 *   `appendingIndicator` / `loadingPlaceholder` で差し替えた表示には効かないため、差し替えた表示の色は
 *   その表示の中で決める。Pull to Refresh のインジケータでは矢印に効き、丸い下地はテーマの色のまま変わらない。
 *   テーマと合わない色 (明るいテーマで白など) を指定すると、下地の上で矢印が見えにくくなることがある。
 *   省略すると標準の色のまま (ページングの 2 つはテーマの primary、Pull to Refresh は Material の既定の色)
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
    paging: KsPaging? = null,
    onRefresh: (suspend () -> Unit)? = null,
    reorder: KsReorder<Item>? = null,
    loadingIndicatorColor: Color? = null,
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
    // 利用者から届いた配列 (重複を畳んだもの)。並べ替えのドラッグ中と、受け入れた後に VM の配列を待つ間は、
    // 表示する並び (displayedItems) がこれと違う。
    val incomingItems = plan.items

    // ページングを付けた一覧では、ページングの表示を載せるためにルートのフッターの枠を常に置く。
    val hasFooterSlot = footer != null || paging != null

    // グループの構成は、配列・宣言の有無・グループの値のラムダのいずれかが変わったときに求め直す
    // (宣言の型 `KsGroups` は呼び出しのたびに作られるため、ラムダそのものの同一性で比べる)。
    // ラムダが差し替わっても、求め直したグループの構成が適用中と等しければ適用中の構成をそのまま使い、
    // 構成に依存する表 (行の数え方など) を作り直さない。見出しの内容は毎コンポジションで最新を使う。
    val hasGroupHeaders = groups?.header != null
    val pinsGroupHeaders = groups?.pinnedHeaders ?: false
    val groupValueOf = groups?.by
    val resolvedGrouping = remember(
        incomingItems,
        groupValueOf,
        hasGroupHeaders,
        pinsGroupHeaders,
        header != null,
        hasFooterSlot,
    ) {
        resolveGroups(
            items = incomingItems,
            groupValueOf = groupValueOf,
            hasHeaders = hasGroupHeaders,
            pinsHeaders = pinsGroupHeaders,
            hasRootHeader = header != null,
            hasRootFooter = hasFooterSlot,
        )
    }

    val gridState = rememberLazyGridState()
    val haptics = LocalHapticFeedback.current

    // ---- 並べ替え ----
    // ドラッグ中は届いた配列を当てずに仮の並びを表示し、受け入れた後は VM の配列が届くまで置いた並びを
    // 表示する (core/ADR-0026、core/ADR-0027、core/ADR-0033)。
    val reorderScope = rememberCoroutineScope()
    val reorderController = remember(gridState, reorderScope) { KsReorderController<Item>(gridState, reorderScope) }
    val reorderEnabled = reorder?.enabled == true
    @Suppress("UNCHECKED_CAST")
    val groupDeclaration = KsGroupDeclaration(
        by = groupValueOf as ((Any?) -> Any?)?,
        hasHeaders = hasGroupHeaders,
        pinsHeaders = groups?.pinnedHeaders ?: false,
    )
    val reorderDrag = reorderController.drag
    // ドラッグ中にグループの宣言が変わったかと、ドラッグ中に元の並びを表示するときの構成。
    //
    // 宣言が変わったかは、持ち上げたときの並びを前後の宣言で組み直した構成が違うかで決める。グループの値の
    // ラムダは、Composable ではない関数の中で作る書き方だと描き直しのたびに別のインスタンスになるため、
    // 同一性の違いだけでは変わったとみなさない。持ち上げたときの並びが受け入れた後の置いた並び (動かした項目の
    // グループの値がまだ古い) のこともあるため、持ち上げたときの構成とではなく、同じ並びを前の宣言で組んだ構成と
    // 比べる。変わっていなければ、元の並びは持ち上げたときの構成で表示する。
    val reorderGroupsChange = remember(
        reorderDrag,
        groupValueOf,
        hasGroupHeaders,
        pinsGroupHeaders,
        header != null,
        hasFooterSlot,
    ) {
        reorderDrag?.let { current ->
            val leading = if (header != null) 1 else 0
            val ownPlan = current.basePlan.withRootSlots(leading, hasFooterSlot)
            if (current.groupDeclaration.isSame(groupDeclaration)) return@let KsReorderGroupsChange(ownPlan, false)
            val resolve = { by: ((Any?) -> Any?)?, declaration: KsGroupDeclaration ->
                resolveGroups(
                    items = current.baseItems,
                    groupValueOf = by,
                    hasHeaders = declaration.hasHeaders,
                    pinsHeaders = declaration.pinsHeaders,
                    hasRootHeader = header != null,
                    hasRootFooter = hasFooterSlot,
                ).plan
            }
            val next = resolve(groupDeclaration.by, groupDeclaration)
            val changed = !current.groupDeclaration.isSameShape(groupDeclaration) ||
                next != resolve(current.groupDeclaration.by, current.groupDeclaration)
            KsReorderGroupsChange(if (changed) next else ownPlan, changed)
        }
    }
    // ドラッグ中にスイッチが無効になった・layout 値かグループの宣言が変わったら取りやめる (core/ADR-0031)。
    val cancelsReorderDrag = reorderDrag != null && !reorderDrag.isCancelled && (
        !reorderEnabled || reorderDrag.layout != layout || reorderGroupsChange?.changed == true
        )
    val reorderShown = reorderController.shown(
        incoming = incomingItems,
        originalPlan = { reorderGroupsChange?.plan ?: resolvedGrouping.plan },
        leadingCount = if (header != null) 1 else 0,
        hasFooter = hasFooterSlot,
        cancelsDrag = cancelsReorderDrag,
        // 受け入れた後にグループの宣言を変えたら、置いた並びの構成は使えないため待つのをやめる。
        awaitingMatches = { waiting -> waiting.groupDeclaration.isSameShape(groupDeclaration) },
    )
    val displayedItems = reorderShown?.items ?: incomingItems
    val shownGroupPlan = reorderShown?.plan ?: resolvedGrouping.plan
    SideEffect {
        if (cancelsReorderDrag) reorderController.cancel()
        // 受け入れた後に待っていた配列と違う配列が届いたら、待つのをやめてその並びに従う。
        if (reorderController.awaiting != null && reorderController.drag == null && reorderShown == null) {
            reorderController.stopAwaiting()
        }
    }

    // 構成が等しい間は、最初に求めた構成を保ち続ける (キーの比較は構成の等しさで行う)。行の数え方・
    // index の写像など構成にだけ依存する計算はこちらを使う。構成の等しさはグループの値の等しさで
    // 比べるため、保った構成のグループの値は古いオブジェクトのことがある。見出しへ渡すグループの値は
    // 必ず最新の結果 (`latestGroupPlan`) から取る。
    val groupPlan = remember(shownGroupPlan) {
        KsGroupingProbe.appliedPlanCount++
        shownGroupPlan
    }
    val latestGroupPlan = shownGroupPlan
    val groupHeader = groups?.erasedHeader
    // 読み上げの移動操作の行き先を求める部品。表示中の並びの構成が変わったときだけ作り直す。
    val reorderPlanner = remember(groupPlan) { KsReorderPlanner(groupPlan) }

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
        // しきい値の誤りは、値が変わったときにだけ警告ログへ出る (文言に値を含めるため)。
        paging?.invalidThresholdMessage()?.let { add(it) }
        val missingKeys = plan.templateKeys.filterNot { templates.containsKey(it) }
        if (missingKeys.isNotEmpty()) {
            add("テンプレートが宣言されていないキーがあります: $missingKeys。空の項目を表示して継続します")
        }
    }
    KsDiagnostics.assertValid(context, diagnostics)
    KsDiagnostics.WarnOnce(diagnostics)

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
        snapshotFlow { receiver.enqueuedCount to reorderController.isHolding }.collect { (_, holding) ->
            // 並べ替えのドラッグで配列を控えている間は命令を溜めておき、ドラッグが終わって配列を表示に
            // 当てた後に、受けた順に実行する (core/ADR-0007、core/ADR-0033)。
            if (holding) return@collect
            // 命令はコンポジションを 1 フレーム待ってから解決する。配列の差し替えと同じ処理で
            // 出された命令も、差し替えが表示へ反映された後の配列で解決される (core/ADR-0007)。
            withFrameNanos { }
            while (true) {
                if (reorderController.isHolding) break
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

    // ライブラリが値を持つ既定の色 (区切り線とスクロールインジケータ) は、一覧が置かれた画面の構成の
    // 夜間モードで選ぶ。Material のテーマの配色は判定に使わない (core/ADR-0036)。読むのは一覧ごとに
    // 1 回で、項目ごとには読まない。
    val isDarkTheme = isSystemInDarkTheme()
    // 利用者が指定した色はそのまま使い、指定が無いときだけ表示モードの側の既定の色にする。
    val separatorColor = listSeparatorColor ?: KsListSeparatorDefaults.color(isDarkTheme)
    val showsSeparators = listSeparators && layout.isList

    // タップのフィードバックはハンドラを宣言した場合だけ出す。色の指定がなければ標準の ripple。
    // 並べ替えのスイッチが有効の間は、長押しは並べ替えの操作になるため長押しの知らせをハンドラに数えない
    // (core/ADR-0031)。
    val hasTapHandler = onItemTap != null || (onItemLongTap != null && !reorderEnabled)
    val itemLongTap = if (reorderEnabled) null else onItemLongTap
    // 指定した色は加工せずに標準の波紋へ渡す。波紋は色みだけを使い、濃さは標準の波紋が決める
    // (core/ADR-0037)。
    val defaultIndication = remember(touchFeedbackColor) {
        if (touchFeedbackColor != null) ripple(color = touchFeedbackColor) else ripple()
    }
    val tapIndication = KsTapFeedback.indicationOverride ?: defaultIndication

    // 縦スクロールインジケータ。表示の濃さとスクロール位置は描画フェーズでだけ読む。
    // 一覧に重ねた表示 (差し替えた次のページの読み込み中) から始めたドラッグも、一覧のスクロールとして
    // インジケータに知らせるための知らせの経路。一覧自身のドラッグの知らせは一覧の内部にあり渡せないため分ける。
    val overlayDragInteractions = remember { MutableInteractionSource() }
    val scrollIndicatorVisibility = rememberKsScrollIndicatorVisibility(gridState, overlayDragInteractions)
    // 端で伸びる効果 (オーバースクロール)。一覧と、一覧に重ねた表示から始めたドラッグで同じ実体を使う。
    val overscrollEffect = rememberOverscrollEffect()
    val scrollIndicatorColor = KsScrollIndicatorDefaults.color(isDarkTheme)

    val positionKeeper = remember { KsPositionKeeper<Item>() }
    val appearing = positionKeeper.appearing
    val heightTracker = remember { KsHeightAnimationTracker() }

    // ---- ページングと Pull to Refresh ----
    // 次ページ要求と取り直しの処理は、一覧のコンポジションに結びついたスコープで実行する。一覧が
    // コンポジションを離れると、実行中の処理はスコープごと取り消される (core/ADR-0022)。
    val actionScope = rememberCoroutineScope()
    val pagingRequester = remember { KsPagingRequester() }
    val itemsVersionTracker = remember { KsPagingItemsVersion() }
    val itemsVersion = if (paging != null) {
        // 版は利用者から届いた配列で数える (並べ替えの仮の並びは数えない)。
        itemsVersionTracker.versionOf(incomingItems)
    } else {
        itemsVersionTracker.reset()
        0
    }
    val latestPaging by rememberUpdatedState(paging)
    val latestItemsVersion by rememberUpdatedState(itemsVersion)
    // 失敗の表示に渡す再試行の操作。状態が失敗なら、項目が 0 件かどうかと Pull to Refresh の有無によらず
    // 次ページ要求を呼ぶ (core/ADR-0019)。
    val retryPaging: () -> Unit = remember(pagingRequester, actionScope) {
        {
            latestPaging?.let { current ->
                pagingRequester.retry(actionScope, current.state, latestItemsVersion, current.onLoadMore)
            }
        }
    }
    // 頼んだ時点からの状態と配列の版の変化は、判定を飛ばす間 (配置がまだ測られていない間など) にも
    // 見落とさないよう、判定とは別に反映のたびに知らせる (core/ADR-0022)。
    if (paging != null) {
        val observedState = paging.state
        SideEffect { pagingRequester.observe(observedState, itemsVersion) }
    }
    // 一覧が破棄されたら、実行中の次ページ要求の処理を取り消す (core/ADR-0022)。処理を起動したスコープも
    // 同時に取り消されるが、取り消しを二度行っても害は無い。
    DisposableEffect(pagingRequester) {
        onDispose { pagingRequester.cancel() }
    }
    if (paging != null) {
        LaunchedEffect(gridState, pagingRequester) {
            // スクロール・配列の差し替え・状態やしきい値の変化・一覧の大きさの変化・処理の終わりのどれでも
            // 判定の材料が変わるため、材料をまとめて観測して判定し直す (core/ADR-0020)。
            snapshotFlow {
                pagingInput(
                    info = gridState.layoutInfo,
                    plan = latestPlan,
                    paging = latestPaging,
                    itemsVersion = latestItemsVersion,
                    isRunning = pagingRequester.isRunning,
                    isReorderHolding = reorderController.isHolding,
                )
            }.collect { input ->
                val current = latestPaging ?: return@collect
                if (input == null) return@collect
                KsPagingProbe.visibleItemCount = input.visibleItemCount
                KsPagingProbe.lastVisibleIndex = input.lastVisibleIndex
                pagingRequester.requestIfNeeded(
                    scope = actionScope,
                    state = input.state,
                    itemsVersion = input.itemsVersion,
                    itemCount = input.itemCount,
                    visibleItemCount = input.visibleItemCount,
                    lastVisibleIndex = input.lastVisibleIndex,
                    threshold = input.threshold,
                    action = current.onLoadMore,
                )
            }
        }
    }

    val pullRefresh = remember { KsPullRefresh() }
    val pullToRefreshState = rememberPullToRefreshState()
    val latestOnRefresh by rememberUpdatedState(onRefresh)
    val pagingState = paging?.state
    val showsRefreshIndicator = onRefresh != null && pullRefresh.isIndicatorShown(pagingState)
    // 引っ張って始めた取り直しの間か。インジケータを消す判定 (下の SideEffect) より前の、このコンポジションの
    // 値を控え、この間に届いた差し替えを先頭から表示する位置の保持に渡す。
    val isPullRefreshing = onRefresh != null && pullRefresh.isPullRefreshing
    // 追加読み込みの間 (状態が追加読み込み中の間と、次ページ要求の処理の実行中) は引っ張れない (core/ADR-0023)。
    val acceptsPull = !(pagingState == KsPagingState.Appending || pagingRequester.isRunning)
    SideEffect {
        if (onRefresh == null) pullRefresh.detach() else pullRefresh.finishIfDone(pagingState)
    }
    val pullToRefreshModifier = if (onRefresh != null) {
        Modifier.pullToRefresh(
            isRefreshing = showsRefreshIndicator,
            state = pullToRefreshState,
            enabled = acceptsPull,
            onRefresh = {
                latestOnRefresh?.let { action -> pullRefresh.start(actionScope, action) }
            },
        )
    } else {
        Modifier
    }

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

    // Pull to Refresh の土台の修飾は安全領域の測り方の後ろに付け、一覧の根の位置と大きさを変えない。
    BoxWithConstraints(modifier = modifier.then(topSafeArea.modifier).then(pullToRefreshModifier)) {
        // 向きの判定はコンポーネント自身のコンテナの縦横比で行う (端末の物理向きでは判定しない)。
        val isPortrait = maxHeight > maxWidth
        val cells = resolveGridCells(layout, isPortrait)
        val layoutDirection = LocalLayoutDirection.current
        val containerWidthPx = if (constraints.hasBoundedWidth) constraints.maxWidth else 0
        // 行の数え方・項目の上下の間隔・行末の埋め方に使う列数。`LazyVerticalGrid` と同じ規則で解く。
        val columns = resolveColumnCount(layout, containerWidthPx, isPortrait, contentPadding, layoutDirection, density)
        val rows = remember(groupPlan, columns) { groupPlan.rows(columns) }

        // 位置の保持は、新しい配置を測る前 (直前の配置が残っている間) に判定して要求する。
        // 並べ替えのドラッグで配列を控えている間は、仮の並びの入れ替えを差し替えとして扱わないよう判定しない。
        // 控えるのをやめて届いた配列を当てるときに、ドラッグの前の並びと状態を直前として判定する。
        SideEffect {
            resolvedColumns.count = columns
            reorderController.bind(
                KsReorderBinding(
                    incoming = incomingItems,
                    items = displayedItems,
                    key = key,
                    plan = groupPlan,
                    valuesPlan = latestGroupPlan,
                    isGrouped = groupValueOf != null,
                    groupDeclaration = groupDeclaration,
                    layout = layout,
                    columns = columns,
                    reorder = reorder,
                    haptics = haptics,
                    density = density,
                ),
            )
            if (reorderController.isHolding) return@SideEffect
            positionKeeper.onUpdate(
                state = gridState,
                items = displayedItems,
                key = key,
                plan = groupPlan,
                columns = columns,
                placementOf = { itemIndex -> placementOfItem(groupPlan, itemIndex, columns, spacing, density) },
                safeTopPx = topSafeArea.overlapPx(),
                pagingState = paging?.state,
                isPullRefreshing = isPullRefreshing,
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
            overscrollEffect = overscrollEffect,
            modifier = Modifier
                .fillMaxSize()
                // 並べ替えの長押しとドラッグは一覧全体で受ける。指の位置を一覧の座標で持ち、ドラッグ中に
                // 項目が入れ替わっても指の位置がずれないようにするため。
                .then(
                    if (reorder != null) {
                        Modifier.pointerInput(reorderController) { ksReorderGestures(reorderController) }
                    } else {
                        Modifier
                    },
                )
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
                        cellWidths.getOrNull(local % columns)
                    } else {
                        null
                    }
                    val itemKey = key(item)
                    // 読み上げの移動操作 (core/ADR-0032)。スイッチが有効で文言を渡した一覧の、動かせる項目にだけ出す。
                    val reorderActions = reorder?.accessibilityActions
                    val accessibilityMoves = if (
                        reorderEnabled && reorderActions != null && reorder.canMove?.invoke(item) != false
                    ) {
                        ksReorderAccessibilityTargets(
                            items = displayedItems,
                            planner = reorderPlanner,
                            valuesPlan = latestGroupPlan,
                            isGrouped = groupValueOf != null,
                            canDrop = reorder.canDrop,
                            index = start + local,
                        )
                    } else {
                        null
                    }
                    KsAnimatedItemBox(
                        tracker = heightTracker,
                        // 持ち上げた項目は配置のアニメーションで追わず、指の下に描く。
                        lifted = reorder != null && reorderController.liftedKey == itemKey,
                        modifier = Modifier
                            .then(if (reorder != null) Modifier.ksReorderLift(itemKey, reorderController) else Modifier)
                            .ksAppearance(itemKey, appearing)
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
                            // 持ち上げた項目の影は間隔の内側にだけ付ける (透明な間隔に影が透けて板に見えないように)。
                            .then(if (reorder != null) Modifier.ksReorderLiftShadow(itemKey, reorderController) else Modifier)
                            .ksListSeparator(
                                isVisible = showsSeparators,
                                // 上端の線はグループの先頭行に引く。見出しが無いときは最初のグループだけ
                                // (グループの境目に線が 2 本並ばないように。core/ADR-0016)。
                                isFirst = local / columns == 0 && (groupPlan.hasHeaders || group == 0),
                                color = separatorColor,
                            )
                            .then(
                                if (accessibilityMoves != null && reorderActions != null) {
                                    Modifier.ksReorderAccessibility(
                                        actions = reorderActions,
                                        hasPrevious = accessibilityMoves.first,
                                        hasNext = accessibilityMoves.second,
                                        move = { forward -> reorderController.performAccessibilityMove(itemKey, forward) },
                                    )
                                } else {
                                    Modifier
                                },
                            )
                            // 項目内の操作要素が先にタッチを消費するため、そこでは項目のタップも
                            // フィードバックも起きない。スクロールが始まったタッチも取り消される。
                            .then(
                                if (hasTapHandler) {
                                    Modifier.combinedClickable(
                                        interactionSource = null,
                                        indication = tapIndication,
                                        onLongClick = itemLongTap?.let { { it(item) } },
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

            if (hasFooterSlot) {
                // 項目があるときの失敗と終端の表示は、フッターの枠の中でフッターの上に置く (最後の項目の
                // 後ろ・ルートのフッターの前)。次のページの読み込み中は枠に置かず、見えている範囲の下端に
                // 重ねる (下)。項目が 0 件のときは枠のページングの部分には何も出さない。
                val pagingFooter = if (paging != null && displayedItems.isNotEmpty()) {
                    KsPagingDisplay.resolve(paging.state, isEmpty = false)
                        ?.takeIf { it.isFooter }
                        ?.let { paging.content(it, retryPaging, loadingIndicatorColor) }
                } else {
                    null
                }
                // フッターも項目と一緒に動かす。項目だけが配置のアニメーションで動くと、項目の挿入・
                // 削除の間にフッターが先に飛び、項目と重なったり隙間が空いたりする。
                item(
                    key = KsRootSlotKey.Footer,
                    span = { GridItemSpan(maxLineSpan) },
                    contentType = KsFooterContentType,
                ) {
                    KsFullSpanBox(heightTracker, animatesPlacement = true) {
                        if (paging != null) KsPagingFooterStack(pagingFooter, footer) else footer?.invoke()
                    }
                }
            }
        }

        // 項目が 0 件のときのページングの表示は、項目の代わりに見えている範囲 (上下の安全領域を除く) の
        // 真ん中に、ルートのヘッダー / フッターより手前に重ねる (core/ADR-0025)。入れ物自体はタッチを
        // 受けないため、表示の外の操作 (ヘッダー / フッター・引っ張り) は下の一覧へ通る。
        val placeholder = if (paging != null && displayedItems.isEmpty()) {
            KsPagingDisplay.resolve(paging.state, isEmpty = true)
                ?.let { paging.content(it, retryPaging, loadingIndicatorColor) }
        } else {
            null
        }
        if (placeholder != null) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .zIndex(1f)
                    .ksExcludingVerticalSafeArea(topSafeArea),
                contentAlignment = Alignment.Center,
            ) {
                placeholder()
            }
        }

        // 項目があるときの次のページの読み込み中は、見えている範囲の下端 (下端のシステムバーとの重なりの
        // 分だけ上) の中央に止めて重ね、項目はその裏を流れる。スクロールに合わせて流れてくると読み込み中だと
        // 分かりにくいため。下の余白 (contentPadding) は中身の周りの余白で、中身の外に重ねるこの表示の置き場は
        // 変えない。入れ物はタッチを受けず、表示の外のタッチは下の項目へ通す。
        val appendingIndicator = if (paging != null && displayedItems.isNotEmpty()) {
            paging.content(KsPagingDisplay.AppendingIndicator, retryPaging, loadingIndicatorColor)
        } else {
            null
        }
        val latestAppendingIndicator by rememberUpdatedState(appendingIndicator)
        // 利用者が差し替えた表示は、押せる部品を持たなくてもその範囲のタッチを止める。既定の表示は止めない。
        val blocksIndicatorTouches = paging?.appendingIndicator != null
        AnimatedVisibility(
            visible = appendingIndicator != null && paging?.state == KsPagingState.Appending,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .zIndex(1f)
                .offset {
                    val bottom = topSafeArea.bottomOverlapPx() + KsAppendingIndicatorMargin.roundToPx()
                    IntOffset(0, -bottom)
                },
            enter = fadeIn(tween(KsAppendingIndicatorFadeMillis)),
            exit = fadeOut(tween(KsAppendingIndicatorFadeMillis)),
        ) {
            // 状態が追加読み込み中でなくなって消えるフェードの間も、同じ表示を描き続ける。
            if (blocksIndicatorTouches) {
                Box(Modifier.ksBlockingTouches(gridState, layoutDirection, overscrollEffect, overlayDragInteractions)) { latestAppendingIndicator?.invoke() }
            } else {
                latestAppendingIndicator?.invoke()
            }
        }

        if (onRefresh != null) {
            // インジケータは上端の安全領域の境目の下から出す。行はバーの裏を流れたまま、インジケータだけを
            // 境目まで下げる (core/ADR-0025)。インジケータは自分の上端より上を描かないため、引っ張り始めは
            // 境目の下に上から現れる。
            // 読み込み中の表示の色は矢印にだけ渡す。丸い下地の色は渡さず、テーマの色のままにする。
            PullToRefreshDefaults.Indicator(
                state = pullToRefreshState,
                isRefreshing = showsRefreshIndicator,
                color = loadingIndicatorColor ?: PullToRefreshDefaults.indicatorColor,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .zIndex(2f)
                    .offset { IntOffset(0, topSafeArea.overlapPx()) },
            )
        }
    }
}

/** 次のページの読み込み中の表示と、見えている範囲の下端 (下端のシステムバーの上) の間の間隔。 */
private val KsAppendingIndicatorMargin = 8.dp

/** 次のページの読み込み中の表示が出る・消えるときのフェードの長さ (ミリ秒)。 */
private const val KsAppendingIndicatorFadeMillis = 200

/**
 * この範囲のタッチを受け止め、重なって下にある兄弟 (一覧の項目) へ通さない。中の部品 (ボタンなど) は
 * そのままタッチを受け取れる。この範囲から始めた縦のドラッグは、一覧 ([gridState]) のスクロールに渡す。
 * 一覧自身のスクロールと同じ向き・慣性・端で伸びる効果 ([overscrollEffect]) にし、ドラッグの知らせは
 * [dragInteractions] へ出してスクロールインジケータに届ける。止めるのは下の項目へのタップだけにするため。
 */
private fun Modifier.ksBlockingTouches(
    gridState: LazyGridState,
    layoutDirection: LayoutDirection,
    overscrollEffect: OverscrollEffect?,
    dragInteractions: MutableInteractionSource,
): Modifier =
    scrollable(
        state = gridState,
        orientation = Orientation.Vertical,
        overscrollEffect = overscrollEffect,
        reverseDirection = ScrollableDefaults.reverseDirection(layoutDirection, Orientation.Vertical, false),
        interactionSource = dragInteractions,
    ).pointerInput(Unit) {
        awaitPointerEventScope {
            while (true) {
                awaitPointerEvent()
            }
        }
    }

/** 次ページ要求の判定の材料。 */
private data class KsPagingInput(
    val state: KsPagingState,
    val threshold: Float,
    val itemsVersion: Int,
    val itemCount: Int,
    val visibleItemCount: Int,
    val lastVisibleIndex: Int?,
    val isRunning: Boolean,
)

/**
 * 配置から次ページ要求の判定の材料を集める。ページングを付けていないとき、一覧がまだ配置されていない
 * とき、新しい配列の配置がまだ測られていないとき (配置と構成の件数が食い違うとき)、並べ替えのドラッグで
 * 配列を控えている間は null。
 *
 * 画面に出ている項目は、表示範囲 (バーの裏を含む一覧の全体) と少しでも重なる項目で、グループの見出し・
 * ルートのヘッダー / フッター (ページングの表示を含む) は数えない。グリッドでも行ではなく項目で数える。
 */
private fun pagingInput(
    info: LazyGridLayoutInfo,
    plan: KsGroupPlan,
    paging: KsPaging?,
    itemsVersion: Int,
    isRunning: Boolean,
    isReorderHolding: Boolean,
): KsPagingInput? {
    if (paging == null) return null
    // 並べ替えのドラッグで配列を控えている間は頼まない。控えるのをやめたら判定し直す (core/ADR-0034)。
    if (isReorderHolding) return null
    if (info.viewportSize.height <= 0 || info.totalItemsCount != plan.totalLazyCount) return null
    var count = 0
    var last = -1
    for (item in info.visibleItemsInfo) {
        val index = plan.itemIndexOfLazy(item.index)
        if (index < 0) continue
        val top = item.offset.y
        if (top >= info.viewportEndOffset || top + item.size.height <= info.viewportStartOffset) continue
        count += 1
        if (index > last) last = index
    }
    return KsPagingInput(
        state = paging.state,
        threshold = paging.threshold,
        itemsVersion = itemsVersion,
        itemCount = plan.itemCount,
        visibleItemCount = count,
        lastVisibleIndex = if (count > 0) last else null,
        isRunning = isRunning,
    )
}

/**
 * 上下の安全領域に重なった分を除いた範囲に中身を置く。重なりは配置の中で読み、値が変わったら置き直す。
 */
private fun Modifier.ksExcludingVerticalSafeArea(safeArea: KsTopSafeArea): Modifier =
    layout { measurable, constraints ->
        val top = safeArea.overlapPx()
        val bottom = safeArea.bottomOverlapPx()
        val height = (constraints.maxHeight - top - bottom).coerceAtLeast(0)
        val placeable = measurable.measure(Constraints.fixed(constraints.maxWidth, height))
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.place(0, top)
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
    lifted: Boolean,
    modifier: Modifier,
    content: @Composable () -> Unit,
) {
    if (lifted) {
        // 持ち上げた項目は、置き場所が表示範囲の外へ出てもコンポジションに残し、指の下に描き続ける。
        val pinnableContainer = LocalPinnableContainer.current
        DisposableEffect(pinnableContainer) {
            val handle = pinnableContainer?.pin()
            onDispose { handle?.release() }
        }
    }
    Box(
        modifier = ksAnimateItem(tracker, lifted).then(modifier),
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
 *
 * 並べ替えで持ち上げた項目 ([lifted]) も配置の変化をアニメーションさせない。持ち上げた項目は指の下に
 * 描き、置き場所の入れ替えを配置のアニメーションで追いかけないため。
 */
private fun LazyGridItemScope.ksAnimateItem(tracker: KsHeightAnimationTracker, lifted: Boolean = false): Modifier =
    Modifier.animateItem(placementSpec = if (tracker.isAnimating || lifted) null else KsItemPlacementSpec)

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
