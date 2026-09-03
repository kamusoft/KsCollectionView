/// プラットフォーム固有の技術検証画面です。デモ画面の集合には数えません。
enum VerificationScreen: String, CaseIterable, Hashable, Identifiable {
    case heightChange = "検証: 行の高さ変化 (iOS 固有)"

    var id: Self { self }
}
