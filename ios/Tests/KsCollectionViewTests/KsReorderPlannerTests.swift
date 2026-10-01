import XCTest
@testable import KsCollectionView

/// 並べ替えの行き先の求め方 (表示から切り離した部品) を確かめる。
final class KsReorderPlannerTests: XCTestCase {
    // 項目 ID の並びとグループ (値, 件数) の列から部品を作る。グループを渡さなければ 1 つの値なしのグループ。
    private func planner(_ ids: [String], groups: [(String, Int)]? = nil) -> KsReorderPlanner {
        let spans: [KsReorderGroupSpan]
        if let groups {
            var start = 0
            spans = groups.map { value, count in
                defer { start += count }
                return KsReorderGroupSpan(value: AnyHashable(value), itemRange: start..<(start + count))
            }
        } else {
            spans = [KsReorderGroupSpan(value: nil, itemRange: 0..<ids.count)]
        }
        return KsReorderPlanner(identifiers: ids.map { AnyHashable($0) }, groups: spans)
    }

    private func before(_ id: String, group: Int = 0) -> KsReorderPlacement {
        KsReorderPlacement(target: .before(AnyHashable(id)), groupIndex: group)
    }

    private func end(group: Int = 0) -> KsReorderPlacement {
        KsReorderPlacement(target: .end, groupIndex: group)
    }

    // A を C と D の間に置くと「D の前」。
    func testCとDの間に置くとDの前になる() {
        let planner = planner(["A", "B", "C", "D"])
        // 動かした A を除いた並び [B, C, D] の 2 番目 (C の後ろ) に置く。
        XCTAssertEqual(planner.placement(moving: 0, toGroup: 0, at: 2), before("D"))
        XCTAssertNil(planner.groups[0].value)
    }

    func test最後に置くと末尾になる() {
        let planner = planner(["A", "B", "C"])
        XCTAssertEqual(planner.placement(moving: 0, toGroup: 0, at: 2), end())
    }

    // 元の位置に置くと、元の位置の行き先と同じになる (知らせない判定に使う)。
    func test元の位置に置くと元の位置の行き先と一致する() {
        let planner = planner(["A", "B", "C", "D"])
        XCTAssertEqual(planner.originalPlacement(of: 1), before("C"))
        XCTAssertEqual(planner.placement(moving: 1, toGroup: 0, at: 1), planner.originalPlacement(of: 1))
        XCTAssertEqual(planner.originalPlacement(of: 3), end())
    }

    // グループ X (A, B) と Y (C, D) で、A を C と D の間に置くと「D の前」・グループ Y。
    func test別のグループの途中へ置くと後ろの項目の前とそのグループになる() {
        let planner = planner(["A", "B", "C", "D"], groups: [("X", 2), ("Y", 2)])
        let placement = planner.placement(moving: 0, toGroup: 1, at: 1)
        XCTAssertEqual(placement, before("D", group: 1))
        XCTAssertEqual(planner.groups[placement.groupIndex].value, AnyHashable("Y"))
    }

    // グループの境目は、前のグループの末尾と次のグループの先頭を置いた先のグループで区別する。
    func testグループの境目は置いた先のグループで末尾と先頭に分かれる() {
        let planner = planner(["A", "B", "C", "D"], groups: [("X", 2), ("Y", 2)])
        // D を X の最後 (B の後ろ) に置く。
        XCTAssertEqual(planner.placement(moving: 3, toGroup: 0, at: 2), end(group: 0))
        // D を Y の先頭 (C の前) に置く。
        XCTAssertEqual(planner.placement(moving: 3, toGroup: 1, at: 0), before("C", group: 1))
    }

    // A の「後ろへ移動」は C の前。
    func test後ろへ移動は1つ後ろの項目の後ろになる() {
        let planner = planner(["A", "B", "C"])
        XCTAssertEqual(planner.nextPlacement(of: 0), before("C"))
        XCTAssertEqual(planner.nextPlacement(of: 1), end())
        // 一覧の最後の項目には後ろへの行き先が無い。
        XCTAssertNil(planner.nextPlacement(of: 2))
    }

    func test前へ移動は1つ前の項目の前になり一覧の先頭には無い() {
        let planner = planner(["A", "B", "C"])
        XCTAssertEqual(planner.previousPlacement(of: 2), before("B"))
        XCTAssertEqual(planner.previousPlacement(of: 1), before("A"))
        XCTAssertNil(planner.previousPlacement(of: 0))
    }

    // グループ X (A, B) と Y (C, D) で、C の「前へ移動」は X の末尾、B の「後ろへ移動」は Y の先頭。
    func testグループの境目を越える移動の操作は隣のグループの末尾と先頭になる() {
        let planner = planner(["A", "B", "C", "D"], groups: [("X", 2), ("Y", 2)])
        XCTAssertEqual(planner.previousPlacement(of: 2), end(group: 0))
        XCTAssertEqual(planner.nextPlacement(of: 1), before("C", group: 1))
    }

    func test置いた後の並びは行き先の前か末尾に入る() {
        let planner = planner(["A", "B", "C", "D"], groups: [("X", 2), ("Y", 2)])
        XCTAssertEqual(planner.reorderedIdentifiers(moving: 0, to: before("D", group: 1)), ["B", "C", "A", "D"])
        XCTAssertEqual(planner.reorderedIdentifiers(moving: 3, to: end(group: 0)), ["A", "B", "D", "C"])
        XCTAssertEqual(planner.reorderedIdentifiers(moving: 0, to: end(group: 1)), ["B", "C", "D", "A"])
    }

    func testグループの並び順を配列の位置から引ける() {
        let planner = planner(["A", "B", "C", "D", "E"], groups: [("X", 2), ("Y", 1), ("Z", 2)])
        XCTAssertEqual((0..<5).map { planner.groupIndex(containing: $0) }, [0, 0, 1, 2, 2])
        XCTAssertNil(planner.groupIndex(containing: 5))
    }
}
