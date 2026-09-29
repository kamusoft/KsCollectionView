/// 「ページング」画面の表示の形。
enum PagingLayoutChoice: String, CaseIterable, Identifiable {
    case list = "リスト"
    case grid = "グリッド"

    var id: Self { self }
}
