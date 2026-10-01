package jp.kamusoft.kscollectionview

/**
 * 並べ替えで項目を置く先。行き先のグループと、行き先の項目の組。
 *
 * @property groupIndex 行き先のグループの、配列の先頭からの並び順。グループを宣言していない一覧では常に 0
 * @property beforeIndex 行き先の項目 (この項目の前に置く) の、動かす前の配列での位置。グループの末尾なら [End]
 */
internal data class KsReorderPlacement(val groupIndex: Int, val beforeIndex: Int) {
    /** グループの末尾に置くかどうか。 */
    val isEnd: Boolean get() = beforeIndex == End

    internal companion object {
        /** グループの末尾を表す [beforeIndex] の値。 */
        const val End: Int = -1
    }
}

/**
 * 並べ替えの行き先を、表示から切り離して求める (core/ADR-0028、core/ADR-0029)。
 *
 * 動かす前の配列のグループの区切り ([plan]) を受け取り、動かした項目を「あるグループの中の、動かした項目を
 * 除いた何番目」に置いたときの行き先を求める。行き先は、置いた位置の後ろに同じグループの項目があれば
 * その項目の前、無ければそのグループの末尾とする。グループの境目は、前のグループの末尾と次のグループの
 * 先頭のどちらに置いたかを、置いた先のグループで区別する。
 *
 * 読み上げの移動操作の「1 つ前 / 1 つ後ろ」も同じ規則で求める。グループの先頭の項目の 1 つ前は前の
 * グループの末尾、グループの最後の項目の 1 つ後ろは次のグループの先頭とする (core/ADR-0032)。
 *
 * グループを宣言していない一覧では、配列全体を 1 つのグループとして持つ構成を渡す。
 */
internal class KsReorderPlanner(private val plan: KsGroupPlan) {

    /** グループの数。 */
    val groupCount: Int get() = plan.groupCount

    /** 位置 [index] の項目が属するグループ。 */
    fun groupOf(index: Int): Int = plan.groupOfItem(index)

    /** グループ [group] の項目のうち、位置 [source] の項目を除いた数。 */
    fun countExcluding(source: Int, group: Int): Int {
        val start = plan.groupStart(group)
        val end = plan.groupEnd(group)
        return end - start - (if (source in start until end) 1 else 0)
    }

    /**
     * 位置 [source] の項目を、グループ [group] の中の、動かした項目を除いた [position] 番目に置いたときの
     * 行き先。[position] がグループの件数以上なら末尾。
     */
    fun placement(source: Int, group: Int, position: Int): KsReorderPlacement {
        val start = plan.groupStart(group)
        val end = plan.groupEnd(group)
        val clamped = position.coerceAtLeast(0)
        // 動かした項目を除いた並びの番号を、配列の位置へ戻す。
        val offset = if (source in start until end && clamped >= source - start) 1 else 0
        val index = start + clamped + offset
        return KsReorderPlacement(group, if (index < end) index else KsReorderPlacement.End)
    }

    /** 動かす前の位置の行き先。求めた行き先がこれと同じなら、元の位置に置いたことになる。 */
    fun originalPlacement(source: Int): KsReorderPlacement {
        val group = plan.groupOfItem(source)
        return placement(source, group, source - plan.groupStart(group))
    }

    /** 1 つ前へ動かすときの行き先。一覧の先頭の項目では null。 */
    fun previousPlacement(source: Int): KsReorderPlacement? {
        val group = plan.groupOfItem(source)
        val offset = source - plan.groupStart(group)
        if (offset > 0) return placement(source, group, offset - 1)
        if (group == 0) return null
        return KsReorderPlacement(group - 1, KsReorderPlacement.End)
    }

    /** 1 つ後ろへ動かすときの行き先。一覧の最後の項目では null。 */
    fun nextPlacement(source: Int): KsReorderPlacement? {
        val group = plan.groupOfItem(source)
        val start = plan.groupStart(group)
        val offset = source - start
        if (offset < plan.groupEnd(group) - start - 1) return placement(source, group, offset + 1)
        if (group >= plan.groupCount - 1) return null
        return placement(source, group + 1, 0)
    }

    /** 行き先 [placement] に置いた後の配列で、動かした項目 (動かす前の位置 [source]) が入る位置。 */
    fun targetIndex(source: Int, placement: KsReorderPlacement): Int {
        val insertion = if (placement.isEnd) plan.groupEnd(placement.groupIndex) else placement.beforeIndex
        // 動かした項目を取り除いた分だけ、後ろの位置を 1 つ詰める。
        return if (insertion > source) insertion - 1 else insertion
    }

    /**
     * 行き先 [placement] に置いた後の、グループの構成。動かした項目は行き先のグループに属する。
     *
     * @param keepsEmptyGroups 項目が無くなったグループを残すかどうか
     */
    fun movedPlan(source: Int, placement: KsReorderPlacement, keepsEmptyGroups: Boolean): KsGroupPlan =
        plan.movingItem(plan.groupOfItem(source), placement.groupIndex, keepsEmptyGroups)
}

/**
 * [base] の位置 [source] の項目を位置 [target] へ動かした並びを、写しを作らずに表す。
 *
 * ドラッグの間は行き先が変わるたびに並びを作り直すため、件数に比例する写しを作らない。
 */
internal class KsReorderedList<Item>(
    private val base: List<Item>,
    private val source: Int,
    val target: Int,
) : AbstractList<Item>() {
    override val size: Int get() = base.size

    override fun get(index: Int): Item = base[baseIndexOf(index)]

    /** 動かした並びの位置 [index] の、動かす前の位置。 */
    fun baseIndexOf(index: Int): Int = when {
        index == target -> source
        source < target && index in source until target -> index + 1
        target < source && index in (target + 1)..source -> index - 1
        else -> index
    }
}
