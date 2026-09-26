import CoreGraphics

// グループの見出しを固定するときに、レイアウトが見出しの属性を書き換えるための材料。
// 固定する構成 (見出しの宣言があり、固定を外していない) のときだけ作る。
internal struct KsGroupHeaderPinning {
    // 適用済みの snapshot の塊の表。見出しの属するグループの塊の範囲を引く。
    let chunkTable: KsGroupChunkTable
    // 見出しとグループの先頭行の間の間隔。グループの先頭の塊の上端の内側余白に入る。
    let headerItemSpacing: CGFloat
    // 行間。グループの 2 つめ以降の塊の上端の内側余白に入る。
    let rowSpacing: CGFloat
}
