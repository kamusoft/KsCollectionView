package jp.kamusoft.kscollectionview

import androidx.compose.foundation.lazy.grid.LazyGridLayoutInfo
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.platform.LocalContext

/**
 * プリフェッチの先読み窓。可視範囲の変化を受けて「可視範囲の外側・進行方向・可視件数と同数」の
 * アイテム集合を作り、その差分だけをローダーへ伝える。
 *
 * 寿命は 2 段の台帳で管理する。
 * - 上段「アイテム ID → 宣言と、その宣言に割り当てた取得単位」: アイテムの再評価 (窓の更新・
 *   配列の差し替え) は宣言で突き合わせる。列の幅が変わっても宣言は変わらないため、回転だけでは
 *   既存の取得を取り消さない。
 * - 下段「取得単位 → 参照数と、取得を始めたときの取っ手と、持ち主が宣言している URL」: 同じ単位を
 *   複数のアイテムが必要とする場合、最後のアイテムが外れるまで取り消さない。取り消しは始めたときの
 *   取っ手で行うので、その後に列の幅が変わっていても始めた取得が止まる。
 *
 * 共有中の単位の取得を始め直すきっかけは、その画像 (識別子) を宣言するアイテムの URL の変更 (署名の
 * 更新など) だけである。URL の変更はアイテムと識別子の組で記録し、その識別子のすべての単位 (幅違いを
 * 含む) の判定に使う。列の幅が変わった後は、同じアイテムの新しい宣言が別の幅の単位へ解けるためである。
 * [update] 1 回分の処理を終えた時点で、URL を変えたアイテム (可視範囲で宣言を変えたアイテムを
 * 含む) がいて、かつ進行中の取得の URL が「URL を変えたアイテムのどれかが直前まで宣言していた URL」か
 * 「いまその単位を持つどのアイテムも宣言していない URL」なら、古い取得を止めて新しい URL で始め直す。
 * アイテムが加わる・外れるだけの更新では始め直さないので、同じ画像が行ごとに違う署名で届いても、
 * 行が入るたびに取得をやり直すことはない。
 *
 * 窓から外れても可視範囲に入っただけのアイテムは取り消さない (表示側の読み込みへ引き継ぐ)。
 *
 * @param reportInvalidInput 利用者の宣言の誤り (空文字のキー・誤った固定の幅) を知らせる先。
 *   同じ文面は 1 度だけ届く
 */
