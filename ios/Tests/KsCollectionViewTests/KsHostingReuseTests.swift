#if canImport(UIKit)
import SwiftUI
import XCTest
@testable import KsCollectionView

// セルが再利用されるとき、前の項目のものを次の項目へ持ち越さないことを固定する。
// iOS 18 以降は中身を載せるホスティングを使い回し、それより前の版は作り直す (ios/ADR-0012)。
@MainActor
final class KsHostingReuseTests: XCTestCase {
    private struct Item: Equatable {
        let id: Int
    }

    private final class Recorder {
        private(set) var appearCounts: [Int: Int] = [:]
        private(set) var taskCounts: [Int: Int] = [:]
        private(set) var lastExpanded: [Int: Bool] = [:]
        private(set) var lastLabel: [Int: String] = [:]
        /// 最後に onAppear が動いた時点の state。
        private(set) var expandedAtAppear: [Int: Bool] = [:]
        private var setters: [Int: (Bool) -> Void] = [:]
        /// テンプレートが行に出す文言の後ろへ足す値。配列を変えずにテンプレートの出力だけを変える。
        var suffix = ""

        func recordAppear(_ id: Int, expanded: Bool, setter: @escaping (Bool) -> Void) {
            appearCounts[id, default: 0] += 1
            expandedAtAppear[id] = expanded
            setters[id] = setter
        }

        func recordTask(_ id: Int) {
            taskCounts[id, default: 0] += 1
        }

        func recordBody(_ id: Int, expanded: Bool, label: String) {
            lastExpanded[id] = expanded
            lastLabel[id] = label
        }

        func setExpanded(_ id: Int, to value: Bool) {
            setters[id]?(value)
        }
    }

    private struct Row: View {
        let id: Int
        let label: String
        let height: CGFloat
        let recorder: Recorder
        @State private var expanded = false

        var body: some View {
            let _ = recorder.recordBody(id, expanded: expanded, label: label)
            Text(label)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .onAppear { recorder.recordAppear(id, expanded: expanded) { expanded = $0 } }
                .task { recorder.recordTask(id) }
        }
    }

    // 行の高さは、先頭側・中ほど・その先の 3 つの範囲で変える。
    private static let middleItemsStart = 100
    private static let tallItemsStart = 200
    private static let shortHeight: CGFloat = 44
    private static let middleHeight: CGFloat = 80
    private static let tallHeight: CGFloat = 120
    // 離れた位置へ一度に送ると、行き先のセルは元のセルが表示から外れる前に用意され、新しく作られる。
    // 元のセルが再利用されるのは、その次に送ったときである。そのため中ほどを経由してから先へ送る。
    private static let middleItem = 150
    private static let farItem = 250

    func test再利用でセルの中身のビューを使い回すのはiOS18以降だけである() async {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)
        let window = show(controller: controller)
        defer { window.isHidden = true }
        await waitUntil("先頭の行の表示", value: { recorder.appearCounts[0] }) { $0 != nil }
        let contentViewsBeforeReuse = contentViewsByCell(in: controller)
        XCTAssertFalse(contentViewsBeforeReuse.isEmpty)

        await scrollViaMiddle(controller, recorder: recorder)

