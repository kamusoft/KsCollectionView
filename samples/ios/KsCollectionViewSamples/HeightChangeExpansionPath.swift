/// 行の高さが変わるときに、展開状態をどこが持つかの経路です。
enum HeightChangeExpansionPath: String, CaseIterable, Identifiable {
    /// 親 View の状態でテンプレート内容を変え、可視セルを再構成する経路です。
    case parentState = "親 state"
    /// テンプレート内の View が自分の状態で展開し、親はタップを知らない経路です。
    case templateState = "テンプレート内 state"

    var id: Self { self }
}
