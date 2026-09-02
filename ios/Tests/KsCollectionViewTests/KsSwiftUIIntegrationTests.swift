import SwiftUI
import XCTest
@testable import KsCollectionView

@MainActor
final class KsSwiftUIIntegrationTests: XCTestCase {
    private struct Item: Identifiable, Equatable {
        let id: Int
        let title: String
    }

    private struct AppendAndScrollView: View {
        @State private var items: [Item]
        let scrollController: KsScrollController
        let register: (@escaping () -> Void) -> Void
        let didRunAction: () -> Void

        init(
            scrollController: KsScrollController,
            register: @escaping (@escaping () -> Void) -> Void,
            didRunAction: @escaping () -> Void
        ) {
            _items = State(initialValue: (0..<30).map {
                Item(id: $0, title: "項目 \($0)")
            })
            self.scrollController = scrollController
            self.register = register
            self.didRunAction = didRunAction
        }

        var body: some View {
            VStack(spacing: 0) {
                Button("追加して末尾へ移動", action: appendAndScroll)
                KsCollectionView(items) { item in
                    Text(item.title)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .scrollController(scrollController)
            }
            .onAppear { register(appendAndScroll) }
        }

        private func appendAndScroll() {
            items.append(Item(id: 30, title: "追加 30"))
            scrollController.scrollToEnd(animated: false)
            didRunAction()
        }
    }

    private struct SelectionHighlightView: View {
        @State private var selectedID: Int?
        let items: [Item]
        let register: (@escaping (Int?) -> Void) -> Void
        let record: (Int, Bool) -> Void

        var body: some View {
            // 選択中 ID は body で読む。テンプレートのクロージャ内でしか読まない値は
            // SwiftUI の再評価の依存にならず、親の更新自体が届かない。
            let selected = selectedID
            return KsCollectionView(items) { item in
                let _ = record(item.id, selected == item.id)
                Text(item.title)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(selected == item.id ? Color.yellow : Color.clear)
            }
            .onAppear { register { selectedID = $0 } }
        }
    }

    func testState更新と同一Button処理の末尾命令が新snapshotへ到達する() async {
        let scrollController = KsScrollController()
        var actionCount = 0
        var buttonAction: (() -> Void)?
        let host = UIHostingController(rootView: AppendAndScrollView(
            scrollController: scrollController,
            register: { buttonAction = $0 },
            didRunAction: { actionCount += 1 }
        ))
        let window = showInWindow(controller: host, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitUntil("SwiftUI 配下の collection controller", value: {
            self.collectionController(in: host)
        }) { $0 != nil }
        guard let controller = collectionController(in: host) else {
            XCTFail("KsCollectionViewController を取得できませんでした")
            return
        }
        await waitUntil("初期 snapshot", value: { controller.appliedItemIdentifiers.count }) {
            $0 == 30
        }
        await waitUntil("Button 処理の登録", value: { buttonAction != nil }) { $0 }

        buttonAction?()

        await waitUntil("Button action", value: { actionCount }) { $0 == 1 }
        await waitUntil("最新 snapshot の末尾へ移動", value: {
            (controller.appliedItemIdentifiers.last, controller.lastScrollTargetIdentifier)
        }) {
            $0.0 == AnyHashable(30) && $0.1 == AnyHashable(30)
        }
    }

    func test配列が同値でも親のState変更を可視セルへ反映する() async {
        var recorded: [Int: Bool] = [:]
        var setSelection: ((Int?) -> Void)?
        let items = (0..<10).map { Item(id: $0, title: "項目 \($0)") }
        let host = UIHostingController(rootView: SelectionHighlightView(
            items: items,
            register: { setSelection = $0 },
            record: { recorded[$0] = $1 }
        ))
        let window = showInWindow(controller: host, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true }

        await waitUntil("初期セルの構成", value: { recorded[3] }) { $0 == false }
        await waitUntil("選択操作の登録", value: { setSelection != nil }) { $0 }

        setSelection?(3)

        await waitUntil("選択中 ID を反映した可視セル", value: { recorded[3] }) { $0 == true }
    }

    private func collectionController(
        in controller: UIViewController
    ) -> KsCollectionViewController<Item>? {
        if let collectionController = controller as? KsCollectionViewController<Item> {
            return collectionController
        }
        for child in controller.children {
            if let collectionController = collectionController(in: child) {
                return collectionController
            }
        }
        return nil
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
