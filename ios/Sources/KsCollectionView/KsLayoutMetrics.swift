import CoreGraphics

internal enum KsLayoutMetrics {
    static func columnCount(
        for columns: KsGridColumns,
        containerSize: CGSize,
        horizontalPadding: Double,
        columnSpacing: Double
    ) -> Int {
        switch columns.storage {
        case let .count(count):
            return max(1, count)
        case let .orientation(portrait, landscape):
            return containerSize.height > containerSize.width ? max(1, portrait) : max(1, landscape)
        case let .adaptive(minItemWidth):
            let availableWidth = max(0, containerSize.width - horizontalPadding)
            let count = Int((availableWidth + columnSpacing) / (minItemWidth + columnSpacing))
            return max(1, count)
        }
    }

    // 1 列分の幅 (ポイント)。表示領域の幅から左右の内側余白と列の間隔を引き、列数で割る。
    // list は 1 列として扱う。余白と間隔が表示領域の幅を超えるときは 0 以下を返す。
    static func columnWidth(
        for layout: KsCollectionLayout,
        containerSize: CGSize,
        horizontalPadding: Double
    ) -> Double {
        let count: Int
        switch layout.kind {
        case .list:
            count = 1
        case let .grid(columns):
            count = columnCount(
                for: columns,
                containerSize: containerSize,
                horizontalPadding: horizontalPadding,
                columnSpacing: layout.columnSpacing
            )
        }
        let spacing = count > 1 ? layout.columnSpacing * Double(count - 1) : 0
        return (Double(containerSize.width) - horizontalPadding - spacing) / Double(count)
    }
}
