#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// グループ化 (グループの値・見出し・間隔・区切り線・差分) をエンジンの実レイアウトで確かめる。
@MainActor
final class KsGroupingEngineTests: XCTestCase {
    private struct Row: Identifiable, Equatable {
        let id: Int
        let group: String
        var title: String
        // 行の高さ。nil なら `rowHeight`。グリッドで同じ行に背の違う項目を並べるときに使う。
        var height: CGFloat? = nil

        // グループの値の取り出し方を差し替えるための、別の区切り方。ID 0...2 を「前半」、それ以降を「後半」にする。
        var half: String { id < 3 ? "前半" : "後半" }
        // `group` と同じ値を返す、別のキーパス。
        var groupAlias: String { group }
    }

    // 見出しの内容の組み立てを記録する。グループの値とグループ内の項目の ID を順に残す。
    private final class HeaderRecorder {
        private(set) var builds: [(group: String, ids: [Int])] = []

        func record(_ group: String, _ rows: [Row]) {
            builds.append((group, rows.map(\.id)))
        }

        func last(for group: String) -> [Int]? {
            builds.last { $0.group == group }?.ids
        }
    }

    // 見出しの中で読む、呼び出し側の状態。
    private final class SelectionBox {
        var selected = "なし"
    }

    private static let rowHeight: CGFloat = 44
    private static let headerHeight: CGFloat = 40
    private static let size = CGSize(width: 390, height: 844)

    override func setUp() {
        super.setUp()
        KsInvalidInput.reset()
    }

    override func tearDown() {
        KsInvalidInput.reset()
        super.tearDown()
    }

    // MARK: - グループの構成と見出し

    func testグループの値が続く範囲が1つのグループになり見出しにグループの値と項目が渡る() async {
        let recorder = HeaderRecorder()
        let rows = makeRows([("果物", 2), ("野菜", 3)])
        let controller = makeController(rows: rows, recorder: recorder)
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)

        XCTAssertEqual(sectionItemCounts(in: controller), [2, 3])
        XCTAssertEqual(controller.appliedSectionIdentifiers.map(\.group), ["果物", "野菜"].map { AnyHashable($0) })
        await waitUntil("見出しの組み立て", value: {
            [recorder.last(for: "果物"), recorder.last(for: "野菜")]
        }) { $0 == [[0, 1], [2, 3, 4]] }

