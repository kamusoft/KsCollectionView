import XCTest
@testable import KsCollectionViewSamples

/// 「グループ化」画面の「項目を別のグループへ」が、項目を隣のグループへ移して両方のグループの件数を
/// 変えることを確かめます。
final class GroupingDemoEditsTests: XCTestCase {
    /// 並び順を反転した画面の配列で項目を移すと、移した先のグループが 1 件増え、元のグループが 1 件減ります。
    @MainActor
    func test項目を別のグループへ移すと移した先と元のグループの件数が変わる() {
        // 反転すると最後のグループが先頭へ来る。先頭のグループの先頭の項目を移す。
        let items = GroupingDemoEdits.reversingGroups(GroupingDemoData.items)
        let source = items[0].group
        let destination = items[counts(of: items)[source, default: 0]].group
        XCTAssertNotEqual(source, destination)

        let moved = GroupingDemoEdits.movingItem(at: 0, in: items)

        let before = counts(of: items)
        let after = counts(of: moved)
        XCTAssertEqual(after[source], before[source].map { $0 - 1 }, "元のグループの件数が 1 減っていません")
        XCTAssertEqual(after[destination], before[destination].map { $0 + 1 }, "移した先の件数が 1 増えていません")
        XCTAssertEqual(
            after.filter { $0.key != source && $0.key != destination },
            before.filter { $0.key != source && $0.key != destination },
            "ほかのグループの件数が変わっています"
        )
        XCTAssertEqual(moved.count, items.count)
        XCTAssertTrue(SampleTestSupport.isContiguous(moved.map(\.group)), "同じグループが離れた位置に現れています")
    }

    /// グループの末尾に近い項目は次のグループの先頭へ、先頭に近い項目は前のグループの末尾へ移ります。
    @MainActor
    func test末尾に近い項目は次のグループの先頭へ先頭に近い項目は前のグループの末尾へ移す() {
        let items = makeItems(groups: [1, 1, 1, 1, 2, 2, 2, 3, 3])

        // グループ 1 の最後の項目 (ID 4) は、グループ 2 の先頭になる。
        let toNext = GroupingDemoEdits.movingItem(at: 3, in: items)
        XCTAssertEqual(toNext.map(\.id), [1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(toNext.map(\.group), [1, 1, 1, 2, 2, 2, 2, 3, 3])

        // グループ 2 の先頭の項目 (ID 5) は、グループ 1 の末尾になる。
        let toPrevious = GroupingDemoEdits.movingItem(at: 4, in: items)
        XCTAssertEqual(toPrevious.map(\.id), [1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(toPrevious.map(\.group), [1, 1, 1, 1, 1, 2, 2, 3, 3])

        // グループ 2 の真ん中の項目 (ID 6) は末尾の側として扱い、グループ 3 の先頭になる。
        let fromMiddle = GroupingDemoEdits.movingItem(at: 5, in: items)
        XCTAssertEqual(fromMiddle.map(\.id), [1, 2, 3, 4, 5, 7, 6, 8, 9])
        XCTAssertEqual(fromMiddle.map(\.group), [1, 1, 1, 1, 2, 2, 3, 3, 3])
    }

    /// 近い側に隣のグループが無ければ反対側へ移し、グループが 1 つしか無ければ何もしません。
    @MainActor
    func test近い側に隣のグループが無ければ反対側へ移す() {
        let items = makeItems(groups: [1, 1, 1, 1, 2, 2, 2, 3, 3])

        // 先頭の項目 (ID 1) は前のグループが無いため、グループ 2 の先頭へ移す。
        let fromHead = GroupingDemoEdits.movingItem(at: 0, in: items)
        XCTAssertEqual(fromHead.map(\.id), [2, 3, 4, 1, 5, 6, 7, 8, 9])
        XCTAssertEqual(fromHead.map(\.group), [1, 1, 1, 2, 2, 2, 2, 3, 3])

        // 最後の項目 (ID 9) は次のグループが無いため、グループ 2 の末尾へ移す。
        let fromTail = GroupingDemoEdits.movingItem(at: 8, in: items)
        XCTAssertEqual(fromTail.map(\.id), [1, 2, 3, 4, 5, 6, 7, 9, 8])
        XCTAssertEqual(fromTail.map(\.group), [1, 1, 1, 1, 2, 2, 2, 2, 3])

        let single = makeItems(groups: [1, 1, 1])
        XCTAssertEqual(GroupingDemoEdits.movingItem(at: 1, in: single), single)
        XCTAssertEqual(GroupingDemoEdits.movingItem(at: 9, in: items), items, "範囲の外の番号で配列が変わっています")
    }

    /// ID を 1 から振った項目を、指定したグループの並びで作る。
    @MainActor
    private func makeItems(groups: [Int]) -> [GroupingDemoItem] {
        groups.enumerated().map { offset, group in
            GroupingDemoItem(row: DemoData.largeItem(offset + 1), group: group)
        }
    }

    /// グループごとの件数。
    @MainActor
    private func counts(of items: [GroupingDemoItem]) -> [Int: Int] {
        items.reduce(into: [:]) { $0[$1.group, default: 0] += 1 }
    }
}
