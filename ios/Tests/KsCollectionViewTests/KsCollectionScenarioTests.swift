import SwiftUI
import XCTest
@testable import KsCollectionView

/// 表示を伴う経路 (実 controller / `UIHostingController`) でしか観測できない振る舞いを固定する。
@MainActor
final class KsCollectionScenarioTests: XCTestCase {
    private struct KeyedItem: Equatable {
        enum Kind: Hashable {
            case message
            case ad
        }

        let id: Int
        let kind: Kind
        let title: String
    }

    private struct SharedItem: Equatable {
        let itemId: String
        let title: String
    }

    private final class RenderRecorder {
        private(set) var lastText: [AnyHashable: String] = [:]

        func record(_ id: some Hashable, _ text: String) {
            lastText[AnyHashable(id)] = text
        }
    }

    private final class StateRecorder {
        private(set) var lastValue: [Int: Bool] = [:]
        private var setters: [Int: (Bool) -> Void] = [:]

        func record(_ id: Int, _ value: Bool) {
            lastValue[id] = value
        }

        func register(_ id: Int, setter: @escaping (Bool) -> Void) {
            setters[id] = setter
        }

        func set(_ id: Int, to value: Bool) {
            setters[id]?(value)
        }
    }

    private struct StatefulRow: View {
        let id: Int
        let title: String
        let recorder: StateRecorder
        @State private var expanded = false

        var body: some View {
            let _ = recorder.record(id, expanded)
            Text(expanded ? "\(title) (展開)" : title)
                .frame(maxWidth: .infinity, minHeight: 44)
                .onAppear { recorder.register(id) { expanded = $0 } }
        }
    }

    private struct SharedItemListView: View {
        @State private var items: [SharedItem]
        let register: (@escaping ([SharedItem]) -> Void) -> Void
        let recorder: RenderRecorder

        init(
            items: [SharedItem],
            register: @escaping (@escaping ([SharedItem]) -> Void) -> Void,
            recorder: RenderRecorder
        ) {
            _items = State(initialValue: items)
            self.register = register
            self.recorder = recorder
        }

        var body: some View {
            KsCollectionView(items, id: \.itemId) { item in
                let _ = recorder.record(item.itemId, item.title)
                Text(item.title)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .onAppear { register { items = $0 } }
        }
    }

    func test同一IDかつ同一キーの内容変更でセルインスタンスを維持して再描画する() async {
        let recorder = RenderRecorder()
        var configuration = makeKeyedConfiguration(
            items: (0..<3).map { KeyedItem(id: $0, kind: .message, title: "本文 \($0)") },
            recorder: recorder
        )
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期描画", value: { recorder.lastText[0] }) { $0 == "本文 0" }
        let cellBeforeUpdate = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        )
        XCTAssertNotNil(cellBeforeUpdate)

        configuration.items[0] = KeyedItem(id: 0, kind: .message, title: "更新後の本文")
        controller.update(configuration: configuration)

        await waitUntil("更新後の描画", value: { recorder.lastText[0] }) { $0 == "更新後の本文" }
        XCTAssertTrue(
            controller.collectionView.cellForItem(
                at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
            ) === cellBeforeUpdate
        )
    }

    func test同一IDでテンプレートキーが変わるとセルを別テンプレートへ置き換える() async {
        let recorder = RenderRecorder()
        var configuration = makeKeyedConfiguration(
            items: (0..<3).map { KeyedItem(id: $0, kind: .message, title: "本文 \($0)") },
            recorder: recorder
        )
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期描画", value: { recorder.lastText[0] }) { $0 == "本文 0" }
        guard let cellBeforeUpdate = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        ) else {
            XCTFail("置換前のセルを取得できませんでした")
            return
        }

        configuration.items[0] = KeyedItem(id: 0, kind: .ad, title: "本文 0")
        controller.update(configuration: configuration)

