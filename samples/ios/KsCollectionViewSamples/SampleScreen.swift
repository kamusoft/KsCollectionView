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

    var id: Self { self }
}
