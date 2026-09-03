/// 高さ変化検証で切り替えるレイアウトです。
enum HeightChangeLayoutChoice: String, CaseIterable, Identifiable {
    case list = "list"
    case grid = "grid"

    var id: Self { self }
}