        // 各グループの先頭行の前に見出しが 1 つずつ置かれる。
        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: [0, 1, 2])
        XCTAssertEqual(headers.count, 2, "見出しの数がグループの数と違います")
        guard headers.count == 2, frames.count == 3 else { return }
        XCTAssertLessThanOrEqual(headers[0].maxY, frames[0].minY + 0.5)
        XCTAssertGreaterThanOrEqual(headers[1].minY, frames[1].maxY - 0.5)
        XCTAssertLessThanOrEqual(headers[1].maxY, frames[2].minY + 0.5)
    }

    func testグループを宣言しなければ1続きで見出しを出さない() async {
        let rows = makeRows([("果物", 2), ("野菜", 3)])
        let configuration = KsCollectionView(rows) { row in RowView(row: row) }.configuration
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)

        XCTAssertEqual(sectionItemCounts(in: controller), [5])
        XCTAssertEqual(controller.appliedSectionIdentifiers.map(\.group), [nil])
        XCTAssertTrue(groupHeaderFrames(in: controller).isEmpty, "グループを宣言していないのに見出しが出ています")
    }

    func test見出しなしのグループは見出しを出さずにグループに分ける() async {
        let rows = makeRows([("果物", 2), ("野菜", 3)])
        let configuration = KsCollectionView(rows) { row in RowView(row: row) }
            .groups(by: \.group)
            .configuration
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)

        XCTAssertEqual(sectionItemCounts(in: controller), [2, 3])
        XCTAssertTrue(groupHeaderFrames(in: controller).isEmpty, "見出しを宣言していないのに見出しが出ています")
    }

    // グリッドの見出しは全幅を占め、グループの先頭の項目は見出しの次の行の行頭に置かれる。
    // 奇数件のグループの最終行だけが列数に満たない。
    func testグリッドでは見出しが全幅で次のグループの先頭は行頭に置かれる() async {
        let rows = makeRows([("果物", 3), ("野菜", 2)])
        let controller = makeController(
            rows: rows,
            layout: .grid(columns: .fixed(2), rowSpacing: 4, columnSpacing: 6),
            padding: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        )
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)
        await settleLayout(in: controller)

        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: [0, 1, 2, 3, 4])
        XCTAssertEqual(headers.count, 2)
        guard headers.count == 2, frames.count == 5 else { return }
        for header in headers {
            XCTAssertEqual(header.minX, 12, accuracy: 0.5, "見出しが左の内側余白に揃っていません")
            XCTAssertEqual(header.width, Self.size.width - 24, accuracy: 0.5, "見出しが全幅を占めていません")
        }
        // 果物の最終行 (3 件目) は 1 列だけで、野菜の先頭は見出しの後の行頭に置かれる。
        XCTAssertEqual(frames[2].minX, frames[0].minX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(headers[1].minY, frames[2].maxY - 0.5)
        XCTAssertEqual(frames[3].minX, frames[0].minX, accuracy: 0.5, "次のグループの先頭が行頭に置かれていません")
        XCTAssertGreaterThanOrEqual(frames[3].minY, headers[1].maxY - 0.5)
        XCTAssertEqual(frames[4].minY, frames[3].minY, accuracy: 0.5)
        XCTAssertGreaterThan(frames[4].minX, frames[3].minX)
    }

    // ルートのヘッダーは最初のグループの見出しより前に、フッターは最後のグループの最終行より後に 1 つずつ置かれる。
    func testルートのヘッダーとフッターはグループの外側に1つずつ置かれる() async {
        var configuration = KsCollectionView(makeRows([("果物", 2), ("野菜", 2)])) { row in RowView(row: row) }
            .groups(by: \.group) { group, _ in HeaderView(text: group) }
            .header { FixedHeightView(text: "ルートのヘッダー", height: 50) }
            .footer { FixedHeightView(text: "ルートのフッター", height: 30) }
            .configuration
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(4, in: controller)
        await settleLayout(in: controller)

        let roots = supplementaryFrames(ofKind: KsSupplementaryKind.rootHeader, in: controller)
        let footers = supplementaryFrames(ofKind: KsSupplementaryKind.rootFooter, in: controller)
        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: [0, 3])
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(footers.count, 1)
        guard roots.count == 1, footers.count == 1, headers.count == 2, frames.count == 2 else {
            XCTFail("補助ビューのレイアウト属性を取得できませんでした (\(roots.count) / \(footers.count) / \(headers.count))")
            return
        }
        XCTAssertLessThanOrEqual(roots[0].maxY, headers[0].minY + 0.5)
        XCTAssertGreaterThanOrEqual(footers[0].minY, frames[1].maxY - 0.5)
    }

    // 上下の内側余白はルートのヘッダーの上とフッターの下に入り、ヘッダー / フッターと行の間には行間が入らない。
    func test内側余白はヘッダーの上とフッターの下に入り前後に行間が入らない() async {
        var configuration = KsCollectionView(makeRows([("果物", 3)]), layout: .list(rowSpacing: 8)) { row in
            RowView(row: row)
        }
        .header { FixedHeightView(text: "ヘッダー", height: 40) }
        .footer { FixedHeightView(text: "フッター", height: 30) }
        .configuration
        configuration.contentPadding = EdgeInsets(top: 20, leading: 0, bottom: 24, trailing: 0)
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(3, in: controller)
        await settleLayout(in: controller)

        guard
            let header = supplementaryFrames(ofKind: KsSupplementaryKind.rootHeader, in: controller).first,
            let footer = supplementaryFrames(ofKind: KsSupplementaryKind.rootFooter, in: controller).first
        else {
            XCTFail("ヘッダー / フッターのレイアウト属性を取得できませんでした")
            return
        }
        let frames = itemFrames(in: controller, offsets: [0, 1, 2])
        guard frames.count == 3 else { return }
        // ヘッダーは内容の先頭から始まり、上の内側余白の分だけ中身の上に空白を持つ。
        XCTAssertEqual(header.minY, 0, accuracy: 0.5)
        XCTAssertEqual(header.height, 40 + 20, accuracy: 0.5, "上の内側余白がヘッダーの上に入っていません")
        XCTAssertEqual(frames[0].minY, header.maxY, accuracy: 0.5, "ヘッダーと先頭行の間に間隔が入っています")
        XCTAssertEqual(frames[1].minY - frames[0].maxY, 8, accuracy: 0.5, "行間が行の間に入っていません")
        XCTAssertEqual(footer.minY, frames[2].maxY, accuracy: 0.5, "最終行とフッターの間に間隔が入っています")
        XCTAssertEqual(footer.height, 30 + 24, accuracy: 0.5, "下の内側余白がフッターの下に入っていません")
        XCTAssertEqual(controller.collectionView.contentSize.height, footer.maxY, accuracy: 0.5)
    }

    // MARK: - 間隔

    func test間隔を指定しなければ見出しの前後とグループの境目に間隔が入らない() async {
        let controller = makeController(
            rows: makeRows([("果物", 3), ("野菜", 3)]),
            layout: .list(rowSpacing: 8)
        )
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)

        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: Array(0..<6))
        guard headers.count == 2, frames.count == 6 else {
            XCTFail("レイアウト属性を取得できませんでした (\(headers.count) / \(frames.count))")
            return
        }
        XCTAssertEqual(headers[0].minY, 0, accuracy: 0.5)
        XCTAssertEqual(frames[0].minY - headers[0].maxY, 0, accuracy: 0.5, "見出しの下に行間が入っています")
        XCTAssertEqual(frames[1].minY - frames[0].maxY, 8, accuracy: 0.5, "行と行の間に行間が入っていません")
        XCTAssertEqual(headers[1].minY - frames[2].maxY, 0, accuracy: 0.5, "見出しの上に行間が入っています")
        XCTAssertEqual(frames[3].minY - headers[1].maxY, 0, accuracy: 0.5)
        XCTAssertEqual(controller.collectionView.contentSize.height, frames[5].maxY, accuracy: 0.5)
    }

    func testグループ間の間隔と見出しの下の間隔を指定した位置に入れる() async {
        let controller = makeController(
            rows: makeRows([("果物", 3), ("野菜", 3)]),
            layout: .list(rowSpacing: 8, groupSpacing: 24, headerItemSpacing: 6),
            padding: EdgeInsets(top: 20, leading: 0, bottom: 10, trailing: 0)
        )
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)

        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: Array(0..<6))
        guard headers.count == 2, frames.count == 6 else {
            XCTFail("レイアウト属性を取得できませんでした (\(headers.count) / \(frames.count))")
            return
        }
        // 先頭にはグループ間の間隔が入らず、上の内側余白だけが見出しの上に入る。
        XCTAssertEqual(headers[0].minY, 20, accuracy: 0.5, "最初の見出しの上に内側余白以外の間隔が入っています")
        XCTAssertEqual(frames[0].minY - headers[0].maxY, 6, accuracy: 0.5, "見出しの下の間隔が違います")
        XCTAssertEqual(frames[1].minY - frames[0].maxY, 8, accuracy: 0.5)
        XCTAssertEqual(headers[1].minY - frames[2].maxY, 24, accuracy: 0.5, "グループ間の間隔が違います")
        XCTAssertEqual(frames[3].minY - headers[1].maxY, 6, accuracy: 0.5, "見出しの下の間隔が違います")
        // 末尾にはグループ間の間隔が入らず、下の内側余白だけが入る。
        XCTAssertEqual(
            controller.collectionView.contentSize.height - frames[5].maxY,
            10,
            accuracy: 0.5,
            "末尾に内側余白以外の間隔が入っています"
        )
    }

    // 見出しを宣言しないグループでも、グループ間の間隔は前のグループの最終行と次のグループの先頭行の間に入る。
    func test見出しなしのグループでもグループ間の間隔が入る() async {
        var configuration = KsCollectionView(
            makeRows([("果物", 2), ("野菜", 2)]),
            layout: .list(rowSpacing: 8, groupSpacing: 24, headerItemSpacing: 6)
        ) { row in RowView(row: row) }
            .groups(by: \.group)
            .configuration
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(4, in: controller)
        await settleLayout(in: controller)

        let frames = itemFrames(in: controller, offsets: Array(0..<4))
        guard frames.count == 4 else { return }
        XCTAssertEqual(frames[0].minY, 0, accuracy: 0.5, "見出しが無いのに見出しの下の間隔が入っています")
        XCTAssertEqual(frames[1].minY - frames[0].maxY, 8, accuracy: 0.5)
        XCTAssertEqual(frames[2].minY - frames[1].maxY, 24, accuracy: 0.5, "グループ間の間隔が違います")
        XCTAssertEqual(frames[3].minY - frames[2].maxY, 8, accuracy: 0.5)
    }

    // MARK: - 区切り線

    func test見出しつきのグループでは各グループの先頭行の上端に区切り線を出す() async {
        let controller = makeController(rows: makeRows([("果物", 3), ("野菜", 3)]), showsSeparators: true)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)

        for offset in 0..<6 {
            let cell = cell(at: offset, in: controller)
            XCTAssertEqual(cell?.isTopSeparatorVisible, offset == 0 || offset == 3, "項目 \(offset) の上端の線")
            XCTAssertEqual(cell?.isBottomSeparatorVisible, true, "項目 \(offset) の下端の線")
        }
        // 見出しは前のグループの最終行の下線と、自分のグループの先頭行の上線の間にある。
        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: [2, 3])
        guard headers.count == 2, frames.count == 2 else { return }
        XCTAssertGreaterThanOrEqual(headers[1].minY, frames[0].maxY - 0.5)
        XCTAssertLessThanOrEqual(headers[1].maxY, frames[1].minY + 0.5)
    }

    func test見出しなしのグループでは境目の上端の区切り線を出さない() async {
        var configuration = KsCollectionView(makeRows([("果物", 3), ("野菜", 3)])) { row in RowView(row: row) }
            .groups(by: \.group)
            .configuration
        configuration.showsSeparators = true
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)

        for offset in 0..<6 {
            let cell = cell(at: offset, in: controller)
            XCTAssertEqual(cell?.isTopSeparatorVisible, offset == 0, "項目 \(offset) の上端の線")
            XCTAssertEqual(cell?.isBottomSeparatorVisible, true, "項目 \(offset) の下端の線")
        }
    }

    // MARK: - 塊に割れたグループ

    // 見出しはグループの先頭の塊では場所を取り、2 つめ以降の塊では場所を取らない。塊の境界の前後の
    // 行間は他の行間と同じで、上端の区切り線はグループの先頭行だけに出る。
    func test塊に割れたグループでは見出しが先頭の塊にだけ場所を取る() async {
        for pinned in [true, false] {
            let controller = makeController(
                rows: makeRows([("大", 1_200), ("小", 5)]),
                layout: .list(rowSpacing: 8, headerItemSpacing: 6),
                pinnedHeaders: pinned,
                showsSeparators: true
            )
            let window = showInsideSafeArea(controller)
            defer { window.isHidden = true }
            await waitForItems(1_205, in: controller)

            XCTAssertEqual(sectionItemCounts(in: controller), [500, 500, 200, 5], "固定 \(pinned)")
            XCTAssertEqual(controller.appliedSectionIdentifiers.map(\.chunkInGroup), [0, 1, 2, 0])
            await settleLayout(in: controller)
            let headers = groupHeaderFrames(in: controller)
            let first = itemFrames(in: controller, offsets: [0])
            if let header = headers.first, let row = first.first {
                XCTAssertEqual(row.minY - header.maxY, 6, accuracy: 0.5, "先頭の塊の見出しが場所を取っていません (固定 \(pinned))")
            } else {
                XCTFail("先頭の見出しのレイアウト属性を取得できませんでした (固定 \(pinned))")
            }

            // 塊の境界まで送って、境界の前後の行間と区切り線を確かめる。
            await scroll(toOffset: 498, in: controller)
            let frames = itemFrames(in: controller, offsets: [498, 499, 500, 501])
            guard frames.count == 4 else {
                XCTFail("塊の境界のレイアウト属性を取得できませんでした (固定 \(pinned))")
                continue
            }
            XCTAssertEqual(frames[1].minY - frames[0].maxY, 8, accuracy: 0.5)
            XCTAssertEqual(
                frames[2].minY - frames[1].maxY,
                8,
                accuracy: 0.5,
                "塊の境界に見出しの場所が入っています (固定 \(pinned))"
            )
            XCTAssertEqual(cell(at: 500, in: controller)?.isTopSeparatorVisible, false, "塊の境界に上端の線が出ています")

            // 固定するときは 2 つめ以降の塊にも見出しが付き、固定しないときはグループの先頭の塊だけに付く。
            let headerSections = groupHeaderIndexPaths(in: controller).map(\.section)
            if pinned {
                XCTAssertTrue(headerSections.contains(1), "2 つめの塊に見出しが付いていません (\(headerSections))")
            } else {
                XCTAssertFalse(headerSections.contains(1), "固定しないのに 2 つめの塊に見出しが付いています (\(headerSections))")
            }
        }
    }

    // MARK: - 見出しの固定

    func test見出しは既定で表示範囲の上端に固定される() async {
        let controller = makeController(rows: makeRows([("果物", 60), ("野菜", 60)]))
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(120, in: controller)

        await scroll(toOffset: 20, in: controller)
        let top = controller.collectionView.bounds.minY
        let pinned = groupHeaderFrames(in: controller).filter { abs($0.minY - top) < 1 }
        XCTAssertEqual(pinned.count, 1, "最初のグループの見出しが上端に固定されていません (上端 \(top))")
    }

    func test固定を外すと見出しはコンテンツと一緒に流れる() async {
        let controller = makeController(rows: makeRows([("果物", 60), ("野菜", 60)]), pinnedHeaders: false)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(120, in: controller)

        await scroll(toOffset: 20, in: controller)
        let top = controller.collectionView.bounds.minY
        let headers = groupHeaderFrames(in: controller)
        XCTAssertFalse(
            headers.contains { $0.maxY > top + 0.5 && $0.minY < top + Self.headerHeight },
            "固定を外したのに見出しが上端に残っています (上端 \(top) / 見出し \(headers))"
        )
    }

    // 次のグループの見出しが上端に達すると、固定中の見出しは押し上げられる (重ならない)。
    func test次のグループの見出しが固定中の見出しを押し上げる() async {
        let controller = makeController(rows: makeRows([("果物", 30), ("野菜", 30)]))
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(60, in: controller)
        await scroll(toOffset: 25, in: controller)

        // 2 つめの見出しの本来の位置が、上端から見出しの高さの 4 分の 1 だけ下に来るまで送る。
        guard let second = unpinnedGroupHeaderFrame(groupIndex: 1, in: controller) else {
            XCTFail("2 つめの見出しの位置を取得できませんでした")
            return
        }
        controller.collectionView.setContentOffset(
            CGPoint(x: 0, y: second.minY - Self.headerHeight * 3 / 4),
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        let top = controller.collectionView.bounds.minY
        let headers = groupHeaderIndexPathsAndFrames(in: controller)
        guard headers.count >= 2 else {
            XCTFail("見出しが 2 つ見えていません (\(headers))")
            return
        }
        XCTAssertLessThan(headers[0].frame.minY, top - 1, "固定中の見出しが押し上げられていません")
        XCTAssertLessThanOrEqual(headers[0].frame.maxY, headers[1].frame.minY + 0.5, "見出しが重なっています")
        // 押し上げの量 (見出しの高さの 4 分の 3) は、薄めに任せれば見えなくなる量を超えている。
        // 押し上げられている間も見出しは薄れない。
        XCTAssertEqual(headers[0].alpha, 1, accuracy: 0.001, "押し上げられている見出しが薄れています")
        let views = groupHeaderViews(in: controller)
        XCTAssertTrue(
            views.contains { abs($0.frame.minY - headers[0].frame.minY) < 0.5 && $0.alpha > 0.999 },
            "押し上げられている見出しのビューが薄れています (\(views.map { ($0.frame.minY, $0.alpha) }))"
        )
    }

    // グリッドでグループの最後の行の最後の項目が同じ行の他の項目より背が低くても、固定中の見出しは
    // 行の下端 (次のグループの見出しと接する位置) まで上端に留まり、そこから押し上げられる。
    // 最後の項目の下端で押し上げを始めると、上端に見出しの無い帯ができる。塊に割れたグループでも
    // 最後の塊の最後の行で同じになる。
    func testグリッドで最後の項目が低い行でも押し上げは次の見出しと接してから始まる() async {
        for count in [10, 1_000] {
            var rows = makeRows([("前", count), ("後", 30)])
            // 最後の行は左の項目 (count - 2) が高く、右の最後の項目 (count - 1) が低い。
            rows[count - 2].height = Self.rowHeight + 60
            let controller = KsCollectionViewController(
                configuration: makeConfiguration(
                    rows: rows,
                    layout: .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 6)
                )
            )
            // 安全領域の境目で固定する分を除くため、安全領域の内側に載せる。
            let window = showInsideSafeArea(controller)
            defer { window.isHidden = true }
            await waitForItems(count + 30, in: controller)
            await scroll(toOffset: count - 2, in: controller)

            let frames = itemFrames(in: controller, offsets: [count - 2, count - 1])
            guard frames.count == 2, let next = unpinnedGroupHeaderFrame(groupIndex: 1, in: controller) else {
                XCTFail("件数 \(count): 最後の行か次の見出しの位置を取得できませんでした")
                continue
            }
            XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 0.5, "件数 \(count): 最後の行の 2 項目が同じ行にありません")
            XCTAssertGreaterThan(frames[0].height, frames[1].height + 50, "件数 \(count): 最後の項目が低くなっていません")

            // 次の見出しが上端から (見出しの高さ + 20) 下: まだ押し上げられず上端に固定されている。
            // 次の見出しが上端から 20 下: 押し上げられ、固定中の見出しの下端が次の見出しの上端に接する。
            for gap in [Self.headerHeight + 20, 20] {
                controller.collectionView.setContentOffset(CGPoint(x: 0, y: next.minY - gap), animated: false)
                controller.collectionView.layoutIfNeeded()
                let top = controller.collectionView.bounds.minY
                // 塊に割れたグループでは、見せているのは上端を含む塊 (最後の塊) の見出しなので、
                // 透明にしていない見出しを塊によらず数える。
                let headers = supplementaryAttributes(ofKind: KsSupplementaryKind.groupHeader, in: controller)
                    .filter { $0.alpha > 0.01 }
                    .map(\.frame)
                guard headers.count >= 2 else {
                    XCTFail("件数 \(count) / 間隔 \(gap): 見出しが 2 つ見えていません (\(headers))")
                    continue
                }
                XCTAssertEqual(headers[1].minY, top + gap, accuracy: 0.5, "件数 \(count) / 間隔 \(gap): 次の見出しの位置")
                let expected = min(top, headers[1].minY - Self.headerHeight)
                XCTAssertEqual(
                    headers[0].minY,
                    expected,
                    accuracy: 0.5,
                    "件数 \(count) / 間隔 \(gap): 固定中の見出しが早く押し上げられ、上端に見出しの無い帯ができています (上端 \(top) / 見出し \(headers))"
                )
            }
        }
    }

    // 塊に割れたグループの見出しは、塊の境目をゆっくり、または速く通過する間、上端に 1 つだけ
    // 同じ位置・同じ横位置と幅で固定され続ける。透明にした塊の見出しは読み上げの対象から外れる。
    func test塊に割れたグループの見出しは塊の境目で1つの見出しとして固定される() async {
        let controller = makeController(
            rows: makeRows([("前", 30), ("大", 1_200), ("後", 30)]),
            layout: .list(rowSpacing: 8, headerItemSpacing: 6),
            padding: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        )
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(1_260, in: controller)
        XCTAssertEqual(sectionItemCounts(in: controller), [30, 500, 500, 200, 30])

        for boundary in [30 + 500, 30 + 1_000] {
            await scroll(toOffset: boundary - 8, in: controller)
            guard let row = itemFrames(in: controller, offsets: [boundary]).first else {
                XCTFail("塊の境目の項目 \(boundary) の位置を取得できませんでした")
                continue
            }
            for (label, step) in [("ゆっくり", CGFloat(2)), ("速く", CGFloat(45))] {
                var y = row.minY - 240
                while y <= row.minY + 240 {
                    controller.collectionView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
                    controller.collectionView.layoutIfNeeded()
                    assertSinglePinnedHeader(
                        in: controller,
                        width: Self.size.width - 16,
                        label: "境目 \(boundary) / \(label) / offset \(y)"
                    )
                    y += step
                }
            }
        }
    }

    // 固定を外した見出しの属性は書き換えない。compositional layout が決めた位置と透明度のまま返す。
    func test固定を外すと見出しの属性を書き換えない() async {
        let controller = makeController(
            rows: makeRows([("大", 1_200), ("小", 5)]),
            layout: .list(rowSpacing: 8, headerItemSpacing: 6),
            pinnedHeaders: false
        )
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(1_205, in: controller)
        await scroll(toOffset: 600, in: controller)

        guard let layout = controller.collectionView.collectionViewLayout as? KsCompositionalLayout else {
            XCTFail("エンジンのレイアウトではありません")
            return
        }
        XCTAssertNil(layout.groupHeaderPinning?(), "固定しないのに書き換えの材料があります")
        let original = layout.unadjustedGroupHeaderAttributes(section: 0)
        let returned = layout.layoutAttributesForSupplementaryView(
            ofKind: KsSupplementaryKind.groupHeader,
            at: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(returned?.frame, original?.frame)
        XCTAssertEqual(returned?.alpha, original?.alpha)
    }

    // MARK: - 回転とスクロール命令

    // 表示範囲の先頭にある項目 X が固定中の見出しに一部隠れていても、向きが変わった後は X を
    // 固定中の見出しのすぐ下の行に置き、見出しの裏に隠さない。塊の 2 つめにある項目で確かめる。
    func test回転後も表示範囲の先頭の項目を固定中の見出しのすぐ下に保つ() async {
        let controller = makeController(
            rows: makeRows([("前", 100), ("大", 1_200), ("後", 100)]),
            layout: .grid(columns: .fixed(portrait: 2, landscape: 4), rowSpacing: 8, headerItemSpacing: 6)
        )
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(1_400, in: controller)
        // 列数の最小公倍数 4 の倍数で区切るため、「大」は 500 / 500 / 200 の塊に割れる。
        XCTAssertEqual(sectionItemCounts(in: controller), [100, 500, 500, 200, 100])

        // X (グループ内の 600 件目) は縦 2 列・横 4 列のどちらでも行頭に置かれる。
        let anchor = 100 + 600
        await scroll(toOffset: anchor, in: controller)
        guard let row = itemFrames(in: controller, offsets: [anchor]).first else {
            XCTFail("項目 \(anchor) の位置を取得できませんでした")
            return
        }
        // X の上 10pt を固定中の見出しに隠した位置で回す。
        controller.collectionView.setContentOffset(
            CGPoint(x: 0, y: row.minY - Self.headerHeight + 10),
            animated: false
        )
        controller.collectionView.layoutIfNeeded()

        for size in [CGSize(width: 844, height: 390), Self.size] {
            rotate(hostView: window, controller: controller, to: size)
            let columns = size.width > size.height ? 4 : 2
            await waitUntil("\(columns) 列の並び", value: { () -> [CGFloat] in
                let frames = itemFrames(in: controller, offsets: [anchor, anchor + columns - 1, anchor + columns])
                return frames.map(\.minY)
            }) { (values: [CGFloat]) -> Bool in
                guard values.count == 3 else { return false }
                return abs(values[0] - values[1]) < 0.5 && values[2] > values[0] + 0.5
            }
            await waitUntil("先頭の項目 \(anchor) の位置 (\(columns) 列)", value: { () -> CGFloat? in
                controller.collectionView.layoutIfNeeded()
                let top = controller.collectionView.bounds.minY
                return itemFrames(in: controller, offsets: [anchor]).first.map { $0.minY - top }
            }) { (offset: CGFloat?) -> Bool in
                guard let offset else { return false }
                return abs(offset - controller.collectionView.safeAreaInsets.top - Self.headerHeight) < 1
            }
            assertSinglePinnedHeader(in: controller, width: size.width, label: "\(columns) 列")
        }
    }

    // ID へのスクロール命令で先頭へ送る項目は、そのグループの固定中の見出しのすぐ下に置かれる。
    // 塊とグループをまたいでも解決し、末尾への命令は末尾の項目を表示範囲に入れる。
    func testIDによるスクロール命令は項目を固定中の見出しのすぐ下に置く() async {
        let scrollController = KsScrollController()
        var configuration = makeConfiguration(
            rows: makeRows([("前", 600), ("後", 1_200)]),
            layout: .list(rowSpacing: 8, headerItemSpacing: 6)
        )
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(1_800, in: controller)

        // 最後のグループの末尾の塊の項目と、最初のグループの 2 つめの塊の項目。
        for target in [600 + 1_100, 550] {
            scrollController.scrollTo(id: target, animated: false)
            await waitUntil("命令の処理 (\(target))", value: { controller.lastScrollTargetIdentifier }) {
                $0 == AnyHashable(target)
            }
            await settleLayout(in: controller)
            let top = controller.collectionView.bounds.minY
            guard let frame = itemFrames(in: controller, offsets: [target]).first else {
                XCTFail("項目 \(target) の位置を取得できませんでした")
                continue
            }
            XCTAssertEqual(
                frame.minY - top,
                controller.collectionView.safeAreaInsets.top + Self.headerHeight,
                accuracy: 1,
                "項目 \(target) が固定中の見出しのすぐ下にありません"
            )
            assertSinglePinnedHeader(in: controller, width: Self.size.width, label: "項目 \(target)")
        }

        scrollController.scrollToEnd(animated: false)
        await waitUntil("末尾命令の処理", value: { controller.lastScrollTargetIdentifier }) {
            $0 == AnyHashable(1_799)
        }
        await settleLayout(in: controller)
        let bounds = controller.collectionView.bounds
        guard let last = itemFrames(in: controller, offsets: [1_799]).first else {
            XCTFail("末尾の項目の位置を取得できませんでした")
            return
        }
        XCTAssertTrue(bounds.contains(last), "末尾の項目が表示範囲に入っていません (\(last) / \(bounds))")
    }

    // 見出しを固定しない構成では、先頭へ送る項目をずらさず表示範囲の上端に置く。
    func test固定しない見出しではスクロール命令で項目をずらさない() async {
        let scrollController = KsScrollController()
        var configuration = makeConfiguration(rows: makeRows([("前", 600), ("後", 600)]), pinnedHeaders: false)
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(1_200, in: controller)

        scrollController.scrollTo(id: 900, animated: false)
        await waitUntil("命令の処理", value: { controller.lastScrollTargetIdentifier }) { $0 == AnyHashable(900) }
        await settleLayout(in: controller)
        let top = controller.collectionView.bounds.minY
        guard let frame = itemFrames(in: controller, offsets: [900]).first else {
            XCTFail("項目の位置を取得できませんでした")
            return
        }
        XCTAssertEqual(frame.minY - top, 0, accuracy: 1, "固定しないのに項目をずらしています")
    }

    // MARK: - 見出しの内容の更新

    func test項目数が変わると見出しの内容を作り直さずに更新する() async {
        let recorder = HeaderRecorder()
        var rows = makeRows([("果物", 2), ("野菜", 2)])
        let controller = makeController(rows: rows, recorder: recorder)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(4, in: controller)
        await waitUntil("見出しの組み立て", value: { recorder.last(for: "果物") }) { $0 == [0, 1] }
        let hostedBefore = groupHeaderViews(in: controller).map { $0.hostedContentView.map(ObjectIdentifier.init) }

        rows.insert(Row(id: 100, group: "果物", title: "追加"), at: 2)
        controller.update(configuration: makeConfiguration(rows: rows, recorder: recorder))
        await waitForItems(5, in: controller)

        await waitUntil("更新後の見出し", value: { recorder.last(for: "果物") }) { $0 == [0, 1, 100] }
        let hostedAfter = groupHeaderViews(in: controller).map { $0.hostedContentView.map(ObjectIdentifier.init) }
        XCTAssertEqual(hostedAfter, hostedBefore, "見出しのビューが作り直されています")
    }

    // 件数は変えず、ID が同じまま内容 (title) だけが変わった項目も、表示中の見出しへ新しい内容で渡る。
    func test内容だけが変わった項目が見出しに渡る() async {
        var builds: [(group: String, titles: [String])] = []
        let rows = makeRows([("果物", 2), ("野菜", 2)])
        func configuration(_ rows: [Row]) -> KsCollectionConfiguration<Row> {
            KsCollectionView(rows) { row in RowView(row: row) }
                .groups(by: \.group) { group, rowsInGroup in
                    let _ = builds.append((group, rowsInGroup.map(\.title)))
                    HeaderView(text: group)
                }
                .configuration
        }
        let controller = KsCollectionViewController(configuration: configuration(rows))
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(4, in: controller)
        await waitUntil("見出しの組み立て", value: { builds.last { $0.group == "果物" }?.titles }) {
            $0 == ["果物 0", "果物 1"]
        }

        let renamed = rows.map { row in
            row.group == "果物" ? Row(id: row.id, group: row.group, title: "\(row.title) 改") : row
        }
        controller.update(configuration: configuration(renamed))

        await waitUntil("更新後の見出し", value: { builds.last { $0.group == "果物" }?.titles }) {
            $0 == ["果物 0 改", "果物 1 改"]
        }
    }

    // グループの宣言、または見出しの宣言を外す更新では、消えていく見出しは前の中身のままフェードする。
    // 差分の適用より前に中身を外すと、帯と文字がフェードを待たずに消える。
    func testグループの宣言を外しても消えていく見出しの中身を先に外さない() async {
        let rows = makeRows([("果物", 2), ("野菜", 2)])
        let withoutGrouping = KsCollectionView(rows) { row in RowView(row: row) }.configuration
        let withoutHeader = KsCollectionView(rows) { row in RowView(row: row) }
            .groups(by: \.group)
            .configuration
        for (label, next) in [("グループの宣言", withoutGrouping), ("見出しの宣言", withoutHeader)] {
            let controller = makeController(rows: rows)
            let window = show(controller)
            defer { window.isHidden = true }
            await waitForItems(4, in: controller)
            await settleLayout(in: controller)
            let headers = groupHeaderViews(in: controller)
            XCTAssertEqual(headers.count, 2, "\(label): 見出しが表示されていません")
            XCTAssertTrue(headers.allSatisfy { $0.hostedContentView != nil })

            controller.update(configuration: next)

            // 構成を渡した時点 (フェードの前) では、表示中の見出しは中身を保っている。
            XCTAssertTrue(
                headers.allSatisfy { $0.hostedContentView != nil },
                "\(label)を外した更新で、消えていく見出しの中身がフェードの前に外れています"
            )
            await settleLayout(in: controller)
            XCTAssertTrue(groupHeaderFrames(in: controller).isEmpty, "\(label)を外したのに見出しが残っています")
        }
    }

    func test観測する値が変わると表示中の見出しを描き直す() async {
        let recorder = HeaderRecorder()
        let box = SelectionBox()
        let rows = makeRows([("果物", 2), ("野菜", 2)])
        var configuration = makeConfiguration(rows: rows, recorder: recorder) { group in
            "\(group) 選択: \(box.selected)"
        }
        configuration.observedValue = AnyHashable(box.selected)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(4, in: controller)
        await waitUntil("見出しの組み立て", value: { recorder.builds.count }) { $0 >= 2 }

        // 観測する値が同じ更新では描き直さない。
        let buildsBefore = recorder.builds.count
        controller.update(configuration: configuration)
        XCTAssertEqual(recorder.builds.count, buildsBefore, "観測する値が同じなのに見出しを描き直しています")

        box.selected = "野菜"
        configuration.observedValue = AnyHashable(box.selected)
        controller.update(configuration: configuration)
        XCTAssertGreaterThanOrEqual(
            recorder.builds.count,
            buildsBefore + 2,
            "観測する値が変わったのに表示中の見出しを描き直していません"
        )
    }

    // MARK: - 差分

    func test項目のグループの値を変えると新しいグループへ移りセルを作り直さない() async {
        let recorder = HeaderRecorder()
        var rows = makeRows([("果物", 3), ("野菜", 3)])
        let controller = makeController(rows: rows, recorder: recorder)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)
        let cellBefore = cell(at: 1, in: controller).map(ObjectIdentifier.init)
        XCTAssertNotNil(cellBefore)

        // 項目 1 を「野菜」へ移し、データ層で並べ直した配列を渡す。
        let moved = Row(id: 1, group: "野菜", title: rows[1].title)
        rows.remove(at: 1)
        rows.insert(moved, at: 2)
        controller.update(configuration: makeConfiguration(rows: rows, recorder: recorder))

        await waitUntil("移動後の塊", value: { sectionItemCounts(in: controller) }) { $0 == [2, 4] }
        XCTAssertEqual(controller.appliedItemIdentifiers, [0, 2, 1, 3, 4, 5].map { AnyHashable($0) })
        await waitUntil("移動後の見出し", value: { recorder.last(for: "野菜") }) { $0 == [1, 3, 4, 5] }
        await settleLayout(in: controller)
        XCTAssertEqual(
            cell(at: 2, in: controller).map(ObjectIdentifier.init),
            cellBefore,
            "別のグループへ移った項目のセルが作り直されています"
        )
    }

    func testグループの並び順を反転すると見出しが項目と一緒に動く() async {
        let rows = makeRows([("果物", 2), ("野菜", 2)])
        let controller = makeController(rows: rows)
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(4, in: controller)
        await settleLayout(in: controller)
        let cellsBefore = Dictionary(uniqueKeysWithValues: (0..<4).compactMap { offset in
            cell(at: offset, in: controller).map { (controller.appliedItemIdentifiers[offset], ObjectIdentifier($0)) }
        })

        let reversed = Array(rows[2...]) + Array(rows[..<2])
        controller.update(configuration: makeConfiguration(rows: reversed))

        await waitUntil("反転後の塊", value: { controller.appliedSectionIdentifiers.map(\.group) }) {
            $0 == ["野菜", "果物"].map { AnyHashable($0) }
        }
        await settleLayout(in: controller)
        let headers = groupHeaderIndexPathsAndFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: [0, 2])
        guard headers.count == 2, frames.count == 2 else {
            XCTFail("反転後のレイアウト属性を取得できませんでした")
            return
        }
        // 野菜の見出しと項目が先に、果物の見出しと項目が後に並ぶ。
        XCTAssertEqual(headers.map(\.indexPath.section), [0, 1])
        XCTAssertLessThanOrEqual(headers[0].frame.maxY, frames[0].minY + 0.5)
        XCTAssertLessThanOrEqual(headers[1].frame.maxY, frames[1].minY + 0.5)
        XCTAssertGreaterThanOrEqual(headers[1].frame.minY, frames[0].maxY - 0.5)
        // 並べ替えの前後とも可視範囲にある項目のセルは作り直されない。
        for offset in 0..<4 {
            let identifier = controller.appliedItemIdentifiers[offset]
            XCTAssertEqual(
                cell(at: offset, in: controller).map(ObjectIdentifier.init),
                cellsBefore[identifier],
                "項目 \(identifier) のセルが作り直されています"
            )
        }
    }

    func test最後の項目が消えたグループは見出しごと消える() async {
        var rows = makeRows([("果物", 2), ("肉", 1), ("野菜", 2)])
        let controller = makeController(rows: rows)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)
        await settleLayout(in: controller)
        XCTAssertEqual(groupHeaderFrames(in: controller).count, 3)

        rows.removeAll { $0.group == "肉" }
        controller.update(configuration: makeConfiguration(rows: rows))

        await waitUntil("肉の消滅", value: { controller.appliedSectionIdentifiers.map(\.group) }) {
            $0 == ["果物", "野菜"].map { AnyHashable($0) }
        }
        await settleLayout(in: controller)
        XCTAssertEqual(groupHeaderFrames(in: controller).count, 2, "消えたグループの見出しが残っています")
    }

    // MARK: - グループの値の取り出し方の差し替え

    func test同じ配列のまま取り出し方を切り替えると新しいグループの構成で表示する() async {
        let recorder = HeaderRecorder()
        let rows = makeRows([("果物", 2), ("野菜", 3)])
        let controller = makeController(rows: rows, recorder: recorder)
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)
        await settleLayout(in: controller)
        XCTAssertEqual(sectionItemCounts(in: controller), [2, 3])
        let buildsBefore = recorder.builds.count

        controller.update(configuration: makeConfiguration(rows: rows, groupBy: \.half, recorder: recorder))

        await waitUntil("組み直した塊", value: { controller.appliedSectionIdentifiers.map(\.group) }) {
            $0 == ["前半", "後半"].map { AnyHashable($0) }
        }
        XCTAssertEqual(sectionItemCounts(in: controller), [3, 2])
        await waitUntil("組み直した見出し", value: {
            [recorder.last(for: "前半"), recorder.last(for: "後半")]
        }) { $0 == [[0, 1, 2], [3, 4]] }
        await settleLayout(in: controller)
        // 切り替え以降の見出しの組み立ては、すべて新しいグループの値と新しい範囲の組でなければならない。
        // 古い範囲に新しいグループの値を当てた組み立てがあると、消えていく古い見出しに新しい名前が出る。
        let buildsAfter = recorder.builds.dropFirst(buildsBefore)
        let expected: [String: [Int]] = ["前半": [0, 1, 2], "後半": [3, 4]]
        for build in buildsAfter {
            XCTAssertEqual(expected[build.group], build.ids, "古い範囲で見出しを組み立てています: \(build)")
        }

        // 見出しは新しい境目 (項目 2 と 3 の間) に置かれる。
        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: [0, 2, 3])
        XCTAssertEqual(headers.count, 2, "見出しの数が新しいグループの数と違います")
        guard headers.count == 2, frames.count == 3 else { return }
        XCTAssertLessThanOrEqual(headers[0].maxY, frames[0].minY + 0.5)
        XCTAssertGreaterThanOrEqual(headers[1].minY, frames[1].maxY - 0.5, "見出しが古い境目に残っています")
        XCTAssertLessThanOrEqual(headers[1].maxY, frames[2].minY + 0.5, "見出しが古い境目に残っています")
    }

    func test同じグループの値を返す別の取り出し方に差し替えても組み直さない() async {
        let recorder = HeaderRecorder()
        let rows = makeRows([("果物", 2), ("野菜", 3)])
        let controller = makeController(rows: rows, recorder: recorder)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(5, in: controller)
        await settleLayout(in: controller)
        let sectionsBefore = controller.appliedSectionIdentifiers
        let appliesBefore = controller.snapshotApplyCount
        let buildsBefore = recorder.builds.count

        controller.update(configuration: makeConfiguration(rows: rows, groupBy: \.groupAlias, recorder: recorder))
        await settleLayout(in: controller)

        // 塊を組み直さない場合も、表示中の見出しは新しい宣言で組み立て直される。
        let buildsAfter = recorder.builds.dropFirst(buildsBefore)
        XCTAssertFalse(buildsAfter.isEmpty, "取り出し方を差し替えたのに見出しを組み立て直していません")
        let expected: [String: [Int]] = ["果物": [0, 1], "野菜": [2, 3, 4]]
        for build in buildsAfter {
            XCTAssertEqual(expected[build.group], build.ids, "見出しの組み立てが構成と食い違っています: \(build)")
        }

        // 同じ取り出し方のままの更新も、もちろん組み直さない。
        controller.update(configuration: makeConfiguration(rows: rows, groupBy: \.groupAlias, recorder: recorder))
        await settleLayout(in: controller)

        XCTAssertEqual(controller.snapshotApplyCount, appliesBefore, "グループの値が同じなのに組み直しています")
        XCTAssertEqual(controller.appliedSectionIdentifiers, sectionsBefore)
    }

    // 最初のグループの先頭へ挿入しても、後ろのグループの塊は組み直されず、表示範囲の先頭の項目は飛ばない。
    func testグループをまたぐ挿入で後ろのグループの項目の位置が飛ばない() async {
        var rows = makeRows([("前", 600), ("後", 600)])
        let controller = makeController(rows: rows, pinnedHeaders: false)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(1_200, in: controller)
        XCTAssertEqual(sectionItemCounts(in: controller), [500, 100, 500, 100])

        let anchorOffset = 900
        await scroll(toOffset: anchorOffset, in: controller)
        let anchor = controller.appliedItemIdentifiers[anchorOffset]
        guard
            let before = itemFrames(in: controller, offsets: [anchorOffset]).first,
            let cellBefore = cell(at: anchorOffset, in: controller).map(ObjectIdentifier.init)
        else {
            XCTFail("挿入前の項目 \(anchorOffset) を取得できませんでした")
            return
        }
        let offsetBefore = before.minY - controller.collectionView.bounds.minY
        let sectionsBefore = controller.appliedSectionIdentifiers

        rows.insert(Row(id: 10_000, group: "前", title: "挿入"), at: 0)
        controller.update(configuration: makeConfiguration(rows: rows))
        await waitForItems(1_201, in: controller)
        controller.collectionView.layoutIfNeeded()

        // 後ろのグループの塊は識別子も件数も変わらない。
        XCTAssertEqual(
            Array(controller.appliedSectionIdentifiers.suffix(2)),
            Array(sectionsBefore.suffix(2)),
            "後ろのグループの塊が組み直されています"
        )
        let newOffset = anchorOffset + 1
        XCTAssertEqual(controller.appliedItemIdentifiers[newOffset], anchor)
        guard let after = itemFrames(in: controller, offsets: [newOffset]).first else {
            XCTFail("挿入後の項目の位置を取得できませんでした")
            return
        }
        let offsetAfter = after.minY - controller.collectionView.bounds.minY
        XCTAssertLessThanOrEqual(
            abs(offsetAfter - offsetBefore),
            Self.rowHeight + 2,
            "挿入した 1 行を超えて位置が飛んでいます (前 \(offsetBefore) / 後 \(offsetAfter))"
        )
        XCTAssertEqual(
            cell(at: newOffset, in: controller).map(ObjectIdentifier.init),
            cellBefore,
            "後ろのグループの項目のセルが作り直されています"
        )
    }

    // MARK: - 不正入力

    // 間隔の負の値は不正入力。release では警告を残し、0 として表示を続ける。
    func testReleaseでは負の間隔を0として表示し警告する() async {
        KsInvalidInput.assertsInDebug = false
        let controller = makeController(
            rows: makeRows([("果物", 3), ("野菜", 3)]),
            layout: .list(rowSpacing: -4, groupSpacing: -10, headerItemSpacing: -6)
        )
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)

        let headers = groupHeaderFrames(in: controller)
        let frames = itemFrames(in: controller, offsets: Array(0..<6))
        guard headers.count == 2, frames.count == 6 else {
            XCTFail("レイアウト属性を取得できませんでした (\(headers.count) / \(frames.count))")
            return
        }
        XCTAssertEqual(frames[0].minY - headers[0].maxY, 0, accuracy: 0.5, "見出しの下の間隔が 0 になっていません")
        XCTAssertEqual(frames[1].minY - frames[0].maxY, 0, accuracy: 0.5, "行間が 0 になっていません")
        XCTAssertEqual(headers[1].minY - frames[2].maxY, 0, accuracy: 0.5, "グループ間の間隔が 0 になっていません")
        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, 1, "警告が記録されていません")
        let warning = KsInvalidInput.reportedWarnings.first ?? ""
        for name in ["rowSpacing", "groupSpacing", "headerItemSpacing"] {
            XCTAssertTrue(warning.contains(name), "警告に \(name) がありません (\(warning))")
        }
        XCTAssertFalse(warning.contains("columnSpacing"), "指定していない間隔を警告しています (\(warning))")
    }

    func testReleaseでは離れた同じグループの値を別々のグループとして表示し警告する() async {
        KsInvalidInput.assertsInDebug = false
        let rows = [
            Row(id: 0, group: "果物", title: "りんご"),
            Row(id: 1, group: "野菜", title: "にんじん"),
            Row(id: 2, group: "果物", title: "みかん"),
        ]
        let controller = makeController(rows: rows)
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(3, in: controller)

        XCTAssertEqual(controller.appliedItemIdentifiers, [0, 1, 2].map { AnyHashable($0) }, "項目の並びが変わっています")
        XCTAssertEqual(
            controller.appliedSectionIdentifiers,
            [
                KsSectionID(group: "果物", occurrence: 0, chunkInGroup: 0),
                KsSectionID(group: "野菜", occurrence: 0, chunkInGroup: 0),
                KsSectionID(group: "果物", occurrence: 1, chunkInGroup: 0),
            ]
        )
        await settleLayout(in: controller)
        XCTAssertEqual(groupHeaderFrames(in: controller).count, 3)
        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, 1, "警告が記録されていません")
        XCTAssertTrue(KsInvalidInput.reportedWarnings.first?.contains("果物") ?? false)
    }

    // MARK: - 部品

    // 表示範囲の上端に、見えている (透明でない) グループの見出しが 1 つだけ固定されていることを確かめる。
    // 横位置と幅は左の内側余白と全幅に揃い、他の見出しのビューは透明で読み上げの対象から外れている。
    private func assertSinglePinnedHeader(
        in controller: KsCollectionViewController<Row>,
        width: CGFloat,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // 固定中の見出しは表示範囲の上端に、上端の安全領域に重なる分を足した位置 (安全領域の境目) に止まる。
        let top = controller.collectionView.bounds.minY + controller.collectionView.safeAreaInsets.top
        let padding = (controller.collectionView.bounds.width - width) / 2
        let visible = supplementaryAttributes(ofKind: KsSupplementaryKind.groupHeader, in: controller)
            .filter { $0.alpha > 0.01 && $0.frame.minY <= top + 0.5 && $0.frame.maxY > top }
        XCTAssertEqual(visible.count, 1, "上端の見出しが 1 つではありません (\(label))", file: file, line: line)
        guard let header = visible.first else { return }
        XCTAssertEqual(header.frame.minY, top, accuracy: 0.5, "見出しが上端から動いています (\(label))", file: file, line: line)
        XCTAssertEqual(header.frame.minX, padding, accuracy: 0.5, "見出しが横にずれています (\(label))", file: file, line: line)
        XCTAssertEqual(header.frame.width, width, accuracy: 0.5, "見出しの幅が変わっています (\(label))", file: file, line: line)
        XCTAssertEqual(header.alpha, 1, accuracy: 0.001, "見出しが薄れています (\(label))", file: file, line: line)

        // 表示中の見出しのビューのうち読み上げの対象は、上端を覆う 1 つだけ。
        let views = controller.collectionView
            .visibleSupplementaryViews(ofKind: KsSupplementaryKind.groupHeader)
        let spoken = views.filter { !$0.accessibilityElementsHidden && $0.frame.minY <= top + 0.5 && $0.frame.maxY > top }
        XCTAssertEqual(spoken.count, 1, "上端で読み上げの対象になる見出しが 1 つではありません (\(label))", file: file, line: line)
        for view in views where view.alpha < 0.01 {
            XCTAssertTrue(view.accessibilityElementsHidden, "透明な見出しが読み上げの対象です (\(label))", file: file, line: line)
        }
    }

    // 表示先の大きさを変える。向きが変わるときと同じく、frame を差し替える前に
    // viewWillTransition(to:with:) を通す。
    private func rotate(hostView: UIView, controller: UIViewController, to size: CGSize) {
        controller.viewWillTransition(to: size, with: KsTransitionCoordinatorStub(containerView: hostView))
        hostView.frame = CGRect(origin: .zero, size: size)
        controller.view.frame = hostView.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    private struct RowView: View {
        let row: Row

        var body: some View {
            Text(row.title)
                .frame(
                    maxWidth: .infinity,
                    minHeight: row.height ?? KsGroupingEngineTests.rowHeight,
                    maxHeight: row.height ?? KsGroupingEngineTests.rowHeight
                )
        }
    }

    private struct HeaderView: View {
        let text: String

        var body: some View {
            Text(text)
                .frame(
                    maxWidth: .infinity,
                    minHeight: KsGroupingEngineTests.headerHeight,
                    maxHeight: KsGroupingEngineTests.headerHeight
                )
                .background(Color.gray)
        }
    }

    private struct FixedHeightView: View {
        let text: String
        let height: CGFloat

        var body: some View {
            Text(text).frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
    }

    // グループごとの件数から、ID が 0 から続く配列を作る。
    private func makeRows(_ groups: [(String, Int)]) -> [Row] {
        var rows: [Row] = []
        for (group, count) in groups {
            for _ in 0..<count {
                rows.append(Row(id: rows.count, group: group, title: "\(group) \(rows.count)"))
            }
        }
        return rows
    }

    private func makeConfiguration(
        rows: [Row],
        layout: KsCollectionLayout = .list,
        padding: EdgeInsets = EdgeInsets(),
        pinnedHeaders: Bool = true,
        showsSeparators: Bool = false,
        groupBy: KeyPath<Row, String> = \.group,
        recorder: HeaderRecorder? = nil,
        headerText: @escaping (String) -> String = { $0 }
    ) -> KsCollectionConfiguration<Row> {
        var configuration = KsCollectionView(rows, layout: layout, contentPadding: padding) { row in
            RowView(row: row)
        }
        .groups(by: groupBy, pinnedHeaders: pinnedHeaders) { group, rowsInGroup in
            let _ = recorder?.record(group, rowsInGroup)
            HeaderView(text: headerText(group))
        }
        .configuration
        configuration.showsSeparators = showsSeparators
        return configuration
    }

    private func makeController(
        rows: [Row],
        layout: KsCollectionLayout = .list,
        padding: EdgeInsets = EdgeInsets(),
        pinnedHeaders: Bool = true,
        showsSeparators: Bool = false,
        recorder: HeaderRecorder? = nil
    ) -> KsCollectionViewController<Row> {
        KsCollectionViewController(
            configuration: makeConfiguration(
                rows: rows,
                layout: layout,
                padding: padding,
                pinnedHeaders: pinnedHeaders,
                showsSeparators: showsSeparators,
                recorder: recorder
            )
        )
    }

    private func show(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    // ウインドウの安全領域の内側に載せる (一覧が安全領域に重ならない普通の置き方)。見出しの固定が
    // 安全領域の境目で止まる分を除いて、見出しの本来の位置と間隔を測るときに使う。
    private func showInsideSafeArea(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.loadViewIfNeeded()
        root.view.layoutIfNeeded()
        let safeArea = window.safeAreaInsets
        root.addChild(controller)
        controller.view.frame = CGRect(
            x: 0,
            y: safeArea.top,
            width: Self.size.width,
            height: Self.size.height - safeArea.top - safeArea.bottom
        )
        root.view.addSubview(controller.view)
        controller.didMove(toParent: root)
        controller.view.layoutIfNeeded()
        return window
    }

    private func waitForItems(_ count: Int, in controller: KsCollectionViewController<Row>) async {
        await waitUntil("\(count) 件の snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == count }
        controller.collectionView.layoutIfNeeded()
    }

    // 自己サイズの解き直しが止まり、内容の高さが動かなくなるまで待つ。
    private func settleLayout(in controller: KsCollectionViewController<Row>) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        var lastHeight = controller.collectionView.contentSize.height
        var quietSince = clock.now
        while clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            controller.collectionView.layoutIfNeeded()
            let height = controller.collectionView.contentSize.height
            if height != lastHeight {
                lastHeight = height
                quietSince = clock.now
            } else if clock.now - quietSince >= .milliseconds(150) {
                return
            }
        }
        XCTFail("内容の高さが期限内に静止しませんでした。実測値: \(lastHeight)")
    }

    // 指定した項目を表示範囲の先頭へ送り、レイアウトが落ち着くまで待つ。
    private func scroll(toOffset offset: Int, in controller: KsCollectionViewController<Row>) async {
        for _ in 0..<3 {
            controller.collectionView.scrollToItem(
                at: ksIndexPath(forItemOffset: offset, in: controller.collectionView),
                at: .top,
                animated: false
            )
            controller.collectionView.layoutIfNeeded()
            await settleLayout(in: controller)
        }
    }

    private func sectionItemCounts(in controller: KsCollectionViewController<Row>) -> [Int] {
        (0..<controller.collectionView.numberOfSections).map {
            controller.collectionView.numberOfItems(inSection: $0)
        }
    }

    private func itemFrames(in controller: KsCollectionViewController<Row>, offsets: [Int]) -> [CGRect] {
        offsets.compactMap { offset in
            guard let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView) else {
                return nil
            }
            return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
        }
    }

    private func cell(at offset: Int, in controller: KsCollectionViewController<Row>) -> KsHostingCell? {
        guard let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView) else {
            return nil
        }
        return controller.collectionView.cellForItem(at: indexPath) as? KsHostingCell
    }

    // 表示範囲に載っている、指定した種類の補助ビューのレイアウト属性 (上から順)。
    private func supplementaryAttributes(
        ofKind kind: String,
        in controller: KsCollectionViewController<Row>
    ) -> [UICollectionViewLayoutAttributes] {
        controller.collectionView.layoutIfNeeded()
        let rect = controller.collectionView.bounds
        return (controller.collectionView.collectionViewLayout.layoutAttributesForElements(in: rect) ?? [])
            .filter { $0.representedElementKind == kind }
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    private func supplementaryFrames(
        ofKind kind: String,
        in controller: KsCollectionViewController<Row>
    ) -> [CGRect] {
        supplementaryAttributes(ofKind: kind, in: controller).map(\.frame)
    }

    // 表示範囲に載っているグループの見出しの矩形 (上から順)。塊に割れたグループの 2 つめ以降の
    // 見出しは場所を取らず先頭の行に重なるため、場所を取る見出し (グループの先頭の塊の見出し) だけを数える。
    private func groupHeaderFrames(in controller: KsCollectionViewController<Row>) -> [CGRect] {
        groupHeaderIndexPathsAndFrames(in: controller).map(\.frame)
    }

    private func groupHeaderIndexPathsAndFrames(
        in controller: KsCollectionViewController<Row>
    ) -> [(indexPath: IndexPath, frame: CGRect, alpha: CGFloat)] {
        let firstChunkSections = Set(
            controller.appliedSectionIdentifiers.enumerated()
                .filter { $0.element.chunkInGroup == 0 }
                .map(\.offset)
        )
        return supplementaryAttributes(ofKind: KsSupplementaryKind.groupHeader, in: controller)
            .filter { firstChunkSections.contains($0.indexPath.section) }
            .map { ($0.indexPath, $0.frame, $0.alpha) }
    }

    // 表示範囲に載っているグループの見出しの位置 (塊の見出しを含む)。
    private func groupHeaderIndexPaths(in controller: KsCollectionViewController<Row>) -> [IndexPath] {
        supplementaryAttributes(ofKind: KsSupplementaryKind.groupHeader, in: controller).map(\.indexPath)
    }

    // 固定の影響を受けない、グループの見出しの本来の位置。グループの先頭の項目の上に見出しの高さ分で置かれる。
    private func unpinnedGroupHeaderFrame(
        groupIndex: Int,
        in controller: KsCollectionViewController<Row>
    ) -> CGRect? {
        let sections = controller.appliedSectionIdentifiers.enumerated().filter { $0.element.chunkInGroup == 0 }
        guard sections.indices.contains(groupIndex) else { return nil }
        let section = sections[groupIndex].offset
        guard let first = controller.collectionView.collectionViewLayout
            .layoutAttributesForItem(at: IndexPath(item: 0, section: section))?.frame else {
            return nil
        }
        return CGRect(x: first.minX, y: first.minY - Self.headerHeight, width: first.width, height: Self.headerHeight)
    }

    private func groupHeaderViews(in controller: KsCollectionViewController<Row>) -> [KsHostingSupplementaryView] {
        controller.collectionView.indexPathsForVisibleSupplementaryElements(ofKind: KsSupplementaryKind.groupHeader)
            .sorted()
            .compactMap {
                controller.collectionView.supplementaryView(
                    forElementKind: KsSupplementaryKind.groupHeader,
                    at: $0
                ) as? KsHostingSupplementaryView
            }
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(3)
        while clock.now < deadline {
            let current = value()
            if predicate(current) {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail(
            "\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))",
            file: file,
            line: line
        )
    }
}
#endif
