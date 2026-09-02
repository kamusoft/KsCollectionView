import Foundation

internal enum KsSnapshotPlanner {
    static func makePlan<Item: Equatable>(
        newItems: [Item],
        oldItems: [AnyHashable: Item],
        oldKeys: [AnyHashable: AnyHashable],
        id: (Item) -> AnyHashable,
        key: (Item) -> AnyHashable
    ) -> KsSnapshotPlan {
        assert(
            Set(newItems.map(id)).count == newItems.count,
            "安定 ID は配列内で一意にしてください"
        )
        // 重複 ID は不正入力。release では後勝ちで 1 件へ畳み、表示を継続する。
        let effectiveItems = deduplicatingByLastOccurrence(newItems, id: id)
        let identifiers = effectiveItems.map(id)

        var reconfigure: [AnyHashable] = []
        var reload: [AnyHashable] = []

        for item in effectiveItems {
            let itemID = id(item)
            guard let oldItem = oldItems[itemID], oldItem != item else { continue }
            if oldKeys[itemID] == key(item) {
                reconfigure.append(itemID)
            } else {
                reload.append(itemID)
            }
        }

        return KsSnapshotPlan(
            identifiers: identifiers,
            reconfigure: reconfigure,
            reload: reload
        )
    }

    private static func deduplicatingByLastOccurrence<Item>(
        _ items: [Item],
        id: (Item) -> AnyHashable
    ) -> [Item] {
        var lastIndexByID: [AnyHashable: Int] = [:]
        for (index, item) in items.enumerated() {
            lastIndexByID[id(item)] = index
        }
        guard lastIndexByID.count != items.count else { return items }
        return items.enumerated()
            .filter { lastIndexByID[id($0.element)] == $0.offset }
            .map(\.element)
    }
}
