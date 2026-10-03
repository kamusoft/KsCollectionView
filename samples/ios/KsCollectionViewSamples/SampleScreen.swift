enum SampleScreen: String, CaseIterable, Hashable, Identifiable {
    case list = "リスト"
    case fixedGrid = "グリッド (固定列)"
    case adaptiveGrid = "グリッド (adaptive)"
    case orientationGrid = "向きで列数変更"
    case templates = "テンプレート切り替え"
    case headerFooter = "ルートヘッダー/フッター"
    case scrolling = "スクロール制御"
    case spacing = "スペーシングと余白"
    case largeData = "大量件数"
    case imageGrid = "画像グリッド"
    case grouping = "グループ化"
    case diffUpdate = "差分更新"
    case paging = "ページング"
    case reorder = "並べ替え"

    var id: Self { self }

    /// 直接開く画面を与える起動引数の名前。値は画面の名前 (ルートメニューの文言)。
    static let argumentName = "--screen"

    /// 起動引数で直接開くよう指定された画面を返します。
    ///
    /// 読むのは最初の ``argumentName`` のすぐ後ろの値だけです。指定が無い・値が無い・どの画面の名前とも
    /// 一致しないときは `nil` (ルートメニューを開く) です。
    ///
    /// - Parameter arguments: 起動引数の並び
    /// - Returns: 指定された画面。無ければ `nil`
    static func requested(arguments: [String]) -> SampleScreen? {
        let name = arguments
            .drop { $0 != argumentName }
            .dropFirst()
            .first
        return name.flatMap(SampleScreen.init(rawValue:))
    }
}
