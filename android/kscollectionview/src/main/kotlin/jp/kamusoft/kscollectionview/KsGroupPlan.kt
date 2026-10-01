package jp.kamusoft.kscollectionview

import android.os.Parcel
import android.os.Parcelable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * グループの見出しの lazy のキー。
 *
 * 項目の `key` と同じ名前空間に置くと、項目のキーとグループの値が偶然一致したときに重複キーに
 * なるため、ライブラリ内部の型で包んで分ける。lazy のキーは状態保存に載る必要があるため
 * `Parcelable` にし、中身のグループの値も状態保存に載せられる型であることを利用契約にする
 * (core/ADR-0015)。
 *
 * @property value グループの値
 * @property occurrence 同じグループの値が離れて現れる不正入力のときの何回目か。正しい入力では常に 0
 */
internal class KsGroupHeaderKey(val value: Any?, val occurrence: Int) : Parcelable {

    override fun equals(other: Any?): Boolean =
        this === other || (other is KsGroupHeaderKey && value == other.value && occurrence == other.occurrence)

    override fun hashCode(): Int = 31 * (value?.hashCode() ?: 0) + occurrence

    override fun toString(): String = "KsGroupHeaderKey(value=$value, occurrence=$occurrence)"

    override fun describeContents(): Int = 0

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeValue(value)
        dest.writeInt(occurrence)
    }

    internal companion object {
        @JvmField
        val CREATOR: Parcelable.Creator<KsGroupHeaderKey> = object : Parcelable.Creator<KsGroupHeaderKey> {
            override fun createFromParcel(source: Parcel): KsGroupHeaderKey =
                KsGroupHeaderKey(
                    value = source.readValue(KsGroupHeaderKey::class.java.classLoader),
                    occurrence = source.readInt(),
                )

            override fun newArray(size: Int): Array<KsGroupHeaderKey?> = arrayOfNulls(size)
        }
    }
}

/**
 * ルートのヘッダー / フッターの lazy のキー。
 *
 * 項目の数が変わっても同じキーで保ち、配置のアニメーションで動かすためにキーを付ける。項目の
 * `key` と衝突しないよう、ライブラリ内部の型にする。状態保存に載るよう `Parcelable` にする。
 *
 * @property slot 0 がヘッダー、1 がフッター
 */
internal class KsRootSlotKey private constructor(val slot: Int) : Parcelable {

    override fun equals(other: Any?): Boolean = this === other || (other is KsRootSlotKey && slot == other.slot)

    override fun hashCode(): Int = slot

    override fun toString(): String = if (slot == 0) "KsRootSlotKey(header)" else "KsRootSlotKey(footer)"

    override fun describeContents(): Int = 0

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeInt(slot)
    }

    internal companion object {
        /** ルートのヘッダーのキー。 */
        val Header = KsRootSlotKey(0)

        /** ルートのフッターのキー。 */
        val Footer = KsRootSlotKey(1)

        @JvmField
        val CREATOR: Parcelable.Creator<KsRootSlotKey> = object : Parcelable.Creator<KsRootSlotKey> {
            override fun createFromParcel(source: Parcel): KsRootSlotKey = if (source.readInt() == 0) Header else Footer

            override fun newArray(size: Int): Array<KsRootSlotKey?> = arrayOfNulls(size)
        }
    }
}

/**
 * 表示する配列をグループに分けた構成と、項目の位置と lazy の index の対応表。
 *
 * lazy には「ルートのヘッダー → (各グループの見出し → 項目) → フッター」の順に並べる。見出しを
 * 宣言しない場合とグループを宣言しない場合は見出しを並べない (グループを宣言しない場合は配列全体を
 * 1 つのグループとして扱う)。表はグループの数に比例する情報だけを持ち、項目の位置と lazy の index は
 * グループの先頭の位置からその場で求める。
 *
 * @property itemCount 表示する項目の数
 * @property hasHeaders グループの見出しを並べるかどうか
 * @property pinsHeaders 見出しを上端に固定するかどうか (見出しを並べないときは false)
 * @property leadingCount 項目より前に並ぶルートのヘッダーの数 (0 か 1)
 * @property hasFooter ルートのフッターを並べるかどうか
 */
