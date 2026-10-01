package jp.kamusoft.kscollectionview

/**
 * 並べ替えで項目を置いた行き先です。
 *
 * 行き先は位置の番号ではなく、配列の要素で表します。置いた位置の後ろに同じグループの項目があれば
 * [Before] でその項目を、置いた位置がグループの最後 (グループを宣言していなければ一覧の最後) なら
 * [End] を表します。
 *
 * @param Item 項目の型
 */
public sealed interface KsReorderDestination<out Item> {
    /**
     * 渡した項目の前です。
     *
     * @property item 行き先の項目。一覧に渡した配列の要素そのものです
     */
    public class Before<out Item>(public val item: Item) : KsReorderDestination<Item> {
        override fun toString(): String = "KsReorderDestination.Before(item=$item)"
    }

    /** グループの末尾です。グループを宣言していない一覧では、一覧の末尾です。 */
    public data object End : KsReorderDestination<Nothing>
}
