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
 * 寿命は「アイテム ID → 解決した URL」と「URL → 参照数」の 2 つの台帳で管理する。参照数が
 * 0 から 1 になったときだけ取得を始め、1 から 0 になったときだけ取り消す。同じ URL を複数の
 * アイテムが返す場合、最後のアイテムが外れるまで取り消さない。
 *
 * 窓から外れても可視範囲に入っただけのアイテムは取り消さない (表示側の読み込みへ引き継ぐ)。
 */
internal class KsImagePrefetchWindow(private val loading: KsImageLoading) : KsImagePrefetchFencing {

    init {
        // キャッシュを消すときに、消す前に始まった取得を止められるようにする。
        KsImagePrefetchRegistry.register(this)
    }

    /** URL 1 件分の要求。参照数が 0 になったときに [handle] で取り消す。 */
    private class Request(val handle: KsImageRequestHandle, var referenceCount: Int)

    private val urlsByItemId = LinkedHashMap<Any, List<String>>()
    private val requestsByUrl = HashMap<String, Request>()

    // 台帳はコレクションの表示 (メインスレッド) から更新するが、キャッシュ操作は任意の
    // スレッドから呼べるため、台帳に触る操作はこの錠で直列化する。
    private val ledger = Any()

    private var previousVisible: IntRange? = null
    private var isForward = true

    /** 台帳が保持しているアイテム ID。テストと診断のために公開する。 */
    val trackedItemIds: Set<Any> get() = synchronized(ledger) { urlsByItemId.keys.toSet() }

    /**
     * 可視範囲を受けて窓を作り直す。[visible] と [items] はアイテム配列上の添字と要素で、
     * ヘッダー・フッターは含めない。
     */
    fun <Item> update(
        visible: IntRange,
        items: List<Item>,
        key: (Item) -> Any,
        resources: (Item) -> List<String>,
        destination: KsPrefetchDestination,
    ): Unit = synchronized(ledger) {
        val window = resolveWindow(visible, items.size)

        // 可視範囲のアイテムは窓に入れないが、台帳からも外さない。窓から可視範囲へ移った
        // 取得を取り消すと、表示側が同じ URL を取り直すことになるため。
        // 台帳と突き合わせられるよう、残すアイテムはその場で URL を解決し直しておく。
        val retained = HashMap<Any, List<String>>()
        for (index in visible) {
            if (index in items.indices) retained[key(items[index])] = resolve(items[index], resources)
        }
        for (index in window) {
            retained[key(items[index])] = resolve(items[index], resources)
        }

        // 窓にも可視範囲にも無くなったアイテム (配列の差し替えで消えたアイテムを含む) と、
        // ID が同じまま URL 集合が変わったアイテムを取り消す。後者は窓の中にいれば直後の
        // 走査で新しい URL の取得が始まり、可視範囲にいるだけなら表示側の読み込みへ委ねる。
        val released = urlsByItemId.keys.filter { retained[it] != urlsByItemId[it] }
        for (itemId in released) {
            release(itemId)
        }

        for (index in window) {
            val itemId = key(items[index])
            if (urlsByItemId.containsKey(itemId)) continue
            start(itemId, retained.getValue(itemId), destination)
        }
    }

    /** 台帳に残っている取得をすべて取り消す。 */
    fun disposeAll(): Unit = synchronized(ledger) {
        for (itemId in urlsByItemId.keys.toList()) {
            release(itemId)
        }
        previousVisible = null
    }

    /**
     * キャッシュを消す直前に呼ばれ、進行中の取得をすべて止める。止めた取得は台帳からも
     * 外れるため、次に可視範囲が動いたときは消去後の新しい取得として始まる。
     */
    override fun fenceAll() {
        disposeAll()
    }

