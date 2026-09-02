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
}