        let reused = contentViewsByCell(in: controller).filter { contentViewsBeforeReuse[$0.key] != nil }
        XCTAssertFalse(reused.isEmpty, "先頭で表示していたセルが、離れた位置で 1 つも再利用されていません")
        // 使い回すのは、OS がテンプレートの内部 state を初期値へ戻す版 (iOS 18 以降) だけである。
        // それより前の版で使い回すと前の項目の state が次の項目に出るので、作り直す。
        for (cell, contentView) in reused {
            if #available(iOS 18, *) {
                XCTAssertTrue(
                    contentView === contentViewsBeforeReuse[cell],
                    "再利用されたセルの中身のビューが作り直されています"
                )
            } else {
                XCTAssertFalse(
                    contentView === contentViewsBeforeReuse[cell],
                    "再利用されたセルの中身のビューが使い回されています"
                )
            }
        }
    }

    func test高さの違う項目へ再利用されたセルは新しい項目の高さになる() async {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)
        let window = show(controller: controller)
        defer { window.isHidden = true }
        await waitUntil("先頭の行の高さ", value: { visibleCellHeights(in: controller) }) {
            !$0.isEmpty && $0.allSatisfy { abs($0 - Self.shortHeight) < 0.5 }
        }
        let cellsBeforeReuse = Set(controller.collectionView.visibleCells.map(ObjectIdentifier.init))

        await scrollViaMiddle(controller, recorder: recorder)

        await waitUntil("高い行へ再利用されたセルの高さ", value: { visibleCellHeights(in: controller) }) {
            !$0.isEmpty && $0.allSatisfy { abs($0 - Self.tallHeight) < 0.5 }
        }
        XCTAssertFalse(
            cellsBeforeReuse.isDisjoint(with: controller.collectionView.visibleCells.map(ObjectIdentifier.init)),
            "先頭で表示していたセルが、離れた位置で 1 つも再利用されていません"
        )

        scroll(controller, to: 0)

        await waitUntil("低い行へ再利用されたセルの高さ", value: { visibleCellHeights(in: controller) }) {
            !$0.isEmpty && $0.allSatisfy { abs($0 - Self.shortHeight) < 0.5 }
        }
    }

    func test再利用で表示に入った項目でonAppearとtaskが動く() async {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)
        let window = show(controller: controller)
        defer { window.isHidden = true }
        await waitUntil("先頭の行の onAppear", value: { recorder.appearCounts[0] }) { $0 == 1 }
        await waitUntil("先頭の行の task", value: { recorder.taskCounts[0] }) { $0 == 1 }
        let cellsBeforeReuse = Set(controller.collectionView.visibleCells.map(ObjectIdentifier.init))

        await scrollViaMiddle(controller, recorder: recorder)

        await waitUntil("再利用で表示に入った行の onAppear", value: { recorder.appearCounts[Self.farItem] }) {
            $0 == 1
        }
        await waitUntil("再利用で表示に入った行の task", value: { recorder.taskCounts[Self.farItem] }) {
            $0 == 1
        }
        let farCell = controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: Self.farItem, in: controller.collectionView)
        )
        XCTAssertTrue(
            farCell.map { cellsBeforeReuse.contains(ObjectIdentifier($0)) } ?? false,
            "離れた位置の行が、先頭で表示していたセルの再利用になっていません"
        )

        scroll(controller, to: 0)

        // 先頭の行は、表示から外れて再利用を経た後にもう一度表示に入る。
        await waitUntil("戻った先頭の行の onAppear", value: { recorder.appearCounts[0] }) { $0 == 2 }
        await waitUntil("戻った先頭の行の task", value: { recorder.taskCounts[0] }) { $0 == 2 }
    }

    func teststateを変えたセルが再利用されて載せた別の項目のstateは初期値である() async {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)
        let window = show(controller: controller)
        defer { window.isHidden = true }
        await expandFirstRow(recorder: recorder)
        let collectionView = controller.collectionView!
        guard let changedCell = collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: collectionView)
        ) else {
            XCTFail("先頭の行のセルがありません")
            return
        }

        // state を変えたセルが別の項目を載せるまで、可視範囲の半分ずつ送る。
        var reusedItem: Int?
        await waitUntil("state を変えたセルの再利用", value: { reusedItem }) { _ in
            collectionView.contentOffset.y += collectionView.bounds.height / 2
            collectionView.layoutIfNeeded()
            reusedItem = collectionView.indexPath(for: changedCell)
                .flatMap { ksItemOffset(for: $0, in: collectionView) }
                .flatMap { $0 == 0 ? nil : $0 }
            return reusedItem != nil
        }
        guard let reusedItem else { return }

        // 再利用の直後には、次の項目の中身が前の項目の state で一度評価されうる。確かめるのは、
        // 表示に出た結果 (落ち着いた後の state と、onAppear が動いた時点の state) である。
        await waitUntil("再利用された項目の onAppear", value: { recorder.appearCounts[reusedItem] }) {
            $0 != nil
        }
        await waitUntil("再利用された項目の state", value: { recorder.lastExpanded[reusedItem] }) {
            $0 == false
        }
        XCTAssertEqual(recorder.expandedAtAppear[reusedItem], false)
    }

    func test同値配列の更新による表示中のセルの作り直しではテンプレートのstateが残る() async {
        let recorder = Recorder()
        let configuration = makeConfiguration(recorder: recorder)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller)
        defer { window.isHidden = true }
        await expandFirstRow(recorder: recorder)

        // 配列は同値のまま、テンプレートの出力だけが変わる更新。
        recorder.suffix = " (更新)"
        controller.update(configuration: configuration)

        await waitUntil("作り直した先頭の行の文言", value: { recorder.lastLabel[0] }) { $0 == "項目 0 (更新)" }
        XCTAssertEqual(recorder.lastExpanded[0], true)
    }

    func test観測する値の変化による表示中のセルの作り直しではテンプレートのstateが残る() async {
        let recorder = Recorder()
        var configuration = makeConfiguration(recorder: recorder)
        configuration.observedValue = AnyHashable(0)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller: controller)
        defer { window.isHidden = true }
        await expandFirstRow(recorder: recorder)

        recorder.suffix = " (更新)"
        configuration.observedValue = AnyHashable(1)
        controller.update(configuration: configuration)

        await waitUntil("作り直した先頭の行の文言", value: { recorder.lastLabel[0] }) { $0 == "項目 0 (更新)" }
        XCTAssertEqual(recorder.lastExpanded[0], true)
    }

    // 先頭から中ほどを経由して、その先へ送る。先頭で表示していたセルは、最後の送りで再利用される。
    private func scrollViaMiddle(_ controller: KsCollectionViewController<Item>, recorder: Recorder) async {
        scroll(controller, to: Self.middleItem)
        await waitUntil("中ほどの行の表示", value: { recorder.appearCounts[Self.middleItem] }) { $0 != nil }
        scroll(controller, to: Self.farItem)
        await waitUntil("その先の行の表示", value: { recorder.appearCounts[Self.farItem] }) { $0 != nil }
    }

    private func expandFirstRow(recorder: Recorder) async {
        await waitUntil("先頭の行の初期 state", value: { recorder.appearCounts[0] }) { $0 != nil }
        XCTAssertEqual(recorder.lastExpanded[0], false)
        recorder.setExpanded(0, to: true)
        await waitUntil("先頭の行の state 変更", value: { recorder.lastExpanded[0] }) { $0 == true }
    }

    private func makeController(recorder: Recorder) -> KsCollectionViewController<Item> {
        KsCollectionViewController(configuration: makeConfiguration(recorder: recorder))
    }

    private func makeConfiguration(recorder: Recorder) -> KsCollectionConfiguration<Item> {
        KsCollectionConfiguration(
            items: (0..<300).map(Item.init),
            id: { AnyHashable($0.id) },
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry<Item> { item in
                Row(
                    id: item.id,
                    label: "項目 \(item.id)\(recorder.suffix)",
                    height: Self.height(of: item.id),
                    recorder: recorder
                )
            },
            layout: .list,
            contentPadding: EdgeInsets(),
            showsSeparators: false,
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

    private static func height(of id: Int) -> CGFloat {
        if id < middleItemsStart { return shortHeight }
        return id < tallItemsStart ? middleHeight : tallHeight
    }

    // 表示中のセルと、その中身のビュー。セルと中身のビューを強参照で控え、後から同じものかを比べる。
    private func contentViewsByCell(
        in controller: KsCollectionViewController<Item>
    ) -> [UICollectionViewCell: UIView] {
        Dictionary(
            uniqueKeysWithValues: controller.collectionView.visibleCells.map { ($0, $0.contentView) }
        )
    }

    private func visibleCellHeights(in controller: KsCollectionViewController<Item>) -> [CGFloat] {
        controller.collectionView.layoutIfNeeded()
        return controller.collectionView.visibleCells.map(\.bounds.height)
    }

    private func scroll(_ controller: KsCollectionViewController<Item>, to item: Int) {
        controller.collectionView.scrollToItem(
            at: ksIndexPath(forItemOffset: item, in: controller.collectionView),
            at: .top,
            animated: false
        )
        controller.collectionView.layoutIfNeeded()
    }

    // 自己サイズの解決には window が要る一方、safe area に重なるセルには SwiftUI が余白を足す。
    // 計測を素のコンテンツ高さで見るため、safe area の内側に収めて載せる。
    private func show(controller: UIViewController) -> UIWindow {
        let size = CGSize(width: 390, height: 844)
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

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while clock.now < deadline {
            if predicate(value()) {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))")
    }
}
#endif
