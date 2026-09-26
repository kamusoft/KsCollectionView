#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// 端を表示中の端への挿入で、表示範囲がその端に留まり、挿入した項目が表示範囲の中に現れることを
/// エンジンの実レイアウトで確かめる (list / グリッド、グループの有無、ルートのフッターの有無)。
@MainActor
final class KsEdgeInsertionTests: XCTestCase {
    private struct Row: Identifiable, Equatable {
        let id: Int
        let group: String
    }

    // 表示の形。挿入の位置と留まる端の判定はどの形でも同じになる。
    private struct Shape: CustomStringConvertible {
        let layout: KsCollectionLayout
        let grouped: Bool
        let footer: Bool

        var description: String {
            "\(layout.kind == .list ? "list" : "grid") / グループ \(grouped) / フッター \(footer)"
        }
    }

    private static let rowHeight: CGFloat = 44
    private static let size = CGSize(width: 390, height: 844)
    private static let shapes: [Shape] = [
        Shape(layout: .list(rowSpacing: 4), grouped: false, footer: false),
        Shape(layout: .grid(columns: .fixed(2), rowSpacing: 4, columnSpacing: 4), grouped: false, footer: false),
        Shape(layout: .list(rowSpacing: 4, groupSpacing: 12, headerItemSpacing: 6), grouped: true, footer: false),
        Shape(
            layout: .grid(columns: .fixed(2), rowSpacing: 4, columnSpacing: 4, groupSpacing: 12, headerItemSpacing: 6),
            grouped: true,
            footer: false
        ),
        Shape(layout: .list(rowSpacing: 4), grouped: false, footer: true),
        Shape(layout: .grid(columns: .fixed(2), rowSpacing: 4, columnSpacing: 4), grouped: true, footer: true),
    ]

