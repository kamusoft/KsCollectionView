import SwiftUI
import XCTest
@testable import KsCollectionView

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
        XCTAssertEqual(first.separatorColor, UIColor(
            red: 217 / 255,
            green: 217 / 255,
            blue: 222 / 255,
            alpha: 1
        ))
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
        let advanced = await advanceUntilVisible(
            item: itemCount - 1,
            in: controller,
            step: controller.collectionView.bounds.height / 2,
            maxLiveCellCount: &maxLiveCellCount
        )
        XCTAssertTrue(advanced, "末尾まで送り切れませんでした")
        let returned = await advanceUntilVisible(
            item: 0,
            in: controller,
            step: -controller.collectionView.bounds.height / 2,
            maxLiveCellCount: &maxLiveCellCount
        )
        XCTAssertTrue(returned, "先頭まで戻り切れませんでした")

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
    #endif

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
            Template("registered") { (item: Item) in
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
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
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

    #if DEBUG
    // 目的の位置が表示されるまで `step` ずつ送り、各段階で生存セル数を採る。
    private func advanceUntilVisible(
        item: Int,
        in controller: KsCollectionViewController<Item>,
        step: CGFloat,
        maxLiveCellCount: inout Int
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
            maxLiveCellCount = max(maxLiveCellCount, controller.liveCellCount)
        }
        return isVisible(item: item, in: controller)
    }
    #endif

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
