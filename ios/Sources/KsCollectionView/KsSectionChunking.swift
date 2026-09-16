/// 配列を内部の塊 (`KsSectionID`) へ区切るときの件数の決め方。
///
/// 塊の件数は「基準 500 件を、列数の候補の最小公倍数の倍数へ切り上げた値」とする。
/// 列数の倍数にするのは、塊の境界に列数へ満たない行を作らないため。候補の最小公倍数にするのは、
/// 向き別列数で表示領域が回転するたびに配列全体を組み直さずに済ませるため。
internal enum KsSectionChunking {
    /// 塊の件数の基準。1 回のレイアウトの再解決に要する費用の上限を配列全体の件数から切り離す値。
    static let baseChunkSize = 500

    /// 列数の最小公倍数として許す上限。これを超える組み合わせでは最小公倍数を諦め、
    /// 現在解決している列数の倍数へ縮退する (互いに素な大きい列数で塊が巨大になるのを防ぐ)。
    ///
    /// 値は、1 つの塊に載せても滑らかさを保てた実測上の件数 (基準 500 件の 4 倍) を採る。
    /// 塊の件数は最小公倍数の倍数へ切り上がるため、最小公倍数がこの値を超えると塊の件数も
    /// 滑らかさを保てる範囲から出る。
    static let maximumColumnMultiple = 2_000

    /// 塊の件数が満たすべき列数の倍数。
    ///
    /// - list: 1
    /// - 固定列数: その列数
    /// - 向き別列数: 両者の最小公倍数。計算があふれる、または上限を超える場合は
    ///   `resolvedColumnCount` へ縮退する
    /// - adaptive: `resolvedColumnCount` (直近のレイアウトパスで解決した列数。未解決なら 1)
    static func columnMultiple(
        layout: KsCollectionLayout,
        resolvedColumnCount: Int?
    ) -> Int {
        let resolved = max(1, resolvedColumnCount ?? 1)
        switch layout.kind {
        case .list:
            return 1
        case let .grid(columns):
            switch columns.storage {
            case let .count(count):
                return max(1, count)
            case let .orientation(portrait, landscape):
                guard
                    let multiple = leastCommonMultiple(max(1, portrait), max(1, landscape)),
                    multiple <= maximumColumnMultiple
                else {
                    return resolved
                }
                return multiple
            case .adaptive:
                return resolved
            }
        }
    }

    /// 基準件数を列数の倍数へ切り上げた、1 つの塊に載せる件数。
    static func chunkSize(columnMultiple: Int) -> Int {
        let multiple = max(1, columnMultiple)
        let chunks = (baseChunkSize + multiple - 1) / multiple
        return max(1, chunks) * multiple
    }

    /// 配列を載せるのに要する塊の数。項目が空でも 1 つ作る (ヘッダー / フッターを載せるため)。
    static func chunkCount(itemCount: Int, chunkSize: Int) -> Int {
        let size = max(1, chunkSize)
        guard itemCount > 0 else { return 1 }
        return (itemCount + size - 1) / size
    }

    /// 最小公倍数。計算があふれる場合は nil を返す。
    static func leastCommonMultiple(_ lhs: Int, _ rhs: Int) -> Int? {
        guard lhs > 0, rhs > 0 else { return nil }
        let divisor = greatestCommonDivisor(lhs, rhs)
        let (product, overflowed) = (lhs / divisor).multipliedReportingOverflow(by: rhs)
        return overflowed ? nil : product
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}
