#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// 一覧を画面いっぱいに載せ、上端の安全領域 (ステータスバー・ナビゲーションバー) に重ねたときの見え方を
/// エンジンの実レイアウトで確かめる。
///
/// - セル・グループの見出し・ルートのヘッダー / フッターは安全領域に被ったまま流れ、中身は安全領域の
///   分だけ押し下げられず、高さも中身どおりになる
/// - 固定中のグループの見出しは上端の安全領域の境目で止まり、押し上げもその境目を基準にする
/// - 安全領域に重ならない置き方では、見出しは表示範囲の上端に固定される
@MainActor
final class KsSafeAreaTests: XCTestCase {
    private struct Row: Identifiable, Equatable {
        let id: Int
        let group: String
    }

    // 中身の背景に敷く目印のビュー。載せたセル / 補助ビューの中で、中身がどこに置かれたかを測るために使う。
    private final class ProbeView: UIView {
        var label = ""
    }

    private struct ProbeRepresentable: UIViewRepresentable {
        let label: String

        func makeUIView(context: Context) -> ProbeView {
            let view = ProbeView()
            view.label = label
            return view
        }

        func updateUIView(_ uiView: ProbeView, context: Context) {
            uiView.label = label
        }
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

    // MARK: - 中身の高さと位置

    func testルートのヘッダーは上端から始まり安全領域に被っても高さが中身どおりになる() async {
        var configuration = KsCollectionView(makeRows([("果物", 3)]), layout: .list) { row in
            FixedHeightView(label: "行 \(row.id)", height: Self.rowHeight)
        }
        .header { FixedHeightView(label: "ヘッダー", height: 40) }
        .footer { FixedHeightView(label: "フッター", height: 30) }
        .configuration
        configuration.contentPadding = EdgeInsets(top: 20, leading: 0, bottom: 24, trailing: 0)
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(3, in: controller)
        await settleLayout(in: controller)

        guard
            let header = supplementaryFrames(ofKind: KsSupplementaryKind.rootHeader, in: controller).first,
            let footer = supplementaryFrames(ofKind: KsSupplementaryKind.rootFooter, in: controller).first
        else {
            XCTFail("ヘッダー / フッターのレイアウト属性を取得できませんでした")
            return
        }
        // 先頭には安全領域の分の余白を足さない。ヘッダーは表示範囲の上端から始まり、安全領域に被る。
        XCTAssertEqual(controller.collectionView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertEqual(controller.collectionView.adjustedContentInset.top, 0, accuracy: 0.5)
        XCTAssertEqual(header.minY, 0, accuracy: 0.5)
        XCTAssertLessThan(header.minY, safeTop, "ヘッダーが安全領域に被っていません")
        XCTAssertEqual(header.height, 40 + 20, accuracy: 0.5, "ヘッダーの高さが安全領域の分だけ増えています")
        XCTAssertEqual(footer.height, 30 + 24, accuracy: 0.5, "フッターの高さが変わっています")
        // ヘッダーの中身は上の内側余白の分だけ下がった位置から始まり、安全領域の分は下がらない。
        let headerView = controller.collectionView.visibleSupplementaryViews(ofKind: KsSupplementaryKind.rootHeader).first
        XCTAssertEqual(headerView.flatMap { contentTop(label: "ヘッダー", in: $0) } ?? -1, 20, accuracy: 0.5)
    }

    func testセルとグループの見出しは安全領域に被っても高さが中身どおりで押し下げられない() async {
        let controller = makeGroupedController(rows: makeRows([("果物", 3), ("野菜", 3)]), pinnedHeaders: false)
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(6, in: controller)
        await settleLayout(in: controller)

        // 先頭の見出しと先頭の行は内容の先頭にあり、上端の安全領域に重なっている。
        let headers = supplementaryFrames(ofKind: KsSupplementaryKind.groupHeader, in: controller)
        let rows = itemFrames(in: controller, offsets: [0, 1])
        guard let firstHeader = headers.first, rows.count == 2 else {
            XCTFail("レイアウト属性を取得できませんでした (\(headers.count) / \(rows.count))")
            return
        }
        XCTAssertEqual(firstHeader.minY, 0, accuracy: 0.5)
        XCTAssertLessThan(rows[0].minY, safeTop, "先頭の行が安全領域に重なる位置にありません")
        XCTAssertEqual(firstHeader.height, Self.headerHeight, accuracy: 0.5, "見出しの高さが安全領域の分だけ増えています")
        XCTAssertEqual(rows[0].height, Self.rowHeight, accuracy: 0.5, "行の高さが安全領域の分だけ増えています")

        // 中身は載せたビューの上端から始まる。
        await waitUntil("見出しの中身の位置", value: { groupHeaderContentTop(label: "見出し 果物", in: controller) }) {
            $0.map { abs($0) < 0.5 } ?? false
        }
        await waitUntil("行の中身の位置", value: { cellContentTop(offset: 0, in: controller) }) {
            $0.map { abs($0) < 0.5 } ?? false
        }
    }

    func test上端の安全領域の下へ送った行の中身は押し下げられない() async {
        let controller = makeGroupedController(rows: makeRows([("果物", 60)]), pinnedHeaders: false)
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(60, in: controller)
        await settleLayout(in: controller)

        // 行 10 を表示範囲の上端に置く。行は上端の安全領域に重なる。
        await scroll(toOffset: 10, in: controller)
        guard let row = itemFrames(in: controller, offsets: [10]).first else {
            XCTFail("行 10 の位置を取得できませんでした")
            return
        }
        XCTAssertLessThan(row.minY - controller.collectionView.bounds.minY, safeTop, "行が安全領域に重なる位置にありません")
        XCTAssertEqual(row.height, Self.rowHeight, accuracy: 0.5, "行の高さが変わっています")
        await waitUntil("行の中身の位置", value: { cellContentTop(offset: 10, in: controller) }) {
            $0.map { abs($0) < 0.5 } ?? false
        }
    }

    // MARK: - 固定中の見出しの位置

    func test固定中の見出しは上端の安全領域の境目に止まり中身が押し下げられない() async {
        let controller = makeGroupedController(rows: makeRows([("果物", 30), ("野菜", 1_200)]))
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(1_230, in: controller)
        await settleLayout(in: controller)

        // 「野菜」の途中 (塊の境目を越えた先を含む) へ送り、見出しが境目に固定されている間を確かめる。
        for target in [30 + 10, 30 + 600] {
            await scroll(toOffset: target, in: controller)
            let boundary = controller.collectionView.bounds.minY + safeTop
            guard let header = pinnedHeader(at: boundary, in: controller, label: "\(target)") else { continue }
            XCTAssertEqual(header.frame.minY, boundary, accuracy: 0.5, "見出しが安全領域の境目に固定されていません (\(target))")
            XCTAssertEqual(header.frame.height, Self.headerHeight, accuracy: 0.5, "見出しの高さが変わっています (\(target))")
            await waitUntil("固定中の見出しの中身の位置 (\(target))", value: {
                pinnedHeaderContentTop(at: boundary, label: "見出し 野菜", in: controller)
            }) { $0.map { abs($0) < 0.5 } ?? false }
        }
    }

    func test固定中の見出しは安全領域の境目を基準に次の見出しに押し上げられる() async {
        let controller = makeGroupedController(rows: makeRows([("果物", 30), ("野菜", 30)]))
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(60, in: controller)
        await settleLayout(in: controller)
        await scroll(toOffset: 20, in: controller)
        guard let lastRow = itemFrames(in: controller, offsets: [29]).first else {
            XCTFail("「果物」の最終行の位置を取得できませんでした")
            return
        }
        let groupBottom = lastRow.maxY

        // 「果物」の最終行の下端が境目の 10pt 下 (見出しの高さより近い) に来る位置。
        // 「果物」の見出しは最終行の下端に押し上げられ、境目より上へ 30pt はみ出す。
        setOffset(groupBottom - 10 - safeTop, in: controller)
        var boundary = controller.collectionView.bounds.minY + safeTop
        let fruit = visibleGroupHeaders(in: controller).first { abs($0.frame.maxY - groupBottom) < 0.5 }
        XCTAssertNotNil(fruit, "「果物」の見出しが最終行の下端まで押し上げられていません")
        XCTAssertEqual(fruit?.frame.minY ?? 0, boundary - (Self.headerHeight - 10), accuracy: 0.5)

        // 最終行の下端が境目の 50pt 下 (見出しの高さより遠い) なら、見出しは境目に止まったまま。
        setOffset(groupBottom - 50 - safeTop, in: controller)
        boundary = controller.collectionView.bounds.minY + safeTop
        let header = pinnedHeader(at: boundary, in: controller, label: "押し上げの前")
        XCTAssertEqual(header?.frame.minY ?? 0, boundary, accuracy: 0.5, "見出しが境目で止まっていません")
    }

    func test固定中の見出しは自然な位置が境目より上なら境目で止まり下なら自然な位置のまま() async {
        var configuration = KsCollectionView(makeRows([("果物", 30)]), layout: .list) { row in
            FixedHeightView(label: "行 \(row.id)", height: Self.rowHeight)
        }
        .header { FixedHeightView(label: "ヘッダー", height: 200) }
        .groups(by: \.group) { group, _ in
            FixedHeightView(label: "見出し \(group)", height: Self.headerHeight)
        }
        .configuration
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(30, in: controller)
        await settleLayout(in: controller)

        // 見出しの自然な位置 (ヘッダーの下 200pt) が境目より下なら、自然な位置のまま。
        setOffset(0, in: controller)
        XCTAssertEqual(visibleGroupHeaders(in: controller).first?.frame.minY ?? -1, 200, accuracy: 0.5)
        // 自然な位置が境目より上へ行く位置まで送ると、境目で止まる。
        setOffset(200 - safeTop + 30, in: controller)
        let boundary = controller.collectionView.bounds.minY + safeTop
        XCTAssertEqual(visibleGroupHeaders(in: controller).first?.frame.minY ?? -1, boundary, accuracy: 0.5)
    }

    func testIDによるスクロール命令は項目を安全領域の境目に固定された見出しのすぐ下に置く() async {
        let scrollController = KsScrollController()
        var configuration = makeGroupedConfiguration(rows: makeRows([("果物", 30), ("野菜", 1_200)]), pinnedHeaders: true)
        configuration.scrollController = scrollController
        let controller = KsCollectionViewController(configuration: configuration)
        let window = showFullScreen(controller)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await waitForItems(1_230, in: controller)

        for target in [15, 30 + 700] {
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
            XCTAssertEqual(frame.minY - top, safeTop + Self.headerHeight, accuracy: 1, "項目 \(target) が見出しのすぐ下にありません")
            XCTAssertNotNil(pinnedHeader(at: top + safeTop, in: controller, label: "\(target)"))
        }
    }

    // MARK: - 普通の置き方

    func test安全領域に重ならない置き方では見出しを表示範囲の上端に固定する() async {
        let controller = makeGroupedController(rows: makeRows([("果物", 30), ("野菜", 1_200)]))
        let window = showInsideSafeArea(controller)
        defer { window.isHidden = true }
        XCTAssertGreaterThan(window.safeAreaInsets.top, 0, "ウインドウが上端の安全領域を持っていません")
        XCTAssertEqual(controller.collectionView.safeAreaInsets.top, 0, accuracy: 0.5)
        await waitForItems(1_230, in: controller)
        await settleLayout(in: controller)

        let headers = supplementaryFrames(ofKind: KsSupplementaryKind.groupHeader, in: controller)
        XCTAssertEqual(headers.first?.minY ?? -1, 0, accuracy: 0.5)
        XCTAssertEqual(headers.first?.height ?? -1, Self.headerHeight, accuracy: 0.5)
        for target in [30 + 10, 30 + 600] {
            await scroll(toOffset: target, in: controller)
            let top = controller.collectionView.bounds.minY
            guard let header = pinnedHeader(at: top, in: controller, label: "\(target)") else { continue }
            XCTAssertEqual(header.frame.minY, top, accuracy: 0.5, "見出しが表示範囲の上端に固定されていません (\(target))")
        }
    }

    // MARK: - 部品

    private struct FixedHeightView: View {
        let label: String
        let height: CGFloat

        var body: some View {
            Text(label)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background(ProbeRepresentable(label: label))
        }
    }

    // 載せたビューの上端から、目印のビュー (中身の背景) の上端までの距離。見つからなければ nil。
    private func contentTop(label: String, in host: UIView) -> CGFloat? {
        host.layoutIfNeeded()
        guard let probe = findProbe(label: label, in: host) else { return nil }
        return probe.convert(probe.bounds, to: host).minY
    }

    private func findProbe(label: String, in view: UIView) -> ProbeView? {
        if let probe = view as? ProbeView, probe.label == label {
            return probe
        }
        for subview in view.subviews {
            if let probe = findProbe(label: label, in: subview) {
                return probe
            }
        }
        return nil
    }

    private func cellContentTop(offset: Int, in controller: KsCollectionViewController<Row>) -> CGFloat? {
        guard
            let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView),
            let cell = controller.collectionView.cellForItem(at: indexPath)
        else {
            return nil
        }
        return contentTop(label: "行 \(offset)", in: cell)
    }