internal class KsImagePrefetchWindow(
    private val loading: KsImageLoading,
    private val reportInvalidInput: (String) -> Unit = {},
) : KsImagePrefetchFencing {

    init {
        // キャッシュを消すときに、消す前に始まった取得を止められるようにする。
        KsImagePrefetchRegistry.register(this)
    }

    /** アイテムの宣言 1 件と、それに割り当てた取得単位。 */
    private data class Assignment(val declaration: KsPrefetchDeclaration, val unit: KsPrefetchUnit)

    /**
     * 1 回の [update] の中で、ある識別子を宣言するアイテムが URL を変えたことの記録。
     *
     * @property previousUrls URL を変えたアイテムが直前まで宣言していた URL
     * @property newestUrl URL を変えたアイテムのうち、直近のものの新しい URL。始め直すときに優先して使う
     */
    private class UrlChange(
        val previousUrls: MutableSet<String> = HashSet(),
        var newestUrl: String? = null,
    )

    /**
     * 取得単位 1 件分の要求。参照数が 0 になったときに [handle] で取り消す。取得に使う URL が
     * 変わったときは [request] と [handle] を始め直した要求のものに置き換える。
     *
     * @property declaredUrls この単位を持つアイテムが宣言している URL と、その URL を宣言している
     *   アイテムの数
     * @property latest 直近にこの単位を確保したアイテムの要求。始め直すときに優先して使う
     */
    private class UnitState(
        var request: KsPrefetchRequest,
        var handle: KsImageRequestHandle,
        var referenceCount: Int,
        val declaredUrls: HashMap<String, Int>,
        var latest: KsPrefetchRequest,
    )

    private val assignmentsByItemId = LinkedHashMap<Any, List<Assignment>>()
    private val units = HashMap<KsPrefetchUnit, UnitState>()

    // この [update] で URL を変えたアイテムがいた識別子と、その変更。処理の終わりに、その識別子の
    // すべての単位について始め直すかを決める。
    private val urlChanges = HashMap<String, UrlChange>()

    // 報告済みの誤りの文面。可視範囲が動くたびに同じ宣言を評価し直すため、同じ誤りを何度も
    // 報告しないよう覚えておく。誤りが続く宣言で膨らみ続けないよう件数に上限を持つ。
    private val reportedMessages = LinkedHashSet<String>()

    // 台帳はコレクションの表示 (メインスレッド) から更新するが、キャッシュ操作は任意の
    // スレッドから呼べるため、台帳に触る操作はこの錠で直列化する。
    private val ledger = Any()

    private var previousVisible: IntRange? = null
    private var isForward = true

    /** 台帳が保持しているアイテム ID。テストと診断のために公開する。 */
    val trackedItemIds: Set<Any> get() = synchronized(ledger) { assignmentsByItemId.keys.toSet() }

    /** 進行中の取得の要求。テストと診断のために公開する。 */
    val activeRequests: List<KsPrefetchRequest>
        get() = synchronized(ledger) { units.values.map { it.request } }

    /**
     * 可視範囲を受けて窓を作り直す。[visible] と [items] はアイテム配列上の添字と要素で、
     * ヘッダー・フッターは含めない。
     *
     * @param metrics 幅をピクセルへ解くための、この時点の寸法。取得を始めるときにだけ使う
     */
    fun <Item> update(
        visible: IntRange,
        items: List<Item>,
        key: (Item) -> Any,
        resources: (Item) -> List<KsResource>,
        destination: KsPrefetchDestination,
        metrics: KsPrefetchMetrics = KsPrefetchMetrics.Unresolved,
    ): Unit = synchronized(ledger) {
        val window = resolveWindow(visible, items.size)

        // 可視範囲のアイテムは窓に入れないが、台帳からも外さない。窓から可視範囲へ移った
        // 取得を取り消すと、表示側が同じ画像を取り直すことになるため。
        // 台帳と突き合わせられるよう、残すアイテムはその場で宣言を求め直しておく。
        val declared = HashMap<Any, List<KsPrefetchDeclaration>>()
        for (index in visible) {
            if (index in items.indices) declared[key(items[index])] = declare(items[index], resources)
        }
        val windowItemIds = ArrayList<Any>()
        for (index in window) {
            val itemId = key(items[index])
            declared[itemId] = declare(items[index], resources)
            windowItemIds.add(itemId)
        }

        // 窓にも可視範囲にも無くなったアイテム (配列の差し替えで消えたアイテムを含む) の取得を
        // 取り消す。可視範囲にだけ残るアイテムは、宣言から消えた分だけを取り消す (新しく増えた
        // 分は表示側の読み込みへ委ねる)。
        val windowIdSet = windowItemIds.toHashSet()
        for (itemId in assignmentsByItemId.keys.toList()) {
            val declarations = declared[itemId]
            when {
                declarations == null -> release(itemId)
                itemId !in windowIdSet -> releaseStale(itemId, declarations)
            }
        }

        for (itemId in windowItemIds) {
            reconcile(itemId, declared.getValue(itemId), destination, metrics)
        }
        settle(destination)
    }

    /** 台帳に残っている取得をすべて取り消す。 */
    fun disposeAll(): Unit = synchronized(ledger) {
        for (itemId in assignmentsByItemId.keys.toList()) {
            release(itemId)
        }
        urlChanges.clear()
        previousVisible = null
    }

    /**
     * キャッシュを消す直前に呼ばれ、進行中の取得をすべて止める。止めた取得は台帳からも
     * 外れるため、次に可視範囲が動いたときは消去後の新しい取得として始まる。
     */
    override fun fenceAll() {
        disposeAll()
    }

    /** キャッシュから消す画像の取得だけを、幅に関わらずすべて止める。他の画像の取得は続ける。 */
    override fun fence(identifier: String): Unit = synchronized(ledger) {
        val fenced = units.keys.filter { it.identifier == identifier }
        if (fenced.isEmpty()) return@synchronized
        val handles = fenced.mapNotNull { units.remove(it)?.handle }
        for (itemId in assignmentsByItemId.keys.toList()) {
            val remaining = assignmentsByItemId.getValue(itemId)
                .filterNot { it.unit.identifier == identifier }
            if (remaining.isEmpty()) {
                assignmentsByItemId.remove(itemId)
            } else {
                assignmentsByItemId[itemId] = remaining
            }
        }
        handles.forEach { it.dispose() }
    }

    /**
     * 可視範囲の変化から進行方向を決め、その先の「可視件数と同数」のアイテムの添字を返す。
     * 静止時 (可視範囲が変わらないとき) は直前の進行方向を保ち、初期表示は末尾方向とみなす。
     */
    private fun resolveWindow(visible: IntRange, itemCount: Int): IntRange {
        val previous = previousVisible
        if (previous != null && !previous.isEmpty() && !visible.isEmpty()) {
            when {
                visible.first > previous.first || visible.last > previous.last -> isForward = true
                visible.first < previous.first || visible.last < previous.last -> isForward = false
            }
        }
        previousVisible = visible
        if (visible.isEmpty() || itemCount == 0) return IntRange.EMPTY

        val visibleCount = visible.last - visible.first + 1
        return if (isForward) {
            (visible.last + 1)..minOf(visible.last + visibleCount, itemCount - 1)
        } else {
            maxOf(visible.first - visibleCount, 0)..(visible.first - 1)
        }
    }

    // アイテム 1 件の宣言。同じ宣言を重ねて返しても 1 つとして数える。
    private fun <Item> declare(
        item: Item,
        resources: (Item) -> List<KsResource>,
    ): List<KsPrefetchDeclaration> =
        resources(item).map { KsPrefetchDeclaration.of(it, ::reportOnce) }.distinct()

    /**
     * アイテム 1 件分の台帳を、いま求まる宣言へ合わせ直す。宣言が変わらなければ何もしないため、
     * 窓の更新が重なっても要求を積み増さない。
     */
    private fun reconcile(
        itemId: Any,
        declarations: List<KsPrefetchDeclaration>,
        destination: KsPrefetchDestination,
        metrics: KsPrefetchMetrics,
    ) {
        val previous = assignmentsByItemId[itemId].orEmpty()
        if (previous.map { it.declaration } == declarations) return

        // 先に手放してから確保する。同じ識別子を違う URL で宣言し直していれば URL の変更として記録する
        // (始め直すかは [update] の終わりに決める)。
        // 両方に残る宣言は参照数を動かさない。動かすと、他のアイテムと共有していない取得が
        // 取り消しと開始を往復してしまう。
        for (assignment in previous) {
            if (assignment.declaration !in declarations) releaseUnit(assignment)
        }
        recordUrlChanges(previous.map { it.declaration }, declarations)
        val next = ArrayList<Assignment>(declarations.size)
        for (declaration in declarations) {
            val kept = previous.firstOrNull { it.declaration == declaration }
            if (kept != null) {
                next.add(kept)
                continue
            }
            // 列の幅が解けない間は、列の幅で宣言した画像の取得を始めない。台帳にも載せないので、
            // 列の幅が解けた後にこのアイテムが改めて評価されたときに始まる。
            val unit = unitFor(declaration, destination, metrics) ?: continue
            acquire(unit, declaration, destination)
            next.add(Assignment(declaration, unit))
        }
        if (next.isEmpty()) assignmentsByItemId.remove(itemId) else assignmentsByItemId[itemId] = next
    }

    /**
     * 宣言から消えた分だけを取り消す。新しく増えた分は始めない。同じ識別子を違う URL で宣言し直して
     * いれば URL の変更として記録し、窓の中のアイテムの変更と同じく [update] の終わりに始め直すかを決める。
     */
    private fun releaseStale(itemId: Any, declarations: List<KsPrefetchDeclaration>) {
        val previous = assignmentsByItemId[itemId] ?: return
        val (kept, stale) = previous.partition { it.declaration in declarations }
        if (stale.isEmpty()) return
        stale.forEach { releaseUnit(it) }
        recordUrlChanges(previous.map { it.declaration }, declarations)
        if (kept.isEmpty()) assignmentsByItemId.remove(itemId) else assignmentsByItemId[itemId] = kept
    }

    /**
     * アイテム 1 件の宣言の変化から、識別子ごとの URL の変更を記録する。直前まで宣言していて今は
     * 宣言していない URL を直前の URL、今は宣言していて直前には宣言していなかった URL を新しい URL とし、
     * 両方がそろった識別子だけを変更とみなす (宣言が加わる・消えるだけなら変更ではない)。
     * 単位ではなく識別子で見るので、列の幅が変わって新しい宣言が別の幅の単位へ解けても記録が漏れない。
     */
    private fun recordUrlChanges(
        previous: List<KsPrefetchDeclaration>,
        declarations: List<KsPrefetchDeclaration>,
    ) {
        for ((identifier, before) in previous.groupBy { it.identifier }) {
            val previousUrls = before.mapTo(HashSet()) { it.url }
            val current = declarations.filter { it.identifier == identifier }
            val dropped = previousUrls - current.mapTo(HashSet()) { it.url }
            val newest = current.lastOrNull { it.url !in previousUrls } ?: continue
            if (dropped.isEmpty()) continue
            val change = urlChanges.getOrPut(identifier) { UrlChange() }
            change.previousUrls.addAll(dropped)
            change.newestUrl = newest.url
        }
    }

    /** 宣言を取得単位へ解く。到達点がディスクまでのときは幅を使わない。 */
    private fun unitFor(
        declaration: KsPrefetchDeclaration,
        destination: KsPrefetchDestination,
        metrics: KsPrefetchMetrics,
    ): KsPrefetchUnit? {
        val widthPixels = when (val width = declaration.width) {
            null -> null
            KsWidth.Column -> metrics.columnWidthPixels ?: return null
            is KsWidth.Fixed -> metrics.pixels(width.width)
        }
        return KsPrefetchUnit(
            identifier = declaration.identifier,
            widthPixels = if (destination == KsPrefetchDestination.Memory) widthPixels else null,
        )
    }

    /**
     * 参照数を増やし、0 から 1 になった単位の取得を始める。既に進行中の単位では宣言した URL を
     * 数えるだけで、始め直すかは [update] の終わりに決める ([settle])。
     */
    private fun acquire(
        unit: KsPrefetchUnit,
        declaration: KsPrefetchDeclaration,
        destination: KsPrefetchDestination,
    ) {
        val request = KsPrefetchRequest(
            url = declaration.url,
            key = declaration.key,
            widthPixels = unit.widthPixels,
        )
        val existing = units[unit]
        if (existing == null) {
            units[unit] = UnitState(
                request = request,
                handle = loading.enqueue(request, destination),
                referenceCount = 1,
                declaredUrls = hashMapOf(request.url to 1),
                latest = request,
            )
            return
        }
        existing.referenceCount += 1
        existing.declaredUrls.merge(request.url, 1, Int::plus)
        existing.latest = request
    }

    private fun release(itemId: Any) {
        val assignments = assignmentsByItemId.remove(itemId) ?: return
        assignments.forEach { releaseUnit(it) }
    }

    /** 参照数を減らし、1 から 0 になった単位の、始めたときの取得を取り消す。 */
    private fun releaseUnit(assignment: Assignment) {
        val unit = assignment.unit
        val state = units[unit] ?: return
        state.referenceCount -= 1
        if (state.referenceCount <= 0) {
            units.remove(unit)
            state.handle.dispose()
            return
        }
        val url = assignment.declaration.url
        val declared = state.declaredUrls[url] ?: return
        if (declared > 1) state.declaredUrls[url] = declared - 1 else state.declaredUrls.remove(url)
    }

    /**
     * [update] 1 回分の処理を終えた時点で、URL を変えたアイテムがいた識別子の単位 (幅違いを含む) に
     * ついて始め直すかを決める。進行中の取得の URL が、URL を変えたアイテムの直前の URL か、どのアイテムも
     * 宣言していない URL なら、古い取得を止めて始め直す (失効した URL の取得が失敗したままにならないため)。
     * 始め直す URL は、URL を変えたアイテムのうち直近のものの新しい URL を、その単位で宣言されていれば
     * 優先する。そうでなければ直近に確保したアイテムの URL、それも無ければ宣言中の URL のうち文字列順で
     * 最初のものを使う (どれを選んでも同じ画像なので、決まった順にするだけ)。幅はその単位の幅のまま使う。
     * 取得済みなら始め直した要求はキーでキャッシュに当たり、ネットワークを使わない。
     */
    private fun settle(destination: KsPrefetchDestination) {
        for ((identifier, change) in urlChanges) {
            for (unit in units.keys.filter { it.identifier == identifier }) {
                val state = units.getValue(unit)
                val running = state.request.url
                if (running !in change.previousUrls && running in state.declaredUrls) continue
                val newestUrl = change.newestUrl
                val url = when {
                    newestUrl != null && newestUrl in state.declaredUrls -> newestUrl
                    state.latest.url in state.declaredUrls -> state.latest.url
                    else -> state.declaredUrls.keys.minOrNull() ?: continue
                }
                if (url == running) continue
                val replacement = state.request.copy(url = url)
                state.handle.dispose()
                state.request = replacement
                state.handle = loading.enqueue(replacement, destination)
            }
        }
        urlChanges.clear()
    }

    private fun reportOnce(message: String) {
        if (!reportedMessages.add(message)) return
        if (reportedMessages.size > ReportedMessageLimit) {
            reportedMessages.remove(reportedMessages.first())
        }
        reportInvalidInput(message)
    }

    private companion object {
        /** 覚えておく報告済みの文面の上限。 */
        const val ReportedMessageLimit = 256
    }
}

