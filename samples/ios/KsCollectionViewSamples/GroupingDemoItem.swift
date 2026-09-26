/// 「グループ化」画面の項目。行の中身と、属するグループの番号を持つ。
struct GroupingDemoItem: Equatable, Identifiable {
    /// 行に出す中身 (「大量件数」と同じ作り方)。
    let row: DemoItem

    /// 属するグループの番号。見出しには「グループ n」と出る。
    var group: Int

    var id: Int { row.id }
}