    private func groupHeaderContentTop(label: String, in controller: KsCollectionViewController<Row>) -> CGFloat? {
        for view in controller.collectionView.visibleSupplementaryViews(ofKind: KsSupplementaryKind.groupHeader)
            where view.alpha > 0.01 {
            if let top = contentTop(label: label, in: view) {
                return top
            }
        }
        return nil
    }

    // 指定した位置に固定されている (透明でない) 見出しのビューについて、その上端から中身の上端までの距離。
    private func pinnedHeaderContentTop(
        at position: CGFloat,
        label: String,
        in controller: KsCollectionViewController<Row>
    ) -> CGFloat? {
        let views = controller.collectionView.visibleSupplementaryViews(ofKind: KsSupplementaryKind.groupHeader)
            .filter { $0.alpha > 0.01 && abs($0.frame.minY - position) < 0.5 }
        guard let view = views.first else { return nil }
        return contentTop(label: label, in: view)
    }

    // 指定した位置を覆う、透明でない見出しの属性。1 つでなければ失敗させる。
    private func pinnedHeader(
        at position: CGFloat,
        in controller: KsCollectionViewController<Row>,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UICollectionViewLayoutAttributes? {
        let pinned = visibleGroupHeaders(in: controller)
            .filter { $0.frame.minY <= position + 0.5 && $0.frame.maxY > position }
        XCTAssertEqual(pinned.count, 1, "境目を覆う見出しが 1 つではありません (\(label))", file: file, line: line)
        return pinned.first
    }

    private func visibleGroupHeaders(in controller: KsCollectionViewController<Row>) -> [UICollectionViewLayoutAttributes] {
        supplementaryAttributes(ofKind: KsSupplementaryKind.groupHeader, in: controller).filter { $0.alpha > 0.01 }
    }

    private func makeRows(_ groups: [(String, Int)]) -> [Row] {
        var rows: [Row] = []
        for (group, count) in groups {
            for _ in 0..<count {
                rows.append(Row(id: rows.count, group: group))
            }
        }
        return rows
    }

    private func makeGroupedConfiguration(rows: [Row], pinnedHeaders: Bool) -> KsCollectionConfiguration<Row> {
        var configuration = KsCollectionView(rows, layout: .list) { row in
            FixedHeightView(label: "行 \(row.id)", height: Self.rowHeight)
        }
        .groups(by: \.group, pinnedHeaders: pinnedHeaders) { group, _ in
            FixedHeightView(label: "見出し \(group)", height: Self.headerHeight)
        }
        .configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func makeGroupedController(
        rows: [Row],
        pinnedHeaders: Bool = true
    ) -> KsCollectionViewController<Row> {
        KsCollectionViewController(configuration: makeGroupedConfiguration(rows: rows, pinnedHeaders: pinnedHeaders))
    }

    // ウインドウいっぱいに載せる。一覧は上端・下端の安全領域に重なる (`.ignoresSafeArea()` で広げた置き方)。
    private func showFullScreen(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    // ウインドウの安全領域の内側に載せる。一覧は安全領域に重ならない (普通の置き方)。
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

    private func setOffset(_ y: CGFloat, in controller: KsCollectionViewController<Row>) {
        controller.collectionView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        controller.collectionView.layoutIfNeeded()
    }

    private func itemFrames(in controller: KsCollectionViewController<Row>, offsets: [Int]) -> [CGRect] {
        offsets.compactMap { offset in
            guard let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView) else {
                return nil
            }
            return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
        }
    }

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

    private func supplementaryFrames(ofKind kind: String, in controller: KsCollectionViewController<Row>) -> [CGRect] {
        supplementaryAttributes(ofKind: kind, in: controller).map(\.frame)
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
