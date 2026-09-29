#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// 端を表示したまま上下の内側余白 (contentPadding) を変えたとき、ルートのヘッダー / フッターの枠が新しい余白で
/// 測り直され、空白が残らないことを実レイアウトの上で確かめる。
///
/// ルートのフッター (ページングを付けた一覧ではページングの表示を載せる枠) は中身から高さが決まり、下の余白を
/// その枠の中に入れる。枠が測り直されないと、余白を小さくしても前の余白の分の空白が残る。
@MainActor
final class KsContentPaddingChangeTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    private static let size = CGSize(width: 390, height: 800)
    private static let rowHeight: CGFloat = 44
    private static let footerHeight: CGFloat = 30
    private static let headerHeight: CGFloat = 40

    // 調査で測った 4 通りの構成 (ページングの有無 × 利用者のルートのフッターの有無)。
    private static let shapes: [(paging: Bool, footer: Bool)] = [
        (false, false), (false, true), (true, false), (true, true),
    ]

    func test末尾を表示したまま下の余白を小さくすると枠が縮み新しい末尾に詰まる() async {
        for shape in Self.shapes {
            let label = "ページング \(shape.paging) / フッター \(shape.footer)"
            let controller = KsCollectionViewController(configuration: makeConfiguration(bottom: 300, shape: shape))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(50, in: controller)
            await Support.scrollToBottom(controller)

            controller.update(configuration: makeConfiguration(bottom: 60, shape: shape))
            await Support.settleLayout(controller)
            let expectedFooter = 60 + (shape.footer ? Self.footerHeight : 0)
            XCTAssertEqual(Support.rootFooterFrame(in: controller)?.height ?? -1, expectedFooter, accuracy: 0.5, "枠が縮んでいません (\(label))")
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                Support.bottomOffset(in: controller),
                accuracy: 0.5,
                "新しい末尾に詰まっていません (\(label))"
            )
            // 最後の項目の下には、新しい余白 (とフッター) の分だけが残る。
            if let last = Support.itemFrame(offset: 49, in: controller) {
                let visibleBottom = controller.collectionView.bounds.maxY
                XCTAssertEqual(visibleBottom - last.maxY, expectedFooter, accuracy: 0.5, "最後の項目の下に空白が残っています (\(label))")
            } else {
                XCTFail("最後の項目の位置を取得できませんでした (\(label))")
            }
        }
    }

    func test末尾を表示したまま下の余白を大きくすると枠が伸びる() async {
        for shape in Self.shapes {
            let label = "ページング \(shape.paging) / フッター \(shape.footer)"
            let controller = KsCollectionViewController(configuration: makeConfiguration(bottom: 60, shape: shape))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(50, in: controller)
            await Support.scrollToBottom(controller)

            controller.update(configuration: makeConfiguration(bottom: 300, shape: shape))
            await Support.settleLayout(controller)
            let expectedFooter = 300 + (shape.footer ? Self.footerHeight : 0)
            XCTAssertEqual(Support.rootFooterFrame(in: controller)?.height ?? -1, expectedFooter, accuracy: 0.5, "枠が伸びていません (\(label))")
            let contentHeight = controller.collectionView.collectionViewLayout.collectionViewContentSize.height
            XCTAssertEqual(contentHeight, 50 * Self.rowHeight + expectedFooter, accuracy: 0.5, "内容の高さが新しい余白を含んでいません (\(label))")
        }
    }

    func test先頭を表示したまま上の余白を変えるとヘッダーの枠が測り直される() async {
        for (from, to) in [(CGFloat(200), CGFloat(20)), (20, 200)] {
            let label = "\(from) → \(to)"
            let controller = KsCollectionViewController(configuration: makeHeaderConfiguration(top: from))
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(50, in: controller)
            await Support.settleLayout(controller)

            controller.update(configuration: makeHeaderConfiguration(top: to))
            await Support.settleLayout(controller)
            let header = controller.collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(
                ofKind: KsSupplementaryKind.rootHeader,
                at: IndexPath(index: 0)
            )?.frame
            XCTAssertEqual(header?.height ?? -1, to + Self.headerHeight, accuracy: 0.5, "ヘッダーの枠が測り直されていません (\(label))")
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                -controller.collectionView.adjustedContentInset.top,
                accuracy: 0.5,
                "先頭にありません (\(label))"
            )
            XCTAssertEqual(Support.itemFrame(offset: 0, in: controller)?.minY ?? -1, to + Self.headerHeight, accuracy: 0.5, "\(label)")
        }
    }

    func test余白が変わらない更新ではヘッダーとフッターの枠を作り直さない() async {
        let shape = (paging: true, footer: true)
        let controller = KsCollectionViewController(configuration: makeConfiguration(bottom: 60, shape: shape))
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(50, in: controller)
        await Support.scrollToBottom(controller)
        let rebuilds = controller.rootSupplementaryRebuildCount

        for _ in 0..<3 {
            controller.update(configuration: makeConfiguration(bottom: 60, shape: shape))
        }
        XCTAssertEqual(controller.rootSupplementaryRebuildCount, rebuilds, "余白が変わらないのに作り直しています")

        controller.update(configuration: makeConfiguration(bottom: 80, shape: shape))
        XCTAssertGreaterThan(controller.rootSupplementaryRebuildCount, rebuilds, "余白が変わったのに作り直していません")
    }

    // MARK: - 部品

    private func makeConfiguration(bottom: CGFloat, shape: (paging: Bool, footer: Bool)) -> KsCollectionConfiguration<KsPagingRow> {
        var view = KsCollectionView(
            (0..<50).map { KsPagingRow(id: $0) },
            layout: .list,
            contentPadding: EdgeInsets(top: 0, leading: 0, bottom: bottom, trailing: 0)
        ) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        if shape.paging {
            // 終端にして次ページ要求と表示を出さない (枠だけを置く)。
            view = view.paging(.endReached) {}
        }
        if shape.footer {
            view = view.footer { KsPagingFixedView(text: "フッター", height: Self.footerHeight) }
        }
        var configuration = view.configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func makeHeaderConfiguration(top: CGFloat) -> KsCollectionConfiguration<KsPagingRow> {
        var configuration = KsCollectionView(
            (0..<50).map { KsPagingRow(id: $0) },
            layout: .list,
            contentPadding: EdgeInsets(top: top, leading: 0, bottom: 0, trailing: 0)
        ) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .header { KsPagingFixedView(text: "ヘッダー", height: Self.headerHeight) }
        .configuration
        configuration.showsSeparators = false
        return configuration
    }
}
#endif
