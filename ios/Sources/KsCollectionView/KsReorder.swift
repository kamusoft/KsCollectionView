// 利用者が一覧に付けた並べ替えの設定 (スイッチ・判定・読み上げの文言・置いたときの処理)。
// 付けていない一覧では構成に載らず (nil)、付けて無効にした一覧と同じ振る舞いになる (core/ADR-0031)。
internal struct KsReorder<Item> {
    // 並べ替えのスイッチ。有効の間は長押しでドラッグが始まり、長押しの知らせは呼ばない。
    var isEnabled: Bool
    // 項目ごとの「動かせるか」。無いときはすべての項目を動かせる (core/ADR-0030)。
    var canMove: ((Item) -> Bool)?
    // 行き先の候補ごとの「ここに置けるか」。無いときはすべての位置に置ける (core/ADR-0030)。
    var canDrop: ((KsReorderMove<Item>) -> Bool)?
    // 読み上げの移動操作の文言。無いときは操作を出さない (core/ADR-0032)。
    var accessibilityActions: KsReorderAccessibilityActions?
    // 置いたときに 1 回だけ呼び、受け入れたかを返してもらう (core/ADR-0026、core/ADR-0027)。
    var onMove: @MainActor (KsReorderMove<Item>) -> Bool
}
