#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// 次ページ要求の発火を、実レイアウトの上のスクロール・配列の差し替え・状態の変化・大きさの変化で確かめる。
@MainActor
final class KsPagingTriggerTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    // 行の高さ 80 に対して表示範囲の高さ 800 で、ちょうど 10 件 (グリッドは 2 列 × 5 行) が画面に出る。
    private static let size = CGSize(width: 390, height: 800)
    private static let rowHeight: CGFloat = 80

    override func setUp() {
        super.setUp()
        KsInvalidInput.reset()
    }

    override func tearDown() {
        KsInvalidInput.reset()
        super.tearDown()
    }

    // MARK: - 発火の位置

    func test既定のしきい値では画面に出るいちばん後ろの項目が89番目に届いたときに頼む() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(100), probe: probe)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)

        // いちばん後ろの項目が 9, 19, ..., 88 番目の位置では頼まない。
        var offset: CGFloat = 0
        while offset <= 89 * Self.rowHeight - Self.size.height {
            Support.scroll(controller, to: offset)
            XCTAssertEqual(controller.pagingRequester.requestCount, 0, "いちばん後ろが \(visibleLast(controller)) 番目で頼んでいます")
            offset += Self.rowHeight
        }
        // いちばん後ろの項目が 89 番目になる位置。
        Support.scroll(controller, to: 90 * Self.rowHeight - Self.size.height)
        XCTAssertEqual(visibleLast(controller), 89)
        XCTAssertEqual(controller.visiblePagingItems().count, 10)
        await Support.waitUntil("次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
        XCTAssertEqual(controller.pagingRequester.requestCount, 1)
    }

    func testしきい値2では79番目に届いたときに頼む() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(100), probe: probe, threshold: 2)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)

        Support.scroll(controller, to: 79 * Self.rowHeight - Self.size.height)
        XCTAssertEqual(visibleLast(controller), 78)
        XCTAssertEqual(controller.pagingRequester.requestCount, 0)
        Support.scroll(controller, to: 80 * Self.rowHeight - Self.size.height)
        XCTAssertEqual(visibleLast(controller), 79)
        await Support.waitUntil("次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    func testしきい値0では最後の項目が画面に入ったときに頼む() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(100), probe: probe, threshold: 0)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)

        // 最後の項目の上端が表示範囲の下端に接する位置 (まだ画面に入っていない)。
        Support.scroll(controller, to: 99 * Self.rowHeight - Self.size.height)
        XCTAssertEqual(visibleLast(controller), 98)
        XCTAssertEqual(controller.pagingRequester.requestCount, 0)
        // 1pt だけ入った位置。
        Support.scroll(controller, to: 99 * Self.rowHeight - Self.size.height + 1)
        XCTAssertEqual(visibleLast(controller), 99)
        await Support.waitUntil("次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    func testグリッドは行ではなく項目の数で数える() async {
        let probe = KsPagingProbe()
        // 2 列で行の高さ 160。画面に 5 行 = 10 件が出る。
        let controller = makeController(
            rows: makeRows(100),
            probe: probe,
            layout: .grid(columns: .fixed(2)),
            rowHeight: 160
        )
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)

        // いちばん後ろが 87 番目 (44 行目の手前の行まで)。残り 12 件 > 10 件。
        Support.scroll(controller, to: 44 * 160 - Self.size.height)
        XCTAssertEqual(visibleLast(controller), 87)
        XCTAssertEqual(controller.visiblePagingItems().count, 10)
        XCTAssertEqual(controller.pagingRequester.requestCount, 0)
        // いちばん後ろが 89 番目。残り 10 件 <= 1 × 10 件。
        Support.scroll(controller, to: 45 * 160 - Self.size.height)
        XCTAssertEqual(visibleLast(controller), 89)
        XCTAssertEqual(controller.visiblePagingItems().count, 10)
        await Support.waitUntil("次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    func test見出しとフッターとページングの表示は数えない() async {
        let probe = KsPagingProbe()
        // 12 件を 4 件ずつ 3 つのグループに分け、見出し・ルートのフッター・ページングの表示を出す。
        let rows = (0..<12).map { KsPagingRow(id: $0, group: $0 / 4) }
        var view = KsCollectionView(rows, layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .groups(by: \.group) { group, _ in KsPagingFixedView(text: "見出し \(group)", height: 60) }
        .footer { KsPagingFixedView(text: "フッター", height: 200) }
        .paging(.appending, onLoadMore: probe.loadMoreAction)
        view = view.pagingAppendingIndicator { KsPagingLabeledView(label: "読み込み中", height: 100) }
        var configuration = view.configuration
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(12, in: controller)
        await Support.scrollToBottom(controller)

        // 表示範囲と重なる要素のうち、項目 (セル) だけを数えた数と一致する。
        let bounds = controller.collectionView.bounds
        let attributes = controller.collectionView.collectionViewLayout.layoutAttributesForElements(in: bounds) ?? []
        let cells = attributes.filter { $0.representedElementCategory == .cell && $0.frame.intersects(bounds) }
        let supplementaries = attributes.filter { $0.representedElementCategory == .supplementaryView && $0.frame.intersects(bounds) }
        XCTAssertFalse(supplementaries.isEmpty, "見出しかフッターが画面に出ていません")
        let visible = controller.visiblePagingItems()
        XCTAssertEqual(visible.count, cells.count)
        XCTAssertEqual(visible.lastIndex, 11, "いちばん後ろの項目の位置が見出しやフッターで数え違えています")
        // 残りの項目の数は 0 で、表示を数えていれば負になる。
        XCTAssertEqual(rows.count - 1 - (visible.lastIndex ?? 0), 0)
    }

    func test項目があるのに表示範囲がヘッダーだけで埋まっていれば頼まずスクロールで項目が出てから頼む() async {
        let probe = KsPagingProbe()
        var view = KsCollectionView(makeRows(5), layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .header { KsPagingFixedView(text: "ヘッダー", height: 1_200) }
        .paging(.idle, onLoadMore: probe.loadMoreAction)
        view = view.pagingAppendingIndicator { EmptyView() }
        let controller = KsCollectionViewController(configuration: view.configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(5, in: controller)
        await Support.settleLayout(controller)
        XCTAssertEqual(controller.visiblePagingItems().count, 0)
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0, "画面に項目が出ていないのに頼んでいます")

        // 項目の一部だけが出る位置 (0〜1 番目が出て、残り 3 件 > 2 件) ではまだ頼まない。
        Support.scroll(controller, to: 500)
        XCTAssertEqual(controller.visiblePagingItems().count, 2)
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0)
        // 末尾まで送ると、画面に出た項目で判定されて頼む。
        await Support.scrollToBottom(controller)
        await Support.waitUntil("項目が出てからの次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    // MARK: - 判定し直すきっかけ

    func test1ページが画面に満たないときはスクロールしなくても残りがしきい値を超えるまで頼み続ける() async {
        let probe = KsPagingProbe()
        var rows: [KsPagingRow] = []
        var controller: KsCollectionViewController<KsPagingRow>!
        // 1 ページ 3 件。処理の中で配列を足し、状態は待機のまま同じ回に書き換える。
        probe.onLoadMore = {
            let start = rows.count
            rows += (start..<start + 3).map { KsPagingRow(id: $0) }
            controller.update(configuration: self.makeConfiguration(rows: rows, probe: probe))
        }
        controller = makeController(rows: [], probe: probe)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }

        // 画面に 10 件出ている間は残りが 10 件以下のため頼み続け、残りが 10 件を超えたところで止まる。
        await Support.waitUntil("頼み続けて止まる", timeout: .seconds(5), value: { rows.count }) { $0 >= 21 }
        await Support.settleLayout(controller)
        let settledCount = rows.count
        await Support.yield()
        XCTAssertEqual(rows.count, settledCount, "止まるべきところで頼み続けています")
        XCTAssertEqual(controller.collectionView.contentOffset.y, 0, accuracy: 0.5, "スクロールしています")
        let visible = controller.visiblePagingItems()
        XCTAssertGreaterThan(rows.count - 1 - (visible.lastIndex ?? 0), visible.count, "残りがしきい値を超えていません")
    }

    func test失敗から待機に戻すと判定し直して頼む() async {
        let probe = KsPagingProbe()
        let rows = makeRows(20)
        let controller = makeController(rows: rows, probe: probe, state: .failed)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(20, in: controller)
        await Support.scrollToBottom(controller)
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0, "失敗の状態で自動で頼んでいます")

        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, state: .idle))
        await Support.waitUntil("待機に戻した後の次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    func test終端では最後の項目までスクロールしても頼まない() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(20), probe: probe, state: .endReached)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(20, in: controller)
        await Support.scrollToBottom(controller)
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0)
    }

    func test一覧の大きさが変わって画面に出る項目の数が増えるとスクロールしなくても頼む() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(100), probe: probe)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)
        // 70〜79 番目が出ている。残り 20 件 > 10 件。
        Support.scroll(controller, to: 70 * Self.rowHeight)
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0)

        // 縦に伸ばして 70〜84 番目の 15 件が出るようにする。残り 15 件 <= 15 件。
        window.frame = CGRect(origin: .zero, size: CGSize(width: Self.size.width, height: 1_200))
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        await Support.waitUntil("大きさの変化の後の次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
        XCTAssertEqual(controller.visiblePagingItems().count, 15)
    }

    // MARK: - ページングを付けない一覧・状態を書き換えない

    func testページングを付けない一覧は末尾までスクロールしても頼まずページングの表示を出さない() async {
        var configuration = KsCollectionView(makeRows(30), layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .configuration
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(30, in: controller)
        await Support.scrollToBottom(controller)
        await Support.yield()
        XCTAssertEqual(controller.pagingRequester.requestCount, 0)
        XCTAssertNil(controller.pagingPlaceholderView)
        XCTAssertNil(Support.rootFooterFrame(in: controller), "フッターの枠を置いています")
        XCTAssertFalse(Support.containsActivityIndicator(in: controller.collectionView))
    }

    func testライブラリは次ページ要求を呼んでも状態を書き換えない() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: [], probe: probe)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("最初の読み込みの次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
        await Support.yield()
        XCTAssertEqual(controller.pagingState, .idle)
        XCTAssertEqual(probe.loadMoreCount, 1, "状態も配列も変わっていないのに頼み直しています")
    }

    func test空で待機なら表示したときに1回だけ頼む() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: [], probe: probe, threshold: 0)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("最初の読み込みの次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 1)
    }

    func test画面に載る前は頼まない() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: [], probe: probe)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: Self.size)
        controller.view.layoutIfNeeded()
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0)
    }

    // MARK: - 取り消し

    func test読み込み中に一覧を含む画面を閉じると実行中の処理が取り消される() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.loadMoreGate = gate
        let visibility = KsPagingVisibility()
        let host = UIHostingController(rootView: KsPagingClosableView(visibility: visibility, probe: probe))
        let window = Support.show(host, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("最初の読み込みの待ち", value: { gate.waitingCount }) { $0 == 1 }

        visibility.showsList = false
        await Support.waitUntil("処理の取り消し", value: { gate.cancelledWhileWaiting }) { $0 }
    }

    func test別の画面を上に積んでも一覧が残っている間は取り消さない() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.loadMoreGate = gate
        let controller = makeController(rows: [], probe: probe)
        let navigation = UINavigationController(rootViewController: controller)
        let window = Support.show(navigation, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("最初の読み込みの待ち", value: { gate.waitingCount }) { $0 == 1 }

        navigation.pushViewController(UIViewController(), animated: false)
        await Support.yield()
        XCTAssertFalse(gate.cancelledWhileWaiting, "一覧が残っているのに取り消しています")
        XCTAssertTrue(controller.pagingRequester.isRunning)
        gate.open()
    }

    // MARK: - 判定を飛ばす間の状態の変化

    // 一覧が画面に載っていない間 (判定を飛ばす間) に、状態が「待機 → 追加読み込み中 → 待機」と往復し配列は
    // 変わらなかった。画面に戻ったら、状態が変わったとして次を頼む。
    func test判定を飛ばす間に状態が往復しても画面に戻ったら次を頼む() async {
        let probe = KsPagingProbe()
        let rows = makeRows(100)
        let controller = makeController(rows: rows, probe: probe)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 90 * Self.rowHeight - Self.size.height)
        await Support.waitUntil("最初の次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
        await Support.waitUntil("処理の終わり", value: { controller.pagingRequester.isRunning }) { !$0 }

        // 画面から外した間に、状態だけが往復する (続きがあるのに 0 件のページが返った VM など)。
        window.rootViewController = UIViewController()
        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, state: .appending))
        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, state: .idle))
        XCTAssertEqual(probe.loadMoreCount, 1)

        window.rootViewController = controller
        controller.view.layoutIfNeeded()
        await Support.waitUntil("画面に戻った後の次ページ要求", value: { probe.loadMoreCount }) { $0 == 2 }
    }

    // MARK: - 不正なしきい値

    func test負のしきい値はリリースの縮退で警告を出し最後の項目が画面に入ったときに頼む() async {
        KsInvalidInput.assertsInDebug = false
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(100), probe: probe, threshold: -2)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        XCTAssertTrue(
            KsInvalidInput.reportedWarnings.contains { $0.contains("しきい値") && $0.contains("-2") },
            "警告が記録されていません: \(KsInvalidInput.reportedWarnings)"
        )
        await Support.waitForItems(100, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 99 * Self.rowHeight - Self.size.height)
        await Support.yield()
        XCTAssertEqual(probe.loadMoreCount, 0, "しきい値 0 の位置より前で頼んでいます")
        Support.scroll(controller, to: 99 * Self.rowHeight - Self.size.height + 1)
        await Support.waitUntil("次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    func test有限でないしきい値も不正として警告を出す() {
        KsInvalidInput.assertsInDebug = false
        let probe = KsPagingProbe()
        let controller = makeController(rows: makeRows(3), probe: probe, threshold: .nan)
        XCTAssertTrue(KsInvalidInput.reportedWarnings.contains { $0.contains("しきい値") && $0.contains("nan") })
        // 同じ値のまま更新しても、改めて知らせない (値が変わった回にだけ知らせる)。
        let count = KsInvalidInput.reportedWarnings.count
        controller.update(configuration: makeConfiguration(rows: makeRows(3), probe: probe, threshold: .nan))
        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, count)
        controller.update(configuration: makeConfiguration(rows: makeRows(3), probe: probe, threshold: .infinity))
        XCTAssertTrue(KsInvalidInput.reportedWarnings.contains { $0.contains("しきい値") && $0.contains("inf") })
    }

    // MARK: - 部品

    private func makeRows(_ count: Int) -> [KsPagingRow] {
        (0..<count).map { KsPagingRow(id: $0) }
    }

    private func makeConfiguration(
        rows: [KsPagingRow],
        probe: KsPagingProbe,
        state: KsPagingState = .idle,
        threshold: Double = 1,
        layout: KsCollectionLayout = .list,
        rowHeight: CGFloat = KsPagingTriggerTests.rowHeight
    ) -> KsCollectionConfiguration<KsPagingRow> {
        // 次のページの読み込み中の表示は、この試験では見なくてよいため消しておく。
        var configuration = KsCollectionView(rows, layout: layout) { row in
            KsPagingFixedView(text: "\(row.id)", height: rowHeight)
        }
        .paging(state, threshold: threshold, onLoadMore: probe.loadMoreAction)
        .pagingAppendingIndicator { EmptyView() }
        .configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func makeController(
        rows: [KsPagingRow],
        probe: KsPagingProbe,
        state: KsPagingState = .idle,
        threshold: Double = 1,
        layout: KsCollectionLayout = .list,
        rowHeight: CGFloat = KsPagingTriggerTests.rowHeight
    ) -> KsCollectionViewController<KsPagingRow> {
        KsCollectionViewController(
            configuration: makeConfiguration(
                rows: rows,
                probe: probe,
                state: state,
                threshold: threshold,
                layout: layout,
                rowHeight: rowHeight
            )
        )
    }

    private func visibleLast(_ controller: KsCollectionViewController<KsPagingRow>) -> Int {
        controller.visiblePagingItems().lastIndex ?? -1
    }
}

// 一覧を出したり消したりする画面の状態。パッケージの対応 OS に合わせて ObservableObject で持つ。
@MainActor
final class KsPagingVisibility: ObservableObject {
    @Published var showsList = true
}

// 一覧を含む画面を閉じる操作を、一覧を表示から外すことで表す。
struct KsPagingClosableView: View {
    @ObservedObject var visibility: KsPagingVisibility
    let probe: KsPagingProbe

    var body: some View {
        if visibility.showsList {
            KsCollectionView([KsPagingRow]()) { row in
                Text("\(row.id)")
            }
            .paging(.idle, onLoadMore: probe.loadMoreAction)
        } else {
            Color.clear
        }
    }
}
#endif
