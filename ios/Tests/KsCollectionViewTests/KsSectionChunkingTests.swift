import XCTest
@testable import KsCollectionView

/// 配列を内部の塊へ区切るときの件数の決め方を固定する。
final class KsSectionChunkingTests: XCTestCase {
    func testリストは基準件数をそのまま使う() {
        let multiple = KsSectionChunking.columnMultiple(layout: .list, resolvedColumnCount: nil)
        XCTAssertEqual(multiple, 1)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: multiple), 500)
    }

    func test固定列数では宣言された列数の倍数へ切り上げる() {
        let multiple = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .fixed(3)),
            resolvedColumnCount: 3
        )
        XCTAssertEqual(multiple, 3)
        // 500 は 3 で割り切れないため、直上の倍数 501 へ切り上げる。
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: multiple), 501)
    }

    func test向き別列数では両方の列数の最小公倍数の倍数にする() {
        let divisible = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .fixed(portrait: 2, landscape: 4)),
            resolvedColumnCount: 2
        )
        XCTAssertEqual(divisible, 4)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: divisible), 500)

        let coprime = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .fixed(portrait: 2, landscape: 3)),
            resolvedColumnCount: 2
        )
        XCTAssertEqual(coprime, 6)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: coprime), 504)
    }

    func test最小公倍数が上限を超える向き別列数は現在の列数へ縮退する() {
        // 互いに素な大きい列数では最小公倍数が上限 (2,000) を超えるため、塊の件数を
        // 現在解決している列数の倍数に切り替える。
        let multiple = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .fixed(portrait: 61, landscape: 67)),
            resolvedColumnCount: 61
        )
        XCTAssertEqual(multiple, 61)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: multiple), 549)
    }

    func test最小公倍数の計算があふれる列数は現在の列数へ縮退する() {
        XCTAssertNil(KsSectionChunking.leastCommonMultiple(Int.max, Int.max - 1))
        let multiple = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .fixed(portrait: Int.max, landscape: Int.max - 1)),
            resolvedColumnCount: 2
        )
        XCTAssertEqual(multiple, 2)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: multiple), 500)
    }

    func testadaptiveは直近に解決した列数を使い未解決なら1で組む() {
        let resolved = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .adaptive(minItemWidth: 120)),
            resolvedColumnCount: 3
        )
        XCTAssertEqual(resolved, 3)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: resolved), 501)

        let unresolved = KsSectionChunking.columnMultiple(
            layout: .grid(columns: .adaptive(minItemWidth: 120)),
            resolvedColumnCount: nil
        )
        XCTAssertEqual(unresolved, 1)
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: unresolved), 500)
    }

    func test列数が基準件数を超える場合は塊の件数を列数に合わせる() {
        XCTAssertEqual(KsSectionChunking.chunkSize(columnMultiple: 700), 700)
    }

    func test塊の数は件数を塊の件数で割った切り上げで空配列でも1つ作る() {
        XCTAssertEqual(KsSectionChunking.chunkCount(itemCount: 0, chunkSize: 500), 1)
        XCTAssertEqual(KsSectionChunking.chunkCount(itemCount: 1, chunkSize: 500), 1)
        XCTAssertEqual(KsSectionChunking.chunkCount(itemCount: 500, chunkSize: 500), 1)
        XCTAssertEqual(KsSectionChunking.chunkCount(itemCount: 501, chunkSize: 500), 2)
        XCTAssertEqual(KsSectionChunking.chunkCount(itemCount: 2_000, chunkSize: 500), 4)
        XCTAssertEqual(KsSectionChunking.chunkCount(itemCount: 10_000, chunkSize: 504), 20)
    }
}
