import XCTest
@testable import KsCollectionView

final class KsSnapshotPlannerTests: XCTestCase {
    private struct Item: Equatable {
        let id: Int
        let kind: String
        let value: String
    }

    func testIdentifiable相当の100件を全てsnapshotへ含める() {
        let items = (0..<100).map { Item(id: $0, kind: "row", value: "\($0)") }

        let plan = KsSnapshotPlanner.makePlan(
            newItems: items,
            oldItems: [:],
            oldKeys: [:],
            id: { AnyHashable($0.id) },
            key: { AnyHashable($0.kind) }
        )

        XCTAssertEqual(plan.identifiers.count, 100)
        XCTAssertEqual(plan.identifiers.first, AnyHashable(0))
        XCTAssertEqual(plan.identifiers.last, AnyHashable(99))
    }

    func test非準拠型のキーパス相当IDで順序を構築する() {
        let items = [
            Item(id: 30, kind: "row", value: "C"),
            Item(id: 10, kind: "row", value: "A"),
        ]

        let plan = KsSnapshotPlanner.makePlan(
            newItems: items,
            oldItems: [:],
            oldKeys: [:],
            id: { AnyHashable($0.id) },
            key: { AnyHashable($0.kind) }
        )

        XCTAssertEqual(plan.identifiers, [AnyHashable(30), AnyHashable(10)])
    }

    func test同一IDかつ同一キーの内容変更は再構成する() {
        let old = Item(id: 1, kind: "message", value: "before")
        let new = Item(id: 1, kind: "message", value: "after")

        let plan = KsSnapshotPlanner.makePlan(
            newItems: [new],
            oldItems: [AnyHashable(1): old],
            oldKeys: [AnyHashable(1): AnyHashable("message")],
            id: { AnyHashable($0.id) },
            key: { AnyHashable($0.kind) }
        )

        XCTAssertEqual(plan.reconfigure, [AnyHashable(1)])
        XCTAssertTrue(plan.reload.isEmpty)
    }

    func test同一IDでキー変更時はセルを置換する() {
        let old = Item(id: 1, kind: "message", value: "content")
        let new = Item(id: 1, kind: "ad", value: "content")

        let plan = KsSnapshotPlanner.makePlan(
            newItems: [new],
            oldItems: [AnyHashable(1): old],
            oldKeys: [AnyHashable(1): AnyHashable("message")],
            id: { AnyHashable($0.id) },
            key: { AnyHashable($0.kind) }
        )

        XCTAssertTrue(plan.reconfigure.isEmpty)
        XCTAssertEqual(plan.reload, [AnyHashable(1)])
    }

    func test挿入削除移動後の順序を新配列に合わせる() {
        let items = [
            Item(id: 3, kind: "row", value: "C"),
            Item(id: 1, kind: "row", value: "A"),
            Item(id: 4, kind: "row", value: "D"),
        ]

        let plan = KsSnapshotPlanner.makePlan(
            newItems: items,
            oldItems: [:],
            oldKeys: [:],
            id: { AnyHashable($0.id) },
            key: { AnyHashable($0.kind) }
        )

        XCTAssertEqual(plan.identifiers, [AnyHashable(3), AnyHashable(1), AnyHashable(4)])
    }
}
