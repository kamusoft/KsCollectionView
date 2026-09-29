#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// ページングの 6 つの表示 (最後の項目の後ろの 3 つ・0 件のときの 3 つ) が、状態と件数に合わせて
/// 実レイアウトの上に出ることを確かめる。
@MainActor
final class KsPagingDisplayTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    private static let size = CGSize(width: 390, height: 800)
    private static let rowHeight: CGFloat = 80
    // 左右で違う内側余白。左右を取り違えると位置がずれるように、差を大きくする。
    private static let asymmetricPadding = EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 8)

    override func setUp() {
        super.setUp()
        KsInvalidInput.reset()
    }

    override func tearDown() {
        KsInvalidInput.reset()
        super.tearDown()
    }

    // MARK: - 表の組み合わせ

    func test状態と件数から出す表示が表のとおりに決まる() {
        let expected: [(KsPagingState, Bool, KsPagingDisplay?)] = [
            (.appending, false, .appendingIndicator),
            (.appending, true, .loadingPlaceholder),
            (.failed, false, .failedFooter),
            (.failed, true, .failedPlaceholder),
            (.endReached, false, .endReachedFooter),
            (.endReached, true, .emptyPlaceholder),
            (.refreshing, false, nil),
            (.refreshing, true, .loadingPlaceholder),
            (.idle, false, nil),
            (.idle, true, nil),
        ]
        for (state, isEmpty, display) in expected {
            XCTAssertEqual(KsPagingDisplay.resolve(state: state, isEmpty: isEmpty), display, "\(state) / 0 件 \(isEmpty)")
        }
    }

    // MARK: - 既定の表示

    func test次のページの読み込み中は最後の項目の後ろには置かず見えている範囲の下端に標準の読み込み中の表示を出す() async {
        let rows = makeRows(5)
        let controller = makeController(rows: rows, state: .appending, footer: true)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(5, in: controller)
        await Support.settleLayout(controller)

        // フッターの枠の中には出さない。
        let footerView = Support.rootFooterView(in: controller)
        XCTAssertFalse(Support.containsActivityIndicator(in: footerView), "フッターの枠の中に読み込み中の表示があります")
        XCTAssertEqual(Support.probeLabels(in: footerView), ["フッター"])
        // 見えている範囲の下端に重ねた入れ物に、標準の読み込み中の表示が 1 つ出る。
        guard let indicatorView = controller.pagingIndicatorView else {
            XCTFail("次のページの読み込み中の表示がありません")
            return
        }
        XCTAssertTrue(controller.isPagingIndicatorShown)
        await Support.waitUntil("標準の読み込み中の表示", value: { Support.containsActivityIndicator(in: indicatorView) }) { $0 }
        XCTAssertEqual(activityIndicatorCount(in: controller.collectionView), 1)
        XCTAssertNil(controller.pagingPlaceholderView.flatMap { $0.isHidden ? nil : $0 }, "0 件の表示が出ています")
    }

    func test最初の読み込み中は項目の代わりに標準の読み込み中の表示が1つ出る() async {
        for state in [KsPagingState.appending, .refreshing] {
            let controller = makeController(rows: [], state: state)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.settleLayout(controller)
            guard let placeholder = controller.pagingPlaceholderView, !placeholder.isHidden else {
                XCTFail("0 件の表示が出ていません (\(state))")
                continue
            }
            await Support.waitUntil("0 件の読み込み中の表示 (\(state))", value: {
                Support.containsActivityIndicator(in: placeholder)
            }) { $0 }
            XCTAssertEqual(activityIndicatorCount(in: controller.collectionView), 1, "読み込み中の表示が 1 つではありません (\(state))")
        }
    }

    func test失敗と終端と空は既定では何も出ない() async {
        for state in [KsPagingState.failed, .endReached] {
            for isEmpty in [false, true] {
                let controller = makeController(rows: isEmpty ? [] : makeRows(5), state: state)
                let window = Support.show(controller, size: Self.size)
                defer { window.isHidden = true }
                await Support.settleLayout(controller)
                let label = "\(state) / 0 件 \(isEmpty)"
                XCTAssertEqual(Support.rootFooterFrame(in: controller)?.height ?? 0, 0, accuracy: 0.5, "フッターの枠に高さがあります (\(label))")
                XCTAssertTrue(controller.pagingPlaceholderView?.isHidden ?? true, "0 件の表示が出ています (\(label))")
                XCTAssertEqual(activityIndicatorCount(in: controller.collectionView), 0, "\(label)")
            }
        }
    }

    // MARK: - 左右の余白

    // 左右の余白が非対称のとき・グリッドのとき・利用者のフッターが無いときも、最後の項目の後ろの
    // ページングの表示は左右の余白の内側に置かれ、利用者のフッターと同じ幅になる。
    func test最後の項目の後ろの表示は左右の余白の内側に置かれ利用者のフッターと同じ幅になる() async {
        let padding = Self.asymmetricPadding
        let layouts: [(String, KsCollectionLayout)] = [
            ("list", .list),
            ("grid", .grid(columns: .fixed(2), columnSpacing: 4)),
        ]
        for (name, layout) in layouts {
            for footer in [true, false] {
                for state in [KsPagingState.failed, .endReached] {
                    let label = "\(name) / フッター \(footer) / \(state)"
                    let controller = makeController(
                        rows: makeRows(5),
                        state: state,
                        footer: footer,
                        replacesAll: true,
                        layout: layout,
                        padding: padding
                    )
                    let window = Support.show(controller, size: Self.size)
                    defer { window.isHidden = true }
                    await Support.waitForItems(5, in: controller)
                    await Support.settleLayout(controller)
                    guard let footerView = Support.rootFooterView(in: controller) else {
                        XCTFail("フッターの枠がありません (\(label))")
                        continue
                    }
                    let expected = ["failed": "失敗", "endReached": "終端"]["\(state)"] ?? ""
                    await Support.waitUntil("ページングの表示 (\(label))", value: {
                        self.probeFrame(label: expected, in: footerView)
                    }) { $0 != nil }
                    footerView.layoutIfNeeded()
                    guard let pagingFrame = probeFrame(label: expected, in: footerView) else { continue }
                    let width = footerView.bounds.width
                    XCTAssertEqual(pagingFrame.minX, padding.leading, accuracy: 0.5, "左の余白の内側にありません (\(label))")
                    XCTAssertEqual(pagingFrame.maxX, width - padding.trailing, accuracy: 0.5, "右の余白の内側にありません (\(label))")
                    if footer, let footerFrame = probeFrame(label: "フッター", in: footerView) {
                        XCTAssertEqual(pagingFrame.minX, footerFrame.minX, accuracy: 0.5, "利用者のフッターと左端がそろいません (\(label))")
                        XCTAssertEqual(pagingFrame.width, footerFrame.width, accuracy: 0.5, "利用者のフッターと幅がそろいません (\(label))")
                    }
                }
            }
        }
    }

    // MARK: - 差し替えた表示

    func test差し替えた表示は表の組み合わせに対応するものだけが出る() async {
        let cases: [(KsPagingState, Bool, String?)] = [
            (.appending, false, "読み込み中"),
            (.failed, false, "失敗"),
            (.endReached, false, "終端"),
            (.appending, true, "最初の読み込み中"),
            (.refreshing, true, "最初の読み込み中"),
            (.failed, true, "失敗 (0 件)"),
            (.endReached, true, "空"),
            (.refreshing, false, nil),
            (.idle, false, nil),
            (.idle, true, nil),
        ]
        for (state, isEmpty, expected) in cases {
            let controller = makeController(rows: isEmpty ? [] : makeRows(5), state: state, replacesAll: true)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.settleLayout(controller)
            let label = "\(state) / 0 件 \(isEmpty)"
            await Support.waitUntil("差し替えた表示 (\(label))", value: { self.shownLabels(in: controller) }) {
                $0 == (expected.map { [$0] } ?? [])
            }
            XCTAssertEqual(activityIndicatorCount(in: controller.collectionView), 0, "既定の表示が出ています (\(label))")
        }
    }

    func testVMが始めた取り直しの間は項目の上に何も出さない() async {
        let rows = makeRows(20)
        let controller = makeController(rows: rows, state: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(20, in: controller)
        await Support.settleLayout(controller)

        controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing))
        await Support.settleLayout(controller)
        XCTAssertEqual(controller.appliedItemIdentifiers.count, 20, "項目が並んだままではありません")
        XCTAssertEqual(activityIndicatorCount(in: controller.collectionView), 0)
        XCTAssertTrue(controller.pagingPlaceholderView?.isHidden ?? true)
        XCTAssertFalse(controller.isPullRefreshing)
    }

    func test状態だけが変わったとき表示が新しい状態に合わせて変わる() async {
        let rows = makeRows(5)
        let controller = makeController(rows: rows, state: .appending, replacesAll: true)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(5, in: controller)
        await Support.settleLayout(controller)
        await Support.waitUntil("読み込み中の表示", value: { self.shownLabels(in: controller) }) { $0 == ["読み込み中"] }
        let snapshotApplies = controller.snapshotApplyCount

        // 配列はそのまま、状態だけを変える。追加読み込み中 → 待機 → 失敗 → 終端 → 追加読み込み中。
        let steps: [(KsPagingState, [String])] = [
            (.idle, []),
            (.failed, ["失敗"]),
            (.endReached, ["終端"]),
            (.appending, ["読み込み中"]),
        ]
        for (state, expected) in steps {
            controller.update(configuration: makeConfiguration(rows: rows, state: state, replacesAll: true))
            await Support.waitUntil("\(state) の表示", value: { self.shownLabels(in: controller) }) { $0 == expected }
        }
        XCTAssertEqual(controller.snapshotApplyCount, snapshotApplies, "状態だけの変化で snapshot を適用しています")
        // 終端 → 追加読み込み中で、フッターの枠の表示が消えて高さが 0 に戻る。
        await Support.waitUntil("フッターの枠の高さ", value: { () -> [CGFloat] in
            controller.collectionView.layoutIfNeeded()
            return [
                Support.rootFooterFrame(in: controller)?.height ?? -1,
                Support.rootFooterView(in: controller)?.frame.height ?? -1,
            ]
        }) { $0.allSatisfy { abs($0) < 0.5 } }
    }

    // MARK: - 0 件の表示の重なりと再試行

    func test0件の表示はヘッダーと重なっても手前に出て再試行を押せる() async {
        let probe = KsPagingProbe()
        var retry: (@MainActor () -> Void)?
        var view = KsCollectionView([KsPagingRow](), layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .header { KsPagingLabeledView(label: "ヘッダー", height: 700) }
        .paging(.failed, onLoadMore: probe.loadMoreAction)
        view = view.pagingFailedPlaceholder { action in
            let _ = { retry = action }()
            KsPagingLabeledView(label: "失敗 (0 件)", height: 60)
        }
        let controller = KsCollectionViewController(configuration: view.configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.settleLayout(controller)
        guard let placeholder = controller.pagingPlaceholderView, !placeholder.isHidden else {
            XCTFail("0 件の表示が出ていません")
            return
        }
        await Support.waitUntil("0 件の表示の中身", value: { Support.probeLabels(in: placeholder) }) {
            $0 == ["失敗 (0 件)"]
        }
        placeholder.layoutIfNeeded()
        guard let content = placeholder.hostedContentView else {
            XCTFail("0 件の表示の中身がありません")
            return
        }
        // 中身の真ん中は、ヘッダーより手前の 0 件の表示に当たる。
        let center = content.convert(CGPoint(x: content.bounds.midX, y: content.bounds.midY), to: window)
        let hit = window.hitTest(center, with: nil)
        XCTAssertTrue(hit.map { $0.isDescendant(of: placeholder) } ?? false, "0 件の表示の中身に当たりません: \(String(describing: hit))")
        // 中身の外 (ヘッダーの上端近く) は下のヘッダーへ通る。
        let outside = window.hitTest(CGPoint(x: 20, y: 120), with: nil)
        XCTAssertFalse(outside.map { $0.isDescendant(of: placeholder) } ?? true, "0 件の表示の外のタッチを受けています")
        XCTAssertTrue(outside.map { $0.isDescendant(of: controller.collectionView) } ?? false)

        // 再試行の操作は次ページ要求を呼ぶ。
        XCTAssertNotNil(retry)
        retry?()
        await Support.waitUntil("再試行の次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    // 0 件の表示の中身が別の表示に切り替わったら、新しい中身の大きさで描く (前の中身の大きさのまま切れない)。
    func test0件の表示の中身が切り替わると新しい中身の大きさで描かれる() async {
        let short = "空"
        let long = "読み込めませんでした。もう一度お試しください"
        func configuration(_ state: KsPagingState) -> KsCollectionConfiguration<KsPagingRow> {
            KsCollectionView([KsPagingRow](), layout: .list) { row in Text("\(row.id)") }
                .paging(state) {}
                .pagingEmptyPlaceholder { Text(short).fixedSize() }
                .pagingFailedPlaceholder { _ in Text(long).fixedSize() }
                .pagingLoadingPlaceholder { Text(short).fixedSize() }
                .configuration
        }
        let expected = UIHostingController(rootView: Text(long).fixedSize())
            .sizeThatFits(in: CGSize(width: 10_000, height: 10_000))
        for first in [KsPagingState.endReached, .appending] {
            let controller = KsCollectionViewController(configuration: configuration(first))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.settleLayout(controller)
            controller.update(configuration: configuration(.failed))
            await Support.waitUntil("切り替えた中身の大きさ (\(first) から)", value: { () -> CGSize in
                controller.pagingPlaceholderView?.layoutIfNeeded()
                return controller.pagingPlaceholderView?.hostedContentView?.bounds.size ?? .zero
            }) { abs($0.width - expected.width) < 1 && abs($0.height - expected.height) < 1 }
        }
    }

    func test0件の表示は上下の安全領域を除いた範囲の真ん中に出る() async {
        let controller = makeController(rows: [], state: .endReached, replacesAll: true)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        let safeArea = controller.collectionView.safeAreaInsets
        XCTAssertGreaterThan(safeArea.top, 0, "表示先が上端の安全領域を持っていません")
        await Support.settleLayout(controller)
        guard let content = controller.pagingPlaceholderView?.hostedContentView else {
            XCTFail("0 件の表示が出ていません")
            return
        }
        controller.pagingPlaceholderView?.layoutIfNeeded()
        let frame = content.convert(content.bounds, to: window)
        let expectedMidY = safeArea.top + (Self.size.height - safeArea.top - safeArea.bottom) / 2
        XCTAssertEqual(frame.midY, expectedMidY, accuracy: 1, "真ん中にありません")
        XCTAssertEqual(frame.midX, Self.size.width / 2, accuracy: 1)
        // スクロールしても表示範囲に留まる。
        Support.scroll(controller, to: -40)
        let moved = content.convert(content.bounds, to: window)
        XCTAssertEqual(moved.midY, expectedMidY, accuracy: 1, "スクロールで動いています")
    }

    func test項目があるときの再試行は次ページ要求を呼ぶ() async {
        let probe = KsPagingProbe()
        var retry: (@MainActor () -> Void)?
        let view = KsCollectionView(makeRows(5), layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .paging(.failed, onLoadMore: probe.loadMoreAction)
        .pagingFailedFooter { action in
            let _ = { retry = action }()
            KsPagingLabeledView(label: "失敗")
        }
        let controller = KsCollectionViewController(configuration: view.configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(5, in: controller)
        await Support.settleLayout(controller)
        await Support.waitUntil("失敗の表示", value: { self.shownLabels(in: controller) }) { $0 == ["失敗"] }
        // 失敗の状態では自動では頼まない。
        XCTAssertEqual(probe.loadMoreCount, 0)
        retry?()
        await Support.waitUntil("再試行の次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
    }

    func test0件のときの再試行は取り直しではなく次ページ要求を呼ぶ() async {
        let probe = KsPagingProbe()
        var retry: (@MainActor () -> Void)?
        var configuration = KsCollectionView([KsPagingRow](), layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .paging(.failed, onLoadMore: probe.loadMoreAction)
        .pagingFailedPlaceholder { action in
            let _ = { retry = action }()
            KsPagingLabeledView(label: "失敗 (0 件)")
        }
        .configuration
        configuration.refresh = probe.refreshAction
        let controller = KsCollectionViewController(configuration: configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.settleLayout(controller)
        await Support.waitUntil("失敗 (0 件) の表示", value: { self.shownLabels(in: controller) }) { $0 == ["失敗 (0 件)"] }
        retry?()
        await Support.waitUntil("再試行の次ページ要求", value: { probe.loadMoreCount }) { $0 == 1 }
        XCTAssertEqual(probe.refreshCount, 0, "取り直しの処理が呼ばれています")
    }

    // MARK: - 読み上げ

    // 既定の読み込み中の表示は、文言を付けない標準の読み込み中の表示 (システムの活動インジケータ) で描かれ、
    // 読み上げでは OS がその部品の言葉で読む。単体テストの実行環境では読み上げの要素の木が組まれないため、
    // ここでは標準の部品で描かれ動いていること・ライブラリが名前を与えていないことを確かめる。
    // 読み上げに出ることそのものは、アプリの UI テストで確かめる。
    func test既定の読み込み中の表示は標準の読み込み中の部品で描かれ文言を持たない() async {
        for isEmpty in [false, true] {
            let controller = makeController(rows: isEmpty ? [] : makeRows(5), state: .appending)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.settleLayout(controller)
            let host: UIView? = isEmpty ? controller.pagingPlaceholderView : controller.pagingIndicatorView
            await Support.waitUntil("読み込み中の表示 (0 件 \(isEmpty))", value: {
                Support.containsActivityIndicator(in: host)
            }) { $0 }
            let indicators = activityIndicators(in: host)
            XCTAssertEqual(indicators.count, 1)
            guard let indicator = indicators.first else { continue }
            XCTAssertTrue(indicator.isAnimating, "読み込み中の表示が動いていません")
            XCTAssertNil(indicator.accessibilityLabel, "ライブラリが読み上げの名前を与えています")
        }
    }

    // MARK: - 部品

    private func makeRows(_ count: Int) -> [KsPagingRow] {
        (0..<count).map { KsPagingRow(id: $0) }
    }

    private func makeConfiguration(
        rows: [KsPagingRow],
        state: KsPagingState,
        footer: Bool = false,
        replacesAll: Bool = false,
        layout: KsCollectionLayout = .list,
        padding: EdgeInsets = EdgeInsets()
    ) -> KsCollectionConfiguration<KsPagingRow> {
        var view = KsCollectionView(rows, layout: layout, contentPadding: padding) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .paging(state) {}
        if footer {
            view = view.footer { KsPagingLabeledView(label: "フッター", height: 30) }
        }
        if replacesAll {
            view = view
                .pagingAppendingIndicator { KsPagingLabeledView(label: "読み込み中") }
                .pagingFailedFooter { _ in KsPagingLabeledView(label: "失敗") }
                .pagingEndReachedFooter { KsPagingLabeledView(label: "終端") }
                .pagingLoadingPlaceholder { KsPagingLabeledView(label: "最初の読み込み中") }
                .pagingFailedPlaceholder { _ in KsPagingLabeledView(label: "失敗 (0 件)") }
                .pagingEmptyPlaceholder { KsPagingLabeledView(label: "空") }
        }
        var configuration = view.configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func makeController(
        rows: [KsPagingRow],
        state: KsPagingState,
        footer: Bool = false,
        replacesAll: Bool = false,
        layout: KsCollectionLayout = .list,
        padding: EdgeInsets = EdgeInsets()
    ) -> KsCollectionViewController<KsPagingRow> {
        KsCollectionViewController(
            configuration: makeConfiguration(
                rows: rows,
                state: state,
                footer: footer,
                replacesAll: replacesAll,
                layout: layout,
                padding: padding
            )
        )
    }

    // フッターの枠と 0 件の表示に出ている、差し替えた表示の目印。
    private func shownLabels(in controller: KsCollectionViewController<KsPagingRow>) -> [String] {
        let footer = Support.probeLabels(in: Support.rootFooterView(in: controller))
        let indicator = controller.isPagingIndicatorShown ? controller.pagingIndicatorView : nil
        let placeholder = controller.pagingPlaceholderView.flatMap { $0.isHidden ? nil : $0 }
        return Support.probeLabels(in: indicator) + footer + Support.probeLabels(in: placeholder)
    }

    private func activityIndicators(in view: UIView?) -> [UIActivityIndicatorView] {
        guard let view, !view.isHidden else { return [] }
        if let indicator = view as? UIActivityIndicatorView {
            return [indicator]
        }
        return view.subviews.flatMap { activityIndicators(in: $0) }
    }

    private func activityIndicatorCount(in view: UIView) -> Int {
        activityIndicators(in: view).count
    }

    private func probeFrame(label: String, in view: UIView) -> CGRect? {
        func find(_ current: UIView) -> KsPagingProbeView? {
            if let probe = current as? KsPagingProbeView, probe.label == label {
                return probe
            }
            for subview in current.subviews {
                if let found = find(subview) {
                    return found
                }
            }
            return nil
        }
        return find(view).map { $0.convert($0.bounds, to: view) }
    }
}
#endif
