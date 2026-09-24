package jp.kamusoft.kscollectionview

import coil3.Image
import coil3.memory.MemoryCache

/**
 * ライブラリがメモリへ載せるよう要求した項目の鍵を、識別子ごとに覚えておく索引 (core/ADR-0013)。
 *
 * ローダーのメモリキャッシュは鍵単位でしか引けず、同じ画像の別の大きさの項目を探すには鍵の一覧を
 * 走査するしかない (項目数に比例する)。そこで、先読みと [KsImage] が要求を出した時点でその鍵を
 * 覚えておき、表示のときに候補の鍵としてローダーのキャッシュへ問い合わせる。
 *
 * 索引はキャッシュではなく手掛かりで、項目が実在するか・どの寸法かの正はローダーのキャッシュにある。
 * 寸法は持たず、問い合わせで返った画像の実物から読む。未完了・失敗・追い出し済みの鍵は問い合わせで
 * 空になるだけで候補にならず、索引には残る。未完了の鍵は完了後の問い合わせで候補になるため、問い合わせ
 * では外さない (先読みの完了前に表示が照会しても、完了後に引き当てられる)。索引から鍵が外れるのは、
 * キャッシュの消去 ([KsImageCache] の `clear` / `remove`) と項目数の上限だけである。
 *
 * 項目数は上限つきで、上限を超えると最も長く使われていない鍵から外れる。上限は、ローダーの
 * メモリキャッシュが実用上保持できる項目数を十分に上回る値にしている。外れた鍵の項目は引き当てられず、
 * 表示は通常の縮小の要求に落ちる (壊れはしない)。
 *
 * あわせて、先読みの要求のうちまだ取得中のもの (完了・失敗・取り消しの前) を鍵ごとに数えておく。
 * 表示は、取得中の先読みがある画像に限って要求を画面に出る時点まで遅らせる。索引の鍵だけでは、
 * 完了して追い出された・失敗した・取り消された先読みと取得中の先読みを見分けられないためである。
 *
 * 登録は表示の組み立て (主スレッド) から、消去はキャッシュ操作 (任意のスレッド) から、取得の完了の
 * 通知はローダーから呼ばれるため、すべての操作を 1 つの錠で直列化する。
 */
internal class KsImageMemoryIndex(capacity: Int) {

    val capacity: Int = capacity.coerceAtLeast(1)

    private val lock = Any()

    // 使われた順に並ぶ鍵の集合。古い側から外していく。
    private val keys = LinkedHashMap<MemoryCache.Key, Unit>(16, 0.75f, true)

    // 識別子 (鍵の本体) ごとの鍵。
    private val keysByIdentifier = HashMap<String, MutableList<MemoryCache.Key>>()

    // 取得中の先読み。鍵ごとに取得 1 件ずつの目印で持つ (取り消して同じ鍵で始め直すと、古い取得の
    // 終わりの通知が新しい取得の開始より後に届くことがあるため、有無ではなく取得ごとに外す)。
    private val fetchesInFlight = HashMap<MemoryCache.Key, MutableSet<Any>>()

    /** 索引にある鍵の数。 */
    val count: Int get() = synchronized(lock) { keys.size }

    /**
     * メモリへ載せるよう要求した鍵を覚える。既に覚えている鍵なら最近使ったものとして扱う。
     */
    fun register(key: MemoryCache.Key): Unit = synchronized(lock) {
        if (keys.put(key, Unit) != null) return@synchronized
        keysByIdentifier.getOrPut(key.key) { mutableListOf() }.add(key)
        while (keys.size > capacity) {
            val eldest = keys.keys.first()
            removeKey(eldest)
        }
    }

    /**
     * 識別子について覚えている鍵のうち、キャッシュに今ある項目を返す。キャッシュに無かった鍵は
     * 候補にしないだけで、索引には残す。
     */
    fun cachedEntries(
        identifier: String,
        memoryCache: MemoryCache,
    ): List<Pair<MemoryCache.Key, Image>> = synchronized(lock) {
        val candidates = keysByIdentifier[identifier] ?: return@synchronized emptyList()
        candidates.mapNotNull { key -> memoryCache[key]?.image?.let { key to it } }
    }

    /**
     * 識別子について、索引にある鍵の先読みがまだ取得中で、その項目がキャッシュにまだ無いか。
     * 待てば引き当てられる見込みがあるのはこの場合だけで、完了・失敗・取り消し・追い出し済みの
     * 先読みは含まない。
     */
    fun hasFetchInFlight(
        identifier: String,
        memoryCache: MemoryCache,
    ): Boolean = synchronized(lock) {
        val candidates = keysByIdentifier[identifier] ?: return@synchronized false
        candidates.any { key -> fetchesInFlight.containsKey(key) && memoryCache[key] == null }
    }

    /**
     * 先読みの取得を始めた時点で呼び、その取得の終わりに 1 度だけ呼ぶ関数を返す。終わりは完了・
     * 失敗・取り消しのどれでもよく、2 度目以降の呼び出しは何もしない。
     */
    fun beginFetch(key: MemoryCache.Key): () -> Unit {
        val fetch = Any()
        synchronized(lock) { fetchesInFlight.getOrPut(key) { HashSet() }.add(fetch) }
        return {
            synchronized(lock) {
                val fetches = fetchesInFlight[key]
                if (fetches != null && fetches.remove(fetch) && fetches.isEmpty()) {
                    fetchesInFlight.remove(key)
                }
            }
        }
    }

    /** 取得中の先読みの数。テストが終わりの通知の漏れを確かめるために読む。 */
    val fetchesInFlightCount: Int get() = synchronized(lock) { fetchesInFlight.values.sumOf { it.size } }

    /** 引き当てに使った鍵を最近使ったものとして扱う。 */
    fun markUsed(key: MemoryCache.Key): Unit = synchronized(lock) {
        // 順序つきの集合は参照で順序が更新される。
        keys[key]
    }

    /** 識別子の鍵をすべて外す。 */
    fun remove(identifier: String): Unit = synchronized(lock) {
        val removed = keysByIdentifier.remove(identifier) ?: return@synchronized
        for (key in removed) {
            keys.remove(key)
        }
    }

    /** すべての鍵と、取得中の先読みの記録を外す。 */
    fun removeAll(): Unit = synchronized(lock) {
        keys.clear()
        keysByIdentifier.clear()
        fetchesInFlight.clear()
    }

    /** 識別子について覚えている鍵。テストが索引の中身を確かめるために読む。 */
    fun keys(identifier: String): List<MemoryCache.Key> = synchronized(lock) {
        keysByIdentifier[identifier]?.toList().orEmpty()
    }

    private fun removeKey(key: MemoryCache.Key) {
        keys.remove(key)
        val list = keysByIdentifier[key.key] ?: return
        list.remove(key)
        if (list.isEmpty()) keysByIdentifier.remove(key.key)
    }

    companion object {
        /** 先読みと表示が共有する索引。 */
        val shared: KsImageMemoryIndex = KsImageMemoryIndex(capacity = 20_000)
    }
}
