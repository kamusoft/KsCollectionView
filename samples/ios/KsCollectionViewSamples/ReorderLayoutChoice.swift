/// 「並べ替え」画面の表示の形。
enum ReorderLayoutChoice: String, CaseIterable, Identifiable {
    case list = "リスト"
    case grid = "グリッド"

    var id: Self { self }
}
