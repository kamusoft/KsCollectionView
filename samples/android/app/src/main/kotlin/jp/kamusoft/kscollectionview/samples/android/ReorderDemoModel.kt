package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.setValue
import jp.kamusoft.kscollectionview.KsReorderDestination
import jp.kamusoft.kscollectionview.KsReorderMove
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 「並べ替え」画面の項目と操作の切り替え、置いたときの並べ替えの規則。
 *
 * iOS Sample の同名の定義と同じ規則にし、同じ操作の順で同じ並びになる。状態は Compose の状態で持ち、
 * メインスレッドからだけ操作する。
 *
 * - 初期の配列: ID 1〜10,000 を昇順に。グループは 100 件ずつ 1〜100
 * - 動かせる項目: 10 の倍数の項目は動かせない ([ReorderDemoItem.isMovable])
 * - 置いたとき ([move]): 「置いても受け入れない」がオンなら並べ替えず、「並べ替えを受け入れませんでした」を
 *   出して受け入れないと返す。オフなら [applying] の規則で並べ替えて受け入れたと返す
 * - 置けるか ([canDrop]): 「グループをまたがせない」がオンの間は、行き先のグループが元のグループと
 *   同じときだけ置ける。グループをオフにしている間 (知らせにグループの値が無い) はどこにでも置ける
 * - 長押し ([didLongPress]): 「長押し: Item n」を出す。一覧は並べ替えのスイッチがオンの間は長押しを
 *   知らせないため、スイッチがオフの間だけ出る
 * - 帯 ([notice]): 出してから [SamplePanelMetrics.BannerDurationMillis] (3 秒) たったら消す。その間に次の帯を
 *   出したら、その時点から 3 秒出す
 * - 構成変更 (回転) をまたいで戻すため、受け入れた並べ替えを記録し、戻すときは初期の配列から同じ順に当て直す
 *
 * @param noticeScope 帯を決まった時間の後に消す処理を実行するスコープ。画面を離れたら取り消される
 * @param initialEdits 戻すときに当て直す並べ替えの記録 ([Saver] が保存したもの)
 * @param awaitNoticeTimeout 帯を出してから消すまで待つ処理
 */
