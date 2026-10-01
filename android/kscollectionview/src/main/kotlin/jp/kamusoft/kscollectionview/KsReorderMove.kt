package jp.kamusoft.kscollectionview

/**
 * 並べ替えで項目を置いたときの知らせです。
 *
 * 動かした項目と行き先の項目は、一覧に渡した配列の要素そのものです。一覧は配列を書き換えないため、
 * 受け入れる場合は呼び出し側で配列を並べ替えて渡し直してください。
 *
 * @param Item 項目の型
 * @property item 動かした項目
 * @property destination 行き先
 * @property group 行き先のグループの値。`KsCollectionView` の `groups` でグループを宣言している一覧では、
 *   行き先のグループのグループの値 ([KsGroups.by] が返した値) が入ります。グループを宣言していない一覧では
 *   null です。別のグループへ動かした場合は、項目のグループの値を呼び出し側で書き換えてください
 */
public class KsReorderMove<out Item>(
    public val item: Item,
    public val destination: KsReorderDestination<Item>,
    public val group: Any?,
) {
    override fun toString(): String = "KsReorderMove(item=$item, destination=$destination, group=$group)"
}
