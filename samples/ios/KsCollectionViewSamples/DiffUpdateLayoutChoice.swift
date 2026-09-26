/// 「差分更新」画面の表示の形。
enum DiffUpdateLayoutChoice: String, CaseIterable, Identifiable {
    case list = "リスト"
    case grid = "グリッド"

    var id: Self { self }
}
