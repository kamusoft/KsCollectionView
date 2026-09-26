/// 「差分更新」画面の項目。
struct DiffUpdateItem: Equatable, Identifiable {
    let id: Int

    /// 属するグループの番号 (0 から)。見出しには「グループ A」のように英大文字で出る。
    var group: Int

    /// 「更新」を受けた回数。1 回以上ならタイトルに印が付く。
    var revision = 0

    /// 行に出す中身。
    var row: DemoItem {
        DemoItem(id: id, title: revision > 0 ? "Item \(id) ★" : "Item \(id)")
    }
}