internal class KsGroupPlan(
    val itemCount: Int,
    private val starts: IntArray,
    private val values: List<Any?>,
    private val occurrences: IntArray,
    val hasHeaders: Boolean,
    val pinsHeaders: Boolean,
    val leadingCount: Int,
    val hasFooter: Boolean,
) {
    /** グループの数。項目が 0 件ならグループも 0。 */
    val groupCount: Int get() = starts.size

    /** ルートのヘッダー・見出し・項目・フッターを合わせた lazy の項目の数。 */
    val totalLazyCount: Int =
        leadingCount + itemCount + (if (hasHeaders) groupCount else 0) + (if (hasFooter) 1 else 0)

    /** グループ [group] の先頭の項目の位置。 */
    fun groupStart(group: Int): Int = starts[group]

    /** グループ [group] の最後の項目の次の位置。 */
    fun groupEnd(group: Int): Int = if (group + 1 < starts.size) starts[group + 1] else itemCount

    /** グループ [group] のグループの値。 */
    fun groupValue(group: Int): Any? = values[group]

    /** グループ [group] の見出しのキー。 */
    fun headerKey(group: Int): KsGroupHeaderKey = KsGroupHeaderKey(values[group], occurrences[group])

    /** グループ [group] の見出しの lazy の index。見出しを並べないときは使わない。 */
    fun headerLazyIndex(group: Int): Int = leadingCount + starts[group] + group

    /** グループ [group] の先頭の項目の lazy の index。 */
    fun firstItemLazyIndex(group: Int): Int =
        leadingCount + starts[group] + (if (hasHeaders) group + 1 else 0)

    /** 項目の位置 [itemIndex] が属するグループ。 */
    fun groupOfItem(itemIndex: Int): Int {
        // starts は昇順。itemIndex 以下で最大の先頭を持つグループを二分探索で探す。
        var low = 0
        var high = starts.size - 1
        while (low < high) {
            val mid = (low + high + 1) ushr 1
            if (starts[mid] <= itemIndex) low = mid else high = mid - 1
        }
        return low
    }

    /** 項目の位置から lazy の index を求める。 */
    fun lazyIndexOfItem(itemIndex: Int): Int =
        leadingCount + itemIndex + (if (hasHeaders) groupOfItem(itemIndex) + 1 else 0)

    /**
     * lazy の index が指すものを返す。項目なら項目の位置 (0 以上)、グループの見出しなら
     * `-(グループ + 2)`、ルートのヘッダー / フッターと範囲外は -1。
     */
    private fun entryAt(lazyIndex: Int): Int {
        val local = lazyIndex - leadingCount
        val entryCount = itemCount + (if (hasHeaders) groupCount else 0)
        if (local < 0 || local >= entryCount) return -1
        if (!hasHeaders) return local
        // 見出しの位置 (starts[g] + g) が local 以下で最大のグループを探す。
        var low = 0
        var high = starts.size - 1
        while (low < high) {
            val mid = (low + high + 1) ushr 1
            if (starts[mid] + mid <= local) low = mid else high = mid - 1
        }
        val headerLocal = starts[low] + low
        return if (local == headerLocal) -(low + 2) else local - low - 1
    }

    /** lazy の index が指す項目の位置。項目でなければ -1。 */
    fun itemIndexOfLazy(lazyIndex: Int): Int = entryAt(lazyIndex).coerceAtLeast(-1)

    /** lazy の index が指すグループの見出しのグループ。見出しでなければ -1。 */
    fun groupOfHeaderLazy(lazyIndex: Int): Int {
        val entry = entryAt(lazyIndex)
        return if (entry <= -2) -(entry + 2) else -1
    }

    /** lazy の index がルートのヘッダーかどうか。 */
    fun isRootHeader(lazyIndex: Int): Boolean = leadingCount == 1 && lazyIndex == 0

    /** lazy の index がルートのフッターかどうか。 */
    fun isRootFooter(lazyIndex: Int): Boolean = hasFooter && lazyIndex == totalLazyCount - 1

    /**
     * 列数 [columns] のときの行の数え方を作る。
     *
     * ルートのヘッダー / フッターと各見出しを 1 行、各グループの項目を切り上げの行数として数える。
     * `LazyVerticalGrid` の行の番号と同じ数え方になる (見出しのないグループは最終行の最後の項目が
     * 行の残りを占めるため、次のグループは行頭から始まる)。
     */
    fun rows(columns: Int): KsGroupRows {
        val columnCount = columns.coerceAtLeast(1)
        val firstRows = IntArray(groupCount)
        var row = leadingCount
        for (group in 0 until groupCount) {
            firstRows[group] = row
            val count = groupEnd(group) - groupStart(group)
            row += (if (hasHeaders) 1 else 0) + (count + columnCount - 1) / columnCount
        }
        val total = row + (if (hasFooter) 1 else 0)
        return KsGroupRows(this, columnCount, firstRows, total)
    }

    /**
     * グループ [fromGroup] の項目 1 件をグループ [toGroup] へ移した構成を作る。
     *
     * 並べ替えの仮の並びと、受け入れた直後の並びの表示に使う。項目のグループの値はまだ変わっていない
     * ため、グループの値から組み直さずに、各グループの項目の数だけを変える。
     *
     * @param keepsEmptyGroups 項目が無くなったグループを残すかどうか。ドラッグの間は元のグループの見出しを
     *   残し、受け入れた時点で見出しごと取り除く (core/ADR-0029)
     */
    fun movingItem(fromGroup: Int, toGroup: Int, keepsEmptyGroups: Boolean): KsGroupPlan {
        val counts = IntArray(groupCount) { group -> groupEnd(group) - groupStart(group) }
        counts[fromGroup] -= 1
        counts[toGroup] += 1
        val kept = (0 until groupCount).filter { keepsEmptyGroups || counts[it] > 0 }
        val newStarts = IntArray(kept.size)
        var start = 0
        kept.forEachIndexed { position, group ->
            newStarts[position] = start
            start += counts[group]
        }
        return KsGroupPlan(
            itemCount = itemCount,
            starts = newStarts,
            values = kept.map { values[it] },
            occurrences = IntArray(kept.size) { occurrences[kept[it]] },
            hasHeaders = hasHeaders,
            pinsHeaders = pinsHeaders,
            leadingCount = leadingCount,
            hasFooter = hasFooter,
        )
    }

    /** ルートのヘッダー / フッターの有無だけを差し替えた構成。同じなら自分自身を返す。 */
    fun withRootSlots(leadingCount: Int, hasFooter: Boolean): KsGroupPlan =
        if (leadingCount == this.leadingCount && hasFooter == this.hasFooter) {
            this
        } else {
            KsGroupPlan(itemCount, starts, values, occurrences, hasHeaders, pinsHeaders, leadingCount, hasFooter)
        }

    /**
     * グループの構成 (境目・グループの値・何回目か) と並べ方がすべて等しいかどうか。
     *
     * グループの値の取り出し方が差し替わっても、構成が変わらなければ組み直さないために比べる。
     * 比べる手間はグループの数に比例する。
     */
    override fun equals(other: Any?): Boolean =
        this === other || (
            other is KsGroupPlan &&
                itemCount == other.itemCount &&
                hasHeaders == other.hasHeaders &&
                pinsHeaders == other.pinsHeaders &&
                leadingCount == other.leadingCount &&
                hasFooter == other.hasFooter &&
                starts.contentEquals(other.starts) &&
                occurrences.contentEquals(other.occurrences) &&
                values == other.values
            )

    override fun hashCode(): Int {
        var result = itemCount
        result = 31 * result + starts.contentHashCode()
        result = 31 * result + values.hashCode()
        result = 31 * result + occurrences.contentHashCode()
        result = 31 * result + hasHeaders.hashCode()
        result = 31 * result + pinsHeaders.hashCode()
        result = 31 * result + leadingCount
        result = 31 * result + hasFooter.hashCode()
        return result
    }
}

