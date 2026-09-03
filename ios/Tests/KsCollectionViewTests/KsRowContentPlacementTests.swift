import CoreGraphics
import SwiftUI
import XCTest
@testable import KsCollectionView

/// `resolvedSize` と `contentOrigin` は `KsRowContentPlacement` の寸法と配置を決める唯一の入口であり、
/// `sizeThatFits` / `placeSubviews` はこの 2 つに委ねるだけにしてある。ここを直接検証するのは
/// `Layout` のプロトコル要件を呼ぶのに要る `LayoutSubviews` をテストから用意できないため。
/// 判断を両メソッドの中へ書き戻すと、この検査が素通りになる。
final class KsRowContentPlacementTests: XCTestCase {
    func test提案された高さよりcontentが高くても提案高さをそのまま返す() {
        let size = KsRowContentPlacement.resolvedSize(
            proposal: ProposedViewSize(width: 402, height: 44),
            natural: CGSize(width: 402, height: 142)
        )

        // 行の高さを超えて自己申告すると、ホスト View が content の高さで組み直して中央に置く。
        XCTAssertEqual(size.height, 44)
    }

    func test高さの提案がないときはcontentの自然高を返す() {
        let size = KsRowContentPlacement.resolvedSize(
            proposal: ProposedViewSize(width: 402, height: nil),
            natural: CGSize(width: 402, height: 142)
        )

        XCTAssertEqual(size.height, 142)
    }

    func test無限大の提案は提案なしとして扱う() {
        let size = KsRowContentPlacement.resolvedSize(
            proposal: ProposedViewSize(width: .infinity, height: .infinity),
            natural: CGSize(width: 402, height: 142)
        )

        XCTAssertEqual(size, CGSize(width: 402, height: 142))
    }

    func test行がcontentより低い間もcontentの原点は行の上端に固定される() {
        let bounds = CGRect(x: 0, y: 0, width: 402, height: 44)

        let origin = KsRowContentPlacement.contentOrigin(in: bounds, naturalWidth: 402)

        // 上方向へはみ出さない (中央揃えなら y は負になる)。
        XCTAssertEqual(origin.y, bounds.minY)
    }

    func test自然幅が提案幅より狭いcontentは水平中央に置かれる() {
        let bounds = CGRect(x: 0, y: 0, width: 402, height: 44)

        let origin = KsRowContentPlacement.contentOrigin(in: bounds, naturalWidth: 100)

        // 縦のはみ出し対策で水平の見え方を変えない (素のホスト View と同じ中央)。
        XCTAssertEqual(origin.x, 151)
    }

    func test幅いっぱいに広がるcontentは行の先頭に置かれる() {
        let bounds = CGRect(x: 0, y: 0, width: 402, height: 44)

        let filling = KsRowContentPlacement.contentOrigin(in: bounds, naturalWidth: 402)
        let greedy = KsRowContentPlacement.contentOrigin(in: bounds, naturalWidth: .infinity)

        XCTAssertEqual(filling.x, bounds.minX)
        XCTAssertEqual(greedy.x, bounds.minX)
    }

    func test原点は行の位置を基準にする() {
        let bounds = CGRect(x: 205, y: 149, width: 197, height: 44)

        let origin = KsRowContentPlacement.contentOrigin(in: bounds, naturalWidth: 97)

        XCTAssertEqual(origin.x, 255)
        XCTAssertEqual(origin.y, 149)
    }
}
