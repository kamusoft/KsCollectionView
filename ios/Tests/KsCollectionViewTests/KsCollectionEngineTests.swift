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

        await waitUntil("data source 件数", value: { ksTotalItemCount(in: controller.collectionView) }) {
            $0 == 100
        }

        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), 100)
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
        await waitUntil("data source 件数", value: { ksTotalItemCount(in: controller.collectionView) }) {
            $0 == 1
        }

        controller.collectionView(
            controller.collectionView,
            didSelectItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )

        XCTAssertEqual(tapped, item)
    }

    func testデータ差し替えとレイアウト切り替えを同じControllerへ適用する() async {
        let initial = (0..<20).map { Item(id: $0, title: "項目 \($0)") }
        let controller = KsCollectionViewController(configuration: makeConfiguration(items: initial))
        controller.loadViewIfNeeded()
        await waitUntil("初期 data source 件数", value: { ksTotalItemCount(in: controller.collectionView) }) {
            $0 == 20
        }

        let updated = (10..<40).map { Item(id: $0, title: "更新 \($0)") }
        var configuration = makeConfiguration(items: updated)
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)
        controller.update(configuration: configuration)
        await waitUntil("更新後 data source 件数", value: { ksTotalItemCount(in: controller.collectionView) }) {
            $0 == 30
        }

        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), 30)
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
                ofKind: KsSupplementaryKind.rootHeader
            ).count + controller.collectionView.visibleSupplementaryViews(
                ofKind: KsSupplementaryKind.rootFooter
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
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), 2)
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

        controller.collectionView(
            controller.collectionView,
            didHighlightItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )
        cell.layoutIfNeeded()

        XCTAssertTrue(cell.isTouchFeedbackVisible)
        XCTAssertEqual(cell.touchFeedbackColor, color)
        XCTAssertGreaterThan(cell.touchFeedbackZPosition, cell.contentViewZPosition)
        XCTAssertNotEqual(normalImage, renderedImageData(of: cell))

        controller.collectionView(
            controller.collectionView,
            didUnhighlightItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )
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
        controller.performLongPress(at: ksIndexPath(forItemOffset: 0, in: controller.collectionView))
        controller.collectionView(
            controller.collectionView,
            didSelectItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )

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
        let indexPath = ksIndexPath(forItemOffset: 0, in: controller.collectionView)
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
            ksTotalItemCount(in: controller.collectionView)
        }) { $0 == 4 }

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [2, 0].map { ksIndexPath(forItemOffset: $0, in: controller.collectionView) }
        )
        controller.collectionView(
            controller.collectionView,
            cancelPrefetchingForItemsAt: [ksIndexPath(forItemOffset: 1, in: controller.collectionView)]
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
            let first = itemFrames(in: controller, items: [0]).first
            let second = itemFrames(in: controller, items: [1]).first
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
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), 30)
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
            at: ksIndexPath(forItemOffset: 50, in: controller.collectionView),
            at: .bottom,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView),
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
        XCTAssertEqual(onScreenLeadingIdentifier(in: controller), anchor)
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
                onScreenLeadingIdentifier(in: controller),
                anchor,
                "行間 \(Double(step) * 6) への変更で画面上の先頭の項目が変わりました"
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

    // 配列は内部で固定件数の塊に分けて載る。塊ごとに item が 0 から始まるため、item だけで
    // 数えると別の塊の項目と重なる。全体の順番 (塊をまたいだ通し番号) なら全件を一意に数えられる。
    func test塊に分かれても項目を全体の順番で一意に数えられる() async {
        let itemCount = 2_000
        let controller = KsCollectionViewController(
            configuration: makeConfiguration(
                items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
            )
        )
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        let sectionCount = controller.collectionView.numberOfSections
        XCTAssertGreaterThan(sectionCount, 1, "配列が 1 つの塊に収まっており、塊をまたぐ検証になっていません")
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), itemCount)

        var offsets: Set<Int> = []
        for section in 0..<sectionCount {
            for item in 0..<controller.collectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                guard let offset = ksItemOffset(for: indexPath, in: controller.collectionView) else {
                    XCTFail("\(indexPath) の全体の順番を求められませんでした")
                    return
                }
                XCTAssertTrue(
                    offsets.insert(offset).inserted,
                    "全体の順番 \(offset) が重複しています (\(indexPath))"
                )
                XCTAssertEqual(
                    ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView),
                    indexPath,
                    "全体の順番 \(offset) が元の位置へ戻りません"
                )
            }
        }
        XCTAssertEqual(offsets, Set(0..<itemCount), "全件を通し番号で数え切れていません")

        // 塊の境界では item が 0 に戻り、次の塊の先頭になる。
        let firstChunkCount = controller.collectionView.numberOfItems(inSection: 0)
        XCTAssertEqual(
            ksIndexPath(forItemOffset: firstChunkCount - 1, in: controller.collectionView),
            IndexPath(item: firstChunkCount - 1, section: 0)
        )
        XCTAssertEqual(
            ksIndexPath(forItemOffset: firstChunkCount, in: controller.collectionView),
            IndexPath(item: 0, section: 1)
        )
        XCTAssertNil(ksIndexPathIfPresent(forItemOffset: itemCount, in: controller.collectionView))

        // 通し番号の変換は本体の入口を通る。Sample の通過記録も同じ入口を使う。
        XCTAssertEqual(
            KsItemOffsetLookup.itemOffset(of: IndexPath(item: 0, section: 1), in: controller.collectionView),
            firstChunkCount
        )
        XCTAssertEqual(KsItemOffsetLookup.totalItemCount(in: controller.collectionView), itemCount)
    }

    // 塊の件数は列数の倍数へ切り上げた値になる。layout から列数、列数から塊の件数、塊の件数から
    // snapshot の section までが繋がっていることを、表示形態ごとに実際の snapshot で確かめる。
    func test塊の件数と数がlayoutごとの列数の倍数になる() async {
        let itemCount = 2_000

        await assertChunkStructure(
            layout: .list,
            itemCount: itemCount,
            expected: [500, 500, 500, 500]
        )
        // 500 は 3 で割り切れないため 501 件ずつに割れる。
        await assertChunkStructure(
            layout: .grid(columns: .fixed(3)),
            itemCount: itemCount,
            expected: [501, 501, 501, 497]
        )
        // 向き別列数では両方の列数の最小公倍数 (2 と 3 で 6) の倍数にする。
        await assertChunkStructure(
            layout: .grid(columns: .fixed(portrait: 2, landscape: 3)),
            itemCount: itemCount,
            expected: [504, 504, 504, 488]
        )
    }

    // 塊の境界が行の切れ目に落ちることを位置で確かめる。件数が列数で割り切れることが境界の条件に
    // なるのは「塊の先頭の項目が行頭に置かれる」前提の下だけなので、その前提ごと固定する。
    func test塊の境界の直前の行が埋まり直後の項目が行頭に置かれる() async {
        let itemCount = 2_000
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = .grid(columns: .fixed(2))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        let counts = sectionItemCounts(in: controller)
        XCTAssertEqual(counts, [500, 500, 500, 500])
        let boundary = counts[0]

        let frames = itemFrames(
            in: controller,
            items: [boundary - 2, boundary - 1, boundary, boundary + 1]
        )
        guard frames.count == 4 else {
            XCTFail("境界の前後の項目のレイアウト属性を取得できませんでした (\(frames.count) 件)")
            return
        }
        // 境界の直前の行は 2 列とも埋まる。
        XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 1, "境界の直前の 2 項目が同じ行にありません")
        XCTAssertLessThan(frames[0].minX, frames[1].minX, "境界の直前の 2 項目が同じ列に重なっています")
        // 境界の直後の項目 (次の塊の先頭) は新しい行の行頭に置かれる。
        XCTAssertEqual(frames[2].minX, frames[0].minX, accuracy: 1, "塊の先頭の項目が行頭に置かれていません")
        XCTAssertGreaterThan(frames[2].minY, frames[1].minY, "塊の先頭の項目が直前の行に残っています")
        XCTAssertEqual(frames[3].minY, frames[2].minY, accuracy: 1, "境界の直後の 2 項目が同じ行にありません")
        XCTAssertEqual(frames[3].minX, frames[1].minX, accuracy: 1, "境界の直後の 2 項目の列が揃っていません")
    }

    // adaptive の列数は最初のレイアウトパスまで決まらないため、初回は列数 1 として 500 件ずつに割れる。
    // 列数が確定した時点で、解決した列数 (幅 390 / 最小幅 120 で 3 列) の倍数へ自動で組み直す。
    // 更新が 1 度も届かない画面でも境界に不完全な行を残さないため、確定そのものを契機にする。
    func testadaptiveは列数が確定した最初のレイアウトで塊を組み直す() async {
        let itemCount = 2_000
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = .grid(columns: .adaptive(minItemWidth: 120))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        await waitUntil("組み直した塊の件数", value: { sectionItemCounts(in: controller) }) {
            $0 == [501, 501, 501, 497]
        }
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), itemCount)
    }

    // 塊の件数が変わる更新は早期 return を抜けて組み直しへ進む。そこでも同値配列の可視セルは
    // 作り直す (ios/ADR-0006)。テンプレートが親の状態を捕捉していると、作り直さないセルは
    // 古い値のまま取り残される。
    func test塊を組み直す同値配列の更新でも可視セルを作り直す() async {
        for itemCount in [2_000, 300] {
            let builds = BuildRecorder()
            var configuration = makeConfiguration(
                items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
            ) { item in
                let _ = builds.record(item.id)
                Text(item.title)
            }
            configuration.layout = .grid(columns: .adaptive(minItemWidth: 120))
            let controller = KsCollectionViewController(configuration: configuration)
            let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
            defer { window.isHidden = true }
            await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
            // 幅 390 / 最小幅 120 で 3 列に解決し、塊は 501 件へ組み直される。
            await waitUntil("列数の解決後の組み直し", value: { controller.chunkRebuildCount }) { $0 == 1 }
            XCTAssertEqual(
                sectionItemCounts(in: controller),
                itemCount <= 501 ? [itemCount] : [501, 501, 501, 497]
            )

            // 幅を狭めて 1 列にすると塊の件数は 500 へ戻る。組み直しの予約が走る前に更新を届けると、
            // 同値配列のまま塊の件数だけが変わる更新になる。項目数が塊の件数以下なら 1 つの塊に
            // 収まり、組み直しても snapshot は同一になる (差分適用では何も起きない状況)。
            resize(window: window, controller: controller, to: CGSize(width: 180, height: 844))
            let visibleOffsets = visibleItemOffsets(in: controller)
            XCTAssertFalse(visibleOffsets.isEmpty, "可視セルが無く、作り直しを観測できません (件数 \(itemCount))")
            let buildsBeforeUpdate = builds.counts

            controller.update(configuration: configuration)
            controller.collectionView.layoutIfNeeded()
            XCTAssertEqual(
                sectionItemCounts(in: controller),
                itemCount <= 500 ? [itemCount] : [500, 500, 500, 500],
                "塊の件数が変わる更新になっていません (件数 \(itemCount))"
            )

            for offset in visibleOffsets {
                XCTAssertGreaterThanOrEqual(
                    builds.counts[offset] ?? 0,
                    (buildsBeforeUpdate[offset] ?? 0) + 1,
                    "項目 \(offset) のテンプレートが呼び直されていません (件数 \(itemCount))"
                )
            }
        }
    }

    // 塊の境界は見た目に現れない。境界の前後の行間は他の行間と同じで、内側余白は配列全体の
    // 上下にだけ付く。
    func test塊の境界に行間だけが入り内側余白は配列全体の上下にだけ付く() async {
        let itemCount = 1_200
        var configuration = makeUniformHeightListConfiguration(itemCount: itemCount)
        configuration.layout = .list(rowSpacing: 8)
        configuration.contentPadding = EdgeInsets(top: 20, leading: 0, bottom: 24, trailing: 0)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        XCTAssertGreaterThan(
            controller.collectionView.numberOfSections,
            1,
            "配列が 1 つの塊に収まっており、境界の検証になっていません"
        )

        let boundary = controller.collectionView.numberOfItems(inSection: 0)
        let frames = itemFrames(
            in: controller,
            items: [0, boundary - 2, boundary - 1, boundary, itemCount - 1]
        )
        XCTAssertEqual(frames.count, 5, "境界の前後のレイアウト属性を取得できませんでした")
        guard frames.count == 5 else { return }
        let spacingWithinChunk = frames[2].minY - frames[1].maxY
        let spacingAtBoundary = frames[3].minY - frames[2].maxY
        XCTAssertEqual(spacingWithinChunk, 8, accuracy: 0.5, "塊の中の行間が宣言と違います")
        XCTAssertEqual(
            spacingAtBoundary,
            spacingWithinChunk,
            accuracy: 0.5,
            "塊の境界の行間が他の行間と違います (境界 \(spacingAtBoundary) / 他 \(spacingWithinChunk))"
        )
        XCTAssertEqual(frames[0].minY, 20, accuracy: 0.5, "先頭の上の内側余白が反映されていません")
        XCTAssertEqual(
            controller.collectionView.contentSize.height - frames[4].maxY,
            24,
            accuracy: 0.5,
            "末尾の下の内側余白が反映されていません"
        )
    }

    // ヘッダーは配列全体の先頭に 1 つ、フッターは末尾に 1 つだけ付く。項目が空でも両方が出る。
    func testヘッダーとフッターは塊が増えても1つずつで空配列でも表示される() async {
        let itemCount = 1_200
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.header = { AnyView(Text("ヘッダー")) }
        configuration.footer = { AnyView(Text("フッター")) }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        XCTAssertGreaterThan(
            controller.collectionView.numberOfSections,
            1,
            "配列が 1 つの塊に収まっており、境界の検証になっていません"
        )

        let counts = supplementaryKindCounts(in: controller)
        XCTAssertEqual(
            counts[KsSupplementaryKind.rootHeader] ?? 0,
            1,
            "ヘッダーが塊の数だけ作られています (\(counts))"
        )
        XCTAssertEqual(
            counts[KsSupplementaryKind.rootFooter] ?? 0,
            1,
            "フッターが塊の数だけ作られています (\(counts))"
        )
        // ヘッダーは先頭の項目の上、フッターは末尾の項目の下に置かれる。
        let frames = itemFrames(in: controller, items: [0, itemCount - 1])
        XCTAssertEqual(frames.count, 2)
        if let header = headerFrame(in: controller), frames.count == 2 {
            XCTAssertLessThanOrEqual(header.maxY, frames[0].minY + 0.5)
        } else {
            XCTFail("ヘッダーのレイアウト属性を取得できませんでした")
        }
        if let footer = footerFrame(in: controller), frames.count == 2 {
            XCTAssertGreaterThanOrEqual(footer.minY, frames[1].maxY - 0.5)
        } else {
            XCTFail("フッターのレイアウト属性を取得できませんでした")
        }

        configuration.items = []
        controller.update(configuration: configuration)
        await waitUntil("空配列の snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 0 }
        controller.collectionView.layoutIfNeeded()
        await waitUntil("空配列のヘッダー", value: { visibleHeaderCount(in: controller) }) { $0 == 1 }
        await waitUntil("空配列のフッター", value: {
            controller.collectionView.visibleSupplementaryViews(
                ofKind: KsSupplementaryKind.rootFooter
            ).count
        }) { $0 == 1 }
    }

    // 上端の区切り線は配列全体の先頭の行にだけ出る。塊の境界では位置の item が 0 に戻るが、
    // そこに線を出してはいけない。
    func test塊の境界で上端の区切り線が出ない() async {
        let itemCount = 1_200
        var configuration = makeUniformHeightListConfiguration(itemCount: itemCount)
        configuration.showsSeparators = true
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        XCTAssertGreaterThan(
            controller.collectionView.numberOfSections,
            1,
            "配列が 1 つの塊に収まっており、境界の検証になっていません"
        )
        controller.collectionView.layoutIfNeeded()
        XCTAssertTrue(
            tryUnwrapCell(controller, item: 0).isTopSeparatorVisible,
            "配列全体の先頭に上端の区切り線が出ていません"
        )

        let boundary = controller.collectionView.numberOfItems(inSection: 0)
        let reached = await advanceUntilVisible(
            item: boundary,
            in: controller,
            step: controller.collectionView.bounds.height / 2
        )
        XCTAssertTrue(reached, "塊の境界まで送り切れませんでした")
        guard reached else { return }
        controller.collectionView.layoutIfNeeded()
        let boundaryCell = tryUnwrapCell(controller, item: boundary)
        XCTAssertFalse(
            boundaryCell.isTopSeparatorVisible,
            "塊の境界の先頭の項目に上端の区切り線が出ています"
        )
        XCTAssertTrue(boundaryCell.isBottomSeparatorVisible)
    }

    // 向き別列数の塊の件数は両方の列数の最小公倍数の倍数なので、回転しても組み直さずに
    // 境界が行の切れ目に落ちる。
    func test向き別列数では回転しても塊を組み直さず不完全な行が出ない() async {
        let itemCount = 1_200
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = .grid(columns: .fixed(portrait: 2, landscape: 3))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        let portraitCounts = sectionItemCounts(in: controller)
        XCTAssertEqual(portraitCounts, [504, 504, 192])
        let rebuildsBeforeRotation = controller.chunkRebuildCount

        // 塊の境界より先まで送ってから回す。アンカーは送り切った後に実際に画面の先頭にあった
        // 項目から採る (送り先が画面の上端に丁度収まるかは行の高さ次第で変わるため)。
        let anchor = await leadingOffsetAfterScrolling(to: 600, in: controller)

        rotate(window: window, controller: controller, to: CGSize(width: 844, height: 390))
        await waitUntil("横向きの列数", value: { columnCount(in: controller) }) { $0 == 3 }

        XCTAssertEqual(sectionItemCounts(in: controller), portraitCounts, "回転で塊を組み直しています")
        XCTAssertEqual(
            controller.chunkRebuildCount,
            rebuildsBeforeRotation,
            "最小公倍数で組んだ塊は回転で組み直さないはずです"
        )
        // 最終の塊を除く塊の件数は、縦横どちらの列数でも割り切れる (境界に不完全な行が無い)。
        for count in portraitCounts.dropLast() {
            XCTAssertEqual(count % 2, 0, "縦向きの列数で割り切れません (\(count))")
            XCTAssertEqual(count % 3, 0, "横向きの列数で割り切れません (\(count))")
        }

        // 塊を組み直さない回転でも、表示範囲の先頭にあった項目は先頭の行に留まる。
        await assertLeadingItemSharesRow(with: anchor, in: controller)

        // 戻す向きでも同じく先頭の行に留まる。
        rotate(window: window, controller: controller, to: CGSize(width: 390, height: 844))
        await waitUntil("戻した後の列数", value: { columnCount(in: controller) }) { $0 == 2 }
        await assertLeadingItemSharesRow(with: anchor, in: controller)
    }

    // adaptive では列数がレイアウトで決まるため、塊の件数が新しい列数で割り切れなくなったら
    // 組み直す。組み直しても表示範囲の先頭にあった項目は先頭に留まる。
    func testadaptiveで列数が変わると塊を組み直して先頭の項目を保つ() async {
        let itemCount = 2_000
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = .grid(columns: .adaptive(minItemWidth: 120))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        // 幅 390 / 最小幅 120 で 3 列に解決し、塊は 3 の倍数 (501) へ組み直される。
        await waitUntil("列数の解決後の塊", value: { sectionItemCounts(in: controller) }) {
            $0 == [501, 501, 501, 497]
        }

        // アンカーは送り切った後に実際に画面の先頭にあった項目から採る。定数で決め打ちして待つと、
        // 行の高さが機種の文字設定で変わったときに送り先が半端な位置に落ちて前提が崩れる。
        let anchor = await leadingOffsetAfterScrolling(to: 900, in: controller)

        // 幅を狭めると 1 列になり、501 件では列数の倍数のまま塊を保てない。
        resize(window: window, controller: controller, to: CGSize(width: 180, height: 844))
        await waitUntil("組み直した塊", value: { sectionItemCounts(in: controller) }) {
            $0 == [500, 500, 500, 500]
        }
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), itemCount)
        await assertLeadingItemSharesRow(with: anchor, in: controller)
    }

    // 列数が変わっても現在の塊の件数が割り切れるなら組み直さない。
    func test割り切れる列数の変化では塊を組み直さない() async {
        let itemCount = 2_000
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = .grid(columns: .adaptive(minItemWidth: 180))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        // 幅 390 / 最小幅 180 で 2 列。500 は 2 で割り切れるので組み直しは起きない。
        await waitUntil("初期の列数", value: { columnCount(in: controller) }) { $0 == 2 }
        XCTAssertEqual(sectionItemCounts(in: controller), [500, 500, 500, 500])
        XCTAssertEqual(controller.chunkRebuildCount, 0, "割り切れる列数の解決で塊を組み直しています")

        // 幅を広げて 4 列にしても 500 は 4 で割り切れる。
        resize(window: window, controller: controller, to: CGSize(width: 800, height: 844))
        await waitUntil("広げた後の列数", value: { columnCount(in: controller) }) { $0 == 4 }
        XCTAssertEqual(sectionItemCounts(in: controller), [500, 500, 500, 500])
        XCTAssertEqual(controller.chunkRebuildCount, 0, "割り切れる列数の変化で塊を組み直しています")
    }

    // 表示形態の切り替えでも塊の件数は変わる (1 列の 500 件から 3 列の 501 件へ)。件数が変われば
    // 先頭の塊を除くほぼ全項目が隣の塊へ移るため、列数の解決で組み直すときと同じ緩和 (アニメーションを
    // 付けない・復元を適用の後の実行機会まで待つ) を通す (ios/ADR-0009)。
    func test表示形態の切り替えで塊の件数が変わっても先頭の項目を保つ() async {
        var configuration = makeUniformHeightListConfiguration(itemCount: 2_000)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 2_000 }
        XCTAssertEqual(sectionItemCounts(in: controller), [500, 500, 500, 500])

        configuration.layout = .grid(columns: .fixed(3))
        await assertAnchorSurvivesChunkSizeChange(
            configuration: configuration,
            in: controller,
            expectedSectionItemCounts: [501, 501, 501, 497]
        )
    }

    // 列数の指定を変えるだけでも塊の件数は変わる (2 列の 500 件から 3 列の 501 件へ)。
    func test列数の指定の変更で塊の件数が変わっても先頭の項目を保つ() async {
        var configuration = makeUniformHeightListConfiguration(itemCount: 2_000)
        configuration.layout = .grid(columns: .fixed(2))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 2_000 }
        XCTAssertEqual(sectionItemCounts(in: controller), [500, 500, 500, 500])

        configuration.layout = .grid(columns: .fixed(3))
        await assertAnchorSurvivesChunkSizeChange(
            configuration: configuration,
            in: controller,
            expectedSectionItemCounts: [501, 501, 501, 497]
        )
    }

    // 表示の変化に備えて控えた位置は、利用者がドラッグを始めた時点で捨てる。捨てずに残すと、
    // 適用が重なって復元が遅れている間に利用者が動かした位置を、後から控えた位置へ引き戻す。
    func testドラッグを始めると控えた位置を捨てる() async {
        let itemCount = 200
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = .grid(columns: .fixed(2))
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        // 表示領域の大きさが変わる直前の経路で位置を控えさせる (frame はまだ差し替えない)。
        controller.viewWillTransition(
            to: CGSize(width: 844, height: 390),
            with: KsTransitionCoordinatorStub(containerView: window)
        )
        XCTAssertTrue(controller.hasPendingAnchor, "表示領域の変化の直前に位置を控えていません")

        controller.scrollViewWillBeginDragging(controller.collectionView)
        XCTAssertFalse(controller.hasPendingAnchor, "ドラッグを始めても控えた位置が残っています")
    }

    // 深い位置まで送ってから構成を差し替え、塊の件数が変わった後も表示範囲の先頭にあった項目が
    // 先頭付近に留まることを確かめる。
    private func assertAnchorSurvivesChunkSizeChange(
        configuration: KsCollectionConfiguration<Item>,
        in controller: KsCollectionViewController<Item>,
        expectedSectionItemCounts: [Int]
    ) async {
        let anchor = await leadingOffsetAfterScrolling(to: 900, in: controller)

        controller.update(configuration: configuration)

        await waitUntil("差し替え後の塊", value: { sectionItemCounts(in: controller) }) {
            $0 == expectedSectionItemCounts
        }
        // 塊の件数が変わると先頭の塊を除くほぼ全項目が隣の塊へ移るが、画面の先頭にあった項目は
        // 先頭の行に留まる。列数が増えると同じ行の行頭はアンカーより前の項目になるため、
        // 画面の先頭の項目そのものの一致ではなく、同じ行にいることで見る。
        await assertLeadingItemSharesRow(with: anchor, in: controller)
    }

    // 指定した位置まで送り、位置が落ち着いた時点で実際に画面の先頭にあった項目の全体の順番を返す。
    // 先頭を定数で決め打ちして待つと、行の高さが機種の文字設定で変わったときに送り先が半端な
    // 位置に落ち、1 つ手前の項目が上端に残ったままテストの前提が崩れる。
    private func leadingOffsetAfterScrolling(
        to item: Int,
        in controller: KsCollectionViewController<Item>
    ) async -> Int {
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: item, in: controller.collectionView),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        // 送った直後は途中の行が推定のままで位置が動き続けるため、静止してから先頭を読む。
        await settleContentSize(in: controller)
        guard let offset = onScreenItemOffsets(in: controller).first else {
            XCTFail("送った後の画面上の先頭の項目を取得できませんでした")
            return item
        }
        return offset
    }

    // 画面の先頭にある項目がアンカーと同じ行にいることを確かめる。行の同一性はレイアウト属性の
    // 上端で見る — 列数が変わると 1 行に入る件数が変わるため、順番の差では決められない。
    private func assertLeadingItemSharesRow(
        with anchor: Int,
        in controller: KsCollectionViewController<Item>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await waitUntil(
            "画面の先頭の項目とアンカー (項目 \(anchor)) の行の上端",
            value: { leadingRowComparison(with: anchor, in: controller) },
            predicate: { comparison in
                guard let comparison else { return false }
                return abs(comparison.leadingRowTop - comparison.anchorRowTop) < 1
            },
            file: file,
            line: line
        )
    }

    // 画面の先頭にある項目の順番と、その項目およびアンカーの行の上端。
    private func leadingRowComparison(
        with anchor: Int,
        in controller: KsCollectionViewController<Item>
    ) -> (leadingItem: Int, leadingRowTop: CGFloat, anchorRowTop: CGFloat)? {
        guard let leading = onScreenItemOffsets(in: controller).first else { return nil }
        let frames = itemFrames(in: controller, items: [leading, anchor])
        guard frames.count == 2 else { return nil }
        return (leading, frames[0].minY, frames[1].minY)
    }

    // 先頭に 1 件挿入すると全項目の順番が 1 つずれ、塊の境界の項目は隣の塊へ移る。
    // 表示範囲の先頭の項目は挿入した行の分だけ動き、それ以外に飛ばない。
    // 塊の所属が変わらない可視セルは作り直されない。
    func test先頭への挿入で塊の所属が変わっても位置が飛ばない() async {
        let itemCount = 2_000
        var configuration = makeUniformHeightListConfiguration(itemCount: itemCount)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        let boundary = controller.collectionView.numberOfItems(inSection: 0)
        XCTAssertGreaterThan(controller.collectionView.numberOfSections, 1)

        // 塊の境界が表示範囲に入る位置まで、行を解かせながら送る。飛ばして送ると境界より上の行が
        // 推定のまま残り、挿入による位置の動きが行の高さと比べられなくなる。
        let anchor = await advanceToSolvedPosition(item: boundary - 4, in: controller)
        let rowHeight = anchorHeight(anchor, in: controller) ?? 0
        XCTAssertGreaterThan(rowHeight, 0)
        guard let offsetBefore = anchorOffsetFromTop(anchor, in: controller) else {
            XCTFail("挿入前のアンカー位置を取得できませんでした")
            return
        }
        let chunksBefore = chunkIndexesByIdentifier(in: controller)
        let cellsBefore = visibleCellsByIdentifier(in: controller)

        configuration.items.insert(Item(id: -1, title: "先頭"), at: 0)
        controller.update(configuration: configuration)
        await waitUntil("挿入後の snapshot", value: { controller.appliedItemIdentifiers.count }) {
            $0 == itemCount + 1
        }
        controller.collectionView.layoutIfNeeded()
        await waitUntil("挿入後のアンカーの位置", value: { anchorOffsetFromTop(anchor, in: controller) }) {
            $0 != nil
        }

        guard let offsetAfter = anchorOffsetFromTop(anchor, in: controller) else {
            XCTFail("挿入後のアンカー位置を取得できませんでした")
            return
        }
        // 動きは挿入した 1 行の分までに収まる (実測では UIKit が表示中の内容を留めるため動かない)。
        // これを超えて動けば、塊の境界で位置が飛んでいる。
        XCTAssertLessThanOrEqual(
            abs(offsetAfter - offsetBefore),
            rowHeight + configuration.layout.rowSpacing + 2,
            "挿入した 1 行を超えて位置が飛んでいます (前 \(offsetBefore) / 後 \(offsetAfter) / 行 \(rowHeight))"
        )
        XCTAssertTrue(
            visibleIdentifiers(in: controller).contains(anchor),
            "挿入後にアンカーが表示範囲から外れています"
        )
        print("KS 先頭への挿入でのアンカーの動き: \(offsetAfter - offsetBefore) (行 \(rowHeight))")
        assertVisibleCellsSurviveWhereChunkUnchanged(
            in: controller,
            chunksBefore: chunksBefore,
            cellsBefore: cellsBefore,
            label: "先頭への挿入"
        )
    }

    // 先頭の 1 件を削除したときも、位置は削除した行の分だけ動く。
    func test先頭の削除で塊の所属が変わっても位置が飛ばない() async {
        let itemCount = 2_000
        var configuration = makeUniformHeightListConfiguration(itemCount: itemCount)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        let boundary = controller.collectionView.numberOfItems(inSection: 0)
        XCTAssertGreaterThan(controller.collectionView.numberOfSections, 1)

        let anchor = await advanceToSolvedPosition(item: boundary - 4, in: controller)
        let rowHeight = anchorHeight(anchor, in: controller) ?? 0
        XCTAssertGreaterThan(rowHeight, 0)
        guard let offsetBefore = anchorOffsetFromTop(anchor, in: controller) else {
            XCTFail("削除前のアンカー位置を取得できませんでした")
            return
        }
        let chunksBefore = chunkIndexesByIdentifier(in: controller)
        let cellsBefore = visibleCellsByIdentifier(in: controller)

        configuration.items.removeFirst()
        controller.update(configuration: configuration)
        await waitUntil("削除後の snapshot", value: { controller.appliedItemIdentifiers.count }) {
            $0 == itemCount - 1
        }
        controller.collectionView.layoutIfNeeded()
        await waitUntil("削除後のアンカーの位置", value: { anchorOffsetFromTop(anchor, in: controller) }) {
            $0 != nil
        }

        guard let offsetAfter = anchorOffsetFromTop(anchor, in: controller) else {
            XCTFail("削除後のアンカー位置を取得できませんでした")
            return
        }
        // 動きは削除した 1 行の分までに収まる (実測では UIKit が表示中の内容を留めるため動かない)。
        XCTAssertLessThanOrEqual(
            abs(offsetBefore - offsetAfter),
            rowHeight + configuration.layout.rowSpacing + 2,
            "削除した 1 行を超えて位置が飛んでいます (前 \(offsetBefore) / 後 \(offsetAfter) / 行 \(rowHeight))"
        )
        XCTAssertTrue(
            visibleIdentifiers(in: controller).contains(anchor),
            "削除後にアンカーが表示範囲から外れています"
        )
        print("KS 先頭の削除でのアンカーの動き: \(offsetBefore - offsetAfter) (行 \(rowHeight))")
        assertVisibleCellsSurviveWhereChunkUnchanged(
            in: controller,
            chunksBefore: chunksBefore,
            cellsBefore: cellsBefore,
            label: "先頭の削除"
        )
    }

    // 末尾の塊にある項目を先頭へ移しても、移動しなかった可視セルは作り直されない。
    func test塊をまたぐ並べ替えで移動しない可視セルを作り直さない() async {
        let itemCount = 2_000
        var configuration = makeUniformHeightListConfiguration(itemCount: itemCount)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }
        XCTAssertEqual(
            ksIndexPath(forItemOffset: itemCount - 1, in: controller.collectionView).section,
            controller.collectionView.numberOfSections - 1,
            "末尾の項目が末尾の塊にありません"
        )
        controller.collectionView.layoutIfNeeded()
        let chunksBefore = chunkIndexesByIdentifier(in: controller)
        let cellsBefore = visibleCellsByIdentifier(in: controller)

        let moved = configuration.items.removeLast()
        configuration.items.insert(moved, at: 0)
        controller.update(configuration: configuration)
        await waitUntil("並べ替え後の先頭", value: { controller.appliedItemIdentifiers.first }) {
            $0 == AnyHashable(itemCount - 1)
        }
        controller.collectionView.layoutIfNeeded()

        XCTAssertEqual(
            ksIndexPath(forItemOffset: 0, in: controller.collectionView),
            IndexPath(item: 0, section: 0)
        )
        XCTAssertTrue(
            visibleIdentifiers(in: controller).contains(AnyHashable(itemCount - 1)),
            "先頭へ移した項目が表示されていません"
        )
        assertVisibleCellsSurviveWhereChunkUnchanged(
            in: controller,
            chunksBefore: chunksBefore,
            cellsBefore: cellsBefore,
            label: "塊をまたぐ並べ替え",
            ignoring: [AnyHashable(itemCount - 1)],
            // 表示は配列の先頭にあり、塊の境界は表示範囲に入らない (所属が変わる可視セルは無い)。
            expectsMovedCells: false
        )
    }

    // ID へのスクロール命令と末尾への命令は、塊に依らず解決される。
    func testスクロール命令は塊をまたいで解決する() async {
        let itemCount = 2_000
        let scrollController = KsScrollController()
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        let target = itemCount - 20
        XCTAssertEqual(
            ksIndexPath(forItemOffset: target, in: controller.collectionView).section,
            controller.collectionView.numberOfSections - 1,
            "対象の項目が末尾の塊にありません"
        )

        scrollController.scrollTo(id: target, animated: false)
        await waitUntil("ID 命令の処理", value: { controller.lastScrollTargetIdentifier }) {
            $0 == AnyHashable(target)
        }
        controller.collectionView.layoutIfNeeded()
        await waitUntil("対象の可視化", value: { isVisible(item: target, in: controller) }) { $0 }

        scrollController.scrollToEnd(animated: false)
        await waitUntil("末尾命令の処理", value: { controller.lastScrollTargetIdentifier }) {
            $0 == AnyHashable(itemCount - 1)
        }
        controller.collectionView.layoutIfNeeded()
        await waitUntil("末尾の可視化", value: { isVisible(item: itemCount - 1, in: controller) }) { $0 }
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
        // 配列を内部の塊へ分けた後の実測 (2 機種・各複数走行) では、収束後の同時生存数の最大は
        // 可視の約 3.4 倍 (可視 39 件に対して 132 件) であり、先読みと再利用プールの分を含めて
        // 4 倍を上限に置く。再利用が壊れれば生存数は走査した件数に比例するため、この幅でも
        // 仮想化の破綻は捕まえられる。
        let visibleCellCount = controller.collectionView.indexPathsForVisibleItems.count
        XCTAssertGreaterThan(visibleCellCount, 0, "初期表示の可視セルを取得できませんでした")
        let liveCellLimit = visibleCellCount * 4

        // 端点間を飛ばさず、表示範囲の半分ずつ送って全項目を通過する。
        // 前後の可視範囲が十分に重ならない刻みでは、UIKit は再利用ではなく作り直しになる。
        var maxLiveCellCount = 0
        await advanceRoundTrip(itemCount: itemCount, in: controller) {
            maxLiveCellCount = max(
                maxLiveCellCount,
                await settledLiveCellCount(in: controller, below: liveCellLimit)
            )
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
            at: ksIndexPath(forItemOffset: itemCount - 1, in: controller.collectionView),
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
            at: ksIndexPath(forItemOffset: 60, in: controller.collectionView),
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

        controller.collectionView(
            controller.collectionView,
            didHighlightItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )
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

    func testグリッドで配列の変更とタッチ色の差し替えが同時に届いても残った可視セルに新しい色が届く() async {
        var configuration = makeConfiguration(items: (0..<6).map { Item(id: $0, title: "項目 \($0)") })
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)
        configuration.onItemTap = { _ in }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(6, in: controller)
        let survivingCells = (0..<6).map { tryUnwrapCell(controller, item: $0) }
        XCTAssertTrue(survivingCells.allSatisfy { $0.touchFeedbackColor == KsHostingCell.defaultTouchFeedbackColor })

        // 配列の変更 (末尾への追加) と色の差し替えが 1 回の更新で届く。残った可視セルは作り直されないため、
        // 新しい色は差分の適用完了からの揃え直しで届く。
        configuration.items.append(Item(id: 6, title: "追加"))
        configuration.touchFeedbackColor = .systemRed
        controller.update(configuration: configuration)

        await waitUntil("残った可視セルのタッチ色", value: {
            survivingCells.map(\.touchFeedbackColor)
        }) { $0.allSatisfy { $0 == .systemRed } }
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), 7)

        // 配列が同値のまま色だけが差し替わる更新も、グリッドの可視セルへ届く。
        configuration.touchFeedbackColor = .systemBlue
        controller.update(configuration: configuration)

        await waitUntil("同値配列の更新後のタッチ色", value: {
            survivingCells.map(\.touchFeedbackColor)
        }) { $0.allSatisfy { $0 == .systemBlue } }
    }

    func test表示前に古い色のまま残ったセルは表示に入る時点で現在の構成に揃う() async {
        var configuration = makeConfiguration(items: (0..<6).map { Item(id: $0, title: "項目 \($0)") })
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)
        configuration.onItemTap = { _ in }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(6, in: controller)

        // 同値配列のまま色だけを差し替える。この更新は可視セルにしか届かない。
        configuration.touchFeedbackColor = .systemRed
        controller.update(configuration: configuration)

        // 先行して組み立てられ、差し替えの間は画面外にあったセルの代わり。ユニットテストのホストでは
        // 先行組み立てが起きないため、差し替え前の構成で組み立てたセルを用意し、表示に入る時点の
        // デリゲート呼び出しを直接行う。
        let staleCell = KsHostingCell(frame: CGRect(x: 0, y: 0, width: 180, height: 44))
        staleCell.configureTouchFeedback(color: KsHostingCell.defaultTouchFeedbackColor)
        XCTAssertEqual(staleCell.touchFeedbackColor, KsHostingCell.defaultTouchFeedbackColor)

        controller.collectionView(
            controller.collectionView,
            willDisplay: staleCell,
            forItemAt: ksIndexPath(forItemOffset: 4, in: controller.collectionView)
        )

        XCTAssertEqual(staleCell.touchFeedbackColor, .systemRed)
    }

    func test表示前に古い区切り線のまま残ったセルは表示に入る時点で位置と色が揃う() async {
        var configuration = makeConfiguration(items: (0..<3).map { Item(id: $0, title: "項目 \($0)") })
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)

        configuration.separatorColor = .systemPink
        controller.update(configuration: configuration)

        // 差し替え前の構成で、先頭以外の位置として組み立てられたセルの代わり (上のテストと同じ理由で
        // 表示に入る時点のデリゲート呼び出しを直接行う)。
        let staleCell = KsHostingCell(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        staleCell.configureSeparators(showsTop: false, showsBottom: true, color: KsHostingCell.defaultSeparatorColor)

        controller.collectionView(
            controller.collectionView,
            willDisplay: staleCell,
            forItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )

        XCTAssertTrue(staleCell.isTopSeparatorVisible)
        XCTAssertTrue(staleCell.isBottomSeparatorVisible)
        XCTAssertEqual(staleCell.topSeparatorColor, UIColor.systemPink)
        XCTAssertEqual(staleCell.bottomSeparatorColor, UIColor.systemPink)
    }

    #if DEBUG
    // 色の書き込み回数と揃え直しの回数は debug ビルドにだけ載るため、これらのテストも debug 構成でだけ実行する。
    func test同じ構成で揃え直しても既定のタッチ色と区切り線の色を書き直さない() async {
        await assertRealigningKeepsColorsUnwritten(
            configuration: makeConfiguration(items: (0..<3).map { Item(id: $0, title: "項目 \($0)") })
        )
    }

    func test同じ構成で揃え直しても指定したタッチ色と区切り線の色を書き直さない() async {
        var configuration = makeConfiguration(items: (0..<3).map { Item(id: $0, title: "項目 \($0)") })
        configuration.touchFeedbackColor = .systemRed
        configuration.separatorColor = .systemPink
        await assertRealigningKeepsColorsUnwritten(configuration: configuration)
    }

    func testグリッドではレイアウト確定で可視セルを揃え直さない() async {
        var configuration = makeConfiguration(items: (0..<60).map { Item(id: $0, title: "項目 \($0)") })
        configuration.layout = .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)
        // 区切り線の表示を宣言していても、グリッドは区切り線を出さない。
        configuration.showsSeparators = true
        let updates = await visibleCellSeparatorUpdatesDuringLayout(configuration: configuration)
        XCTAssertEqual(updates, 0)
    }

    func test区切り線なしのリストではレイアウト確定で可視セルを揃え直さない() async {
        var configuration = makeConfiguration(items: (0..<60).map { Item(id: $0, title: "項目 \($0)") })
        configuration.showsSeparators = false
        let updates = await visibleCellSeparatorUpdatesDuringLayout(configuration: configuration)
        XCTAssertEqual(updates, 0)
    }

    func test区切り線ありのリストではレイアウト確定で可視セルを揃え直す() async {
        // 上の 2 つのテストの対照。同じ手順で揃え直しが数えられることを確かめ、0 件が空振りでないことを示す。
        let configuration = makeConfiguration(items: (0..<60).map { Item(id: $0, title: "項目 \($0)") })
        let updates = await visibleCellSeparatorUpdatesDuringLayout(configuration: configuration)
        XCTAssertGreaterThan(updates, 0)
    }

    // 初回表示が落ち着いた後に、構成の差し替え (同じ構成) とレイアウト確定の 2 経路で可視セルを揃え直し、
    // 色の書き込みが増えないことを確かめる。
    private func assertRealigningKeepsColorsUnwritten(
        configuration: KsCollectionConfiguration<Item>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitForVisibleItemCount(3, in: controller)
        await waitUntil("初回適用の完了後の揃え直し", value: {
            controller.visibleCellSeparatorUpdateCount
        }) { $0 >= 1 }
        let cells = (0..<3).map { tryUnwrapCell(controller, item: $0) }
        let touchWrites = cells.map(\.touchFeedbackColorWriteCount)
        let separatorWrites = cells.map(\.separatorColorWriteCount)
        let updatesBefore = controller.visibleCellSeparatorUpdateCount

        controller.update(configuration: configuration)
        for _ in 0..<3 {
            controller.collectionView.setNeedsLayout()
            controller.collectionView.layoutIfNeeded()
        }

        // 揃え直しは実際に走っている (書き込みが増えないのは揃え直しが起きなかったからではない)。
        XCTAssertGreaterThan(controller.visibleCellSeparatorUpdateCount, updatesBefore, file: file, line: line)
        XCTAssertEqual(cells.map(\.touchFeedbackColorWriteCount), touchWrites, file: file, line: line)
        XCTAssertEqual(cells.map(\.separatorColorWriteCount), separatorWrites, file: file, line: line)
        let expectedTouchColor = configuration.touchFeedbackColor ?? KsHostingCell.defaultTouchFeedbackColor
        let expectedSeparatorColor = configuration.separatorColor ?? KsHostingCell.defaultSeparatorColor
        // 控えは構成が渡したオブジェクトそのもの。色を指定しないときは固定した既定色が渡っており、
        // 参照のたびに別のオブジェクトになりうる色では書き込みの省略が効かなくなる。
        XCTAssertTrue(
            cells.allSatisfy { $0.lastWrittenTouchFeedbackColor === expectedTouchColor },
            file: file,
            line: line
        )
        // ビューから読み戻した色は書いたオブジェクトそのものとは限らない (動的色は別のオブジェクトで返る) ため、値で比べる。
        XCTAssertTrue(cells.allSatisfy { $0.touchFeedbackColor == expectedTouchColor }, file: file, line: line)
        XCTAssertTrue(cells.allSatisfy { $0.bottomSeparatorColor == expectedSeparatorColor }, file: file, line: line)
    }

    // 初回表示が落ち着いた後に、レイアウトの確定だけを繰り返し (その場での再レイアウトとスクロール) 起こし、
    // その間に可視セルを揃え直した回数を返す。
    private func visibleCellSeparatorUpdatesDuringLayout(
        configuration: KsCollectionConfiguration<Item>
    ) async -> Int {
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) {
            $0 == configuration.items.count
        }
        // 初回の適用完了からの揃え直しを済ませてから数え始める。
        await waitUntil("初回適用の完了後の揃え直し", value: {
            controller.visibleCellSeparatorUpdateCount
        }) { $0 >= 1 }
        let updatesBefore = controller.visibleCellSeparatorUpdateCount

        for step in 1...5 {
            controller.collectionView.setNeedsLayout()
            controller.collectionView.layoutIfNeeded()
            controller.collectionView.setContentOffset(CGPoint(x: 0, y: CGFloat(step) * 120), animated: false)
            controller.collectionView.layoutIfNeeded()
        }
        XCTAssertGreaterThan(controller.collectionView.contentOffset.y, 0, "スクロールが起きていません")
        return controller.visibleCellSeparatorUpdateCount - updatesBefore
    }
    #endif

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
            ksTotalItemCount(in: controller.collectionView)
        }) { $0 == 1 }
        let recognizer = controller.longPressRecognizer

        XCTAssertEqual(recognizer?.isEnabled, false)
        controller.collectionView(
            controller.collectionView,
            didSelectItemAt: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )
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
                ofKind: KsSupplementaryKind.rootHeader
            ).count
        }) { $0 == 1 }
        guard let headerView = controller.collectionView.visibleSupplementaryViews(
            ofKind: KsSupplementaryKind.rootHeader
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

    // レイアウトに載っている補助ビューの種類ごとの数。
    private func supplementaryKindCounts(
        in controller: KsCollectionViewController<Item>
    ) -> [String: Int] {
        let rect = CGRect(origin: .zero, size: controller.collectionView.contentSize)
        var counts: [String: Int] = [:]
        let attributes = controller.collectionView.collectionViewLayout
            .layoutAttributesForElements(in: rect) ?? []
        for element in attributes {
            guard let kind = element.representedElementKind else { continue }
            counts[kind, default: 0] += 1
        }
        return counts
    }

    private func footerFrame(
        in controller: KsCollectionViewController<Item>
    ) -> CGRect? {
        supplementaryFrames(ofKind: KsSupplementaryKind.rootFooter, in: controller).first
    }

    // レイアウトに載っている、指定した種類の補助ビューの矩形 (上から順)。ルートのヘッダー /
    // フッターはレイアウト全体に付くため、位置 (indexPath) ではなく種類で引く。
    private func supplementaryFrames(
        ofKind kind: String,
        in controller: KsCollectionViewController<Item>
    ) -> [CGRect] {
        controller.collectionView.layoutIfNeeded()
        let rect = CGRect(
            origin: .zero,
            size: CGSize(
                width: controller.collectionView.bounds.width,
                height: max(controller.collectionView.contentSize.height, controller.collectionView.bounds.height)
            )
        )
        return (controller.collectionView.collectionViewLayout.layoutAttributesForElements(in: rect) ?? [])
            .filter { $0.representedElementKind == kind }
            .map(\.frame)
            .sorted { $0.minY < $1.minY }
    }

    // 目的の位置まで、途中の行を解かせながら送る。送り終えたときの先頭可視要素を返す。
    // 飛ばして送ると途中の行が推定のまま残り、位置の動きを行の高さと比べられない。
    private func advanceToSolvedPosition(
        item: Int,
        in controller: KsCollectionViewController<Item>
    ) async -> AnyHashable {
        let reached = await advanceUntilVisible(
            item: item,
            in: controller,
            step: controller.collectionView.bounds.height / 2
        )
        XCTAssertTrue(reached, "項目 \(item) まで送り切れませんでした")
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: item, in: controller.collectionView),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        await settleContentSize(in: controller)
        guard let anchor = onScreenLeadingIdentifier(in: controller) else {
            XCTFail("画面上の先頭の要素を取得できませんでした")
            return AnyHashable(0)
        }
        return anchor
    }

    // 項目 ID と、その項目が載っている塊の順番の対応。
    private func chunkIndexesByIdentifier(
        in controller: KsCollectionViewController<Item>
    ) -> [AnyHashable: Int] {
        let identifiers = controller.appliedItemIdentifiers
        var result: [AnyHashable: Int] = [:]
        for offset in identifiers.indices {
            guard
                let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView)
            else {
                continue
            }
            result[identifiers[offset]] = indexPath.section
        }
        return result
    }

    // 可視セルを項目 ID から引けるようにした対応。セルの同一性 (作り直されたかどうか) を見る。
    private func visibleCellsByIdentifier(
        in controller: KsCollectionViewController<Item>
    ) -> [AnyHashable: ObjectIdentifier] {
        let identifiers = controller.appliedItemIdentifiers
        var result: [AnyHashable: ObjectIdentifier] = [:]
        for indexPath in controller.collectionView.indexPathsForVisibleItems {
            guard
                let offset = ksItemOffset(for: indexPath, in: controller.collectionView),
                identifiers.indices.contains(offset),
                let cell = controller.collectionView.cellForItem(at: indexPath)
            else {
                continue
            }
            result[identifiers[offset]] = ObjectIdentifier(cell)
        }
        return result
    }

    // 塊の所属が変わらなかった可視セルが作り直されていないことを確かめる。
    // 所属が変わった可視セルの扱いは契約の外なので、観測結果を出力するだけにする。
    private func assertVisibleCellsSurviveWhereChunkUnchanged(
        in controller: KsCollectionViewController<Item>,
        chunksBefore: [AnyHashable: Int],
        cellsBefore: [AnyHashable: ObjectIdentifier],
        label: String,
        ignoring: Set<AnyHashable> = [],
        expectsMovedCells: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let chunksAfter = chunkIndexesByIdentifier(in: controller)
        let cellsAfter = visibleCellsByIdentifier(in: controller)
        var checkedCount = 0
        var movedCount = 0
        var movedReusedCount = 0
        for (identifier, cellBefore) in cellsBefore where !ignoring.contains(identifier) {
            guard
                let before = chunksBefore[identifier],
                let after = chunksAfter[identifier],
                let cellAfter = cellsAfter[identifier]
            else {
                continue
            }
            if before == after {
                checkedCount += 1
                XCTAssertEqual(
                    cellAfter,
                    cellBefore,
                    "\(label)で塊の所属が変わらない可視セルが作り直されています (項目 \(identifier))",
                    file: file,
                    line: line
                )
            } else {
                movedCount += 1
                if cellAfter == cellBefore {
                    movedReusedCount += 1
                }
            }
        }
        XCTAssertGreaterThan(
            checkedCount,
            0,
            "\(label)で所属が変わらない可視セルを 1 つも確かめられていません",
            file: file,
            line: line
        )
        // 送り先が塊の境界から外れると、所属が変わる可視セルが 1 件も無いまま緑になる。
        // 境界が表示範囲に入っていることを前提にする検査では、その前提をここで固定する。
        if expectsMovedCells {
            XCTAssertGreaterThan(
                movedCount,
                0,
                "\(label)で塊の所属が変わる可視セルが 1 件もありません (送り先が塊の境界から外れています)",
                file: file,
                line: line
            )
        }
        print("KS 塊の所属が変わった可視セル (\(label)): \(movedCount) 件中 \(movedReusedCount) 件が同じセルのまま")
    }

    // 塊ごとの件数を先頭から並べて返す。
    private func sectionItemCounts(in controller: KsCollectionViewController<Item>) -> [Int] {
        (0..<controller.collectionView.numberOfSections).map {
            controller.collectionView.numberOfItems(inSection: $0)
        }
    }

    // 可視セルの位置を全体の順番で並べて返す。
    private func visibleItemOffsets(in controller: KsCollectionViewController<Item>) -> [Int] {
        controller.collectionView.indexPathsForVisibleItems.compactMap {
            ksItemOffset(for: $0, in: controller.collectionView)
        }.sorted()
    }

    // 指定した表示形態で配列を載せ、塊ごとの件数が期待どおりに割れることを確かめる。
    private func assertChunkStructure(
        layout: KsCollectionLayout,
        itemCount: Int,
        expected: [Int],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        var configuration = makeConfiguration(
            items: (0..<itemCount).map { Item(id: $0, title: "項目 \($0)") }
        )
        configuration.layout = layout
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showInWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == itemCount }

        XCTAssertEqual(sectionItemCounts(in: controller), expected, file: file, line: line)
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), itemCount, file: file, line: line)
    }

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
        items.compactMap { offset in
            guard
                let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView)
            else {
                return nil
            }
            return controller.collectionView.collectionViewLayout
                .layoutAttributesForItem(at: indexPath)?.frame
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
            ksTotalItemCount(in: controller.collectionView)
        }) { $0 == itemCount }
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView),
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

    // 画面の向きが変わるときは、表示領域の frame が差し替わる前に viewWillTransition(to:with:)
    // が届く。本番と同じ順序で駆動するため、テストでもこの経路を通してから frame を差し替える。
    private func rotate(
        window: UIWindow,
        controller: UIViewController,
        to size: CGSize
    ) {
        controller.viewWillTransition(
            to: size,
            with: KsTransitionCoordinatorStub(containerView: window)
        )
        resize(window: window, controller: controller, to: size)
    }

    private func tryUnwrapCell(
        _ controller: KsCollectionViewController<Item>,
        item: Int
    ) -> KsHostingCell {
        guard let cell = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: item, in: controller.collectionView)
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
        return controller.collectionView.indexPathsForVisibleItems.sorted().compactMap { indexPath in
            guard let offset = ksItemOffset(for: indexPath, in: controller.collectionView) else {
                return nil
            }
            return identifiers.indices.contains(offset) ? identifiers[offset] : nil
        }
    }

    // 画面と実際に重なっている項目の全体の順番。可視セルの一覧には、遠くへ送った直後に送る前の
    // セルが残ることがあるため、レイアウト属性の矩形で表示範囲と重なるものだけに絞る。
    private func onScreenItemOffsets(in controller: KsCollectionViewController<Item>) -> [Int] {
        let bounds = controller.collectionView.bounds
        return controller.collectionView.indexPathsForVisibleItems.compactMap { indexPath -> Int? in
            guard
                let attributes = controller.collectionView.collectionViewLayout
                    .layoutAttributesForItem(at: indexPath),
                attributes.frame.intersects(bounds)
            else {
                return nil
            }
            return ksItemOffset(for: indexPath, in: controller.collectionView)
        }.sorted()
    }

    // 画面と実際に重なっている項目のうち、全体の順番が先頭のものの ID。
    private func onScreenLeadingIdentifier(
        in controller: KsCollectionViewController<Item>
    ) -> AnyHashable? {
        let identifiers = controller.appliedItemIdentifiers
        guard
            let offset = onScreenItemOffsets(in: controller).first,
            identifiers.indices.contains(offset)
        else {
            return nil
        }
        return identifiers[offset]
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

    // 指定位置まで送り、そのときの画面上の先頭の要素を返す (レイアウト切り替えのアンカーになる要素)。
    // 送り先が画面の先頭に来たことは、可視セルの一覧ではなく表示範囲と重なる矩形で確かめる。
    // 一覧には送る前のセルが残ることがあり、そのままでは送る前の項目を先頭だと見なしてしまう。
    private func scrollToDeepPosition(
        item: Int,
        in controller: KsCollectionViewController<Item>
    ) async -> AnyHashable {
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: item, in: controller.collectionView),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        await waitUntil("送った後の画面上の先頭の項目", value: { onScreenItemOffsets(in: controller).first }) {
            $0 == item
        }
        guard let anchor = onScreenLeadingIdentifier(in: controller) else {
            XCTFail("画面上の先頭の要素を取得できませんでした")
            return AnyHashable(0)
        }
        return anchor
    }

    // 目的の位置が表示されるまで `step` ずつ送る。各段階の後に `onStep` を呼ぶ。
    private func advanceUntilVisible(
        item: Int,
        in controller: KsCollectionViewController<Item>,
        step: CGFloat,
        onStep: () async -> Void = {}
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
            await onStep()
        }
        return isVisible(item: item, in: controller)
    }

    // 末尾まで送ってから先頭へ戻る。再利用プールが埋まった状態を作るために使う。
    @discardableResult
    private func advanceRoundTrip(
        itemCount: Int,
        in controller: KsCollectionViewController<Item>,
        onStep: () async -> Void = {}
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

    #if DEBUG
    // 落ち着いた同時生存セルの数。送りの直後に読んだ値は、新しいセルが作られてから古いセルが
    // 再利用プールへ戻って余剰が破棄されるまでの過渡の値になるため、そのまま標本にすると
    // 送りの瞬間しだいで上下する。レイアウトを確定させ、実行機会を譲りながら規模の内側へ
    // 収まるまで待ってから読む。期限まで収まらなければその時点の実測値を返し、呼び出し側の
    // アサーションの失敗メッセージに載せる。
    private func settledLiveCellCount(
        in controller: KsCollectionViewController<Item>,
        below limit: Int
    ) async -> Int {
        let clock = ContinuousClock()
        let deadline = clock.now + .milliseconds(500)
        controller.collectionView.layoutIfNeeded()
        var current = controller.liveCellCount
        while current >= limit, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(1))
            controller.collectionView.layoutIfNeeded()
            current = controller.liveCellCount
        }
        return current
    }
    #endif

    private func isVisible(
        item: Int,
        in controller: KsCollectionViewController<Item>
    ) -> Bool {
        controller.collectionView.indexPathsForVisibleItems.contains {
            ksItemOffset(for: $0, in: controller.collectionView) == item
        }
    }

    private func anchorAttributes(
        _ anchor: AnyHashable,
        in controller: KsCollectionViewController<Item>
    ) -> UICollectionViewLayoutAttributes? {
        guard
            let index = controller.appliedItemIdentifiers.firstIndex(of: anchor),
            let indexPath = ksIndexPathIfPresent(forItemOffset: index, in: controller.collectionView)
        else {
            return nil
        }
        return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)
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
            let leading = onScreenLeadingIdentifier(in: controller),
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
            let clipped = onScreenLeadingIdentifier(in: controller),
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
            ofKind: KsSupplementaryKind.rootHeader
        ).count
    }

    private func headerFrame(
        in controller: KsCollectionViewController<Item>
    ) -> CGRect? {
        supplementaryFrames(ofKind: KsSupplementaryKind.rootHeader, in: controller).first
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
        let positions = itemFrames(in: controller, items: Array(0..<8)).map(\.minX)
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
        predicate: (Value) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
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
        XCTFail(
            "\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))",
            file: file,
            line: line
        )
    }
}
