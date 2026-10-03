import XCTest
@testable import KsCollectionViewSamples

/// 「差分更新」画面の操作ごとの配列の組み替えと、グループありの間は同じグループの項目が続いて並ぶことを
/// 確かめます。
///
/// 同じグループが離れた位置に現れる配列は、グループありの一覧に渡せない不正な入力です。
final class DiffUpdateModelTests: XCTestCase {
    /// 挿入・更新・グループの切り替え・元に戻すが、配列と行の文言に反映されます。
    @MainActor
    func test挿入と更新とグループの切り替えと元に戻すが反映される() {
        var model = DiffUpdateModel()
        XCTAssertTrue(model.grouped)
        XCTAssertEqual(model.items.map(\.id), Array(1...20))
        XCTAssertEqual(model.items.first?.row.title, "Item 1")
        XCTAssertEqual(DiffUpdateModel.groupName(0), "グループ A")
        XCTAssertEqual(count(inGroup: 0, of: model), 5)

        // 先頭への挿入。新しい ID は 21 から振られ、先頭のグループに入る。
        model.insert(at: .head)
        XCTAssertEqual(model.items.first?.id, 21)
        XCTAssertEqual(model.items.first?.row.title, "Item 21")
        XCTAssertEqual(model.items.first?.group, 0)
        XCTAssertEqual(count(inGroup: 0, of: model), 6)

        // 更新は同じ位置の項目の文言に印を付ける (ID は変えない)。
        model.update(at: .head)
        XCTAssertEqual(model.items.first?.id, 21)
        XCTAssertEqual(model.items.first?.row.title, "Item 21 ★")

        // グループなしに切り替えても、配列は変わらない。
        let beforeUngrouping = model.items
        model.setGrouped(false)
        XCTAssertFalse(model.grouped)
        XCTAssertEqual(model.items, beforeUngrouping)

        // 元に戻すと初期の 20 件に戻る。グループの有無は変えない。
        model.reset()
        XCTAssertEqual(model.items.map(\.id), Array(1...20))
        XCTAssertEqual(model.items.map(\.row.title), (1...20).map { "Item \($0)" })
        XCTAssertFalse(model.grouped)
    }

    /// グループありで、全ての位置の全ての操作を繰り返しても、同じグループが離れて現れる配列になりません。
    @MainActor
    func testグループありの操作を繰り返しても同じグループが離れて現れない() {
        var model = DiffUpdateModel()
        let operations: [(String, (inout DiffUpdateModel, DiffUpdatePosition) -> Void)] = [
            ("挿入", { $0.insert(at: $1) }),
            ("移動", { $0.move(at: $1) }),
            ("更新", { $0.update(at: $1) }),
            ("削除", { $0.delete(at: $1) }),
            ("移動", { $0.move(at: $1) }),
        ]

        for round in 1...2 {
            for position in DiffUpdatePosition.allCases {
                for (name, operation) in operations {
                    operation(&model, position)
                    assertValidGroupedInput(model, after: "\(round) 周目 \(position.rawValue) \(name)")
                }
            }
            model.reverse()
            assertValidGroupedInput(model, after: "\(round) 周目 反転")
            model.shuffle()
            assertValidGroupedInput(model, after: "\(round) 周目 シャッフル")
            model.move(at: .tail)
            assertValidGroupedInput(model, after: "\(round) 周目 移動")
        }
    }

    /// グループなしで配列を崩してからグループありに切り替えると、切り替えと同じ変更の中で並べ直され、
    /// 同じグループが離れて現れる配列がグループありで渡りません。
    @MainActor
    func testグループなしで崩してからグループありにしても同じグループが離れて現れない() {
        var model = DiffUpdateModel()
        // シャッフルで崩す経路と、中ほどの項目の移動で崩す経路。グループなしの移動は項目を件数の半分先へ
        // 移すため、グループ単位に並んだ 20 件で中ほどの項目を 1 回移すと、その項目のグループが離れて現れる。
        let breakings: [(String, (inout DiffUpdateModel) -> Void)] = [
            ("シャッフル", { $0.shuffle() }),
            ("中ほどの移動", { $0.move(at: .middle) }),
        ]

        for (name, breaking) in breakings {
            model.setGrouped(false)
            breaking(&model)
            XCTAssertFalse(
                SampleTestSupport.isContiguous(model.items.map(\.group)),
                "\(name) で配列が崩れておらず、並べ直しを確かめられません"
            )
            let ids = Set(model.items.map(\.id))

            model.setGrouped(true)

            XCTAssertTrue(model.grouped)
            assertValidGroupedInput(model, after: "\(name) の後のグループあり")
            XCTAssertEqual(Set(model.items.map(\.id)), ids, "並べ直しで項目が増減しています")
        }
    }

    /// グループありの一覧に渡せる配列 (同じグループが続いて並び、ID が重ならない) であることを確かめる。
    @MainActor
    private func assertValidGroupedInput(
        _ model: DiffUpdateModel,
        after operation: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let groups = model.items.map(\.group)
        XCTAssertTrue(
            SampleTestSupport.isContiguous(groups),
            "\(operation) の後に同じグループが離れて現れています: \(groups)",
            file: file,
            line: line
        )
        let ids = model.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "\(operation) の後に ID が重なっています", file: file, line: line)
    }

    /// 指定したグループの件数。
    @MainActor
    private func count(inGroup group: Int, of model: DiffUpdateModel) -> Int {
        model.items.filter { $0.group == group }.count
    }
}
