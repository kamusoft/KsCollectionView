import SwiftUI

// 利用者が宣言したグループ化 (グループの値・見出し・見出しの固定の有無) を型消去して保持する。
internal struct KsGrouping<Item> {
    // 項目のグループの値。
    let value: (Item) -> AnyHashable
    // グループの値の取り出し方 (利用者が指したキーパス)。前回の宣言と同じなら、同じ配列からは
    // 同じグループの値の列が得られるため、列を求め直さずに済ませる判定に使う。
    let valueSource: AnyHashable
    // 見出しの内容。グループの先頭の項目 (グループの値を型を保ったまま取り出すため) と、
    // グループ内の項目を受け取る。見出しを宣言しないときは nil。
    let header: ((Item, [Item]) -> AnyView)?
    // 見出しをスクロール時に表示範囲の上端へ固定するか。
    let pinsHeaders: Bool
}
