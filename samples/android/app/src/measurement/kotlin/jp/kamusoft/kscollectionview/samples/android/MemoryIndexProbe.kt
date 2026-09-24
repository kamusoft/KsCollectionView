package jp.kamusoft.kscollectionview.samples.android

import android.content.Context
import coil3.SingletonImageLoader
import coil3.memory.MemoryCache

/**
 * 画像のメモリキャッシュと、本体がメモリの項目を引き当てるために持つ索引の中身を読む計測用の覗き窓。
 *
 * 読むのは次の 3 つ。
 * - メモリキャッシュの項目: 件数・合計の大きさと、この Sample の画像の項目の寸法の内訳と鍵の形の内訳
 * - 索引の充足: この Sample の画像の項目のうち、索引に鍵が残っているものの割合。索引から外れた
 *   項目は引き当てられず、表示のたびに縮小のデコードへ落ちる
 * - 索引が持つものの型: 索引が鍵 (文字列と付随情報) 以外を持っていないこと。持っていなければ、
 *   索引は画面を離れた後もコレクションや項目の表示を保持しえない
 *
 * 索引は本体の内部の型で、公開面には出ていない。計測のために本体の公開面を増やさないよう、この構成
 * からは実行時に名前で読む (本体の内部の形が変わると読めなくなり、そのときは読めないことを出力する)。
 * 配布する構成には入らない。
 */
object MemoryIndexProbe {

    /** この Sample の画像の URL の頭。ほかの画像の項目を数えに入れないために使う。 */
    private const val SampleImagePrefix = "https://picsum.photos/seed/ks-"

    /** 画像の読み込みを始めた画面が、覗き窓を使うことを表明したか。 */
    @Volatile
    var enabled: Boolean = false

    /**
     * 現在の中身を 1 行の文字列にする。形は
     * `cache=<件数> cacheBytes=<大きさ> ours=<件数> inIndex=<件数> fill=<割合> index=<件数>
     * foreign=<件数> dims=<寸法:件数,...> keyShapes=<形:件数,...>`。
     *
     * @param context 共有インスタンスの ImageLoader を得るための文脈
     */
    fun describe(context: Context): String {
        val memory = SingletonImageLoader.get(context).memoryCache
            ?: return "cache=none"
        val indexKeys = readIndexKeys()
        val cacheKeys = memory.keys.toList()
        val ours = cacheKeys.filter { it.key.startsWith(SampleImagePrefix) }
        val dims = sortedMapOf<String, Int>()
        val shapes = sortedMapOf<String, Int>()
        for (key in ours) {
            val image = memory[key]?.image
            val dim = if (image == null) "gone" else "${image.width}x${image.height}"
            dims[dim] = (dims[dim] ?: 0) + 1
            val shape = keyShape(key)
            shapes[shape] = (shapes[shape] ?: 0) + 1
        }
        val indexPart = when (indexKeys) {
            null -> "inIndex=unreadable fill=unreadable index=unreadable foreign=unreadable"
            else -> {
                val inIndex = ours.count { it in indexKeys.keys }
                val fill = if (ours.isEmpty()) "n/a" else "%.3f".format(inIndex.toDouble() / ours.size)
                "inIndex=$inIndex fill=$fill index=${indexKeys.keys.size} foreign=${indexKeys.foreign}"
            }
        }
        return "cache=${cacheKeys.size} cacheBytes=${memory.size} maxBytes=${memory.maxSize} " +
            "ours=${ours.size} $indexPart " +
            "dims=${dims.entries.joinToString(",") { "${it.key}:${it.value}" }} " +
            "keyShapes=${shapes.entries.joinToString(",") { "${it.key}:${it.value}" }}"
    }

    /** 鍵の形。付随情報の名前の組で分ける (無し = 元の大きさの項目)。 */
    private fun keyShape(key: MemoryCache.Key): String =
        if (key.extras.isEmpty()) "plain" else key.extras.keys.sorted().joinToString("+")

    /** 索引から読んだ鍵と、鍵ではないものの件数。 */
    private class IndexKeys(val keys: Set<MemoryCache.Key>, val foreign: Int)

    /**
     * 本体の索引が持つ鍵を読む。読めないときは null。
     *
     * 索引は操作ごとに自身の錠を取るので、読む間も同じ錠を取る。
     */
    private fun readIndexKeys(): IndexKeys? = runCatching {
        val indexClass = Class.forName("jp.kamusoft.kscollectionview.KsImageMemoryIndex")
        val shared = indexClass.getDeclaredField("shared").apply { isAccessible = true }.get(null)
        val lock = indexClass.getDeclaredField("lock").apply { isAccessible = true }.get(shared)!!
        val keysField = indexClass.getDeclaredField("keys").apply { isAccessible = true }
        val byIdentifierField = indexClass.getDeclaredField("keysByIdentifier")
            .apply { isAccessible = true }
        synchronized(lock) {
            val keys = keysField.get(shared) as Map<*, *>
            val byIdentifier = byIdentifierField.get(shared) as Map<*, *>
            // 索引の持ち物をすべて辿り、鍵 (本体の文字列と文字列どうしの付随情報) 以外を数える。
            var foreign = 0
            val collected = HashSet<MemoryCache.Key>()
            for ((key, value) in keys) {
                if (key is MemoryCache.Key && key.isPlainData()) collected += key else foreign++
                if (value != Unit) foreign++
            }
            for ((identifier, list) in byIdentifier) {
                if (identifier !is String) foreign++
                for (key in list as List<*>) {
                    if (!(key is MemoryCache.Key && key.isPlainData())) foreign++
                }
            }
            IndexKeys(collected, foreign)
        }
    }.getOrNull()

    /** 鍵が文字列と文字列どうしの付随情報だけでできているか。 */
    private fun MemoryCache.Key.isPlainData(): Boolean {
        // 型引数は実行時に消えているため、実物の型で確かめる。
        val entries: Map<*, *> = extras
        return (key as Any?) is String && entries.all { (name, value) -> name is String && value is String }
    }
}
