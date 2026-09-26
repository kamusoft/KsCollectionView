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
     * 行間を空けない既定のリストは `KsLayout.List` と括弧なしでも宣言できます。間隔はいずれも
     * 0 以上で指定します。負の値は誤りで、デバッグビルドでは停止して知らせ、リリースビルドでは
     * 警告を記録して 0 として表示します。
     *
     * @param rowSpacing 行と行の間隔。グループの見出しの前後とヘッダー / フッターの前後には入らない
     * @param groupSpacing グループとグループの間の間隔。前のグループの最終行と次のグループの見出しの
     *   間に入り、コンテンツ全体の先頭と末尾には入らない。グループを宣言しない場合は使われない
     * @param headerItemSpacing グループの見出しと、そのグループの先頭行の間の間隔。見出しを宣言しない
     *   場合は使われない
     */
    public open class List(
        public val rowSpacing: Dp = 0.dp,
        public val groupSpacing: Dp = 0.dp,
        public val headerItemSpacing: Dp = 0.dp,
    ) : KsLayout {
        /** 間隔を空けないリストです。`KsLayout.List` と書いたときの値になります。 */
        public companion object : List()

        override fun equals(other: Any?): Boolean =
            this === other || (
                other is List &&
                    rowSpacing == other.rowSpacing &&
                    groupSpacing == other.groupSpacing &&
                    headerItemSpacing == other.headerItemSpacing
                )

        override fun hashCode(): Int {
            var result = rowSpacing.hashCode()
            result = 31 * result + groupSpacing.hashCode()
            result = 31 * result + headerItemSpacing.hashCode()
            return result
        }

        override fun toString(): String =
            "KsLayout.List(rowSpacing=$rowSpacing, groupSpacing=$groupSpacing, " +
                "headerItemSpacing=$headerItemSpacing)"
    }

    /**
     * 多列のグリッドです。
     *
     * 間隔はいずれも 0 以上で指定します。負の値は誤りで、デバッグビルドでは停止して知らせ、
     * リリースビルドでは警告を記録して 0 として表示します。
     *
     * @param columns 列数の決め方
     * @param rowSpacing 行と行の間隔。グループの見出しの前後とヘッダー / フッターの前後には入らない
     * @param columnSpacing 列と列の間隔
     * @param groupSpacing グループとグループの間の間隔。前のグループの最終行と次のグループの見出しの
     *   間に入り、コンテンツ全体の先頭と末尾には入らない。グループを宣言しない場合は使われない
     * @param headerItemSpacing グループの見出しと、そのグループの先頭行の間の間隔。見出しを宣言しない
     *   場合は使われない
     */
    public data class Grid(
        val columns: KsColumns,
        val rowSpacing: Dp = 0.dp,
        val columnSpacing: Dp = 0.dp,
        val groupSpacing: Dp = 0.dp,
        val headerItemSpacing: Dp = 0.dp,
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

/** グループ間の間隔として実際に使う値。負の指定は 0 として扱う。 */
internal val KsLayout.effectiveGroupSpacing: Dp
    get() = when (this) {
        is KsLayout.List -> groupSpacing
        is KsLayout.Grid -> groupSpacing
    }.coerceAtLeast(0.dp)

/** 見出しと先頭行の間の間隔として実際に使う値。負の指定は 0 として扱う。 */
internal val KsLayout.effectiveHeaderItemSpacing: Dp
    get() = when (this) {
        is KsLayout.List -> headerItemSpacing
        is KsLayout.Grid -> headerItemSpacing
    }.coerceAtLeast(0.dp)

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
    val (groupSpacing, headerItemSpacing) = when (this@invalidValueMessages) {
        is KsLayout.List -> groupSpacing to headerItemSpacing
        is KsLayout.Grid -> groupSpacing to headerItemSpacing
    }
    if (groupSpacing < 0.dp) {
        add("groupSpacing は 0 以上で指定してください: $groupSpacing。0 として表示を継続します")
    }
    if (headerItemSpacing < 0.dp) {
        add("headerItemSpacing は 0 以上で指定してください: $headerItemSpacing。0 として表示を継続します")
    }

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
