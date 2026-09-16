import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

@MainActor
final class KsCollectionEngineTests: XCTestCase {
    private struct Item: Identifiable, Equatable {
        let id: Int
        let title: String
    }

    private final class BuildRecorder {
        private(set) var counts: [Int: Int] = [:]

        func record(_ id: Int) -> Int {
            let count = counts[id, default: 0] + 1
            counts[id] = count
            return count
        }
    }

    // セル内に置く操作要素。アクセシビリティ設定に依存せず `UIControl` として判定させるために UIKit の
    // ボタンを使う (SwiftUI の Button を実座標でタップする経路は Sample の UI テストが担う)。
    private struct ControlRow: UIViewRepresentable {
        let onTap: () -> Void

        func makeUIView(context: Context) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle("子操作", for: .normal)
            button.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
            return button
        }

        func updateUIView(_ uiView: UIButton, context: Context) {}
    }

    // 固定高と可変行高が 6 : 1 で混ざる行。7 件ごとに長文が付く (Sample「大量件数」と同じ混ざり方)。
    private struct MixedHeightRow: View {
        let item: Item

        private var detail: String? {
            item.id.isMultiple(of: 7)
                ? "可変行高を確認するための固定シード長文データ \(item.id) — KsCollectionView"
                : nil
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // どの項目でも同じ高さになる行。
    private struct UniformHeightRow: View {
        let item: Item

        var body: some View {
            Text(item.title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    // 偶数番だけに長文が付く行。2 列に並べると各行の片方だけが高くなる。
    private struct AlternatingHeightRow: View {
        let item: Item

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                if item.id.isMultiple(of: 2) {
                    Text("可変行高を確認するための固定シード長文データ \(item.id) — KsCollectionView")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private final class PrefetchRecorder: KsPrefetching {
        var prefetched: [Item] = []
        var cancelled: [Item] = []

        func prefetch(items: [Item]) {
            prefetched = items
        }

        func cancelPrefetching(items: [Item]) {
            cancelled = items
        }
    }

    func test100件をdataSourceへ反映する() async {
        let items = (0..<100).map { Item(id: $0, title: "項目 \($0)") }
        let controller = KsCollectionViewController(configuration: makeConfiguration(items: items))
        controller.loadViewIfNeeded()

        await waitUntil("data source 件数", value: { controller.collectionView.numberOfItems(inSection: 0) }) {
            $0 == 100
        }

        XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), 100)
    }

    func test初回表示前にセル登録を準備して再利用セルを生成する() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let controller = KsCollectionViewController(configuration: makeConfiguration(items: items))
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitUntil("可視セル", value: { controller.collectionView.visibleCells.count }) {
            $0 > 0
        }

        XCTAssertFalse(controller.collectionView.visibleCells.isEmpty)
    }

    func test選択時に型付き項目を通知する() async {
        let item = Item(id: 7, title: "選択対象")
        var tapped: Item?
        var configuration = makeConfiguration(items: [item])
        configuration.onItemTap = { tapped = $0 }
        let controller = KsCollectionViewController(configuration: configuration)
        controller.loadViewIfNeeded()
        await waitUntil("data source 件数", value: { controller.collectionView.numberOfItems(inSection: 0) }) {
            $0 == 1
        }

        controller.collectionView(
            controller.collectionView,
            didSelectItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(tapped, item)
    }

    func testデータ差し替えとレイアウト切り替えを同じControllerへ適用する() async {
        let initial = (0..<20).map { Item(id: $0, title: "項目 \($0)") }
        let controller = KsCollectionViewController(configuration: makeConfiguration(items: initial))
        controller.loadViewIfNeeded()
        await waitUntil("初期 data source 件数", value: { controller.collectionView.numberOfItems(inSection: 0) }) {
            $0 == 20
        }

        let updated = (10..<40).map { Item(id: $0, title: "更新 \($0)") }
        var configuration = makeConfiguration(items: updated)
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)
        controller.update(configuration: configuration)
        await waitUntil("更新後 data source 件数", value: { controller.collectionView.numberOfItems(inSection: 0) }) {
            $0 == 30
        }

        XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), 30)
    }

    func testリスト区切り線を全幅で先頭と行間に表示し即時に切り替える() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitUntil("3 行の可視セル", value: { controller.collectionView.visibleCells.count }) {
            $0 == 3
        }

        let first = tryUnwrapCell(controller, item: 0)
        let middle = tryUnwrapCell(controller, item: 1)
        let last = tryUnwrapCell(controller, item: 2)
        controller.collectionView.layoutIfNeeded()
        [first, middle, last].forEach {
            $0.setNeedsLayout()
            $0.layoutIfNeeded()
            $0.contentView.layoutIfNeeded()
        }

        XCTAssertTrue(first.isTopSeparatorVisible)
        XCTAssertTrue(first.isBottomSeparatorVisible)
        XCTAssertFalse(middle.isTopSeparatorVisible)
        XCTAssertTrue(middle.isBottomSeparatorVisible)
        XCTAssertFalse(last.isTopSeparatorVisible)
        XCTAssertTrue(last.isBottomSeparatorVisible)
        XCTAssertEqual(first.topSeparatorFrame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(first.topSeparatorFrame.width, first.bounds.width, accuracy: 0.5)
        XCTAssertEqual(first.topSeparatorFrame.height, 1, accuracy: 0.01)
        XCTAssertEqual(middle.bottomSeparatorFrame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(middle.bottomSeparatorFrame.width, middle.bounds.width, accuracy: 0.5)
        XCTAssertEqual(middle.bottomSeparatorFrame.height, 1, accuracy: 0.01)
        XCTAssertEqual(last.bottomSeparatorFrame.maxY, last.bounds.height, accuracy: 0.5)
        XCTAssertGreaterThan(first.separatorZPosition, first.contentViewZPosition)
        XCTAssertEqual(first.topSeparatorColor, KsHostingCell.defaultSeparatorColor)
        XCTAssertEqual(first.bottomSeparatorColor, KsHostingCell.defaultSeparatorColor)
        let separatorsOnImage = renderedImageData(of: first)

        configuration.showsSeparators = false
        controller.update(configuration: configuration)
        XCTAssertTrue([first, middle, last].allSatisfy {
            !$0.isTopSeparatorVisible && !$0.isBottomSeparatorVisible
        })
        XCTAssertNotEqual(separatorsOnImage, renderedImageData(of: first))

        configuration.showsSeparators = true
        controller.update(configuration: configuration)
        XCTAssertTrue(first.isTopSeparatorVisible)
        XCTAssertTrue(first.isBottomSeparatorVisible)
    }

    func test区切り線の色を指定すると位置と本数を変えずにその色で描く() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        configuration.separatorColor = .systemPink
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitForVisibleItemCount(3, in: controller)

        let first = tryUnwrapCell(controller, item: 0)
        let middle = tryUnwrapCell(controller, item: 1)
        let last = tryUnwrapCell(controller, item: 2)
        controller.collectionView.layoutIfNeeded()
        [first, middle, last].forEach {
            $0.setNeedsLayout()
            $0.layoutIfNeeded()
        }

        // 中間行・最終行で実際に見えるのは下端の線なので、上端と下端の両方の色を確かめる。
        XCTAssertEqual(first.topSeparatorColor, UIColor.systemPink)
        XCTAssertEqual(first.bottomSeparatorColor, UIColor.systemPink)
        XCTAssertEqual(middle.topSeparatorColor, UIColor.systemPink)
        XCTAssertEqual(middle.bottomSeparatorColor, UIColor.systemPink)
        XCTAssertEqual(last.topSeparatorColor, UIColor.systemPink)
        XCTAssertEqual(last.bottomSeparatorColor, UIColor.systemPink)
        XCTAssertTrue(first.isTopSeparatorVisible)
        XCTAssertTrue(first.isBottomSeparatorVisible)
        XCTAssertFalse(middle.isTopSeparatorVisible)
        XCTAssertTrue(middle.isBottomSeparatorVisible)
        XCTAssertFalse(last.isTopSeparatorVisible)
        XCTAssertTrue(last.isBottomSeparatorVisible)
        XCTAssertEqual(first.topSeparatorFrame.width, first.bounds.width, accuracy: 0.5)
        XCTAssertEqual(first.topSeparatorFrame.height, 1, accuracy: 0.01)

        configuration.separatorColor = nil
        controller.update(configuration: configuration)
        XCTAssertEqual(first.topSeparatorColor, KsHostingCell.defaultSeparatorColor)
        XCTAssertEqual(first.bottomSeparatorColor, KsHostingCell.defaultSeparatorColor)
        XCTAssertEqual(middle.bottomSeparatorColor, KsHostingCell.defaultSeparatorColor)
        XCTAssertEqual(last.bottomSeparatorColor, KsHostingCell.defaultSeparatorColor)
    }

    func test区切り線が非表示なら色を指定しても描かない() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        configuration.showsSeparators = false
        configuration.separatorColor = .systemPink
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitForVisibleItemCount(3, in: controller)

        let cells = (0..<3).map { tryUnwrapCell(controller, item: $0) }
        controller.collectionView.layoutIfNeeded()
        cells.forEach {
            $0.setNeedsLayout()
            $0.layoutIfNeeded()
        }
        XCTAssertTrue(cells.allSatisfy { !$0.isTopSeparatorVisible && !$0.isBottomSeparatorVisible })

        // 上端・下端のどちらの線も画素として現れないことを、色を外した描画との一致で確かめる。
        let middle = cells[1]
        let coloredImage = renderedImageData(of: middle)
        configuration.separatorColor = nil
        controller.update(configuration: configuration)
        middle.setNeedsLayout()
        middle.layoutIfNeeded()
        XCTAssertEqual(coloredImage, renderedImageData(of: middle))
    }

    func test挿入削除並べ替え後に区切り線の位置を再構成する() async {
        var configuration = makeConfiguration(items: [
            Item(id: 1, title: "A"),
            Item(id: 2, title: "B"),
            Item(id: 3, title: "C"),
        ])
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)

        configuration.items.insert(Item(id: 0, title: "先頭"), at: 0)
        controller.update(configuration: configuration)
        await settleAtStart(itemCount: 4, in: controller)
        assertSeparatorPositions(itemCount: 4, in: controller)

        configuration.items.removeFirst()
        controller.update(configuration: configuration)
        await settleAtStart(itemCount: 3, in: controller)
        assertSeparatorPositions(itemCount: 3, in: controller)

        configuration.items = [configuration.items[2], configuration.items[0], configuration.items[1]]
        controller.update(configuration: configuration)
        await waitUntil("並べ替え後の ID 順", value: { controller.appliedItemIdentifiers }) {
            $0 == [AnyHashable(3), AnyHashable(1), AnyHashable(2)]
        }
        await settleAtStart(itemCount: 3, in: controller)
        assertSeparatorPositions(itemCount: 3, in: controller)
    }

    func test表示中のheaderと動的件数footerを更新後に再構成する() async {
        var headerBuilds: [String] = []
        var footerBuilds: [Int] = []
        var configuration = makeConfiguration(items: [Item(id: 1, title: "A")])
        configuration.header = {
            headerBuilds.append("初期")
            return AnyView(Text("初期ヘッダー"))
        }
        configuration.footer = {
            footerBuilds.append(1)
            return AnyView(Text("全 1 件"))
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("header/footer 表示", value: {
            controller.collectionView.visibleSupplementaryViews(
                ofKind: UICollectionView.elementKindSectionHeader
            ).count + controller.collectionView.visibleSupplementaryViews(
                ofKind: UICollectionView.elementKindSectionFooter
            ).count
        }) { $0 == 2 }

        configuration.items.append(Item(id: 2, title: "B"))
        configuration.header = {
            headerBuilds.append("更新")
            return AnyView(Text("更新ヘッダー"))
        }
        configuration.footer = {
            footerBuilds.append(2)
            return AnyView(Text("全 2 件"))
        }
        controller.update(configuration: configuration)

        await waitUntil("supplementary 再構成", value: {
            headerBuilds.last == "更新" && footerBuilds.last == 2
        }) { $0 }
        XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), 2)
    }

    func test不透明な内容の上へ指定色のtouchFeedbackを表示して消す() async {
        let color = UIColor(red: 47 / 255, green: 111 / 255, blue: 237 / 255, alpha: 0.3)
        var configuration = makeConfiguration(items: [Item(id: 1, title: "A")]) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.white)
        }
        configuration.onItemTap = { _ in }
        configuration.touchFeedbackColor = color
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(1, in: controller)
        let cell = tryUnwrapCell(controller, item: 0)
        cell.layoutIfNeeded()
        let normalImage = renderedImageData(of: cell)

        controller.collectionView(controller.collectionView, didHighlightItemAt: IndexPath(item: 0, section: 0))
        cell.layoutIfNeeded()

        XCTAssertTrue(cell.isTouchFeedbackVisible)
        XCTAssertEqual(cell.touchFeedbackColor, color)
        XCTAssertGreaterThan(cell.touchFeedbackZPosition, cell.contentViewZPosition)
        XCTAssertNotEqual(normalImage, renderedImageData(of: cell))

        controller.collectionView(controller.collectionView, didUnhighlightItemAt: IndexPath(item: 0, section: 0))
        XCTAssertFalse(cell.isTouchFeedbackVisible)
    }

    func test長押し成立後の別タッチによる通常タップを抑止しない() async {
        let item = Item(id: 1, title: "対象")
        var taps: [Item] = []
        var longTaps: [Item] = []
        var configuration = makeConfiguration(items: [item])
        configuration.onItemTap = { taps.append($0) }
        configuration.onItemLongTap = { longTaps.append($0) }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(1, in: controller)

        let longPress = controller.longPressRecognizer
        XCTAssertEqual(longPress?.cancelsTouchesInView, true)
        XCTAssertEqual(longPress?.isEnabled, true)
        controller.performLongPress(at: IndexPath(item: 0, section: 0))
        controller.collectionView(controller.collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))

        XCTAssertEqual(longTaps, [item])
        XCTAssertEqual(taps, [item])
    }

    func testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない() async {
        let item = Item(id: 1, title: "対象")
        var taps: [Item] = []
        var buttonActionCount = 0
        var configuration = makeConfiguration(items: [item]) { _ in
            ControlRow(onTap: { buttonActionCount += 1 })
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        configuration.onItemTap = { taps.append($0) }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(1, in: controller)
        let cell = tryUnwrapCell(controller, item: 0)
        cell.layoutIfNeeded()
        guard let button = firstControl(in: cell) else {
            XCTFail("UIHostingConfiguration 内の操作要素を取得できませんでした")
            return
        }

        // 実タッチと同じ経路でセルの hitTest を通し、操作要素が当たったことを判定させる。
        let indexPath = IndexPath(item: 0, section: 0)
        let point = cell.convert(
            CGPoint(x: button.bounds.midX, y: button.bounds.midY),
            from: button
        )
        XCTAssertTrue(cell.hitTest(point, with: UIEvent()) === button)
        XCTAssertTrue(cell.lastHitWasInteractive)
        XCTAssertFalse(controller.collectionView(controller.collectionView, shouldHighlightItemAt: indexPath))
        controller.collectionView(controller.collectionView, didSelectItemAt: indexPath)
        button.sendActions(for: .touchUpInside)

        XCTAssertEqual(buttonActionCount, 1)
        XCTAssertTrue(taps.isEmpty)
        XCTAssertFalse(cell.isTouchFeedbackVisible)
    }

    func testprefetchとcancelはindexPathを項目へ変換して通知する() async {
        let items = (0..<4).map { Item(id: $0, title: "項目 \($0)") }
        let recorder = PrefetchRecorder()
        var configuration = makeConfiguration(items: items)
        configuration.prefetcher = KsAnyPrefetcher(recorder)
        let controller = KsCollectionViewController(configuration: configuration)
        controller.loadViewIfNeeded()
        await waitUntil("data source 件数", value: {
            controller.collectionView.numberOfItems(inSection: 0)
        }) { $0 == 4 }

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [IndexPath(item: 2, section: 0), IndexPath(item: 0, section: 0)]
        )
        controller.collectionView(
            controller.collectionView,
            cancelPrefetchingForItemsAt: [IndexPath(item: 1, section: 0)]
        )

        XCTAssertEqual(recorder.prefetched, [items[2], items[0]])
        XCTAssertEqual(recorder.cancelled, [items[1]])
    }

    func testデータ追加と同一処理の末尾命令を最後のsnapshot後に実行する() async {
        let scrollController = KsScrollController()
        var configuration = makeConfiguration(items: (0..<30).map {
            Item(id: $0, title: "項目 \($0)")
        })
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 320))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 30 }

        scrollController.scrollToEnd(animated: false)
        configuration.items.append(Item(id: 30, title: "追加 30"))
        controller.update(configuration: configuration)
        configuration.items.append(Item(id: 31, title: "追加 31"))
        controller.update(configuration: configuration)

        await waitUntil("最後の snapshot と末尾移動", value: {
            (
                controller.appliedItemIdentifiers.last,
                controller.lastScrollTargetIdentifier
            )
        }) { $0.0 == AnyHashable(31) && $0.1 == AnyHashable(31) }
    }

    func testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する() async {
        let items = (0..<8).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        configuration.layout = .grid(columns: .adaptive(minItemWidth: 120), columnSpacing: 8)
        configuration.contentPadding = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitUntil("adaptive 実レイアウト", value: {
            let first = controller.collectionView.collectionViewLayout.layoutAttributesForItem(
                at: IndexPath(item: 0, section: 0)
            )?.frame
            let second = controller.collectionView.collectionViewLayout.layoutAttributesForItem(
                at: IndexPath(item: 1, section: 0)
            )?.frame
            return (first, second)
        }) { frames in
            guard let first = frames.0, let second = frames.1 else { return false }
            return abs(first.minX - 15) < 1
                && abs(second.minX - first.maxX - 8) < 1
                && first.width >= 120
                && second.width >= 120
                && abs(second.maxX - 375) < 1
        }
    }

    func test連続するスペーシングと余白変更でレイアウトを作り直さない() async {
        let items = (0..<30).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 4, columnSpacing: 4)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期セル", value: { controller.collectionView.visibleCells.count }) { $0 > 0 }
        let initialLayout = controller.collectionView.collectionViewLayout

        for value in 0..<16 {
            configuration.layout = .grid(
                columns: .fixed(2),
                rowSpacing: Double(value),
                columnSpacing: Double(value)
            )
            configuration.contentPadding = EdgeInsets(
                top: Double(value),
                leading: Double(value),
                bottom: Double(value),
                trailing: Double(value)
            )
            controller.update(configuration: configuration)
            controller.collectionView.layoutIfNeeded()
        }

        XCTAssertTrue(controller.collectionView.collectionViewLayout === initialLayout)
        XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), 30)
    }

    func testグリッドからリストへ切替後にスクロールしても全セルが一列になる() async {
        let items = (0..<60).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        configuration.layout = .grid(columns: .fixed(3))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("グリッドセル", value: { controller.collectionView.visibleCells.count }) { $0 > 3 }

        configuration.layout = .list
        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()
        controller.collectionView.scrollToItem(
            at: IndexPath(item: 50, section: 0),
            at: .bottom,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        controller.collectionView.scrollToItem(
            at: IndexPath(item: 0, section: 0),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()

        await waitUntil("一列のレイアウト属性", value: { visibleCellWidths(in: controller) }) {
            !$0.isEmpty && $0.allSatisfy { abs($0 - controller.collectionView.bounds.width) < 1 }
        }
    }

    func testリストからグリッドへの切替後も先頭可視要素を表示範囲に残す() async {
        var configuration = makeConfiguration(items: (0..<300).map { Item(id: $0, title: "項目 \($0)") })
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        let anchor = await scrollToDeepPosition(item: 150, in: controller)

        configuration.layout = .grid(columns: .fixed(2))
        controller.update(configuration: configuration)

        await waitUntil("アンカーの表示範囲内への復元", value: {
            visibleIdentifiers(in: controller)
        }) { $0.contains(anchor) }
    }

    func test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す() async {
        // 行高を推定値と一致させ、自己サイズの補正で位置が動かない条件にする
        // (復元されるオフセットを数値で突き合わせるため)。
        var configuration = makeConfiguration(
            items: (0..<300).map { Item(id: $0, title: "項目 \($0)") }
        ) { item in
            Text(item.title).frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        _ = await scrollToDeepPosition(item: 150, in: controller)
        let (anchor, offsetBefore) = clipLeadingAnchor(in: controller, fraction: 0.5)

        configuration.layout = .list(rowSpacing: 40)
        controller.update(configuration: configuration)

        await waitUntil("行間の反映", value: { leadingRowSpacing(in: controller) }) {
            guard let spacing = $0 else { return false }
            return abs(spacing - 40) < 1
        }
        controller.collectionView.layoutIfNeeded()
        XCTAssertEqual(visibleIdentifiers(in: controller).first, anchor)
        XCTAssertEqual(
            anchorOffsetFromTop(anchor, in: controller) ?? .nan,
            offsetBefore,
            accuracy: 1.5,
            "半分クリップしたアンカーの表示範囲上端からの位置が変更前と一致しません"
        )
    }

    func test行間を連続して変えても先頭可視要素が変わらない() async {
        // 行高を推定値と一致させ、自己サイズの補正で位置が動かない条件にする
        // (復元されるオフセットを数値で突き合わせるため)。
        var configuration = makeConfiguration(
            items: (0..<300).map { Item(id: $0, title: "項目 \($0)") }
        ) { item in
            Text(item.title).frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        _ = await scrollToDeepPosition(item: 150, in: controller)
        let (anchor, offsetBefore) = clipLeadingAnchor(in: controller, fraction: 0.5)

        for step in 1...8 {
            configuration.layout = .list(rowSpacing: Double(step) * 6)
            controller.update(configuration: configuration)
            controller.collectionView.layoutIfNeeded()

            XCTAssertEqual(
                visibleIdentifiers(in: controller).first,
                anchor,
                "行間 \(Double(step) * 6) への変更で先頭可視要素が変わりました"
            )
            XCTAssertEqual(
                anchorOffsetFromTop(anchor, in: controller) ?? .nan,
                offsetBefore,
                accuracy: 1.5,
                "行間 \(Double(step) * 6) への変更でアンカーの表示範囲上端からの位置がずれました"
            )
        }
    }

    func testレイアウト切替と同時の先頭側への大量挿入でもアンカーを保つ() async {
        var configuration = makeConfiguration(items: (0..<300).map { Item(id: $0, title: "項目 \($0)") })
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        let anchor = await scrollToDeepPosition(item: 150, in: controller)

        configuration.items.insert(
            contentsOf: (1_000..<1_100).map { Item(id: $0, title: "先頭挿入 \($0)") },
            at: 0
        )
        configuration.layout = .grid(columns: .fixed(2))
        controller.update(configuration: configuration)

        await waitUntil("挿入後もアンカーが表示範囲内", value: {
            visibleIdentifiers(in: controller)
        }) { $0.contains(anchor) }
    }

    func testレイアウト切替と同時にアンカーが消えたら近傍要素を表示範囲に残す() async {
        var configuration = makeConfiguration(items: (0..<300).map { Item(id: $0, title: "項目 \($0)") })
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        let anchor = await scrollToDeepPosition(item: 150, in: controller)
        guard let anchorID = anchor.base as? Int else {
            XCTFail("アンカーの ID を解決できませんでした")
            return
        }

        configuration.items.removeAll { $0.id == anchorID }
        configuration.layout = .grid(columns: .fixed(2))
        controller.update(configuration: configuration)

        await waitUntil("近傍要素が表示範囲内", value: {
            visibleIdentifiers(in: controller)
        }) { $0.contains(AnyHashable(anchorID + 1)) }
        XCTAssertFalse(controller.appliedItemIdentifiers.contains(anchor))
    }

    func testアンカーの高さが大きく縮む切り替えでもアンカーを表示範囲に残す() async {
        var configuration = makeConfiguration(
            items: (0..<200).map { Item(id: $0, title: "項目 \($0)") }
        ) { _ in
            // 幅と同じ高さになる内容。1 列では表示範囲に近い高さ、2 列ではその約半分になる。
            Rectangle()
                .fill(Color.gray)
                .aspectRatio(1, contentMode: .fit)
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 200 }
        _ = await scrollToDeepPosition(item: 40, in: controller)
        // アンカーの大部分を表示範囲の上へ追い出す。高さが縮んだ後もこの位置を保つと表示範囲から外れる。
        let (anchor, offsetBefore) = clipLeadingAnchor(in: controller, fraction: 0.9)
        let clippedLength = -offsetBefore
        guard let heightBefore = anchorHeight(anchor, in: controller) else {
            XCTFail("切り替え前のアンカーの高さを取得できませんでした")
            return
        }

        configuration.layout = .grid(columns: .fixed(2))
        controller.update(configuration: configuration)

        await waitUntil("切り替え後のアンカーの高さ", value: { anchorHeight(anchor, in: controller) }) {
            guard let height = $0 else { return false }
            return height < heightBefore * 0.75
        }
        guard let heightAfter = anchorHeight(anchor, in: controller) else {
            XCTFail("切り替え後のアンカーの高さを取得できませんでした")
            return
        }
        XCTAssertLessThan(
            heightAfter,
            clippedLength,
            "クリップ量より高さが大きく、クランプを必要としない条件になっています"
        )
        await waitUntil("アンカーの表示範囲内への復元", value: {
            visibleIdentifiers(in: controller)
        }) { $0.contains(anchor) }
    }

    #if DEBUG
    // 同時生存セルの計数 (`liveCellCount` / `cellProviderCallCount`) は debug ビルドにだけ載るため、
    // このテストも debug 構成でだけ実行する。
    func test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める() async {
        let itemCount = 2_000
        let controller = KsCollectionViewController(
            configuration: makeConfiguration(
                items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
            )
        )
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        // 上限は可視セル数から導く。件数ではなく画面に載る量で決めることで、項目数を変えても同じ意味の上限になる。
        // この窓 (390x844) では可視 39 件に対して同時生存の実測最大が 115 件 (可視の約 3 倍) であり、
        // 先読みと再利用プールの分を含めて 4 倍を上限に置く。再利用が壊れれば生存数は走査した件数に比例するため、
        // この幅でも仮想化の破綻は捕まえられる。
        let visibleCellCount = controller.collectionView.indexPathsForVisibleItems.count
        XCTAssertGreaterThan(visibleCellCount, 0, "初期表示の可視セルを取得できませんでした")
        let liveCellLimit = visibleCellCount * 4

        // 端点間を飛ばさず、表示範囲の半分ずつ送って全項目を通過する。
        // 前後の可視範囲が十分に重ならない刻みでは、UIKit は再利用ではなく作り直しになる。
        var maxLiveCellCount = 0
        await advanceRoundTrip(itemCount: itemCount, in: controller) {
            maxLiveCellCount = max(maxLiveCellCount, controller.liveCellCount)
        }

        // 全項目を 2 度通過してもなお、同時生存セルは可視範囲と再利用プールの規模に留まる。
        // 件数に依存しないことがこの上限の意味である。
        XCTAssertGreaterThan(controller.cellProviderCallCount, itemCount)
        XCTAssertLessThan(
            maxLiveCellCount,
            liveCellLimit,
            "同時生存セルが可視範囲と再利用プールの規模を超えています "
                + "(可視 \(visibleCellCount) 件 / 実測の最大 \(maxLiveCellCount) 件 / 上限 \(liveCellLimit) 件)"
        )
    }

    // 推定高さが多数派の高さに達した後は、新しく可視になるセルのほとんどが推定と同じ高さに測られ、
    // レイアウトの解き直しを起こさない。不一致率は解き直しの回数の上界であり (同一と見なす幅を
    // 最下位桁の丸め誤差までに限っており、その幅では解き直しが起きないことを
    // `KsSelfSizingInvalidationTests` で確かめている)、件数にも操作量にも依らない値として読める。
    func test高さ2種類が6対1で混ざる2000件で推定と違うセルの割合を0_20以下に保つ() async {
        let itemCount = 2_000
        let controller = KsCollectionViewController(
            configuration: makeMixedHeightGridConfiguration(itemCount: itemCount)
        )
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        let majorityHeight = await settleMajorityEstimate(in: controller)

        // 推定が多数派に達した後の区間だけを数える。
        KsLayoutDiagnostics.reset()
        let advanced = await advanceUntilVisible(
            item: itemCount / 2,
            in: controller,
            step: controller.collectionView.bounds.height / 2
        )
        XCTAssertTrue(advanced, "中程まで送り切れませんでした")

        XCTAssertGreaterThan(
            KsLayoutDiagnostics.selfSizedCellCount,
            itemCount / 4,
            "自己サイズを返したセルが少なすぎ、割合の標本になりません"
        )
        XCTAssertLessThanOrEqual(
            KsLayoutDiagnostics.estimateMismatchRate,
            0.20,
            "推定と違う高さに測られたセルの割合が上限を超えています "
                + "(多数派の高さ \(majorityHeight) / 自己サイズ \(KsLayoutDiagnostics.selfSizedCellCount) 件 / "
                + "不一致 \(KsLayoutDiagnostics.estimateMismatchCount) 件 / 率 \(KsLayoutDiagnostics.estimateMismatchRate))"
        )
    }

    // 一致の判定は、そのセルに渡されていた高さと測った高さの比較で行う。
    // レイアウトを渡した後に推定値が動くと「いまの推定値」とは食い違うため、比較の相手を
    // 取り違えると不一致を数え落とす (または過剰に数える)。
    func testレイアウトを渡した後に推定値が動いても渡された高さと比べて数える() async {
        let itemCount = 100
        let controller = KsCollectionViewController(
            configuration: makeUniformHeightListConfiguration(itemCount: itemCount)
        )
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        await waitUntil("自己サイズの反映", value: { itemFrames(in: controller, items: [0]).first?.height }) {
            ($0 ?? 0) > 0
        }

        let rowWidth = itemFrames(in: controller, items: [0])[0].width
        let cell = tryUnwrapCell(controller, item: 0)
        // このセルが返す高さを先に確かめる。比較の相手の違いは、この高さを基準にしないと作れない。
        let measuredHeight = cell.preferredLayoutAttributesFitting(
            layoutAttributes(width: rowWidth, height: KsEstimatedHeight.defaultValue)
        ).size.height
        // 以下の 2 つの向きのうち、少なくとも一方は比較の相手の違いで結果が変わる。いまの推定値が
        // このセルの返す高さと違えば前者 (一致のはずが不一致に数えられる) が、同じなら後者
        // (不一致のはずが一致に数えられる) が食い違うためで、どちらになるかは環境で変わる。
        KsLayoutDiagnostics.reset()
        _ = cell.preferredLayoutAttributesFitting(
            layoutAttributes(width: rowWidth, height: measuredHeight)
        )
        XCTAssertEqual(KsLayoutDiagnostics.selfSizedCellCount, 1)
        XCTAssertEqual(
            KsLayoutDiagnostics.estimateMismatchCount,
            0,
            "渡された高さと同じに測られたのに不一致として数えています "
                + "(いまの推定値 \(controller.currentEstimatedHeight) / 測った高さ \(measuredHeight))"
        )

        _ = cell.preferredLayoutAttributesFitting(
            layoutAttributes(width: rowWidth, height: measuredHeight + 20)
        )
        XCTAssertEqual(KsLayoutDiagnostics.selfSizedCellCount, 2)
        XCTAssertEqual(
            KsLayoutDiagnostics.estimateMismatchCount,
            1,
            "渡された高さと違う高さに測られたのに一致として数えています "
                + "(いまの推定値 \(controller.currentEstimatedHeight) / 測った高さ \(measuredHeight))"
        )
    }
    #endif

    // 行の高さは行内で最も高いセルに揃い、各セルはコンテンツに必要な高さで表示される。
    // 自己サイズの正しさは推定の決め方に依らない。
    func test2列で片方だけ高い配列では行の高さが高い方に揃う() async {
        let itemCount = 200
        var configuration = makeConfiguration(items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }) {
            // 偶数番のセルだけに長文が付く配列。2 列なので各行の片方だけが高くなる。
            AlternatingHeightRow(item: $0)
        }
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 1, columnSpacing: 1)
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        await waitUntil("自己サイズの反映", value: { itemFrames(in: controller, items: [0, 1]) }) { frames in
            guard frames.count == 2 else { return false }
            return frames[0].height != frames[1].height
        }

        let frames = itemFrames(in: controller, items: [0, 1, 2, 3])
        XCTAssertEqual(frames.count, 4, "先頭 2 行のレイアウト属性を取得できませんでした")
        XCTAssertGreaterThan(frames[0].height, frames[1].height, "長文の付いたセルが高くなっていません")
        XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 0.5, "同じ行のセルの上端が揃っていません")
        // 次の行は、行内で最も高いセルの下端より下から始まる (= 行の高さが高い方に揃っている)。
        XCTAssertGreaterThanOrEqual(
            frames[2].minY,
            max(frames[0].maxY, frames[1].maxY),
            "次の行が高いセルに重なっています"
        )
    }

    // 行の高さが一様な配列で、合計高さの見積もり (初回表示のコンテンツ高さと、末尾までの
    // contentSize の変化回数) が壊れないことを固定する。行 = セルになるため、推定値は行の
    // 高さそのものを言い当てられる。
    //
    // 行の高さが混在する複数列のグリッドはこの基準の対象にしない。行の高さが列内の最も高い
    // セルで決まるのに対し、実測として拾えるのはセル単位の高さであり、コレクション全体で
    // 1 つの推定値をどう選んでも行の高さを言い当てられないためである (参考の実測: 2 列で
    // 高さ 2 種類が 6 : 1 の 2,000 件では、最頻値で誤差 34.5% / 変化 134 回、平均でも
    // 誤差 12.0% / 変化 134 回。iPhone 17 Pro Max Simulator / iOS 26.0、全件を刻んで走査し
    // 到達後の contentSize と比べる計測形での値で、このテストの計測形では採り直していない)。
    func test行高が一様な配列で初回表示の合計高さの見積もりを損ねない() async {
        let itemCount = 2_000
        let controller = KsCollectionViewController(
            configuration: makeUniformHeightListConfiguration(itemCount: itemCount)
        )
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        await settleContentSize(in: controller)

        // 行 = セルで高さが一様なので、コンテンツ全体の実際の高さは「実測した行の高さ × 件数」で
        // 決まる。初回表示の contentSize をこの値と比べることで、見積もりの当たり具合を、
        // どこまで解き終えたかに依らず測れる。
        // 行の高さは、先頭 20 行のうち最も多く現れた高さを採る。ごく一部の行は、表示の過程で
        // 提案された高さのまま伸びることがあり (推定の決め方に依らない)、その行を基準にすると
        // 合計を測れないため。
        let sampledHeights = itemFrames(in: controller, items: Array(0..<20)).map(\.height)
        XCTAssertEqual(sampledHeights.count, 20, "先頭の行のレイアウト属性を取得できませんでした")
        var heightCounts: [CGFloat: Int] = [:]
        sampledHeights.forEach { heightCounts[$0, default: 0] += 1 }
        guard let rowHeight = heightCounts.max(by: { $0.value < $1.value })?.key else {
            XCTFail("行の高さを取得できませんでした")
            return
        }
        XCTAssertGreaterThanOrEqual(
            heightCounts[rowHeight] ?? 0,
            14,
            "行の高さが一様ではありません (\(heightCounts.sorted { $0.key < $1.key }))"
        )
        let actualHeight = rowHeight * CGFloat(itemCount)

        // 見積もりが外れていれば、末尾へ送っている間に行位置の積み上げが何度も引き直され、
        // contentSize が段階的に伸びる。
        let initialHeight = controller.collectionView.contentSize.height
        var observedHeights: [CGFloat] = []
        let observation = controller.collectionView.observe(\.contentSize, options: [.new]) { collectionView, _ in
            let height = collectionView.contentSize.height
            if observedHeights.last != height {
                observedHeights.append(height)
            }
        }
        defer { observation.invalidate() }

        controller.collectionView.scrollToItem(
            at: IndexPath(item: itemCount - 1, section: 0),
            at: .bottom,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        await waitUntil("末尾の可視化", value: { isVisible(item: itemCount - 1, in: controller) }) { $0 }
        await settleContentSize(in: controller)

        let measuredHeight = controller.collectionView.contentSize.height
        XCTAssertGreaterThan(actualHeight, 0)
        let error = abs(initialHeight - actualHeight) / actualHeight
        XCTAssertLessThanOrEqual(
            error,
            0.05,
            "初回表示のコンテンツ高さの誤差が ±5% を超えています "
                + "(初回 \(initialHeight) / 実測 \(actualHeight) = 行 \(rowHeight) × \(itemCount) / "
                + "誤差 \(error))"
        )

        // 数えるのは合計高さの 0.1% を超える引き直しだけとする。件数が多いほど、どの推定値でも
        // 到達直前に微小な引き直し (合計の 0.03% 未満) が数回入り、その回数は機種によって変わる。
        // 捕まえたいのは「見積もりが外れて段階的に伸びる」動き (推定を固定値にすると 1 回あたり
        // 合計の数 % の伸びが何十回も入る) なので、微小な引き直しは回数に数えない。
        let significantThreshold = actualHeight * 0.001
        var significantChanges: [CGFloat] = []
        var minorChangeCount = 0
        var previousHeight = initialHeight
        for height in observedHeights where height != previousHeight {
            if abs(height - previousHeight) > significantThreshold {
                significantChanges.append(height - previousHeight)
            } else {
                minorChangeCount += 1
            }
            previousHeight = height
        }
        XCTAssertLessThanOrEqual(
            significantChanges.count,
            3,
            "末尾までの contentSize の大きな変化の回数が上限を超えています "
                + "(0.1% 超 \(significantChanges.count) 回 \(significantChanges) / "
                + "0.1% 以下 \(minorChangeCount) 回 / 合計 \(actualHeight))"
        )
        // 次回との比較のため、閾値に届かなかった引き直しの回数も残す。
        print(
            "KS 合計高さの見積もり: 初回 \(initialHeight) / 実測 \(actualHeight) / 到達後 \(measuredHeight) / 誤差 \(error) / "
                + "0.1% 超 \(significantChanges.count) 回 / 0.1% 以下 \(minorChangeCount) 回"
        )
    }

    #if DEBUG
    // 配列を置き換えても、置換前の項目のために作ったセルは保持されない。
    func test配列の置換で同時生存セルが可視範囲の規模に戻る() async {
        let itemCount = 2_000
        let controller = KsCollectionViewController(
            configuration: makeConfiguration(
                items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
            )
        )
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        let visibleCellCount = controller.collectionView.indexPathsForVisibleItems.count
        XCTAssertGreaterThan(visibleCellCount, 0, "初期表示の可視セルを取得できませんでした")
        let liveCellLimit = visibleCellCount * 4

        // 再利用プールが埋まるまで全件を往復する。
        await advanceRoundTrip(itemCount: itemCount, in: controller)

        var replaced = makeConfiguration(
            items: (itemCount..<(itemCount * 2)).map { Item(id: $0, title: "置換 \($0)") }
        )
        replaced.layout = .list
        controller.update(configuration: replaced)
        await waitUntil("置換後の snapshot", value: { controller.appliedItemIdentifiers.first }) {
            $0 == AnyHashable(itemCount)
        }

        // 置換の直後は前の項目のセルが解放される機会をまだ得ていないため、収束を待つ。
        await waitUntil("置換後の同時生存セル", value: { controller.liveCellCount }) { $0 < liveCellLimit }
        XCTAssertLessThan(
            controller.liveCellCount,
            liveCellLimit,
            "置換後も同時生存セルが可視範囲と再利用プールの規模を超えています "
                + "(可視 \(visibleCellCount) 件 / 実測 \(controller.liveCellCount) 件 / 上限 \(liveCellLimit) 件)"
        )
    }
    #endif

    // コレクションへの強参照を手放すと、エンジンとそれが持つセル・ホスティングが解放される。
    // 破棄後は同じインスタンスの計数を読めないため、弱参照が nil になることで確かめる。
    func testコレクションへの強参照を手放すとエンジンが解放される() async {
        let itemCount = 2_000
        weak var engine: KsCollectionViewController<Item>?
        var window: UIWindow? = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        do {
            let controller = KsCollectionViewController(
                configuration: makeConfiguration(
                    items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
                )
            )
            engine = controller
            window?.rootViewController = controller
            window?.makeKeyAndVisible()
            controller.loadViewIfNeeded()
            controller.view.layoutIfNeeded()
            await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

            // 再利用プールと多数のホスティングを通過した状態から解放する。
            // 走査が成立しなければ、その前提を作れていないので破棄の確認へ進まない。
            let traversed = await advanceRoundTrip(itemCount: itemCount, in: controller)
            XCTAssertTrue(traversed, "全件を往復できなかったため破棄の確認へ進みません")
            guard traversed else { return }
            XCTAssertNotNil(engine)
        }

        window?.rootViewController = nil
        window?.isHidden = true
        window = nil

        await waitUntil("エンジンの解放", value: { engine == nil }) { $0 }
        XCTAssertNil(engine, "コレクションを手放してもエンジンが解放されていません")
    }

    func test左右の内側余白を変えてもスクロールインジケータをコンポーネント端に保つ() async {
        var configuration = makeConfiguration(items: (0..<80).map { Item(id: $0, title: "項目 \($0)") })
        configuration.contentPadding = EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 40)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("左右余白の反映", value: { leadingItemFrame(in: controller)?.minX }) {
            guard let minX = $0 else { return false }
            return abs(minX - 40) < 1
        }
        assertScrollIndicatorStaysAtComponentEdge(in: controller, paddingDescription: "40pt")

        configuration.contentPadding = EdgeInsets(top: 0, leading: 120, bottom: 0, trailing: 120)
        controller.update(configuration: configuration)

        await waitUntil("左右余白の変更の反映", value: { leadingItemFrame(in: controller)?.minX }) {
            guard let minX = $0 else { return false }
            return abs(minX - 120) < 1
        }
        assertScrollIndicatorStaysAtComponentEdge(in: controller, paddingDescription: "120pt")
    }

    func testheaderは下方向のスクロールでコンテンツと一緒に画面外へ出る() async {
        var configuration = makeConfiguration(items: (0..<200).map { Item(id: $0, title: "項目 \($0)") })
        configuration.header = {
            AnyView(Text("ヘッダー").frame(maxWidth: .infinity, minHeight: 60))
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("header の表示", value: { visibleHeaderCount(in: controller) }) { $0 == 1 }
        guard let frameBefore = headerFrame(in: controller) else {
            XCTFail("header のレイアウト属性を取得できませんでした")
            return
        }
        XCTAssertTrue(frameBefore.intersects(controller.collectionView.bounds))

        controller.collectionView.scrollToItem(
            at: IndexPath(item: 60, section: 0),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()

        // pin されていれば header は表示範囲の上端へ貼り付いたままになる。
        // コンテンツと一緒に動くなら、コンテンツ座標での位置は変わらず表示範囲から外れる。
        await waitUntil("header の画面外への退出", value: { visibleHeaderCount(in: controller) }) { $0 == 0 }
        XCTAssertEqual(headerFrame(in: controller), frameBefore)
        XCTAssertFalse(frameBefore.intersects(controller.collectionView.bounds))
    }

    func testコンテナ縦横比の変更で縦2列と横4列を再計算する() async {
        let items = (0..<40).map { Item(id: $0, title: "項目 \($0)") }
        var configuration = makeConfiguration(items: items)
        configuration.layout = .grid(columns: .fixed(portrait: 2, landscape: 4))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitUntil("縦向き 2 列", value: { columnCount(in: controller) }) { $0 == 2 }
        resize(window: window, controller: controller, to: CGSize(width: 844, height: 390))
        await waitUntil("横向き 4 列", value: { columnCount(in: controller) }) { $0 == 4 }
        resize(window: window, controller: controller, to: CGSize(width: 390, height: 844))
        await waitUntil("逆さま相当の縦向き 2 列", value: { columnCount(in: controller) }) { $0 == 2 }
    }

    func test既定のtouchFeedbackは半透明でセル内容を隠さない() async {
        var configuration = makeConfiguration(items: [Item(id: 1, title: "A")]) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.white)
        }
        configuration.onItemTap = { _ in }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(1, in: controller)
        let cell = tryUnwrapCell(controller, item: 0)
        cell.layoutIfNeeded()
        let samplePoint = CGPoint(x: cell.bounds.midX, y: cell.bounds.midY)
        let normalImage = renderedImageData(of: cell)
        let normalPixels = renderedPixels(of: cell, at: [samplePoint])

        controller.collectionView(controller.collectionView, didHighlightItemAt: IndexPath(item: 0, section: 0))
        cell.layoutIfNeeded()
        let highlightedPixels = renderedPixels(of: cell, at: [samplePoint])

        XCTAssertTrue(cell.isTouchFeedbackVisible)
        XCTAssertNotEqual(normalImage, renderedImageData(of: cell))
        XCTAssertNotEqual(normalPixels, highlightedPixels)
        // 解決済みの色が不透明ではない = 下のセル内容が透ける。
        let alpha = cell.touchFeedbackColor?
            .resolvedColor(with: cell.traitCollection)
            .cgColor
            .alpha
        XCTAssertLessThan(alpha ?? 1, 1)
    }

    func test挿入時に内容不変の要素のセルプロバイダを再実行しない() async {
        let builds = BuildRecorder()
        var configuration = makeConfiguration(items: [
            Item(id: 1, title: "A"),
            Item(id: 2, title: "B"),
            Item(id: 3, title: "C"),
        ]) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let countsBeforeInsert = builds.counts

        configuration.items.insert(Item(id: 0, title: "先頭"), at: 0)
        controller.update(configuration: configuration)
        await settleAtStart(itemCount: 4, in: controller)

        XCTAssertEqual(builds.counts[1], countsBeforeInsert[1])
        XCTAssertEqual(builds.counts[2], countsBeforeInsert[2])
        XCTAssertEqual(builds.counts[3], countsBeforeInsert[3])
        XCTAssertEqual(builds.counts[0], 1)
        assertSeparatorPositions(itemCount: 4, in: controller)
    }

    func test同一配列の再適用ではID解決を行わず可視セルだけ再構成する() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let idCalls = BuildRecorder()
        let builds = BuildRecorder()
        let configuration = makeConfiguration(
            items: items,
            id: { item in
                _ = idCalls.record(item.id)
                return AnyHashable(item.id)
            }
        ) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let idCallsBeforeUpdate = idCalls.counts
        let buildsBeforeUpdate = builds.counts

        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()

        XCTAssertEqual(idCalls.counts, idCallsBeforeUpdate)
        for id in 0..<3 {
            XCTAssertEqual(builds.counts[id], (buildsBeforeUpdate[id] ?? 0) + 1)
        }
    }

    func test観測する値の変化で同値配列でも可視セルを再構成する() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let builds = BuildRecorder()
        var configuration = makeConfiguration(items: items) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        configuration.observedValue = AnyHashable(Set<Int>())
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let buildsBeforeUpdate = builds.counts

        configuration.observedValue = AnyHashable(Set([1]))
        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()

        for id in 0..<3 {
            XCTAssertEqual(builds.counts[id], (buildsBeforeUpdate[id] ?? 0) + 1)
        }
    }

    func test観測する値が同じなら可視セルを再構成しない() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let builds = BuildRecorder()
        var configuration = makeConfiguration(items: items) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        configuration.observedValue = AnyHashable(Set([1]))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let buildsBeforeUpdate = builds.counts
        XCTAssertEqual(tryUnwrapCell(controller, item: 0).touchFeedbackColor, .systemFill)

        // 観測する値に関係のない更新 (色の差し替え) だけが届いた状況。
        configuration.touchFeedbackColor = .systemRed
        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()

        XCTAssertEqual(builds.counts, buildsBeforeUpdate)
        // テンプレートは呼び直さない一方で、タッチ時の背景色は表示中のセルへ届く。
        XCTAssertEqual(tryUnwrapCell(controller, item: 0).touchFeedbackColor, .systemRed)
    }

    func test観測する値の変化ではID解決もsnapshot適用も行わない() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let idCalls = BuildRecorder()
        let builds = BuildRecorder()
        var configuration = makeConfiguration(
            items: items,
            id: { item in
                _ = idCalls.record(item.id)
                return AnyHashable(item.id)
            }
        ) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        configuration.observedValue = AnyHashable(0)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let idCallsBeforeUpdate = idCalls.counts
        let buildsBeforeUpdate = builds.counts
        let identifiersBeforeUpdate = controller.appliedItemIdentifiers

        configuration.observedValue = AnyHashable(1)
        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()

        XCTAssertEqual(idCalls.counts, idCallsBeforeUpdate)
        XCTAssertEqual(controller.appliedItemIdentifiers, identifiersBeforeUpdate)
        for id in 0..<3 {
            XCTAssertEqual(builds.counts[id], (buildsBeforeUpdate[id] ?? 0) + 1)
        }
    }

    func test配列と観測する値が同時に変わった更新でも観測する値を記録する() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let builds = BuildRecorder()
        var configuration = makeConfiguration(items: items) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        configuration.observedValue = AnyHashable(0)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)

        configuration.items.append(Item(id: 3, title: "項目 3"))
        configuration.observedValue = AnyHashable(1)
        controller.update(configuration: configuration)
        await settleAtStart(itemCount: 4, in: controller)
        XCTAssertEqual(builds.counts[3], 1)
        let buildsAfterInsert = builds.counts

        // 観測する値を元へ戻す更新。直前の更新で新しい値が記録されていれば変化として扱われる。
        configuration.observedValue = AnyHashable(0)
        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()

        for id in 0..<4 {
            XCTAssertEqual(builds.counts[id], (buildsAfterInsert[id] ?? 0) + 1)
        }
    }

    func test配列と観測する値が同時に変わった更新で既存の可視セルも再構成する() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let builds = BuildRecorder()
        var configuration = makeConfiguration(items: items) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        configuration.observedValue = AnyHashable(Set<Int>())
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let buildsBeforeUpdate = builds.counts

        // 項目の追加と観測する値の変化が 1 回の更新で同時に届く状況。
        configuration.items.append(Item(id: 3, title: "項目 3"))
        configuration.observedValue = AnyHashable(Set([1]))
        controller.update(configuration: configuration)
        await settleAtStart(itemCount: 4, in: controller)

        // 追加された項目だけでなく、内容が同値のまま残った可視セルも新しい観測する値で作り直される。
        for id in 0..<3 {
            XCTAssertEqual(builds.counts[id], (buildsBeforeUpdate[id] ?? 0) + 1)
        }
        XCTAssertEqual(builds.counts[3], 1)
    }

    func test観測する値を渡していなければ更新ごとに可視セルを再構成する() async {
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let builds = BuildRecorder()
        let configuration = makeConfiguration(items: items) { item in
            let _ = builds.record(item.id)
            Text(item.title)
        }
        XCTAssertNil(configuration.observedValue)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        let buildsBeforeUpdate = builds.counts

        controller.update(configuration: configuration)
        controller.collectionView.layoutIfNeeded()

        for id in 0..<3 {
            XCTAssertEqual(builds.counts[id], (buildsBeforeUpdate[id] ?? 0) + 1)
        }
    }

    func testtouchFeedback色の変更を可視セルへ反映する() async {
        var configuration = makeConfiguration(items: [Item(id: 1, title: "A")])
        configuration.onItemTap = { _ in }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(1, in: controller)
        XCTAssertEqual(tryUnwrapCell(controller, item: 0).touchFeedbackColor, .systemFill)

        configuration.touchFeedbackColor = .systemRed
        controller.update(configuration: configuration)

        XCTAssertEqual(tryUnwrapCell(controller, item: 0).touchFeedbackColor, .systemRed)
    }

    func test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す() async {
        let scrollController = KsScrollController()
        var configuration = makeConfiguration(items: [])
        configuration.header = { AnyView(Color.gray.frame(height: 2_000)) }
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("header の表示", value: {
            controller.collectionView.contentSize.height
        }) { $0 > 844 }
        controller.collectionView.setContentOffset(CGPoint(x: 0, y: 600), animated: false)
        XCTAssertEqual(controller.collectionView.contentOffset.y, 600)

        scrollController.scrollToStart(animated: false)

        await waitUntil("先頭オフセット", value: {
            controller.collectionView.contentOffset.y
        }) { $0 == -controller.collectionView.adjustedContentInset.top }
    }

    func test未登録テンプレートキーをsnapshot準備時に検知する() async {
        let registry = KsTemplateRegistry<Item>(templates: [
            KsTemplate("registered") { (item: Item) in
                Text(item.title).frame(maxWidth: .infinity, minHeight: 44)
            },
        ])
        // ID 100 番台だけが未登録キーを返す。画面内に収まる件数より後ろへ置き、可視化を待たずに検知されることを見る。
        let templateKey: (Item) -> AnyHashable = {
            $0.id >= 100 ? AnyHashable("unregistered") : AnyHashable("registered")
        }
        var configuration = KsCollectionConfiguration(
            items: (0..<60).map { Item(id: $0, title: "項目 \($0)") },
            id: { AnyHashable($0.id) },
            templateKey: templateKey,
            registry: registry,
            layout: .list,
            contentPadding: EdgeInsets(),
            showsSeparators: true,
            separatorColor: nil,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 60 }
        XCTAssertTrue(controller.unregisteredTemplateKeysAtPreparation.isEmpty)

        controller.assertsUnregisteredTemplateKeys = false
        configuration.items.append(Item(id: 100, title: "画面外の未登録キー"))
        controller.update(configuration: configuration)

        await waitUntil("未登録キーの検知", value: {
            controller.unregisteredTemplateKeysAtPreparation
        }) { $0 == [AnyHashable("unregistered")] }
    }

    func test同一配列の再適用でも保留中のスクロール命令を実行する() async {
        let scrollController = KsScrollController()
        let items = (0..<30).map { Item(id: $0, title: "項目 \($0)") }
        let configuration = {
            var configuration = makeConfiguration(items: items)
            configuration.scrollController = scrollController
            return configuration
        }()
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 320))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 30 }

        scrollController.scrollToEnd(animated: false)
        controller.update(configuration: configuration)

        await waitUntil("末尾への移動", value: { controller.lastScrollTargetIdentifier }) {
            $0 == AnyHashable(29)
        }
    }

    func testロングタップ未宣言のときは長押し認識器を無効にする() async {
        let item = Item(id: 1, title: "対象")
        var taps: [Item] = []
        var configuration = makeConfiguration(items: [item])
        configuration.onItemTap = { taps.append($0) }
        let controller = KsCollectionViewController(configuration: configuration)
        controller.loadViewIfNeeded()
        await waitUntil("data source 件数", value: {
            controller.collectionView.numberOfItems(inSection: 0)
        }) { $0 == 1 }
        let recognizer = controller.longPressRecognizer

        XCTAssertEqual(recognizer?.isEnabled, false)
        controller.collectionView(controller.collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(taps, [item])

        configuration.onItemLongTap = { _ in }
        controller.update(configuration: configuration)
        XCTAssertEqual(recognizer?.isEnabled, true)
    }

    func test内容不変のheader更新でホスティングビューを維持する() async {
        var configuration = makeConfiguration(items: [Item(id: 1, title: "A")])
        configuration.header = { AnyView(Text("ヘッダー")) }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("header 表示", value: {
            controller.collectionView.visibleSupplementaryViews(
                ofKind: UICollectionView.elementKindSectionHeader
            ).count
        }) { $0 == 1 }
        guard let headerView = controller.collectionView.visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionHeader
        ).first as? KsHostingSupplementaryView else {
            XCTFail("header のホスティングビューを取得できませんでした")
            return
        }
        let hostedView = headerView.hostedContentView
        XCTAssertNotNil(hostedView)

        configuration.header = { AnyView(Text("ヘッダー")) }
        controller.update(configuration: configuration)

        XCTAssertTrue(headerView.hostedContentView === hostedView)
    }

    #if !DEBUG
    func testReleaseでは重複IDを後勝ちで解決して表示を継続する() async {
        let configuration = makeConfiguration(items: [
            Item(id: 1, title: "先勝ち"),
            Item(id: 2, title: "B"),
            Item(id: 1, title: "後勝ち"),
        ])
        let controller = KsCollectionViewController(configuration: configuration)
        controller.loadViewIfNeeded()

        await waitUntil("重複を畳んだ snapshot", value: { controller.appliedItemIdentifiers }) {
            $0 == [AnyHashable(2), AnyHashable(1)]
        }
    }
    #endif

    private func makeConfiguration(items: [Item]) -> KsCollectionConfiguration<Item> {
        makeConfiguration(items: items) { item in
            Text(item.title)
        }
    }

    private func makeConfiguration<Content: View>(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> KsCollectionConfiguration<Item> {
        makeConfiguration(items: items, id: { AnyHashable($0.id) }, content: content)
    }

    private func makeConfiguration<Content: View>(
        items: [Item],
        id: @escaping (Item) -> AnyHashable,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> KsCollectionConfiguration<Item> {
        KsCollectionConfiguration(
            items: items,
            id: id,
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry(content: content),
            layout: .list,
            contentPadding: EdgeInsets(),
            showsSeparators: true,
            separatorColor: nil,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
    }

    // 固定高と可変行高が 6 : 1 で混ざる 2 列グリッドの構成。
    private func makeMixedHeightGridConfiguration(itemCount: Int) -> KsCollectionConfiguration<Item> {
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        ) { item in
            MixedHeightRow(item: item)
        }
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 1, columnSpacing: 1)
        configuration.showsSeparators = false
        return configuration
    }

    // 行の高さが一様な 1 列リストの構成。行 = セルになる。
    private func makeUniformHeightListConfiguration(itemCount: Int) -> KsCollectionConfiguration<Item> {
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        ) { item in
            UniformHeightRow(item: item)
        }
        configuration.layout = .list
        configuration.showsSeparators = false
        return configuration
    }

    // セルへ渡すレイアウト属性を組み立てる。
    private func layoutAttributes(width: CGFloat, height: CGFloat) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attributes.frame = CGRect(x: 0, y: 0, width: width, height: height)
        return attributes
    }

    // 指定した項目のレイアウト属性の矩形を返す。
    private func itemFrames(
        in controller: KsCollectionViewController<Item>,
        items: [Int]
    ) -> [CGRect] {
        items.compactMap {
            controller.collectionView.collectionViewLayout.layoutAttributesForItem(
                at: IndexPath(item: $0, section: 0)
            )?.frame
        }
    }

    #if DEBUG
    // 推定高さが多数派の高さ (長文の付かない行の高さ = 可視セルの最小の高さ) に達するまで送り、
    // その高さを返す。達しないまま締切を過ぎたら失敗させる。
    private func settleMajorityEstimate(
        in controller: KsCollectionViewController<Item>
    ) async -> CGFloat {
        let step = controller.collectionView.bounds.height / 2
        var majority: CGFloat = 0
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        var steps = 0
        while clock.now < deadline {
            let heights = controller.collectionView.indexPathsForVisibleItems.compactMap {
                controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: $0)?.frame.height
            }
            if let shortest = heights.min() {
                majority = shortest
                if abs(controller.currentEstimatedHeight - shortest) < 0.5 {
                    return shortest
                }
            }
            controller.collectionView.setContentOffset(
                CGPoint(
                    x: controller.collectionView.contentOffset.x,
                    y: controller.collectionView.contentOffset.y + step
                ),
                animated: false
            )
            controller.collectionView.layoutIfNeeded()
            steps += 1
            if steps.isMultiple(of: 4) {
                try? await Task.sleep(for: .milliseconds(1))
            }
        }
        XCTFail(
            "推定高さが多数派の高さに達しませんでした "
                + "(推定 \(controller.currentEstimatedHeight) / 多数派 \(majority))"
        )
        return majority
    }
    #endif

    // contentSize が動かなくなるまで待つ。初回表示の見積もりを読む基準点にする。
    private func settleContentSize(in controller: KsCollectionViewController<Item>) async {
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
            } else if clock.now - quietSince >= .milliseconds(200) {
                return
            }
        }
        XCTFail("初回表示の contentSize が期限内に静止しませんでした。実測値: \(lastHeight)")
    }

    private func waitForVisibleItemCount(
        _ count: Int,
        in controller: KsCollectionViewController<Item>
    ) async {
        await waitUntil("\(count) 行の可視セル", value: {
            controller.collectionView.visibleCells.count
        }) { $0 == count }
    }

    private func settleAtStart(
        itemCount: Int,
        in controller: KsCollectionViewController<Item>
    ) async {
        await waitUntil("\(itemCount) 件の data source", value: {
            controller.collectionView.numberOfItems(inSection: 0)
        }) { $0 == itemCount }
        controller.collectionView.scrollToItem(
            at: IndexPath(item: 0, section: 0),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        await waitForVisibleItemCount(itemCount, in: controller)
    }

    private func assertSeparatorPositions(
        itemCount: Int,
        in controller: KsCollectionViewController<Item>
    ) {
        for index in 0..<itemCount {
            let cell = tryUnwrapCell(controller, item: index)
            XCTAssertEqual(cell.isTopSeparatorVisible, index == 0)
            XCTAssertTrue(cell.isBottomSeparatorVisible)
        }
    }

    private func show(
        controller: UIViewController,
        size: CGSize
    ) -> UIView {
        let hostView = UIView(frame: CGRect(origin: .zero, size: size))
        controller.loadViewIfNeeded()
        controller.view.frame = hostView.bounds
        hostView.addSubview(controller.view)
        controller.view.layoutIfNeeded()
        return hostView
    }

    private func showInWindow(
        controller: UIViewController,
        size: CGSize
    ) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    private func resize(
        window: UIView,
        controller: UIViewController,
        to size: CGSize
    ) {
        window.frame = CGRect(origin: .zero, size: size)
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    private func tryUnwrapCell(
        _ controller: KsCollectionViewController<Item>,
        item: Int
    ) -> KsHostingCell {
        guard let cell = controller.collectionView.cellForItem(
            at: IndexPath(item: item, section: 0)
        ) as? KsHostingCell else {
            XCTFail("項目 \(item) のセルを取得できませんでした")
            return KsHostingCell(frame: .zero)
        }
        return cell
    }

    private func visibleIdentifiers(
        in controller: KsCollectionViewController<Item>
    ) -> [AnyHashable] {
        let identifiers = controller.appliedItemIdentifiers
        return controller.collectionView.indexPathsForVisibleItems.sorted().compactMap {
            identifiers.indices.contains($0.item) ? identifiers[$0.item] : nil
        }
    }

    // 表示範囲の先頭にある 2 行の間隔 (行間の反映を観測するために使う)。
    private func leadingRowSpacing(
        in controller: KsCollectionViewController<Item>
    ) -> CGFloat? {
        let frames = controller.collectionView.indexPathsForVisibleItems.sorted().prefix(2).compactMap {
            controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: $0)?.frame
        }
        guard frames.count == 2 else { return nil }
        return frames[1].minY - frames[0].maxY
    }

    // 指定位置まで送り、そのときの先頭可視要素を返す (レイアウト切り替えのアンカーになる要素)。
    private func scrollToDeepPosition(
        item: Int,
        in controller: KsCollectionViewController<Item>
    ) async -> AnyHashable {
        controller.collectionView.scrollToItem(
            at: IndexPath(item: item, section: 0),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        await waitUntil("深い位置の可視セル", value: { visibleIdentifiers(in: controller).first }) {
            $0 != nil
        }
        guard let anchor = visibleIdentifiers(in: controller).first else {
            XCTFail("先頭可視要素を取得できませんでした")
            return AnyHashable(0)
        }
        return anchor
    }

    // 目的の位置が表示されるまで `step` ずつ送る。各段階の後に `onStep` を呼ぶ。
    private func advanceUntilVisible(
        item: Int,
        in controller: KsCollectionViewController<Item>,
        step: CGFloat,
        onStep: () -> Void = {}
    ) async -> Bool {
        let limit = 4_000
        var steps = 0
        for _ in 0..<limit {
            if isVisible(item: item, in: controller) {
                return true
            }
            controller.collectionView.setContentOffset(
                CGPoint(
                    x: controller.collectionView.contentOffset.x,
                    y: controller.collectionView.contentOffset.y + step
                ),
                animated: false
            )
            controller.collectionView.layoutIfNeeded()
            // 数段階ごとに実行機会を譲る。譲らないと UIKit がセルを手放す機会を持てず、
            // 同時生存数が走査した件数に比例して見えてしまう。
            steps += 1
            if steps.isMultiple(of: 8) {
                try? await Task.sleep(for: .milliseconds(1))
            }
            onStep()
        }
        return isVisible(item: item, in: controller)
    }

    // 末尾まで送ってから先頭へ戻る。再利用プールが埋まった状態を作るために使う。
    @discardableResult
    private func advanceRoundTrip(
        itemCount: Int,
        in controller: KsCollectionViewController<Item>,
        onStep: () -> Void = {}
    ) async -> Bool {
        let step = controller.collectionView.bounds.height / 2
        let advanced = await advanceUntilVisible(
            item: itemCount - 1,
            in: controller,
            step: step,
            onStep: onStep
        )
        XCTAssertTrue(advanced, "末尾まで送り切れませんでした")
        guard advanced else { return false }
        let returned = await advanceUntilVisible(item: 0, in: controller, step: -step, onStep: onStep)
        XCTAssertTrue(returned, "先頭まで戻り切れませんでした")
        return returned
    }

    private func isVisible(
        item: Int,
        in controller: KsCollectionViewController<Item>
    ) -> Bool {
        controller.collectionView.indexPathsForVisibleItems.contains {
            $0.section == 0 && $0.item == item
        }
    }

    private func anchorAttributes(
        _ anchor: AnyHashable,
        in controller: KsCollectionViewController<Item>
    ) -> UICollectionViewLayoutAttributes? {
        guard let index = controller.appliedItemIdentifiers.firstIndex(of: anchor) else { return nil }
        return controller.collectionView.collectionViewLayout.layoutAttributesForItem(
            at: IndexPath(item: index, section: 0)
        )
    }

    // アンカー上端と表示範囲上端の差。復元方式を数値で固定するための観測値。
    private func anchorOffsetFromTop(
        _ anchor: AnyHashable,
        in controller: KsCollectionViewController<Item>
    ) -> CGFloat? {
        guard let attributes = anchorAttributes(anchor, in: controller) else { return nil }
        return attributes.frame.minY - controller.collectionView.bounds.minY
    }

    private func anchorHeight(
        _ anchor: AnyHashable,
        in controller: KsCollectionViewController<Item>
    ) -> CGFloat? {
        anchorAttributes(anchor, in: controller)?.frame.height
    }

    // 先頭可視行を高さの `fraction` だけ表示範囲の上へはみ出させ、そのあとの先頭可視要素と
    // そのオフセットを返す。行の境界に揃っていない任意の位置から復元させるために使う。
    private func clipLeadingAnchor(
        in controller: KsCollectionViewController<Item>,
        fraction: CGFloat
    ) -> (anchor: AnyHashable, offsetFromTop: CGFloat) {
        guard
            let leading = visibleIdentifiers(in: controller).first,
            let offset = anchorOffsetFromTop(leading, in: controller),
            let height = anchorHeight(leading, in: controller)
        else {
            XCTFail("先頭可視要素のレイアウト属性を取得できませんでした")
            return (AnyHashable(0), 0)
        }
        controller.collectionView.setContentOffset(
            CGPoint(
                x: controller.collectionView.contentOffset.x,
                y: controller.collectionView.contentOffset.y + offset + height * fraction
            ),
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        guard
            let clipped = visibleIdentifiers(in: controller).first,
            let clippedOffset = anchorOffsetFromTop(clipped, in: controller)
        else {
            XCTFail("クリップ後の先頭可視要素を取得できませんでした")
            return (AnyHashable(0), 0)
        }
        XCTAssertLessThan(
            clippedOffset,
            0,
            "先頭可視要素が行境界に揃っており、任意 offset からの復元になっていません"
        )
        return (clipped, clippedOffset)
    }

    private func leadingItemFrame(
        in controller: KsCollectionViewController<Item>
    ) -> CGRect? {
        guard let indexPath = controller.collectionView.indexPathsForVisibleItems.min() else { return nil }
        return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
    }

    // スクロールインジケータの位置は contentInset とインジケータ用 inset だけで決まる。
    // 内側余白はセクションの内側で吸収されるため、どちらも 0 のままであることが「余白に寄らない」の観測になる。
    private func assertScrollIndicatorStaysAtComponentEdge(
        in controller: KsCollectionViewController<Item>,
        paddingDescription: String
    ) {
        XCTAssertEqual(
            controller.collectionView.contentInset,
            .zero,
            "左右余白 \(paddingDescription) が contentInset へ漏れています"
        )
        XCTAssertEqual(
            controller.collectionView.adjustedContentInset,
            .zero,
            "左右余白 \(paddingDescription) が adjustedContentInset へ漏れています"
        )
        XCTAssertEqual(
            controller.collectionView.verticalScrollIndicatorInsets,
            .zero,
            "左右余白 \(paddingDescription) がスクロールインジケータの位置へ漏れています"
        )
    }

    private func visibleHeaderCount(
        in controller: KsCollectionViewController<Item>
    ) -> Int {
        controller.collectionView.visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionHeader
        ).count
    }

    private func headerFrame(
        in controller: KsCollectionViewController<Item>
    ) -> CGRect? {
        controller.collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )?.frame
    }

    private func visibleCellWidths(
        in controller: KsCollectionViewController<Item>
    ) -> [CGFloat] {
        controller.collectionView.indexPathsForVisibleItems.compactMap {
            controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: $0)?.frame.width
        }
    }

    private func columnCount(
        in controller: KsCollectionViewController<Item>
    ) -> Int {
        let positions = (0..<8).compactMap {
            controller.collectionView.collectionViewLayout.layoutAttributesForItem(
                at: IndexPath(item: $0, section: 0)
            )?.frame.minX
        }
        return positions.reduce(into: [CGFloat]()) { columns, position in
            if !columns.contains(where: { abs($0 - position) < 1 }) {
                columns.append(position)
            }
        }.count
    }

    private func renderedImageData(of view: UIView) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            view.layer.render(in: context.cgContext)
        }.pngData()
    }

    private func renderedPixels(of view: UIView, at points: [CGPoint]) -> [UInt32] {
        let width = Int(view.bounds.width)
        let height = Int(view.bounds.height)
        guard width > 0, height > 0 else { return [] }
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return
            }
            view.layer.render(in: context)
        }
        return points.map { point in
            let x = min(max(Int(point.x), 0), width - 1)
            let y = min(max(Int(point.y), 0), height - 1)
            let offset = (y * width + x) * 4
            return UInt32(buffer[offset]) << 24
                | UInt32(buffer[offset + 1]) << 16
                | UInt32(buffer[offset + 2]) << 8
                | UInt32(buffer[offset + 3])
        }
    }

    private func firstControl(in view: UIView) -> UIControl? {
        for subview in view.subviews {
            if let control = subview as? UIControl {
                return control
            }
            if let control = firstControl(in: subview) {
                return control
            }
        }
        return nil
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(2)
        while clock.now < deadline {
            let current = value()
            if predicate(current) {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))")
    }
}