/**
 * 列数を決めたときの、lazy の index から行の番号への対応。
 *
 * @property columns 列数
 * @property totalRows ルートのヘッダー / フッターと見出しを含む全体の行の数
 */
internal class KsGroupRows(
    private val plan: KsGroupPlan,
    val columns: Int,
    private val firstRows: IntArray,
    val totalRows: Int,
) {
    /** lazy の index が載る行の番号。 */
    fun rowOfLazy(lazyIndex: Int): Int {
        if (plan.isRootHeader(lazyIndex)) return 0
        if (plan.isRootFooter(lazyIndex)) return totalRows - 1
        val headerGroup = plan.groupOfHeaderLazy(lazyIndex)
        if (headerGroup >= 0) return firstRows[headerGroup]
        val itemIndex = plan.itemIndexOfLazy(lazyIndex)
        if (itemIndex < 0) return 0
        val group = plan.groupOfItem(itemIndex)
        val position = itemIndex - plan.groupStart(group)
        return firstRows[group] + (if (plan.hasHeaders) 1 else 0) + position / columns
    }
}

/**
 * 項目の上下に置く間隔の値。
 *
 * 行間・見出しの下の間隔・グループ間の間隔は、いずれも項目の側 (項目の上下の余白) に置く。
 * 見出しやルートのヘッダー / フッターの側に置くと、固定中の見出しと一緒に空白が上端へ貼り付き、
 * また見出しの前後だけ行間を外せないため。
 *
 * @property row 行と行の間隔
 * @property headerItem 見出しとそのグループの先頭行の間の間隔
 * @property group グループとグループの間の間隔
 */
internal class KsGroupSpacing(val row: Dp, val headerItem: Dp, val group: Dp) {
    internal companion object {
        /** layout 値から、実際に使う (負の指定を 0 にした) 間隔を作る。 */
        fun of(layout: KsLayout): KsGroupSpacing = KsGroupSpacing(
            row = layout.effectiveRowSpacing,
            headerItem = layout.effectiveHeaderItemSpacing,
            group = layout.effectiveGroupSpacing,
        )
    }
}

