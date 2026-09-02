/// グリッドの列数の決め方です。
public struct KsGridColumns: Equatable, Sendable {
    internal enum Storage: Equatable, Sendable {
        case count(Int)
        case orientation(portrait: Int, landscape: Int)
        case adaptive(Double)
    }

    internal let storage: Storage

    /// 常に同じ列数を使います。
    public static func fixed(_ count: Int) -> KsGridColumns {
        KsGridColumns(storage: .count(count))
    }

    /// コンテナが縦長のときと横長のときで列数を切り替えます。
    public static func fixed(portrait: Int, landscape: Int) -> KsGridColumns {
        KsGridColumns(storage: .orientation(portrait: portrait, landscape: landscape))
    }

    /// 各項目が最小幅以上になる範囲で列数を自動調整します。
    public static func adaptive(minItemWidth: Double) -> KsGridColumns {
        KsGridColumns(storage: .adaptive(minItemWidth))
    }
}
