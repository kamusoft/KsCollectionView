package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.saveable.Saver

/**
 * 「差分更新」画面の配列と、操作ごとの組み替えの規則。
 *
 * 値は不変で、操作は組み替えた新しい値を返すだけ (表示側に並べ替えを命じない)。iOS Sample の同名の
 * 定義と同じ規則にし、同じ初期状態から同じ順で同じ操作をすれば同じ並びになる。
 *
 * - 初期の配列: ID 1〜20 を昇順に。グループは 5 件ずつ 0〜3 (見出しは A〜D)
 * - 挿入: 新しい ID (21 から 1 ずつ増える) の項目を [DiffUpdatePosition.insertionIndex] に入れる。
 *   グループはその位置の項目 (末尾なら最後の項目、空なら 0) と同じ
 * - 削除: [DiffUpdatePosition.targetIndex] の項目を取り除く
 * - 更新: 同じ位置の項目の「更新」の回数を 1 増やす (ID は変えない)
 * - 移動: 同じ位置の項目を取り除き、グループありなら次のグループ (グループの並びで次。最後の
 *   グループなら最初のグループ) の先頭へ、そのグループの番号に変えて入れる。グループが 1 つしか
 *   無ければ何もしない。グループなしなら、元の位置 i と元の件数 n から (i + n / 2) % n の位置
 *   (取り除いた後の件数を超えるなら末尾) へ入れる
 * - 反転: 配列全体を逆順にする (グループありなら、グループの順とグループ内の順の両方が逆になる)
 * - シャッフル: グループありなら、グループの並び (初めて現れた順) を混ぜ、次にそのグループの順で
 *   各グループの項目を混ぜて並べる。グループなしなら配列全体を混ぜる。混ぜ方は
 *   [SampleRandom.shuffle] で、乱数は種 [ShuffleSeed] から作った 1 本を、元に戻すまで
 *   シャッフルのたびに続けて消費する
 * - 元に戻す: 初期の配列・次の ID・乱数を初期の状態に戻す (表示の形とグループの有無は変えない)
 * - グループありへの切り替え: 同じグループの項目が続くよう、グループが初めて現れた順に集め直す
 *   (グループ内の順は保つ)
 *
 * @property items 表示する配列
 * @property nextId 次に挿入する項目の ID
 * @property randomState シャッフルの乱数の今の状態 ([SampleRandom.state])
 */
data class DiffUpdateModel(
    val items: List<DiffUpdateItem> = InitialItems,
    val nextId: Int = InitialCount + 1,
    val randomState: UInt = ShuffleSeed,
) {
    /** その位置に新しい項目を 1 件入れる。 */
    fun inserting(position: DiffUpdatePosition): DiffUpdateModel {
        val index = position.insertionIndex(items.size)
        val neighbor = items.getOrNull(index) ?: items.lastOrNull()
        val result = items.toMutableList()
        result.add(index, DiffUpdateItem(id = nextId, group = neighbor?.group ?: 0))
        return copy(items = result, nextId = nextId + 1)
    }

    /** その位置の項目を 1 件取り除く。 */
    fun deleting(position: DiffUpdatePosition): DiffUpdateModel {
        val index = position.targetIndex(items.size) ?: return this
        return copy(items = items.toMutableList().apply { removeAt(index) })
    }

    /** その位置の項目の内容を、同じ ID のまま変える。 */
    fun updating(position: DiffUpdatePosition): DiffUpdateModel {
        val index = position.targetIndex(items.size) ?: return this
        val result = items.toMutableList()
        result[index] = result[index].copy(revision = result[index].revision + 1)
        return copy(items = result)
    }

    /**
     * その位置の項目を 1 件、別の位置へ移す。
     *
     * @param grouped グループありで表示しているか。ありなら次のグループの先頭へ移す
     */
    fun moving(position: DiffUpdatePosition, grouped: Boolean): DiffUpdateModel {
        val index = position.targetIndex(items.size) ?: return this
        val result = items.toMutableList()
        if (grouped) {
            val order = groupOrder()
            val current = order.indexOf(items[index].group)
            if (order.size <= 1 || current < 0) return this
            val target = order[(current + 1) % order.size]
            val moved = result.removeAt(index).copy(group = target)
            // 移り先のグループは空にならない (移すのは別のグループの項目) ため、先頭が必ず見つかる。
            val head = result.indexOfFirst { it.group == target }.takeIf { it >= 0 } ?: result.size
            result.add(head, moved)
        } else {
            val count = items.size
            val moved = result.removeAt(index)
            result.add(minOf((index + count / 2) % count, result.size), moved)
        }
        return copy(items = result)
    }

    /** 配列全体を逆順にする。 */
    fun reversed(): DiffUpdateModel = copy(items = items.asReversed().toList())

    /**
     * 配列を混ぜる。
     *
     * @param grouped グループありで表示しているか。ありならグループの並びと各グループの中を混ぜる
     */
    fun shuffled(grouped: Boolean): DiffUpdateModel {
        val random = SampleRandom(randomState)
        val result = if (grouped) {
            val order = groupOrder().toMutableList()
            random.shuffle(order)
            order.flatMap { group ->
                items.filter { it.group == group }.toMutableList().also { random.shuffle(it) }
            }
        } else {
            items.toMutableList().also { random.shuffle(it) }
        }
        return copy(items = result, randomState = random.state)
    }

    /** 初期の配列・次の ID・乱数を初期の状態に戻す。 */
    fun reset(): DiffUpdateModel = DiffUpdateModel()

    /** 同じグループの項目が続くよう、グループが初めて現れた順に集め直す。 */
    fun regrouped(): DiffUpdateModel =
        copy(items = groupOrder().flatMap { group -> items.filter { it.group == group } })

    /** グループが初めて現れた順のグループの番号。 */
    private fun groupOrder(): List<Int> = items.map { it.group }.distinct()

    companion object {
        /** 初期の件数。 */
        const val InitialCount: Int = 20

        /** 1 グループの件数 (初期の配列)。 */
        const val GroupSize: Int = 5

        /** シャッフルの乱数の種。 */
        const val ShuffleSeed: UInt = 20_260_925u

        private val InitialItems: List<DiffUpdateItem> =
            (1..InitialCount).map { DiffUpdateItem(id = it, group = (it - 1) / GroupSize) }

        /**
         * グループの見出しの名前。
         *
         * @param group グループの番号 (0 から)
         */
        fun groupName(group: Int): String = "グループ ${'A' + group % 26}"

        /** 構成変更 (回転) をまたいで保つための保存の形。数値の並びに畳む。 */
        val Saver: Saver<DiffUpdateModel, IntArray> = Saver(
            save = { model ->
                buildList {
                    add(model.nextId)
                    add(model.randomState.toInt())
                    model.items.forEach { item ->
                        add(item.id)
                        add(item.group)
                        add(item.revision)
                    }
                }.toIntArray()
            },
            restore = { saved ->
                DiffUpdateModel(
                    items = (2 until saved.size step 3).map { start ->
                        DiffUpdateItem(id = saved[start], group = saved[start + 1], revision = saved[start + 2])
                    },
                    nextId = saved[0],
                    randomState = saved[1].toUInt(),
                )
            },
        )
    }
}