/**
 * グループの中で [position] 番目の項目の上に置く間隔。
 *
 * グループの先頭行は見出しの下の間隔 (見出しが無ければ 0)、それ以外の行は行間。
 */
internal fun KsGroupPlan.topSpacing(position: Int, columns: Int, spacing: KsGroupSpacing): Dp =
    if (position / columns == 0) {
        if (hasHeaders) spacing.headerItem else 0.dp
    } else {
        spacing.row
    }

/**
 * グループ [group] の [position] 番目の項目の下に置く間隔。
 *
 * 最後のグループ以外の最終行はグループ間の間隔、それ以外は 0。コンテンツの末尾には間隔を入れない。
 */
internal fun KsGroupPlan.bottomSpacing(group: Int, position: Int, columns: Int, spacing: KsGroupSpacing): Dp {
    if (group == groupCount - 1) return 0.dp
    val count = groupEnd(group) - groupStart(group)
    return if (position / columns == (count - 1) / columns) spacing.group else 0.dp
}

/** グループの宣言を配列に当てはめた結果。 */
internal class KsGroupResolution(
    val plan: KsGroupPlan,
    val diagnostics: List<String>,
)

/**
 * 表示する配列をグループに分ける。
 *
 * 配列の順に同じグループの値が続く範囲を 1 つのグループにする。同じグループの値が離れた位置に
 * 再び現れる入力と、状態保存に載せられないグループの値は不正入力として診断に集める
 * (core/ADR-0011、core/ADR-0015)。離れて現れた同じ値は配列の順のまま別々のグループにし、何回目かで見出しの
 * キーを分ける。[groupValueOf] が null (グループを宣言しない) なら配列全体を 1 つのグループにする。
 *
 * @param hasHeaders 見出しを並べるかどうか
 * @param pinsHeaders 見出しを上端に固定するかどうか
 */
internal fun <Item> resolveGroups(
    items: List<Item>,
    groupValueOf: ((Item) -> Any?)?,
    hasHeaders: Boolean,
    pinsHeaders: Boolean,
    hasRootHeader: Boolean,
    hasRootFooter: Boolean,
): KsGroupResolution {
    val leadingCount = if (hasRootHeader) 1 else 0
    if (groupValueOf == null || items.isEmpty()) {
        val starts = if (items.isEmpty()) IntArray(0) else IntArray(1)
        val plan = KsGroupPlan(
            itemCount = items.size,
            starts = starts,
            values = if (items.isEmpty()) emptyList() else listOf(null),
            occurrences = IntArray(starts.size),
            hasHeaders = false,
            pinsHeaders = false,
            leadingCount = leadingCount,
            hasFooter = hasRootFooter,
        )
        return KsGroupResolution(plan, emptyList())
    }

    val starts = ArrayList<Int>()
    val values = ArrayList<Any?>()
    val occurrences = ArrayList<Int>()
    // グループの値ごとに、これまでに何回グループとして現れたか。
    val seenCounts = HashMap<Any?, Int>()
    var separatedValue: Any? = null
    var hasSeparatedValue = false
    var unsavableValue: Any? = null
    var current: Any? = null
    items.forEachIndexed { index, item ->
        val value = groupValueOf(item)
        if (index == 0 || value != current) {
            val occurrence = seenCounts[value] ?: 0
            if (occurrence > 0 && !hasSeparatedValue) {
                separatedValue = value
                hasSeparatedValue = true
            }
            seenCounts[value] = occurrence + 1
            if (unsavableValue == null && value != null && !isSavableKey(value)) {
                unsavableValue = value
            }
            starts += index
            values += value
            occurrences += occurrence
            current = value
        }
    }

    val diagnostics = buildList {
        if (hasSeparatedValue) {
            add(
                "同じグループの値 $separatedValue が配列の離れた位置に再び現れました。" +
                    "同じグループの項目は続けて並べてください。配列の順のまま別々のグループとして表示を継続します",
            )
        }
        unsavableValue?.let { value ->
            add(
                "グループの値が状態保存に載せられない型です: ${value::class.java.name}。" +
                    "文字列・数値・enum・Serializable・Parcelable のいずれかを返してください",
            )
        }
    }
    val plan = KsGroupPlan(
        itemCount = items.size,
        starts = starts.toIntArray(),
        values = values,
        occurrences = occurrences.toIntArray(),
        hasHeaders = hasHeaders,
        pinsHeaders = hasHeaders && pinsHeaders,
        leadingCount = leadingCount,
        hasFooter = hasRootFooter,
    )
    return KsGroupResolution(plan, diagnostics)
}
