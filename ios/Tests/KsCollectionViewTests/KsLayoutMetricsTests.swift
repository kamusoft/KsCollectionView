import CoreGraphics
import XCTest
@testable import KsCollectionView

final class KsLayoutMetricsTests: XCTestCase {
    func test固定3列を返す() {
        let count = KsLayoutMetrics.columnCount(
            for: .fixed(3),
            containerSize: CGSize(width: 390, height: 844),
            horizontalPadding: 0,
            columnSpacing: 0
        )

        XCTAssertEqual(count, 3)
    }

    func testAdaptiveは最小幅を下回らない最大列数を返す() {
        let count = KsLayoutMetrics.columnCount(
            for: .adaptive(minItemWidth: 120),
            containerSize: CGSize(width: 390, height: 844),
            horizontalPadding: 30,
            columnSpacing: 8
        )
        XCTAssertEqual(count, 2)
    }

    func test向き別列数はコンテナ縦横比で切り替える() {
        let columns = KsGridColumns.fixed(portrait: 2, landscape: 4)

        let portrait = KsLayoutMetrics.columnCount(
            for: columns,
            containerSize: CGSize(width: 390, height: 844),
            horizontalPadding: 0,
            columnSpacing: 0
        )
        let landscape = KsLayoutMetrics.columnCount(
            for: columns,
            containerSize: CGSize(width: 844, height: 390),
            horizontalPadding: 0,
            columnSpacing: 0
        )

        XCTAssertEqual(portrait, 2)
        XCTAssertEqual(landscape, 4)
    }
}