    func testいちばん上での先頭への挿入は先頭に留まり挿入した項目が表示範囲に現れる() async {
        for shape in Self.shapes {
            var rows = makeRows()
            let controller = KsCollectionViewController(configuration: makeConfiguration(rows: rows, shape: shape))
            let window = show(controller)
            defer { window.isHidden = true }
            await waitForItems(rows.count, in: controller)
            await settleLayout(in: controller)
            let top = -controller.collectionView.adjustedContentInset.top
            XCTAssertEqual(controller.collectionView.contentOffset.y, top, accuracy: 0.5, "\(shape)")

            rows.insert(Row(id: 1_000, group: rows[0].group), at: 0)
            controller.update(configuration: makeConfiguration(rows: rows, shape: shape))
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                top,
                accuracy: 0.5,
                "挿入の適用で先頭から動いています (\(shape))"
            )

            await waitForItems(rows.count, in: controller)
            await settleLayout(in: controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, top, accuracy: 0.5, "先頭に留まっていません (\(shape))")
            XCTAssertEqual(controller.appliedItemIdentifiers.first, AnyHashable(1_000))
            assertVisible(offset: 0, in: controller, label: "先頭に挿入した項目 (\(shape))")
        }
    }

    func testいちばん下での末尾への挿入は末尾に留まり挿入した項目が表示範囲に現れる() async {
        for shape in Self.shapes {
            var rows = makeRows()
            let controller = KsCollectionViewController(configuration: makeConfiguration(rows: rows, shape: shape))
            let window = show(controller)
            defer { window.isHidden = true }
            await waitForItems(rows.count, in: controller)
            await scrollToBottom(in: controller)

            rows.append(Row(id: 1_000, group: rows[rows.count - 1].group))
            controller.update(configuration: makeConfiguration(rows: rows, shape: shape))
            // 表示範囲は差分の適用の中で (適用の後に改めて送るのではなく) 新しい末尾へ動く。
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                bottomOffset(in: controller),
                accuracy: 0.5,
                "差分の適用で末尾へ留まっていません (\(shape))"
            )

            await waitForItems(rows.count, in: controller)
            await settleLayout(in: controller)
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                bottomOffset(in: controller),
                accuracy: 1,
                "末尾に留まっていません (\(shape))"
            )
            assertVisible(offset: rows.count - 1, in: controller, label: "末尾に挿入した項目 (\(shape))")
            if shape.footer {
                // フッターの下端まで表示したまま、挿入した項目はフッターの前に現れる。
                let bounds = controller.collectionView.bounds
                let footer = (controller.collectionView.collectionViewLayout.layoutAttributesForElements(in: bounds) ?? [])
                    .first { $0.representedElementKind == KsSupplementaryKind.rootFooter }
                XCTAssertEqual(footer?.frame.maxY ?? 0, bounds.maxY, accuracy: 1, "フッターの下端が表示範囲の下端にありません")
                if let footer, let last = itemFrame(offset: rows.count - 1, in: controller) {
                    XCTAssertLessThanOrEqual(last.maxY, footer.frame.minY + 0.5, "挿入した項目がフッターの前にありません")
                }
            }
        }
    }

    // 端を表示していないときの末尾への挿入は、表示範囲を動かさない (既定の位置の保ち方のまま)。
    func test端を表示していないときの末尾への挿入では表示範囲を動かさない() async {
        let shape = Self.shapes[0]
        var rows = makeRows()
        let controller = KsCollectionViewController(configuration: makeConfiguration(rows: rows, shape: shape))
        let window = show(controller)
        defer { window.isHidden = true }
        await waitForItems(rows.count, in: controller)
        await settleLayout(in: controller)
        controller.collectionView.setContentOffset(CGPoint(x: 0, y: 600), animated: false)
        controller.collectionView.layoutIfNeeded()

        rows.append(Row(id: 1_000, group: rows[rows.count - 1].group))
        controller.update(configuration: makeConfiguration(rows: rows, shape: shape))
        await waitForItems(rows.count, in: controller)
        await settleLayout(in: controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, 600, accuracy: 0.5, "表示範囲が動いています")
    }

    // MARK: - 部品

    private struct RowView: View {
        let row: Row

        var body: some View {
            Text("\(row.id)")
                .frame(maxWidth: .infinity, minHeight: KsEdgeInsertionTests.rowHeight, maxHeight: KsEdgeInsertionTests.rowHeight)
        }
    }

    private struct FixedHeightView: View {
        let text: String
        let height: CGFloat

        var body: some View {
            Text(text).frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
    }

    // 画面より十分長い 60 件を、20 件ずつ 3 つのグループに分ける。
    private func makeRows() -> [Row] {
        (0..<60).map { Row(id: $0, group: ["A", "B", "C"][$0 / 20]) }
    }

    private func makeConfiguration(rows: [Row], shape: Shape) -> KsCollectionConfiguration<Row> {
        var view = KsCollectionView(rows, layout: shape.layout) { row in RowView(row: row) }
        if shape.grouped {
            view = view.groups(by: \.group) { group, _ in FixedHeightView(text: group, height: 30) }
        }
        if shape.footer {
            view = view.footer { FixedHeightView(text: "フッター", height: 50) }
        }
        var configuration = view.configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func show(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    private func bottomOffset(in controller: KsCollectionViewController<Row>) -> CGFloat {
        let collectionView = controller.collectionView!
        let insets = collectionView.adjustedContentInset
        // 表示先がウインドウに載っていない間は contentSize の反映が遅れるため、レイアウトの値から求める。
        let contentHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
        return max(-insets.top, contentHeight + insets.bottom - collectionView.bounds.height)
    }

    // 末尾まで送り、自己サイズの解き直しで末尾が動かなくなるまで送り直す。
    private func scrollToBottom(in controller: KsCollectionViewController<Row>) async {
        for _ in 0..<5 {
            await settleLayout(in: controller)
            let bottom = bottomOffset(in: controller)
            if abs(controller.collectionView.contentOffset.y - bottom) < 0.5 {
                return
            }
            controller.collectionView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
            controller.collectionView.layoutIfNeeded()
        }
        XCTFail("末尾まで送れませんでした")
    }

    private func itemFrame(offset: Int, in controller: KsCollectionViewController<Row>) -> CGRect? {
        guard let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView) else {
            return nil
        }
        return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
    }

    private func assertVisible(
        offset: Int,
        in controller: KsCollectionViewController<Row>,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let bounds = controller.collectionView.bounds
        guard let frame = itemFrame(offset: offset, in: controller) else {
            XCTFail("\(label) の位置を取得できませんでした", file: file, line: line)
            return
        }
        XCTAssertTrue(
            bounds.insetBy(dx: 0, dy: -0.5).contains(frame),
            "\(label) が表示範囲に入っていません (\(frame) / \(bounds))",
            file: file,
            line: line
        )
    }

    private func waitForItems(_ count: Int, in controller: KsCollectionViewController<Row>) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(3)
        while clock.now < deadline {
            if controller.appliedItemIdentifiers.count == count {
                controller.collectionView.layoutIfNeeded()
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("\(count) 件の snapshot が期限内に適用されませんでした。実測値: \(controller.appliedItemIdentifiers.count)")
    }

    // 差分のアニメーションと自己サイズの解き直しが止まり、内容の高さと表示位置が動かなくなるまで待つ。
    private func settleLayout(in controller: KsCollectionViewController<Row>) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        var last = (controller.collectionView.contentSize.height, controller.collectionView.contentOffset.y)
        var quietSince = clock.now
        while clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            controller.collectionView.layoutIfNeeded()
            let current = (controller.collectionView.contentSize.height, controller.collectionView.contentOffset.y)
            if current != last {
                last = current
                quietSince = clock.now
            } else if clock.now - quietSince >= .milliseconds(400) {
                return
            }
        }
        XCTFail("内容の高さと表示位置が期限内に静止しませんでした。実測値: \(last)")
    }
}
#endif
