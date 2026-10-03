/// ルートメニューの 1 行。メニューに上から並ぶ順は ``all`` が決める。
enum RootMenuRow: Hashable {
    /// 項目群の見出し。選べない。
    case heading(String)
    /// 外観の 1 項目。
    case appearance(SampleAppearance)
    /// 項目群の間の隙間。
    case gap
    /// デモ画面を開く項目。
    case screen(SampleScreen)
    /// 技術検証画面を開く項目。
    case verification(VerificationScreen)

    /// メニューの行を上から並ぶ順に並べたもの。
    ///
    /// 見出し「外観」と外観の 3 項目、隙間、デモ画面、技術検証画面の順。
    static let all: [RootMenuRow] = [.heading(SampleAppearance.sectionTitle)]
        + SampleAppearance.allCases.map(RootMenuRow.appearance)
        + [.gap]
        + SampleScreen.allCases.map(RootMenuRow.screen)
        + VerificationScreen.allCases.map(RootMenuRow.verification)
}