        await waitUntil("広告テンプレートでの描画", value: { recorder.lastText[0] }) {
            $0 == "広告: 本文 0"
        }
        guard let cellAfterUpdate = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        ) else {
            XCTFail("置換後のセルを取得できませんでした")
            return
        }
        XCTAssertFalse(cellAfterUpdate === cellBeforeUpdate)
        XCTAssertNotEqual(cellAfterUpdate.reuseIdentifier, cellBeforeUpdate.reuseIdentifier)
    }

    func testレイアウト切替と同時にテンプレートキーが変わってもセルを置き換える() async {
        let recorder = RenderRecorder()
        var configuration = makeKeyedConfiguration(
            items: (0..<6).map { KeyedItem(id: $0, kind: .message, title: "本文 \($0)") },
            recorder: recorder
        )
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期描画", value: { recorder.lastText[0] }) { $0 == "本文 0" }
        guard let cellBeforeUpdate = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        ) else {
            XCTFail("置換前のセルを取得できませんでした")
            return
        }

        configuration.items[0] = KeyedItem(id: 0, kind: .ad, title: "本文 0")
        configuration.layout = .grid(columns: .fixed(2))
        controller.update(configuration: configuration)

        await waitUntil("広告テンプレートでの描画", value: { recorder.lastText[0] }) {
            $0 == "広告: 本文 0"
        }
        guard let cellAfterUpdate = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        ) else {
            XCTFail("置換後のセルを取得できませんでした")
            return
        }
        XCTAssertFalse(cellAfterUpdate === cellBeforeUpdate)
        XCTAssertNotEqual(cellAfterUpdate.reuseIdentifier, cellBeforeUpdate.reuseIdentifier)
        XCTAssertEqual(ksTotalItemCount(in: controller.collectionView), 6)
    }

    func test非Identifiable型のidキーパスで描画し差分更新のidentityにする() async {
        let recorder = RenderRecorder()
        var updateItems: (([SharedItem]) -> Void)?
        let items = [
            SharedItem(itemId: "a", title: "共有モデル A"),
            SharedItem(itemId: "bb", title: "共有モデル B"),
            SharedItem(itemId: "ccc", title: "共有モデル C"),
        ]
        let host = UIHostingController(rootView: SharedItemListView(
            items: items,
            register: { updateItems = $0 },
            recorder: recorder
        ))
        let window = showInWindow(controller: host, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("SwiftUI 配下の collection controller", value: {
            self.sharedItemController(in: host)
        }) { $0 != nil }
        guard let controller = sharedItemController(in: host) else {
            XCTFail("KsCollectionViewController を取得できませんでした")
            return
        }
        await waitUntil("初期描画", value: { recorder.lastText["bb"] }) { $0 == "共有モデル B" }
        XCTAssertEqual(
            controller.appliedItemIdentifiers,
            [AnyHashable("a"), AnyHashable("bb"), AnyHashable("ccc")]
        )
        let cellBeforeUpdate = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 1, in: controller.collectionView)
        )
        XCTAssertNotNil(cellBeforeUpdate)

        await waitUntil("更新操作の登録", value: { updateItems != nil }) { $0 }
        updateItems?([
            SharedItem(itemId: "a", title: "共有モデル A"),
            SharedItem(itemId: "bb", title: "更新後の B"),
            SharedItem(itemId: "ccc", title: "共有モデル C"),
        ])

        await waitUntil("更新後の描画", value: { recorder.lastText["bb"] }) { $0 == "更新後の B" }
        XCTAssertEqual(
            controller.appliedItemIdentifiers,
            [AnyHashable("a"), AnyHashable("bb"), AnyHashable("ccc")]
        )
        XCTAssertTrue(
            controller.collectionView.cellForItem(
                at: ksIndexPath(forItemOffset: 1, in: controller.collectionView)
            ) === cellBeforeUpdate
        )
    }

    func test本文量の異なる行はそれぞれ必要な高さになる() async {
        let recorder = RenderRecorder()
        let items = [
            KeyedItem(id: 0, kind: .message, title: "短い本文"),
            KeyedItem(id: 1, kind: .message, title: String(repeating: "長い本文です。", count: 40)),
            KeyedItem(id: 2, kind: .message, title: "短い本文"),
        ]
        var configuration = makeKeyedConfiguration(items: [], recorder: recorder)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        configuration.items = items
        controller.update(configuration: configuration)
        await waitUntil("自己サイズの確定", value: { rowHeights(in: controller) }) {
            $0.count == 3 && abs($0[0] - $0[2]) < 0.5
        }

        let heights = rowHeights(in: controller)

        XCTAssertEqual(heights.count, 3)
        XCTAssertGreaterThan(heights[1], heights[0] * 2)
        XCTAssertEqual(heights[0], heights[2], accuracy: 0.5)
        for index in 0..<3 {
            guard let cell = controller.collectionView.cellForItem(
                at: ksIndexPath(forItemOffset: index, in: controller.collectionView)
            ) else {
                XCTFail("項目 \(index) のセルを取得できませんでした")
                continue
            }
            XCTAssertEqual(
                heights[index],
                hostedFittingHeight(of: cell),
                accuracy: 0.5,
                "項目 \(index) のセル高さが内容の必要高さと一致しません (切れ・余分な空白がある)"
            )
        }
    }

    func test接続済みでも存在しないIDへのスクロール命令では表示位置が変わらない() async {
        let recorder = RenderRecorder()
        let scrollController = KsScrollController()
        var configuration = makeKeyedConfiguration(
            items: (0..<300).map { KeyedItem(id: $0, kind: .message, title: "項目 \($0)") },
            recorder: recorder
        )
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: 100, in: controller.collectionView),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
        let offsetBefore = controller.collectionView.contentOffset.y

        // 無効な命令は表示を動かさないため、待つ対象は「その命令が処理し切られたこと」にする。
        let processedBefore = controller.processedCommandCount
        scrollController.scrollTo(id: 9_999, animated: false)
        await waitUntil("無効な命令の処理", value: { controller.processedCommandCount }) {
            $0 == processedBefore + 1
        }
        controller.collectionView.layoutIfNeeded()

        XCTAssertEqual(controller.collectionView.contentOffset.y, offsetBefore, accuracy: 0.5)
        XCTAssertNil(controller.lastScrollTargetIdentifier)

        // 命令の経路が生きていること自体は、この後の有効な命令が届くことで確かめる。
        scrollController.scrollTo(id: 120, animated: false)
        await waitUntil("有効な命令の到達", value: { controller.lastScrollTargetIdentifier }) {
            $0 == AnyHashable(120)
        }
    }

    func test表示範囲外の要素へのcenter指定スクロールでその要素が中央に来る() async {
        let recorder = RenderRecorder()
        let scrollController = KsScrollController()
        var configuration = makeKeyedConfiguration(
            items: (0..<300).map { KeyedItem(id: $0, kind: .message, title: "項目 \($0)") },
            recorder: recorder
        )
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) { $0 == 300 }
        let target = ksIndexPath(forItemOffset: 150, in: controller.collectionView)
        XCTAssertFalse(controller.collectionView.indexPathsForVisibleItems.contains(target))

        scrollController.scrollTo(id: 150, position: .center, animated: false)

        await waitUntil("center 指定の到達", value: { controller.lastScrollTargetIdentifier }) {
            $0 == AnyHashable(150)
        }
        controller.collectionView.layoutIfNeeded()
        guard let attributes = controller.collectionView.collectionViewLayout
            .layoutAttributesForItem(at: target) else {
            XCTFail("対象要素のレイアウト属性を取得できませんでした")
            return
        }
        XCTAssertEqual(
            attributes.frame.midY,
            controller.collectionView.bounds.midY,
            accuracy: 2
        )
    }

    func testセルの再利用が起きる距離を往復するとテンプレートのstateは初期値へ戻る() async {
        let recorder = StateRecorder()
        let items = (0..<300).map { KeyedItem(id: $0, kind: .message, title: "項目 \($0)") }
        let controller = KsCollectionViewController(
            configuration: makeStatefulConfiguration(items: items, recorder: recorder)
        )
        let window = show(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }
        await waitUntil("先頭行の初期 state", value: { recorder.lastValue[0] }) { $0 == false }

        recorder.set(0, to: true)
        await waitUntil("先頭行の state 変更", value: { recorder.lastValue[0] }) { $0 == true }

        scroll(controller, to: 250)
        await waitUntil("往路の再利用", value: { recorder.lastValue[250] }) { $0 == false }
        scroll(controller, to: 0)

        await waitUntil("復路での state 初期化", value: { recorder.lastValue[0] }) { $0 == false }
    }

    private func makeKeyedConfiguration(
        items: [KeyedItem],
        recorder: RenderRecorder
    ) -> KsCollectionConfiguration<KeyedItem> {
        let registry = KsTemplateRegistry<KeyedItem>(templates: [
            KsTemplate(KeyedItem.Kind.message) { (item: KeyedItem) in
                let _ = recorder.record(item.id, item.title)
                Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
            },
            KsTemplate(KeyedItem.Kind.ad) { (item: KeyedItem) in
                let _ = recorder.record(item.id, "広告: \(item.title)")
                Text("広告: \(item.title)").frame(maxWidth: .infinity, alignment: .leading)
            },
        ])
        return makeConfiguration(
            items: items,
            templateKey: { AnyHashable($0.kind) },
            registry: registry
        )
    }

    private func makeStatefulConfiguration(
        items: [KeyedItem],
        recorder: StateRecorder
    ) -> KsCollectionConfiguration<KeyedItem> {
        makeConfiguration(
            items: items,
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry<KeyedItem> { item in
                StatefulRow(id: item.id, title: item.title, recorder: recorder)
            }
        )
    }

    private func makeConfiguration(
        items: [KeyedItem],
        templateKey: @escaping (KeyedItem) -> AnyHashable,
        registry: KsTemplateRegistry<KeyedItem>
    ) -> KsCollectionConfiguration<KeyedItem> {
        KsCollectionConfiguration(
            items: items,
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
    }

    private func rowHeights(in controller: KsCollectionViewController<KeyedItem>) -> [CGFloat] {
        (0..<3).compactMap { offset in
            guard
                let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView)
            else {
                return nil
            }
            return controller.collectionView.collectionViewLayout
                .layoutAttributesForItem(at: indexPath)?.frame.height
        }
    }

    // ホストされた内容が必要とする高さ。セルの実高さと一致すれば、切れも余分な空白も無い。
    private func hostedFittingHeight(of cell: UICollectionViewCell) -> CGFloat {
        cell.contentView.systemLayoutSizeFitting(
            CGSize(width: cell.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    private func scroll(_ controller: KsCollectionViewController<KeyedItem>, to item: Int) {
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: item, in: controller.collectionView),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
    }

    private func sharedItemController(
        in controller: UIViewController
    ) -> KsCollectionViewController<SharedItem>? {
        if let collectionController = controller as? KsCollectionViewController<SharedItem> {
            return collectionController
        }
        for child in controller.children {
            if let collectionController = sharedItemController(in: child) {
                return collectionController
            }
        }
        return nil
    }

    // 自己サイズの解決には window が要る一方、safe area に重なるセルには SwiftUI が余白を足す。
    // 計測を素のコンテンツ高さで見るため、safe area の内側に収めて載せる。
    private func show(controller: UIViewController, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
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
            width: size.width,
            height: size.height - safeArea.top - safeArea.bottom
        )
        root.view.addSubview(controller.view)
        controller.didMove(toParent: root)
        controller.view.layoutIfNeeded()
        return window
    }

    private func showInWindow(controller: UIViewController, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
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
