/// 「リスト」画面で選べる区切り線の状態。
enum ListSeparatorChoice: String, CaseIterable, Identifiable {
    case hidden = "なし"
    case standard = "既定"
    case accent = "アクセント"

    var id: Self { self }
}
