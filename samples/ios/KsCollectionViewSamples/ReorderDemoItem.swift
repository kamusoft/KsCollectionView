/// 「並べ替え」画面の項目。番号と、属するグループの番号を持つ。
struct ReorderDemoItem: Equatable, Identifiable {
    let id: Int

    /// 属するグループの番号 (1 から)。見出しには「グループ n」と出る。並べ替えで別のグループへ動かすと書き換わる。
    var group: Int

    /// 行に出すタイトル (「Item n」)。
    var title: String { "Item \(id)" }

    /// 並べ替えで動かせるか。10 の倍数の項目は動かせない。
    var isMovable: Bool { !id.isMultiple(of: 10) }
}
