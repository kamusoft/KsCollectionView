import XCTest
@testable import KsCollectionView

/// 配列をグループと内部の塊へ区切る表の作り方を固定する。
final class KsGroupChunkTableTests: XCTestCase {
    func test続いた同じ値が1つのグループになる() {
        let table = KsGroupChunkTable.make(
            groupValues: ["果物", "果物", "野菜", "野菜", "野菜"].map(AnyHashable.init),
            itemCount: 5,
            chunkSize: 500
        )

        XCTAssertEqual(table.groups.map(\.value), ["果物", "野菜"].map { AnyHashable($0) })
        XCTAssertEqual(table.groups.map(\.itemRange), [0..<2, 2..<5])
        XCTAssertEqual(table.sectionIDs, [
            KsSectionID(group: "果物", occurrence: 0, chunkInGroup: 0),
            KsSectionID(group: "野菜", occurrence: 0, chunkInGroup: 0),
        ])
        XCTAssertEqual(table.sectionItemRanges, [0..<2, 2..<5])
        XCTAssertEqual(table.chunks.map(\.itemCount), [2, 3])
        XCTAssertEqual(table.chunks.map(\.isFirstGroup), [true, false])
        XCTAssertEqual(table.chunks.map(\.isLastGroup), [false, true])
        XCTAssertTrue(table.reappearingValues.isEmpty)
    }

    func testグループを宣言しなければ配列全体が値なしの1つのグループになる() {
        let table = KsGroupChunkTable.make(groupValues: nil, itemCount: 1_200, chunkSize: 500)

        XCTAssertEqual(table.groups.count, 1)
        XCTAssertNil(table.groups[0].value)
        XCTAssertEqual(table.groups[0].sectionRange, 0..<3)
        XCTAssertEqual(table.sectionIDs.map(\.chunkInGroup), [0, 1, 2])
        XCTAssertEqual(table.sectionItemRanges, [0..<500, 500..<1_000, 1_000..<1_200])
    }

    func test項目が空でも塊を1つ作る() {
        for values in [nil, [AnyHashable]()] {
            let table = KsGroupChunkTable.make(groupValues: values, itemCount: 0, chunkSize: 500)
            XCTAssertEqual(table.sectionIDs, [KsSectionID(group: nil, occurrence: 0, chunkInGroup: 0)])
            XCTAssertEqual(table.chunks.map(\.itemCount), [0])
            XCTAssertEqual(table.groups.map(\.itemRange), [0..<0])
        }
    }

    // 塊はグループごとにその先頭から区切る。1 つの塊が 2 つのグループにまたがらず、端数は各グループの
    // 最後の塊にだけ出る。
    func test塊はグループの先頭から区切りグループをまたがない() {
        let values = Array(repeating: AnyHashable("A"), count: 1_003)
            + Array(repeating: AnyHashable("B"), count: 7)
            + Array(repeating: AnyHashable("C"), count: 500)
        let table = KsGroupChunkTable.make(groupValues: values, itemCount: values.count, chunkSize: 500)

        XCTAssertEqual(table.chunks.map(\.itemCount), [500, 500, 3, 7, 500])
        XCTAssertEqual(table.sectionItemRanges, [0..<500, 500..<1_000, 1_000..<1_003, 1_003..<1_010, 1_010..<1_510])
        XCTAssertEqual(table.chunks.map(\.chunkInGroup), [0, 1, 2, 0, 0])
        XCTAssertEqual(table.chunks.map(\.chunkCountInGroup), [3, 3, 3, 1, 1])
        XCTAssertEqual(table.chunks.map(\.groupIndex), [0, 0, 0, 1, 2])
        XCTAssertEqual(table.chunks.map(\.isFirstChunkInGroup), [true, false, false, true, true])
        XCTAssertEqual(table.chunks.map(\.isLastChunkInGroup), [false, false, true, true, true])
        XCTAssertEqual(table.groups.map(\.sectionRange), [0..<3, 3..<4, 4..<5])
        // セクションの番号から、そのセクションが属するグループの範囲を引ける。
        XCTAssertEqual(table.group(containingSection: 1)?.sectionRange, 0..<3)
        XCTAssertEqual(table.group(containingSection: 1)?.itemRange, 0..<1_003)
        XCTAssertNil(table.group(containingSection: 5))
        XCTAssertNil(table.chunk(at: -1))
    }

    // 離れて現れた同じ値は、配列の順のまま別々のグループにし、何回目かで区別する。
    func test離れて現れた同じ値は別々のグループにして何回目かで区別する() {
        let table = KsGroupChunkTable.make(
            groupValues: ["果物", "野菜", "果物", "果物", "野菜", "果物"].map(AnyHashable.init),
            itemCount: 6,
            chunkSize: 500
        )

        XCTAssertEqual(table.groups.map(\.value), ["果物", "野菜", "果物", "野菜", "果物"].map { AnyHashable($0) })
        XCTAssertEqual(table.groups.map(\.occurrence), [0, 0, 1, 1, 2])
        XCTAssertEqual(table.groups.map(\.itemRange), [0..<1, 1..<2, 2..<4, 4..<5, 5..<6])
        XCTAssertEqual(Set(table.sectionIDs).count, table.sectionIDs.count, "塊の識別子が重複しています")
        // 再び現れた値は、最初に再び現れた順に 1 度ずつ並ぶ。
        XCTAssertEqual(table.reappearingValues, ["果物", "野菜"].map { AnyHashable($0) })
    }

    // グループの値が変わらなければ、グループの前に項目が増えても後ろのグループの塊の識別子は変わらない。
    func test前のグループへの挿入で後ろのグループの識別子が変わらない() {
        let before = KsGroupChunkTable.make(
            groupValues: Array(repeating: AnyHashable("A"), count: 600) + Array(repeating: AnyHashable("B"), count: 600),
            itemCount: 1_200,
            chunkSize: 500
        )
        let after = KsGroupChunkTable.make(
            groupValues: Array(repeating: AnyHashable("A"), count: 601) + Array(repeating: AnyHashable("B"), count: 600),
            itemCount: 1_201,
            chunkSize: 500
        )

        let beforeB = Array(before.sectionIDs[before.groups[1].sectionRange])
        let afterB = Array(after.sectionIDs[after.groups[1].sectionRange])
        XCTAssertEqual(beforeB, afterB)
        XCTAssertEqual(
            before.chunks[before.groups[1].sectionRange].map(\.itemCount),
            after.chunks[after.groups[1].sectionRange].map(\.itemCount)
        )
    }
}
