#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// 一覧に指定した読み込み中の表示の色が、差し替えていない次のページの読み込み中・最初の読み込み中と
/// Pull to Refresh の部品の 3 つに効き、差し替えた表示には効かず、指定しない一覧では標準の色のままで
/// あることを確かめる。色は、実際に描いている標準の部品 (読み込み中の部品・引っ張りの部品) から読む。
@MainActor
final class KsLoadingIndicatorColorTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    private static let size = CGSize(width: 390, height: 800)
    private static let red = UIColor(red: 0.9, green: 0.1, blue: 0.2, alpha: 1)
    private static let teal = UIColor(red: 0.1, green: 0.6, blue: 0.7, alpha: 1)
    private static let purple = UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1)

    // 2 つの読み込み中の表示が出る状態と件数。
    private enum Display: CaseIterable {
        // 次のページの読み込み中 (項目あり・追加読み込み中)。
        case appending
        // 最初の読み込み中 (0 件・追加読み込み中)。
        case loading
        // 最初の読み込み中 (0 件・取り直し中)。
        case loadingWhileRefreshing

        var rowCount: Int {
            self == .appending ? 40 : 0
        }

        var state: KsPagingState {
            self == .loadingWhileRefreshing ? .refreshing : .appending
        }
    }

    // MARK: - 指定した色で描く

    func test色を指定すると次のページの読み込み中と最初の読み込み中の部品が指定した色になる() async {
        for display in Display.allCases {
            let controller = KsCollectionViewController(configuration: makeConfiguration(display, color: Self.red))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await waitForSpinnerColor(Self.red, display, in: controller)
        }
    }

    func test色を指定するとPullToRefreshの部品がページングの有無によらず指定した色になる() async {
        for paging in [true, false] {
            let gate = KsPagingGate()
            let controller = KsCollectionViewController(
                configuration: makeRefreshConfiguration(paging: paging, color: Self.red, gate: gate)
            )
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)

            pull(controller)
            await Support.waitUntil("取り直しの処理の待ち (ページング \(paging))", value: { gate.waitingCount }) { $0 == 1 }
            XCTAssertTrue(controller.pullRefreshControl.isRefreshing, "ページング \(paging)")
            assertRefreshColors(of: controller, equal: Self.red, "ページング \(paging)")
            gate.open()
        }
    }

    // MARK: - 差し替えた表示には効かない

    func test差し替えた表示は利用者の色のまま出て指定した色にならない() async {
        for display in Display.allCases {
            // 利用者が自分で色を付けた表示。
            let tinted = KsCollectionViewController(
                configuration: makeConfiguration(display, color: Self.red, replacement: Self.purple)
            )
            let tintedWindow = Support.show(tinted, size: Self.size)
            defer { tintedWindow.isHidden = true }
            await waitForSpinnerColor(Self.purple, display, in: tinted)

            // 利用者が色を付けていない表示。色を指定しない一覧に同じ表示を差し替えたときと同じ色で出る。
            let reference = KsCollectionViewController(
                configuration: makeConfiguration(display, color: nil, replacesWithPlainProgress: true)
            )
            let referenceWindow = Support.show(reference, size: Self.size)
            defer { referenceWindow.isHidden = true }
            await Support.waitUntil("差し替えた表示 (\(display))", value: { self.spinner(display, in: reference) != nil }) { $0 }
            guard let expected = spinnerColor(display, in: reference) else {
                XCTFail("差し替えた表示の色を読めません (\(display))")
                continue
            }
            let plain = KsCollectionViewController(
                configuration: makeConfiguration(display, color: Self.red, replacesWithPlainProgress: true)
            )
            let plainWindow = Support.show(plain, size: Self.size)
            defer { plainWindow.isHidden = true }
            await Support.waitUntil("差し替えた表示 (\(display))", value: { self.spinner(display, in: plain) != nil }) { $0 }
            await Support.yield()
            XCTAssertEqual(spinnerColor(display, in: plain), expected, "差し替えた表示に指定した色が効いています (\(display))")
            XCTAssertNotEqual(expected, Self.components(Self.red), "色を付けていない表示の色が指定した色と同じで、見分けられません")
        }
    }

    // MARK: - 表示中の変更

    func test読み込み中の表示を出したまま指定を別の色に変えると新しい色になる() async {
        for display in Display.allCases {
            let controller = KsCollectionViewController(configuration: makeConfiguration(display, color: Self.red))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await waitForSpinnerColor(Self.red, display, in: controller)

            controller.update(configuration: makeConfiguration(display, color: Self.teal))
            await waitForSpinnerColor(Self.teal, display, in: controller)
        }
    }

    func testPullToRefreshのインジケータを出したまま指定を別の色に変えると新しい色になる() async {
        let gate = KsPagingGate()
        let controller = KsCollectionViewController(
            configuration: makeRefreshConfiguration(paging: true, color: Self.red, gate: gate)
        )
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)
        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
        assertRefreshColors(of: controller, equal: Self.red, "変える前")

        controller.update(configuration: makeRefreshConfiguration(paging: true, color: Self.teal, gate: gate))
        XCTAssertTrue(controller.pullRefreshControl.isRefreshing, "色を変えたらインジケータが消えました")
        assertRefreshColors(of: controller, equal: Self.teal, "変えた後")
        gate.open()
    }

    func test読み込み中の表示を出したまま指定を外すと色を指定しない一覧と同じ色になる() async {
        for display in Display.allCases {
            // 色を指定しない一覧の色。
            let reference = KsCollectionViewController(configuration: makeConfiguration(display, color: nil))
            let referenceWindow = Support.show(reference, size: Self.size)
            defer { referenceWindow.isHidden = true }
            await Support.waitUntil("読み込み中の表示 (\(display))", value: { self.spinner(display, in: reference) != nil }) { $0 }
            guard let expected = spinnerColor(display, in: reference) else {
                XCTFail("色を指定しない一覧の読み込み中の部品の色を読めません (\(display))")
                continue
            }
            XCTAssertNotEqual(expected, Self.components(Self.red), "標準の色が指定した色と同じで、見分けられません")

            let controller = KsCollectionViewController(configuration: makeConfiguration(display, color: Self.red))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await waitForSpinnerColor(Self.red, display, in: controller)

            controller.update(configuration: makeConfiguration(display, color: nil))
            await Support.waitUntil("標準の色に戻る (\(display))", value: { self.spinnerColor(display, in: controller) }) {
                $0 == expected
            }
        }
    }

    func testPullToRefreshのインジケータを出したまま指定を外すと標準の部品と同じ色になる() async {
        let gate = KsPagingGate()
        let controller = KsCollectionViewController(
            configuration: makeRefreshConfiguration(paging: true, color: Self.red, gate: gate)
        )
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)
        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
        assertRefreshColors(of: controller, equal: Self.red, "外す前")

        controller.update(configuration: makeRefreshConfiguration(paging: true, color: nil, gate: gate))
        XCTAssertTrue(controller.pullRefreshControl.isRefreshing, "指定を外したらインジケータが消えました")
        assertRefreshColorsAreStandard(of: controller, "外した後")
        gate.open()
    }

    // MARK: - 並べ替えのドラッグ中

    func test並べ替えのドラッグ中に色を変えるとドラッグの間は前の色のままで終わると新しい色になる() async {
        let probe = KsReorderProbe()
        let rows = (0..<40).map { KsReorderRow(id: "\($0)") }
        let view = { (color: UIColor) in
            KsReorderTestSupport.view(rows, probe: probe)
                .paging(.appending, onLoadMore: {})
                .loadingIndicatorColor(Color(color))
        }
        let (controller, window) = await KsReorderTestSupport.show(view(Self.red))
        defer { window.isHidden = true }
        let color = { Self.components(self.spinner(in: controller.pagingIndicatorView)?.color) }
        await Support.waitUntil("読み込み中の表示の色", value: color) { Self.isClose($0, Self.components(Self.red)) }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("3"))
        controller.update(configuration: view(Self.teal).configuration)
        await Support.yield()
        XCTAssertTrue(controller.isReorderDragging)
        XCTAssertTrue(Self.isClose(color(), Self.components(Self.red)), "ドラッグの間に色が変わりました: \(String(describing: color()))")

        driver.end()
        await Support.waitUntil("ドラッグの後の色", value: color) { Self.isClose($0, Self.components(Self.teal)) }
    }

    // MARK: - 指定しない一覧

    func test色を指定しない一覧の読み込み中の部品は親に付けたtintに従う() async {
        for isEmpty in [false, true] {
            let model = KsLoadingIndicatorTintModel(rowCount: isEmpty ? 0 : 40, tint: Self.purple)
            let host = UIHostingController(rootView: KsLoadingIndicatorTintView(model: model))
            let window = Support.show(host, size: Self.size)
            defer { window.isHidden = true }
            let color = { Self.components(self.spinner(in: window)?.color) }
            await Support.waitUntil("親の tint の色 (0 件 \(isEmpty))", value: color) {
                Self.isClose($0, Self.components(Self.purple))
            }

            // 親の tint を変えると追随する。
            model.tint = Self.teal
            await Support.waitUntil("変えた後の親の tint の色 (0 件 \(isEmpty))", value: color) {
                Self.isClose($0, Self.components(Self.teal))
            }
        }
    }

    func test色を指定しない一覧のPullToRefreshの部品は標準の部品と同じ色である() async {
        for paging in [true, false] {
            let gate = KsPagingGate()
            let controller = KsCollectionViewController(
                configuration: makeRefreshConfiguration(paging: paging, color: nil, gate: gate)
            )
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)
            pull(controller)
            await Support.waitUntil("取り直しの処理の待ち (ページング \(paging))", value: { gate.waitingCount }) { $0 == 1 }
            assertRefreshColorsAreStandard(of: controller, "ページング \(paging)")
            gate.open()
        }
    }

    // MARK: - Pull to Refresh の部品に渡す色

    // 標準の部品は渡した色を成分ごとに 2 乗して描くため、渡す色を 2 乗すると指定した色に戻ることを確かめる。
    // 実際に描いた画素は単体テストでは読めないため、ここでは渡す色の計算だけを確かめる。
    func testPullToRefreshの部品に渡す色は成分ごとに2乗すると指定した色に戻り不透明度は変えない() {
        let colors = [
            Self.red,
            Self.teal,
            UIColor(red: 0x8E / 255.0, green: 0x9A / 255.0, blue: 0xB3 / 255.0, alpha: 1),
            UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.4),
            UIColor.black,
            UIColor.white,
        ]
        for color in colors {
            guard
                let specified = Self.components(color),
                let passed = Self.components(KsRefreshControl.tintColor(drawing: color))
            else {
                XCTFail("色の成分を読めません: \(color)")
                continue
            }
            let squared = passed.prefix(3).map { $0 * $0 } + passed.suffix(1)
            XCTAssertTrue(Self.isClose(Array(squared), specified), "2 乗しても指定した色に戻りません: \(color) → \(passed)")
        }
    }

    func testPullToRefreshの部品に渡す色は表示モードで変わる色を外観ごとに解決してから補正する() {
        let light = UIColor(red: 0x6E / 255.0, green: 0x70 / 255.0, blue: 0x76 / 255.0, alpha: 1)
        let dark = UIColor(red: 0x8E / 255.0, green: 0x9A / 255.0, blue: 0xB3 / 255.0, alpha: 1)
        let adaptive = UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        let passed = KsRefreshControl.tintColor(drawing: adaptive)
        for (style, expected) in [(UIUserInterfaceStyle.light, light), (.dark, dark)] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            guard let components = Self.components(passed, traits: traits) else {
                XCTFail("色の成分を読めません (外観 \(style.rawValue))")
                continue
            }
            let squared = components.prefix(3).map { $0 * $0 } + components.suffix(1)
            XCTAssertTrue(
                Self.isClose(Array(squared), Self.components(expected)),
                "外観 \(style.rawValue) で指定した色に戻りません: \(components)"
            )
        }
    }

    func testPullToRefreshの部品に渡す色はsRGBの外の色をsRGBの範囲に収めてから補正する() {
        // 赤の成分が 1 を超え、緑の成分が負になる色 (sRGB の外の Display P3 の赤)。
        let wide = UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
        guard let passed = Self.components(KsRefreshControl.tintColor(drawing: wide)) else {
            XCTFail("色の成分を読めません")
            return
        }
        XCTAssertTrue(passed.allSatisfy { $0.isFinite && (0...1).contains($0) }, "成分が 0〜1 に収まっていません: \(passed)")
        XCTAssertEqual(passed[0], 1, accuracy: 0.01)
        XCTAssertEqual(passed[1], 0, accuracy: 0.01)
    }

    func test色を指定した一覧の表示モードが変わるとPullToRefreshの部品の色が追随する() async {
        let light = UIColor(red: 0x6E / 255.0, green: 0x70 / 255.0, blue: 0x76 / 255.0, alpha: 1)
        let dark = UIColor(red: 0x8E / 255.0, green: 0x9A / 255.0, blue: 0xB3 / 255.0, alpha: 1)
        let adaptive = UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        let gate = KsPagingGate()
        let controller = KsCollectionViewController(
            configuration: makeRefreshConfiguration(paging: true, color: adaptive, gate: gate)
        )
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)
        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }

        // 外観の切り替えは次の画面の更新で部品に届く。
        let style = { controller.pullRefreshControl.traitCollection.userInterfaceStyle }
        window.overrideUserInterfaceStyle = .light
        await Support.waitUntil("ライトへの切り替え", value: style) { $0 == .light }
        assertRefreshColors(of: controller, equal: light, "ライト")
        window.overrideUserInterfaceStyle = .dark
        await Support.waitUntil("ダークへの切り替え", value: style) { $0 == .dark }
        assertRefreshColors(of: controller, equal: dark, "ダーク")
        gate.open()
    }

    // MARK: - 部品

    // 読み込み中の表示を出す一覧の構成。`replacement` は差し替えた表示に利用者が付ける色、
    // `replacesWithPlainProgress` は利用者が色を付けない表示への差し替え。
    private func makeConfiguration(
        _ display: Display,
        color: UIColor?,
        replacement: UIColor? = nil,
        replacesWithPlainProgress: Bool = false
    ) -> KsCollectionConfiguration<KsPagingRow> {
        var view = KsCollectionView((0..<display.rowCount).map { KsPagingRow(id: $0) }) { row in
            KsPagingFixedView(text: "\(row.id)", height: 80)
        }
        .paging(display.state) {}
        if let color {
            view = view.loadingIndicatorColor(Color(color))
        }
        if let replacement {
            view = view
                .pagingAppendingIndicator { ProgressView().tint(Color(replacement)) }
                .pagingLoadingPlaceholder { ProgressView().tint(Color(replacement)) }
        } else if replacesWithPlainProgress {
            view = view
                .pagingAppendingIndicator { ProgressView() }
                .pagingLoadingPlaceholder { ProgressView() }
        }
        var configuration = view.configuration
        configuration.showsSeparators = false
        return configuration
    }

    // 取り直しの処理を渡した一覧の構成。取り直しの処理は門が開くまで戻らない。
    private func makeRefreshConfiguration(
        paging: Bool,
        color: UIColor?,
        gate: KsPagingGate
    ) -> KsCollectionConfiguration<KsPagingRow> {
        var view = KsCollectionView((0..<40).map { KsPagingRow(id: $0) }) { row in
            KsPagingFixedView(text: "\(row.id)", height: 80)
        }
        if paging {
            view = view.paging(.idle) {}
        }
        if let color {
            view = view.loadingIndicatorColor(Color(color))
        }
        var configuration = view.configuration
        configuration.refresh = { await gate.wait() }
        configuration.showsSeparators = false
        return configuration
    }

    // 引っ張って取り直しを始める。標準の部品が引っ張りを認めたときと同じく、部品を取り直し中にして値の変化を送る。
    private func pull(_ controller: KsCollectionViewController<KsPagingRow>) {
        let control = controller.pullRefreshControl
        control.beginRefreshing()
        for target in control.allTargets {
            for action in control.actions(forTarget: target, forControlEvent: .valueChanged) ?? [] {
                _ = (target as NSObject).perform(Selector(action), with: control)
            }
        }
        controller.collectionView.layoutIfNeeded()
    }

    // 見えている標準の読み込み中の部品。
    private func spinner(in view: UIView?) -> UIActivityIndicatorView? {
        guard let view, !view.isHidden else { return nil }
        if let indicator = view as? UIActivityIndicatorView {
            return indicator
        }
        for subview in view.subviews {
            if let found = spinner(in: subview) {
                return found
            }
        }
        return nil
    }

    // 表示の入れ物の中の読み込み中の部品。次のページの読み込み中は下端の入れ物、最初の読み込み中は真ん中の入れ物。
    private func spinner(_ display: Display, in controller: KsCollectionViewController<KsPagingRow>) -> UIActivityIndicatorView? {
        spinner(in: display == .appending ? controller.pagingIndicatorView : controller.pagingPlaceholderView)
    }

    private func spinnerColor(_ display: Display, in controller: KsCollectionViewController<KsPagingRow>) -> [CGFloat]? {
        Self.components(spinner(display, in: controller)?.color)
    }

    private func waitForSpinnerColor(
        _ expected: UIColor,
        _ display: Display,
        in controller: KsCollectionViewController<KsPagingRow>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await Support.waitUntil(
            "読み込み中の部品の色 (\(display))",
            value: { self.spinnerColor(display, in: controller) },
            file: file,
            line: line
        ) {
            Self.isClose($0, Self.components(expected))
        }
    }

    // 引っ張りの部品と、その中で描いている部品に付いている色。
    private func refreshColors(of control: UIRefreshControl) -> [[CGFloat]?] {
        ([control] + control.subviews).map { Self.components($0.tintColor, traits: control.traitCollection) }
    }

    private func assertRefreshColors(
        of controller: KsCollectionViewController<KsPagingRow>,
        equal expected: UIColor,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let control = controller.pullRefreshControl
        XCTAssertFalse(control.subviews.isEmpty, "引っ張りの部品が中身を描いていません (\(label))", file: file, line: line)
        // 部品には、標準の部品が指定した色の色みで描くように補正した色 (成分ごとの平方根) が渡る。
        let passed = Self.components(expected).map { $0.prefix(3).map { $0.squareRoot() } + $0.suffix(1) }
        for color in refreshColors(of: control) {
            XCTAssertTrue(
                Self.isClose(color, passed),
                "引っ張りの部品の色が違います (\(label)): \(String(describing: color))",
                file: file,
                line: line
            )
        }
    }

    // 引っ張りの部品の色が、作ったばかりの標準の部品を同じように取り直し中にしたときと同じか。
    private func assertRefreshColorsAreStandard(
        of controller: KsCollectionViewController<KsPagingRow>,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let scrollView = UIScrollView(frame: CGRect(origin: .zero, size: Self.size))
        let window = UIWindow(frame: scrollView.frame)
        window.addSubview(scrollView)
        window.isHidden = false
        defer { window.isHidden = true }
        let standard = UIRefreshControl()
        scrollView.refreshControl = standard
        standard.beginRefreshing()
        scrollView.layoutIfNeeded()

        let control = controller.pullRefreshControl
        XCTAssertFalse(standard.subviews.isEmpty, "標準の部品が中身を描いていません (\(label))", file: file, line: line)
        XCTAssertNil(control.tintColor, "引っ張りの部品に色が付いたままです (\(label))", file: file, line: line)
        let actual = refreshColors(of: control)
        let expected = refreshColors(of: standard)
        XCTAssertEqual(actual.count, expected.count, "引っ張りの部品の中身が標準の部品と違います (\(label))", file: file, line: line)
        for (actualColor, expectedColor) in zip(actual, expected) {
            XCTAssertEqual(actualColor, expectedColor, "標準の部品と色が違います (\(label))", file: file, line: line)
        }
    }

    // 色の RGBA の成分。動的な色は渡した表示の特性で解決する。
    private static func components(_ color: UIColor?, traits: UITraitCollection = .current) -> [CGFloat]? {
        guard let color else { return nil }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return [red, green, blue, alpha]
    }

    private static func isClose(_ lhs: [CGFloat]?, _ rhs: [CGFloat]?) -> Bool {
        guard let lhs, let rhs, lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { abs($0 - $1) < 0.01 }
    }
}

// 親に付ける tint と項目を持つモデル。パッケージの対応 OS に合わせて ObservableObject で持つ。
@MainActor
final class KsLoadingIndicatorTintModel: ObservableObject {
    @Published var tint: UIColor
    let rows: [KsPagingRow]

    init(rowCount: Int, tint: UIColor) {
        rows = (0..<rowCount).map { KsPagingRow(id: $0) }
        self.tint = tint
    }
}

// 色を指定しない、追加読み込み中の一覧に、親から tint を付けた画面。
struct KsLoadingIndicatorTintView: View {
    @ObservedObject var model: KsLoadingIndicatorTintModel

    var body: some View {
        KsCollectionView(model.rows) { row in
            KsPagingFixedView(text: "\(row.id)", height: 80)
        }
        .paging(.appending) {}
        .tint(Color(model.tint))
    }
}
#endif
