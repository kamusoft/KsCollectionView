// 利用者のグループ 1 つが、内部の塊と配列のどこに載っているか。
// 見出しの内容 (グループの値と項目) の組み立てと、塊に割れたグループの範囲を引くために使う。
internal struct KsGroupInfo: Equatable {
    // グループの値。グループを宣言しないときは nil。
    let value: AnyHashable?
    // 同じグループの値が離れて現れる不正入力のときの何回目か。正しい入力では常に 0。
    let occurrence: Int
    // グループの塊が載るセクションの番号の範囲。
    let sectionRange: Range<Int>
    // グループの項目の、配列全体での位置の範囲。
    let itemRange: Range<Int>
}
