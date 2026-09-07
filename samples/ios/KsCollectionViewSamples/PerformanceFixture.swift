import KsCollectionView

/// メモリ計測が走査する土俵です。
enum PerformanceFixture {
    /// 固定高と可変行高が混在する 2 列グリッド。
    case largeData

    /// リモート画像の 3 列グリッド。プリフェッチの到達点を選べます (nil は宣言しない)。
    case imageGrid(destination: KsPrefetchDestination?)

    /// この土俵の件数です。走査が全件を通過したかの判定に使います。
    var itemCount: Int {
        switch self {
        case .largeData: DemoData.largeItems.count
        case .imageGrid: ImageGridFixture.items.count
        }
    }
}
