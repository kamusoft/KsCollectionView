// 内部の塊 (compositional layout のセクション) 1 つの、グループの中での位置と中身の件数。
// sectionProvider・区切り線・見出しの構成が、セクションの番号からこの値を引いて使う。
internal struct KsChunkInfo: Equatable {
    // 塊が属するグループの、配列の先頭からの並び順。
    let groupIndex: Int
    // グループの先頭の塊を 0 とする、グループの中での塊の並び順。
    let chunkInGroup: Int
    // 塊が属するグループの塊の数。
    let chunkCountInGroup: Int
    // 塊に載る項目の数。
    let itemCount: Int
    // 塊が属するグループが配列の先頭のグループか。
    let isFirstGroup: Bool
    // 塊が属するグループが配列の末尾のグループか。
    let isLastGroup: Bool

    // グループの先頭の塊か。
    var isFirstChunkInGroup: Bool { chunkInGroup == 0 }

    // グループの末尾の塊か。
    var isLastChunkInGroup: Bool { chunkInGroup == chunkCountInGroup - 1 }
}
