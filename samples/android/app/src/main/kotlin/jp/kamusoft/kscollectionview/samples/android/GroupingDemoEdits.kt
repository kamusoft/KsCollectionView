package jp.kamusoft.kscollectionview.samples.android

/**
 * 「グループ化」画面の 2 つの操作で、配列をデータ側で組み替える規則。
 *
 * どちらも新しい配列を作って返すだけで、表示側に並べ替えを命じない。同じグループの項目は
 * 操作の後も続いて並ぶ (離れた位置に同じグループが現れる配列は作らない)。
 * iOS Sample の同名の定義と同じ規則にする。
 */
object GroupingDemoEdits {
    /** グループの並び順を反転する。グループの中の項目の順は変えない。 */
    fun reversingGroups(items: List<GroupingDemoItem>): List<GroupingDemoItem> =
        runs(items).asReversed().flatMap { items.subList(it.first, it.last + 1) }

    /**
     * 通し番号 [offset] の項目を、隣のグループへ移す。
     *
     * 項目がグループの末尾に近ければ (末尾までの件数が先頭までの件数以下なら) 次のグループの先頭へ、
     * 先頭に近ければ前のグループの末尾へ移す。近い側に隣のグループが無ければ反対側へ移す。
     * 移した項目のグループの番号は移り先のグループのものに変わる。グループが 1 つしか無いときは
     * 何もしない。
     *
     * @param offset 移す項目の通し番号 (先頭を 0 とする)
     * @param items 今の配列
     * @return 組み替えた配列。移せないときは [items] のまま
     */
    fun movingItem(offset: Int, items: List<GroupingDemoItem>): List<GroupingDemoItem> {
        if (offset !in items.indices) return items
        val run = runs(items).firstOrNull { offset in it } ?: return items
        // run.last + 1 は次のグループの先頭 (iOS の半開区間の上端と同じ位置)。
        val end = run.last + 1
        val hasNext = end < items.size
        val hasPrevious = run.first > 0
        val prefersNext = offset - run.first >= run.last - offset

        val result = items.toMutableList()
        val moved = result.removeAt(offset)
        when {
            hasNext && (prefersNext || !hasPrevious) -> {
                // 取り除いた分だけ次のグループの先頭が 1 つ前へ詰まる。
                result.add(end - 1, moved.copy(group = items[end].group))
            }

            hasPrevious -> {
                // 前のグループの末尾のすぐ後ろ (= 今のグループの先頭の位置) に入れる。
                result.add(run.first, moved.copy(group = items[run.first - 1].group))
            }

            else -> return items
        }
        return result
    }

    /** 同じグループが続く範囲を、配列の順に返す。 */
    private fun runs(items: List<GroupingDemoItem>): List<IntRange> {
        if (items.isEmpty()) return emptyList()
        val runs = mutableListOf<IntRange>()
        var start = 0
        for (index in 1 until items.size) {
            if (items[index].group != items[index - 1].group) {
                runs += start until index
                start = index
            }
        }
        runs += start until items.size
        return runs
    }
}
