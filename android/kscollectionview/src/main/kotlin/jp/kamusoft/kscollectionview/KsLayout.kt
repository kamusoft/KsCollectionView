package jp.kamusoft.kscollectionview

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * コレクションの表示形態です。
 *
 * リストとグリッドを別コンポーネントに分けず、この値 1 つで宣言します。表示中に差し替えると
 * データとスクロール位置を保ったまま表示形態が切り替わります。
 */
public sealed interface KsLayout {
    /**
     * 1 列のリストです。
     *
     * 行間を空けない既定のリストは `KsLayout.List` と括弧なしでも宣言できます。
     *
     * @param rowSpacing 行と行の間隔
     */
    public open class List(public val rowSpacing: Dp = 0.dp) : KsLayout {
        /** 行間を空けないリストです。`KsLayout.List` と書いたときの値になります。 */
        public companion object : List(0.dp)

        override fun equals(other: Any?): Boolean =
            this === other || (other is List && rowSpacing == other.rowSpacing)

        override fun hashCode(): Int = rowSpacing.hashCode()

        override fun toString(): String = "KsLayout.List(rowSpacing=$rowSpacing)"
    }

    /**
     * 多列のグリッドです。
     *
     * @param columns 列数の決め方
     * @param rowSpacing 行と行の間隔
     * @param columnSpacing 列と列の間隔
     */
    public data class Grid(
        val columns: KsColumns,
        val rowSpacing: Dp = 0.dp,
        val columnSpacing: Dp = 0.dp,
    ) : KsLayout
}

/** グリッドの列数の決め方です。 */
public sealed interface KsColumns {
    /**
     * コンテナが縦長のときと横長のときで列数を切り替えます。
     *
     * 判定はコンポーネント自身のコンテナの縦横比で行うため、分割画面や折りたたみでも
     * 見えている領域の形に従います。
     *
     * @param portrait コンテナの高さが幅より大きいときの列数
     * @param landscape コンテナの幅が高さ以上のときの列数
     */
    public data class Fixed(val portrait: Int, val landscape: Int) : KsColumns {
        /**
         * 向きによらず同じ列数を使います。
         *
         * @param count 列数
         */
        public constructor(count: Int) : this(count, count)
    }

    /**
     * 各項目が最小幅以上になる範囲で最大の列数を自動的に決めます。
     *
     * 余剰幅は各項目の幅へ均等に配分され、列と列の間隔は指定した値のまま保たれます。
     *
     * @param minItemWidth 項目の最小幅
     */
    public data class Adaptive(val minItemWidth: Dp) : KsColumns
}

/** 行間として実際に使う値。負の指定は 0 として扱う。 */
internal val KsLayout.effectiveRowSpacing: Dp
    get() = when (this) {
        is KsLayout.List -> rowSpacing
        is KsLayout.Grid -> rowSpacing
    }.coerceAtLeast(0.dp)

/** 列間として実際に使う値。list は 1 列のため常に 0。 */
internal val KsLayout.effectiveColumnSpacing: Dp
    get() = when (this) {
        is KsLayout.List -> 0.dp
        is KsLayout.Grid -> columnSpacing.coerceAtLeast(0.dp)
    }

/** list レイアウトかどうか (区切り線を描く条件)。 */
internal val KsLayout.isList: Boolean
    get() = this is KsLayout.List

/**
 * コンテナの向きから列数を決める。
 *
 * `KsColumns.Adaptive` は列数ではなく最小幅で決まるため、ここでは扱わない。
 *
 * @param isPortrait コンテナの高さが幅より大きいなら true
 */
internal fun KsColumns.Fixed.resolveCount(isPortrait: Boolean): Int =
    (if (isPortrait) portrait else landscape).coerceAtLeast(1)

/** 不正な指定を洗い出す。空なら適正。 */
internal fun KsLayout.invalidValueMessages(): kotlin.collections.List<String> = buildList {
    val rowSpacing = when (this@invalidValueMessages) {
        is KsLayout.List -> rowSpacing
        is KsLayout.Grid -> rowSpacing
    }
    if (rowSpacing < 0.dp) add("rowSpacing は 0 以上で指定してください: $rowSpacing")

    if (this@invalidValueMessages is KsLayout.Grid) {
        if (columnSpacing < 0.dp) add("columnSpacing は 0 以上で指定してください: $columnSpacing")
        when (val columns = columns) {
            is KsColumns.Fixed -> {
                if (columns.portrait <= 0 || columns.landscape <= 0) {
                    add("列数は 1 以上で指定してください: $columns")
                }
            }

            is KsColumns.Adaptive -> {
                if (columns.minItemWidth <= 0.dp) {
                    add("minItemWidth は 0 より大きい値で指定してください: ${columns.minItemWidth}")
                }
            }
        }
    }
}
