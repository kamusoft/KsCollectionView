// 並べ替えの行き先を求めるときの、グループ 1 つの値と配列の中での範囲。
internal struct KsReorderGroupSpan: Equatable {
    // グループの値。グループを宣言していない一覧では nil (配列全体で 1 つのグループ)。
    let value: AnyHashable?
    // グループの項目の、配列全体での位置の範囲。
    let itemRange: Range<Int>
}