    /** キャッシュから消すソースの取得だけを止める。他のソースの取得は続ける。 */
    override fun fence(url: String): Unit = synchronized(ledger) {
        val request = requestsByUrl.remove(url) ?: return@synchronized
        val emptied = mutableListOf<Any>()
        for ((itemId, urls) in urlsByItemId) {
            if (url !in urls) continue
            val remaining = urls.filterNot { it == url }
            if (remaining.isEmpty()) emptied.add(itemId) else urlsByItemId[itemId] = remaining
        }
        for (itemId in emptied) {
            urlsByItemId.remove(itemId)
        }
        request.handle.dispose()
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

    // アイテム 1 件が必要とする URL 集合。同じ URL を重ねて返しても参照数は 1 として数える。
    private fun <Item> resolve(item: Item, resources: (Item) -> List<String>): List<String> =
        resources(item).distinct()

    private fun start(itemId: Any, urls: List<String>, destination: KsPrefetchDestination) {
        urlsByItemId[itemId] = urls
        for (url in urls) {
            val existing = requestsByUrl[url]
            if (existing == null) {
                requestsByUrl[url] = Request(loading.enqueue(url, destination), referenceCount = 1)
            } else {
                existing.referenceCount += 1
            }
        }
    }

    private fun release(itemId: Any) {
        val urls = urlsByItemId.remove(itemId) ?: return
        for (url in urls) {
            val request = requestsByUrl[url] ?: continue
            request.referenceCount -= 1
            if (request.referenceCount <= 0) {
                requestsByUrl.remove(url)
                request.handle.dispose()
            }
        }
    }
}

/**
 * 先読み窓を可視範囲へ追従させる副作用。プリフェッチの宣言があるときだけ組み立てる
 * (宣言が無いコレクションでは可視範囲の観測自体を起こさない)。
 *
 * @param leadingItemCount ヘッダーなど、アイテムより前に並ぶ lazy 側の項目数
 */
@Composable
internal fun <Item> KsPrefetchWindowEffect(
    gridState: LazyGridState,
    items: List<Item>,
    key: (Item) -> Any,
    leadingItemCount: Int,
    resources: (Item) -> List<String>,
    destination: KsPrefetchDestination,
) {
    val context = LocalContext.current
    val loading = LocalKsImageLoading.current
    val resolvedLoading = remember(loading, context) { loading ?: KsCoilImageLoading(context) }
    val window = remember(resolvedLoading) { KsImagePrefetchWindow(resolvedLoading) }

    // 宣言は表示中に差し替えない前提だが、差し替えられた場合は以後に始まる取得にだけ反映する。
    val latestKey by rememberUpdatedState(key)
    val latestResources by rememberUpdatedState(resources)
    val latestDestination by rememberUpdatedState(destination)

    DisposableEffect(window) {
        onDispose { window.disposeAll() }
    }

    LaunchedEffect(window, gridState, items, leadingItemCount) {
        // 可視範囲の添字だけを取り出して観測する。スクロール中は毎フレーム評価されるため、
        // 位置の細かな変化では流さず、可視範囲が動いたときだけ窓を作り直す。
        snapshotFlow { gridState.layoutInfo.visibleItemRange(leadingItemCount, items.size) }
            .collect { visible ->
                window.update(
                    visible = visible,
                    items = items,
                    key = latestKey,
                    resources = latestResources,
                    destination = latestDestination,
                )
            }
    }
}

/**
 * 可視の lazy 項目からアイテム配列上の添字の範囲を作る。ヘッダー・フッターは範囲に含めない。
 */
internal fun LazyGridLayoutInfo.visibleItemRange(leadingItemCount: Int, itemCount: Int): IntRange {
    var first = Int.MAX_VALUE
    var last = Int.MIN_VALUE
    for (info in visibleItemsInfo) {
        val index = info.index - leadingItemCount
        if (index < 0 || index >= itemCount) continue
        if (index < first) first = index
        if (index > last) last = index
    }
    return if (first > last) IntRange.EMPTY else first..last
}
