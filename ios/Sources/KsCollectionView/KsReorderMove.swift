/// 並べ替えで項目を置いたときの知らせです。
///
/// 動かした項目と行き先の項目は、一覧に渡した配列の要素そのものです。一覧は配列を書き換えないため、
/// 受け入れる場合は呼び出し側で配列を並べ替えて渡し直してください。
public struct KsReorderMove<Item> {
    /// 動かした項目です。
    public let item: Item
    /// 行き先です。
    public let destination: KsReorderDestination<Item>
    /// 行き先のグループの値です。
    ///
    /// ``KsCollectionView/groups(by:pinnedHeaders:header:)`` などでグループを宣言している一覧では、
    /// 行き先のグループのグループの値 (`by` で指したプロパティの値) が入ります。グループを宣言していない
    /// 一覧では nil です。別のグループへ動かした場合は、項目のグループの値を呼び出し側で書き換えてください。
    public let group: AnyHashable?

    /// 知らせを作ります。
    public init(item: Item, destination: KsReorderDestination<Item>, group: AnyHashable?) {
        self.item = item
        self.destination = destination
        self.group = group
    }
}

extension KsReorderMove: Equatable where Item: Equatable {}
