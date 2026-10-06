import SwiftUI
import XCTest
@testable import KsCollectionView

/// list の区切り線の既定の色が、線が置かれた場所の外観 (ライト / ダーク) の側の値で描かれることを確かめる。
///
/// 色は 2 通りで見る。線に入っている色を線の外観で解決した値と、セルを描いた結果の線の位置の画素である。
/// 前者だけでは、外観が切り替わった後に線が描き直されたかが分からない。
@MainActor
final class KsDefaultSeparatorColorTests: XCTestCase {
    private typealias Support = KsDefaultColorTestSupport
    private typealias Expected = KsDefaultColorTestSupport.Expected

    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    // 区切り線の出方。位置と本数が外観で変わらないことを比べるために控える。
    private struct SeparatorLayout: Equatable {
        let showsTop: [Bool]
        let showsBottom: [Bool]
        let topFrames: [CGRect]
        let bottomFrames: [CGRect]
    }

    private static let size = CGSize(width: 320, height: 480)
    private static let itemCount = 3
    // 外観で値の変わらない、利用者が指定する色。
    private static let fixedRGB: UInt32 = 0x2F6FED

    private var windows: [UIWindow] = []

    override func tearDown() async throws {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
        try await super.tearDown()
    }

    // MARK: - 値

    func test既定の色4つのライトとダークの値が色の表の値と一致する() {
        let table: [(String, UInt32, UInt32, UInt32, UInt32, UIColor)] = [
            (
                "区切り線",
                KsDefaultColors.separatorLight, KsDefaultColors.separatorDark,
                Expected.separatorLight, Expected.separatorDark,
                KsDefaultColors.separator
            ),
            (
                "画像の読み込み中",
                KsDefaultColors.imageLoadingLight, KsDefaultColors.imageLoadingDark,
                Expected.imageLoadingLight, Expected.imageLoadingDark,
                KsDefaultColors.imageLoading
            ),
            (
                "画像の失敗の下地",
                KsDefaultColors.imageFailureBackgroundLight, KsDefaultColors.imageFailureBackgroundDark,
                Expected.imageFailureBackgroundLight, Expected.imageFailureBackgroundDark,
                KsDefaultColors.imageFailureBackground
            ),
            (
                "画像の失敗の印",
                KsDefaultColors.imageFailureMarkLight, KsDefaultColors.imageFailureMarkDark,
                Expected.imageFailureMarkLight, Expected.imageFailureMarkDark,
                KsDefaultColors.imageFailureMark
            ),
        ]
        for (label, light, dark, expectedLight, expectedDark, color) in table {
            XCTAssertEqual(light, expectedLight, "\(label) のライト用の値")
            XCTAssertEqual(dark, expectedDark, "\(label) のダーク用の値")
            // 描くのに使う色が、持っている値どおりに外観ごとに解決される。
            XCTAssertEqual(Support.resolved(color, .light), Support.components(expectedLight), "\(label) のライトの色")
            XCTAssertEqual(Support.resolved(color, .dark), Support.components(expectedDark), "\(label) のダークの色")
            XCTAssertEqual(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor.alpha, 1)
            XCTAssertEqual(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).cgColor.alpha, 1)
        }
    }

    func test区切り線のライト用の既定の色は赤217緑217青222の不透明な色で参照のたびに同じオブジェクトである() {
        let color = KsHostingCell.defaultSeparatorColor
        XCTAssertEqual(Support.resolved(color, .light), [217, 217, 222])
        XCTAssertTrue(KsHostingCell.defaultSeparatorColor === color, "既定の色が参照のたびに別のオブジェクトになっています")
        XCTAssertTrue(color === KsDefaultColors.separator)
    }

    // MARK: - ライト / ダーク

    func test色を指定しない一覧の区切り線はライトではライト用ダークではダーク用の値で描かれ位置と本数は同じ() async {
        var layouts: [SeparatorLayout] = []
        for style in [UIUserInterfaceStyle.light, .dark] {
            let controller = KsCollectionViewController(configuration: makeConfiguration(separatorColor: nil))
            let window = show(controller, style: style)
            await waitForCells(in: controller)
            await waitForStyle(style, in: controller)

            await assertSeparators(in: controller, are: Expected.separator(style), Support.name(style))
            layouts.append(separatorLayout(in: controller))
            window.isHidden = true
        }
        XCTAssertEqual(layouts[0], layouts[1], "ライトとダークで区切り線の位置か本数が違います")
        XCTAssertEqual(layouts[0].showsTop, [true, false, false])
        XCTAssertEqual(layouts[0].showsBottom, [true, true, true])
    }

    func test色を指定しない一覧を出したまま外観を切り替えると区切り線の色が追随し位置と本数は変わらない() async {
        let controller = KsCollectionViewController(configuration: makeConfiguration(separatorColor: nil))
        let window = show(controller, style: .light)
        await waitForCells(in: controller)
        await waitForStyle(.light, in: controller)
        await assertSeparators(in: controller, are: Expected.separatorLight, "切り替える前のライト")
        let layout = separatorLayout(in: controller)
        let cells = visibleCells(in: controller)
        let writes = cells.map(\.separatorColorWriteCount)

        window.overrideUserInterfaceStyle = .dark
        await waitForStyle(.dark, in: controller)
        await assertSeparators(in: controller, are: Expected.separatorDark, "ダークへ切り替えた後")
        XCTAssertEqual(separatorLayout(in: controller), layout, "ダークへの切り替えで区切り線の位置か本数が変わりました")

        window.overrideUserInterfaceStyle = .light
        await waitForStyle(.light, in: controller)
        await assertSeparators(in: controller, are: Expected.separatorLight, "ライトへ戻した後")
        XCTAssertEqual(separatorLayout(in: controller), layout, "ライトへ戻すと区切り線の位置か本数が変わりました")

        // 画面は作り直されておらず、線の色も書き込み直されていない (色そのものが外観で解決される)。
        XCTAssertTrue(
            zip(visibleCells(in: controller), cells).allSatisfy { $0 === $1 },
            "外観の切り替えでセルが作り直されました"
        )
        XCTAssertEqual(cells.map(\.separatorColorWriteCount), writes, "外観の切り替えで線の色を書き込み直しました")
    }

    func test一覧を置いたwindowの外観だけを上書きすると区切り線が上書きした側の既定の色になる() async {
        let controller = KsCollectionViewController(configuration: makeConfiguration(separatorColor: nil))
        // 上書きしない窓の外観が、端末の表示モードである。その反対へ上書きする
        // (ライトの端末ではダークへの上書きになる)。
        let window = show(controller, style: .unspecified)
        await waitForCells(in: controller)
        let deviceStyle = window.traitCollection.userInterfaceStyle
        await assertSeparators(in: controller, are: Expected.separator(deviceStyle), "上書きする前")
        let overridden = Support.opposite(of: deviceStyle)

        window.overrideUserInterfaceStyle = overridden
        await waitForStyle(overridden, in: controller)

        await assertSeparators(
            in: controller, are: Expected.separator(overridden), "\(Support.name(overridden)) へ上書きした後"
        )
    }

    // MARK: - 指定した色

    func test固定の色を指定した一覧はライトでもダークでも指定した色のままで指定を外すとその外観の既定の色になる() async {
        let fixed = UIColor(
            red: 0x2F / 255.0, green: 0x6F / 255.0, blue: 0xED / 255.0, alpha: 1
        )
        var configuration = makeConfiguration(separatorColor: fixed)
        let controller = KsCollectionViewController(configuration: configuration)
        let window = show(controller, style: .light)
        await waitForCells(in: controller)
        await waitForStyle(.light, in: controller)
        await assertSeparators(in: controller, are: Self.fixedRGB, "ライトで指定した色")
        let layout = separatorLayout(in: controller)

        window.overrideUserInterfaceStyle = .dark
        await waitForStyle(.dark, in: controller)
        await assertSeparators(in: controller, are: Self.fixedRGB, "ダークで指定した色")
        XCTAssertTrue(
            visibleCells(in: controller).allSatisfy { $0.bottomSeparatorColor == fixed },
            "指定した色が別の色に差し替えられました"
        )

        configuration.separatorColor = nil
        controller.update(configuration: configuration)
        await assertSeparators(in: controller, are: Expected.separatorDark, "ダークで指定を外した後")
        XCTAssertEqual(separatorLayout(in: controller), layout)

        window.overrideUserInterfaceStyle = .light
        await waitForStyle(.light, in: controller)
        await assertSeparators(in: controller, are: Expected.separatorLight, "指定を外したままライトへ戻した後")
    }

    // MARK: - 部品

    private func makeConfiguration(separatorColor: UIColor?) -> KsCollectionConfiguration<Item> {
        KsCollectionConfiguration(
            items: (0..<Self.itemCount).map { Item(id: $0) },
            id: { AnyHashable($0.id) },
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry(content: { (item: Item) in
                Text("項目 \(item.id)")
                    .frame(maxWidth: .infinity, minHeight: 56)
            }),
            layout: .list,
            contentPadding: EdgeInsets(),
            showsSeparators: true,
            separatorColor: separatorColor,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
    }

    // 一覧を窓に出す。`style` が `.unspecified` 以外なら、出す前に窓の外観を上書きしておく。
    private func show(_ controller: UIViewController, style: UIUserInterfaceStyle) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        windows.append(window)
        return window
    }

    private func visibleCells(in controller: KsCollectionViewController<Item>) -> [KsHostingCell] {
        (0..<Self.itemCount).compactMap {
            controller.collectionView.cellForItem(
                at: ksIndexPath(forItemOffset: $0, in: controller.collectionView)
            ) as? KsHostingCell
        }
    }

    private func separatorLayout(in controller: KsCollectionViewController<Item>) -> SeparatorLayout {
        let cells = visibleCells(in: controller)
        cells.forEach { $0.layoutIfNeeded() }
        return SeparatorLayout(
            showsTop: cells.map(\.isTopSeparatorVisible),
            showsBottom: cells.map(\.isBottomSeparatorVisible),
            topFrames: cells.map(\.topSeparatorFrame),
            bottomFrames: cells.map(\.bottomSeparatorFrame)
        )
    }

    private func waitForCells(in controller: KsCollectionViewController<Item>) async {
        await waitUntil("セルの表示", value: { self.visibleCells(in: controller).count }) { $0 == Self.itemCount }
        controller.collectionView.layoutIfNeeded()
        visibleCells(in: controller).forEach { $0.layoutIfNeeded() }
    }

    // 外観の切り替えは次の画面の更新でセルに届く。
    private func waitForStyle(
        _ style: UIUserInterfaceStyle,
        in controller: KsCollectionViewController<Item>
    ) async {
        await waitUntil(
            "\(Support.name(style)) への切り替え",
            value: { self.visibleCells(in: controller).map(\.traitCollection.userInterfaceStyle.rawValue) }
        ) { styles in
            styles.count == Self.itemCount && styles.allSatisfy { $0 == style.rawValue }
        }
    }

    // 出ている線 (先頭行の上端と、すべての行の下端) の色が `expected` であることを確かめる。
    private func assertSeparators(
        in controller: KsCollectionViewController<Item>,
        are expected: UInt32,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let expected = Support.components(expected)
        let cells = visibleCells(in: controller)
        XCTAssertEqual(cells.count, Self.itemCount, file: file, line: line)
        // 線に入っている色を、その線が置かれたセルの外観で解決した値。
        for (index, cell) in cells.enumerated() {
            XCTAssertEqual(
                Support.resolved(cell.bottomSeparatorColor, in: cell), expected,
                "\(label): 項目 \(index) の下端の線の色", file: file, line: line
            )
            XCTAssertEqual(
                Support.resolved(cell.topSeparatorColor, in: cell), expected,
                "\(label): 項目 \(index) の上端の線の色", file: file, line: line
            )
        }
        // セルを描いた結果の、線の位置の画素。描き直しは画面の更新を待つ。
        let drawn = { () -> [[Int]?] in
            cells.enumerated().flatMap { index, cell -> [[Int]?] in
                let x = cell.bounds.midX
                let bottom = Support.pixel(of: cell, at: CGPoint(x: x, y: cell.bounds.height - 1))
                return index == 0 ? [Support.pixel(of: cell, at: CGPoint(x: x, y: 0)), bottom] : [bottom]
            }
        }
        await waitUntil("\(label): 描いた線の色", value: drawn, file: file, line: line) { pixels in
            pixels.count == Self.itemCount + 1 && pixels.allSatisfy { Support.isClose($0, expected) }
        }
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        file: StaticString = #filePath,
        line: UInt = #line,
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
        XCTFail(
            "\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))",
            file: file,
            line: line
        )
    }
}
