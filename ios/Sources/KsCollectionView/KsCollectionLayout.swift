/// コレクションの表示形態です。
public struct KsCollectionLayout: Equatable, Sendable {
    internal enum Kind: Equatable, Sendable {
        case list
        case grid(KsGridColumns)
    }

    internal let kind: Kind

    /// 行と行の間隔です。
    public let rowSpacing: Double

    /// 列と列の間隔です。
    public let columnSpacing: Double

    /// 1 列のリストを作成します。
    public static let list = KsCollectionLayout(kind: .list)

    /// 行間を指定した 1 列のリストを作成します。
    public static func list(rowSpacing: Double) -> KsCollectionLayout {
        KsCollectionLayout(kind: .list, rowSpacing: rowSpacing)
    }

    /// グリッドを作成します。
    public static func grid(
        columns: KsGridColumns,
        rowSpacing: Double = 0,
        columnSpacing: Double = 0
    ) -> KsCollectionLayout {
        KsCollectionLayout(
            kind: .grid(columns),
            rowSpacing: rowSpacing,
            columnSpacing: columnSpacing
        )
    }

    private init(kind: Kind, rowSpacing: Double = 0, columnSpacing: Double = 0) {
        assert(rowSpacing >= 0, "rowSpacing は 0 以上で指定してください")
        assert(columnSpacing >= 0, "columnSpacing は 0 以上で指定してください")

        switch kind {
        case .list:
            break
        case let .grid(columns):
            switch columns.storage {
            case let .count(count):
                assert(count > 0, "列数は 1 以上で指定してください")
            case let .orientation(portrait, landscape):
                assert(portrait > 0 && landscape > 0, "列数は 1 以上で指定してください")
            case let .adaptive(minItemWidth):
                assert(minItemWidth > 0, "minItemWidth は 0 より大きい値を指定してください")
            }
        }

        self.kind = kind
        self.rowSpacing = rowSpacing
        self.columnSpacing = columnSpacing
    }
}
