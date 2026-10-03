import KsCollectionView
import XCTest
@testable import KsCollectionViewSamples

/// 「並べ替え」画面のモデルの、初期の並びと切り替え・置いたときの並べ替え・置けるかの判定・帯の知らせを
/// 確かめます。
final class ReorderDemoModelTests: XCTestCase {
    // MARK: - 構成

    /// 初期の並びは Item 1 からの 10,000 件で、100 件ずつのグループに分かれ、10 の倍数は動かせず、
    /// 切り替えは並べ替えとグループだけがオンです。
    @MainActor
    func test初期の並びと切り替え() {
        let model = ReorderDemoModel()

        XCTAssertEqual(model.items.map(\.id), Array(1...10_000))
        XCTAssertEqual(model.items.prefix(5).map(\.title), ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"])
        XCTAssertEqual(model.items[0].group, 1)
        XCTAssertEqual(model.items[99].group, 1)
        XCTAssertEqual(model.items[100].group, 2)
        XCTAssertEqual(model.items.last?.group, 100)
        XCTAssertEqual(ReorderDemoText.groupName(model.items[0].group), "グループ 1")

        XCTAssertFalse(model.items[9].isMovable, "Item 10 が動かせる項目になっています")
        XCTAssertTrue(model.items[8].isMovable, "Item 9 が動かせない項目になっています")
        XCTAssertEqual(
            model.items.filter { !$0.isMovable }.map(\.id),
            Array(stride(from: 10, through: 10_000, by: 10))
        )

        XCTAssertTrue(model.isReorderEnabled, "並べ替えが初めからオンではありません")
        XCTAssertTrue(model.isGrouped, "グループが初めからオンではありません")
        XCTAssertFalse(model.keepsGroups, "グループをまたがせないが初めからオンです")
        XCTAssertFalse(model.rejectsMoves, "置いても受け入れないが初めからオンです")
        XCTAssertNil(model.notice)
    }

    // MARK: - 並べ替え

    /// グループ 1 の Item 1 をグループ 2 の Item 102 の前に置くと、Item 101 と Item 102 の間に並び、
    /// Item 1 のグループはグループ 2 になります。
    @MainActor
    func test別のグループへ動かす() throws {
        let model = ReorderDemoModel()
        let move = KsReorderMove(
            item: model.items[0],
            destination: .before(model.items[101]),
            group: AnyHashable(2)
        )

        XCTAssertTrue(model.move(move), "並べ替えを受け入れていません")

        let index = try XCTUnwrap(model.items.firstIndex { $0.id == 1 })
        XCTAssertEqual(model.items[(index - 1)...(index + 1)].map(\.id), [101, 1, 102])
        XCTAssertEqual(model.items[index].group, 2, "Item 1 がグループ 2 に入っていません")
        XCTAssertEqual(model.items.filter { $0.group == 1 }.count, 99)
        XCTAssertEqual(model.items.filter { $0.group == 2 }.count, 101)
        XCTAssertTrue(SampleTestSupport.isContiguous(model.items.map(\.group)))
    }

    /// グループをオフにしている間 (知らせにグループの値が無い) に Item 1 を Item 4 の前に置くと、
    /// Item 2, 3, 1, 4 の順に並びます。動かした項目のグループは、行き先の隣の項目のグループになります。
    @MainActor
    func testグループなしでも並べ替えられる() {
        let items = ReorderDemoModel.initialItems

        let moved = ReorderDemoModel.applying(
            KsReorderMove(item: items[0], destination: .before(items[3]), group: nil),
            to: items
        )
        XCTAssertEqual(moved.prefix(5).map(\.id), [2, 3, 1, 4, 5])
        XCTAssertEqual(moved.count, items.count)

        // グループの境目をまたいで置くと、行き先の項目のグループに書き換わる。
        let crossed = ReorderDemoModel.applying(
            KsReorderMove(item: items[0], destination: .before(items[101]), group: nil),
            to: items
        )
        XCTAssertEqual(crossed[100].id, 1)
        XCTAssertEqual(crossed[100].group, 2)
        XCTAssertTrue(SampleTestSupport.isContiguous(crossed.map(\.group)))

        // 一覧の末尾に置くと、最後の項目のグループに書き換わる。
        let toEnd = ReorderDemoModel.applying(
            KsReorderMove(item: items[0], destination: .end, group: nil),
            to: items
        )
        XCTAssertEqual(toEnd.last?.id, 1)
        XCTAssertEqual(toEnd.last?.group, 100)
    }

    // MARK: - 長押し

    /// 項目の長押しを知らされると、「長押し: Item 5」の帯を出します。
    @MainActor
    func test長押しを知らされると帯を出す() {
        let model = ReorderDemoModel()

        model.didLongPress(model.items[4])

        XCTAssertEqual(model.notice, "長押し: Item 5")
    }

    // MARK: - 受け入れない・またがせない

    /// 「置いても受け入れない」がオンのときに置くと、受け入れないと返して並びを変えず、
    /// 「並べ替えを受け入れませんでした」の帯を出します。帯は決まった時間の後に消えます。
    @MainActor
    func test受け入れないと並びを変えず帯を出して消す() async {
        // 帯を出しておく時間を縮める (既定は 3 秒)。
        let model = ReorderDemoModel(noticeDuration: 0.05)
        model.rejectsMoves = true
        let move = KsReorderMove(
            item: model.items[0],
            destination: .before(model.items[3]),
            group: AnyHashable(1)
        )

        XCTAssertFalse(model.move(move), "受け入れないはずの並べ替えを受け入れています")

        XCTAssertEqual(model.items, ReorderDemoModel.initialItems, "受け入れないのに並びが変わっています")
        XCTAssertEqual(model.notice, "並べ替えを受け入れませんでした")
        await SampleTestSupport.waitUntil("帯が消える", value: { model.notice }) { $0 == nil }
    }

    /// 「グループをまたがせない」がオンの間は、元のグループの中にだけ置けます。オフの間と、グループを
    /// オフにしている間 (知らせにグループの値が無い) は、どこにでも置けます。
    @MainActor
    func testグループをまたがせない() {
        let model = ReorderDemoModel()
        let item = model.items[0]
        let toOtherGroup = KsReorderMove(item: item, destination: .before(model.items[101]), group: AnyHashable(2))
        let withinGroup = KsReorderMove(item: item, destination: .before(model.items[50]), group: AnyHashable(1))
        let ungrouped = KsReorderMove(item: item, destination: .before(model.items[101]), group: nil)

        XCTAssertTrue(model.canDrop(toOtherGroup), "切り替えがオフなのに別のグループへ置けません")

        model.keepsGroups = true

        XCTAssertFalse(model.canDrop(toOtherGroup), "別のグループへ置けています")
        XCTAssertTrue(model.canDrop(withinGroup), "元のグループの中に置けません")
        XCTAssertTrue(model.canDrop(ungrouped), "グループをオフにしている間に置けません")
    }
}
