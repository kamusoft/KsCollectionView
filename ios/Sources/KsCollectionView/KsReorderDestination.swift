/// 並べ替えで項目を置いた行き先です。
///
/// 行き先は位置の番号ではなく、配列の要素で表します。置いた位置の後ろに同じグループの項目があれば
/// ``before(_:)`` でその項目を、置いた位置がグループの最後 (グループを宣言していなければ一覧の最後) なら
/// ``end`` を表します。
public enum KsReorderDestination<Item> {
    /// 渡した項目の前です。
    case before(Item)
    /// グループの末尾です。グループを宣言していない一覧では、一覧の末尾です。
    case end
}

extension KsReorderDestination: Equatable where Item: Equatable {}