/**
 * 先読み窓を可視範囲へ追従させる副作用。プリフェッチの宣言があるときだけ組み立てる
 * (宣言が無いコレクションでは可視範囲の観測自体を起こさない)。
 *
 * @param plan 配列のグループの構成。lazy の index からアイテム配列上の添字を引くのに使う
 */
@Composable
internal fun <Item> KsPrefetchWindowEffect(
    gridState: LazyGridState,
    items: List<Item>,
    key: (Item) -> Any,
    plan: KsGroupPlan,
    resources: (Item) -> List<KsResource>,
    destination: KsPrefetchDestination,
    metrics: KsPrefetchMetrics,
) {
    val context = LocalContext.current
    val loading = LocalKsImageLoading.current
    val resolvedLoading = remember(loading, context) { loading ?: KsCoilImageLoading(context) }
    val window = remember(resolvedLoading, context) {
        // 宣言の誤りは debug では停止し、release では警告して縮退する (core/ADR-0011)。
        KsImagePrefetchWindow(resolvedLoading) { message ->
            KsDiagnostics.invalidInput(context, message)
        }
    }

    // 宣言は表示中に差し替えない前提だが、差し替えられた場合は以後に始まる取得にだけ反映する。
    val latestKey by rememberUpdatedState(key)
    val latestResources by rememberUpdatedState(resources)
    val latestDestination by rememberUpdatedState(destination)
    // 列の幅は回転・列数・余白の変更で変わる。取得を始める時点の最新の値を使う。
    val latestMetrics by rememberUpdatedState(metrics)

    DisposableEffect(window) {
        onDispose { window.disposeAll() }
    }

    LaunchedEffect(window, gridState, items, plan) {
        // 可視範囲の添字だけを取り出して観測する。スクロール中は毎フレーム評価されるため、
        // 位置の細かな変化では流さず、可視範囲が動いたときだけ窓を作り直す。
        snapshotFlow { gridState.layoutInfo.visibleItemRange(plan::itemIndexOfLazy) }
            .collect { visible ->
                window.update(
                    visible = visible,
                    items = items,
                    key = latestKey,
                    resources = latestResources,
                    destination = latestDestination,
                    metrics = latestMetrics,
                )
            }
    }
}

/**
 * 可視の lazy 項目からアイテム配列上の添字の範囲を作る。ヘッダー・フッター・グループの見出しは
 * 範囲に含めない。
 *
 * @param itemIndexOfLazy lazy の index からアイテム配列上の添字を引く。アイテムでなければ負の値
 */
internal fun LazyGridLayoutInfo.visibleItemRange(itemIndexOfLazy: (Int) -> Int): IntRange {
    var first = Int.MAX_VALUE
    var last = Int.MIN_VALUE
    for (info in visibleItemsInfo) {
        val index = itemIndexOfLazy(info.index)
        if (index < 0) continue
        if (index < first) first = index
        if (index > last) last = index
    }
    return if (first > last) IntRange.EMPTY else first..last
}