class ReorderDemoModel(
    private val noticeScope: CoroutineScope,
    initialEdits: IntArray = IntArray(0),
    private val awaitNoticeTimeout: suspend () -> Unit = { delay(SamplePanelMetrics.BannerDurationMillis) },
) {
    /** 受け入れた並べ替えの記録。1 回につき (項目の番号, 行き先の後ろの項目の番号 (末尾なら 0), グループ (無ければ 0))。 */
    private var edits: IntArray = initialEdits

    /** 表示している項目。 */
    var items: List<ReorderDemoItem> by mutableStateOf(replay(initialEdits))
        private set

    /** 並べ替えのスイッチ。 */
    var isReorderEnabled: Boolean by mutableStateOf(true)

    /** グループの有無。 */
    var isGrouped: Boolean by mutableStateOf(true)

    /** 「グループをまたがせない」。 */
    var keepsGroups: Boolean by mutableStateOf(false)

    /** 「置いても受け入れない」。 */
    var rejectsMoves: Boolean by mutableStateOf(false)

    /** 画面の上の帯に出している知らせ。出していなければ null。 */
    var notice: String? by mutableStateOf(null)
        private set

    /** 最後に出した知らせ。帯が消えていく間も、その文言を出し続けるために使う。 */
    var lastNotice: String by mutableStateOf("")
        private set

    /** 帯を決まった時間の後に消す処理。 */
    private var noticeJob: Job? = null

    /**
     * 置いたときの知らせを受ける。受け入れたら配列を並べ替えて true を返す。
     *
     * @param move 置いたときの知らせ
     */
    fun move(move: KsReorderMove<ReorderDemoItem>): Boolean {
        if (rejectsMoves) {
            showNotice(ReorderDemoText.Rejected)
            return false
        }
        items = applying(move, items)
        val before = (move.destination as? KsReorderDestination.Before)?.item?.id ?: 0
        edits += intArrayOf(move.item.id, before, move.group as? Int ?: 0)
        return true
    }

    /**
     * 行き先に置けるか。
     *
     * @param move 行き先の候補の知らせ
     */
    fun canDrop(move: KsReorderMove<ReorderDemoItem>): Boolean {
        val group = move.group as? Int
        if (!keepsGroups || group == null) return true
        return group == move.item.group
    }

    /**
     * 項目を長押ししたときの知らせを出す。
     *
     * @param item 長押しした項目
     */
    fun didLongPress(item: ReorderDemoItem) {
        showNotice(ReorderDemoText.longPressed(item))
    }

    /** 帯を出し、決まった時間の後に消す。 */
    private fun showNotice(text: String) {
        noticeJob?.cancel()
        notice = text
        lastNotice = text
        noticeJob = noticeScope.launch {
            awaitNoticeTimeout()
            notice = null
        }
    }

    /** 保存した切り替えの値を戻す。 */
    private fun restoreFlags(flags: Int) {
        isReorderEnabled = flags and FlagReorder != 0
        isGrouped = flags and FlagGrouped != 0
        keepsGroups = flags and FlagKeepsGroups != 0
        rejectsMoves = flags and FlagRejectsMoves != 0
    }

    /** 切り替えの値をまとめた数。 */
    private val flags: Int
        get() = (if (isReorderEnabled) FlagReorder else 0) or
            (if (isGrouped) FlagGrouped else 0) or
            (if (keepsGroups) FlagKeepsGroups else 0) or
            (if (rejectsMoves) FlagRejectsMoves else 0)

    companion object {
        /** 項目の件数。 */
        const val ItemCount = 10_000

        /** 1 グループの件数 (初期の配列)。 */
        const val GroupSize = 100

        private const val FlagReorder = 1
        private const val FlagGrouped = 2
        private const val FlagKeepsGroups = 4
        private const val FlagRejectsMoves = 8

        /** 初期の配列。 */
        fun initialItems(): List<ReorderDemoItem> =
            (1..ItemCount).map { ReorderDemoItem(id = it, group = (it - 1) / GroupSize + 1) }

        /**
         * 置いたときの知らせのとおりに並べ替えた配列を返す。
         *
         * 動かした項目を取り除き、行き先 (`Before` ならその項目の前、`End` なら知らせのグループの末尾。
         * グループの値が無ければ配列の末尾) に入れる。項目のグループの値は、知らせのグループの値に書き換える。
         * 知らせにグループの値が無い (グループをオフにしている) ときは、行き先の隣の項目 (`Before` ならその項目、
         * `End` なら最後の項目) のグループの値に書き換える。オフの間に動かした項目のグループの値を変えないと、
         * オンに戻したときに同じグループの値が離れた位置に現れ、一覧に渡せない配列になるため。
         *
         * @param move 置いたときの知らせ
         * @param items 並べ替える前の配列
         */
        fun applying(move: KsReorderMove<ReorderDemoItem>, items: List<ReorderDemoItem>): List<ReorderDemoItem> {
            val from = items.indexOfFirst { it.id == move.item.id }
            if (from < 0) return items
            val result = items.toMutableList()
            val moved = result.removeAt(from)
            val group = move.group as? Int
            when (val destination = move.destination) {
                is KsReorderDestination.Before -> {
                    val index = result.indexOfFirst { it.id == destination.item.id }
                    if (index < 0) return items
                    result.add(index, moved.copy(group = group ?: result[index].group))
                }
                KsReorderDestination.End -> if (group != null) {
                    val last = result.indexOfLast { it.group == group }
                    result.add(if (last < 0) result.size else last + 1, moved.copy(group = group))
                } else {
                    result.add(moved.copy(group = result.lastOrNull()?.group ?: moved.group))
                }
            }
            return result
        }

        /** 並べ替えの記録を初期の配列から順に当て直す。 */
        private fun replay(edits: IntArray): List<ReorderDemoItem> {
            var items = initialItems()
            for (offset in edits.indices step 3) {
                val item = items.first { it.id == edits[offset] }
                val destination = if (edits[offset + 1] == 0) {
                    KsReorderDestination.End
                } else {
                    KsReorderDestination.Before(items.first { it.id == edits[offset + 1] })
                }
                val group = edits[offset + 2].takeIf { it != 0 }
                items = applying(KsReorderMove(item, destination, group), items)
            }
            return items
        }

        /**
         * 構成変更 (回転) をまたいで戻すための保存の形。切り替えの値と並べ替えの記録を保存する。
         *
         * @param noticeScope 戻したモデルが帯を消す処理を実行するスコープ
         */
        fun saver(noticeScope: CoroutineScope): Saver<ReorderDemoModel, IntArray> = Saver(
            save = { intArrayOf(it.flags) + it.edits },
            restore = { saved ->
                ReorderDemoModel(noticeScope, initialEdits = saved.copyOfRange(1, saved.size)).apply {
                    restoreFlags(saved[0])
                }
            },
        )
    }
}
