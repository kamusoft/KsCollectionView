import KsCollectionView

/// 「画像グリッド」画面で選べるプリフェッチの到達点。
enum ImagePrefetchChoice: String, CaseIterable, Identifiable {
    case none = "なし"
    case disk = "ディスクまで"
    case memory = "メモリまで"

    var id: Self { self }

    /// 対応する到達点。`nil` はプリフェッチを宣言しないことを表す。
    var destination: KsPrefetchDestination? {
        switch self {
        case .none: nil
        case .disk: .disk
        case .memory: .memory
        }
    }
}
