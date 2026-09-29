#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// ページングを付けた一覧で、差し替えの直前のページングの状態によって表示範囲の置き方が変わることを、
/// 実レイアウトの上で確かめる (list / グリッド)。
@MainActor
final class KsPagingPositionTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    private static let size = CGSize(width: 390, height: 800)
    private static let rowHeight: CGFloat = 80
    private static let layouts: [(String, KsCollectionLayout)] = [
        ("list", .list(rowSpacing: 4)),
        ("grid", .grid(columns: .fixed(2), rowSpacing: 4, columnSpacing: 4)),
    ]

    // MARK: - 末尾への追加読み込み

    func test追加読み込みで届いたページは表示範囲を末尾へ送らず今の位置の下に現れる() async {
        for (name, layout) in Self.layouts {
            let probe = KsPagingProbe()
            var rows = makeRows(0..<40)
            let controller = makeController(rows: rows, state: .appending, layout: layout, probe: probe)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)
            await Support.scrollToBottom(controller)
            await Support.waitUntil("読み込み中の表示 (\(name))", value: {
                Support.containsActivityIndicator(in: controller.pagingIndicatorView)
            }) { $0 }
            let offset = controller.collectionView.contentOffset.y
            // 次のページの読み込み中の表示はフッターの枠の外に重ねるため、最後の項目のすぐ後ろがフッターの枠になる。
            let footerTop = Support.rootFooterFrame(in: controller)?.minY ?? -1

            // 次のページを足し、同じ回に状態を待機にする。
            rows += makeRows(40..<80)
            controller.update(configuration: makeConfiguration(rows: rows, state: .idle, layout: layout, probe: probe))
            XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 0.5, "差分の適用で末尾へ送っています (\(name))")
            await Support.waitForItems(80, in: controller)
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 1, "表示範囲が動いています (\(name))")
            XCTAssertLessThan(offset, Support.bottomOffset(in: controller) - 1, "末尾に留まっています (\(name))")
            // 届いた項目は、読み込み中の表示があった位置 (今の位置の下) から続く。
            if let arrived = Support.itemFrame(offset: 40, in: controller) {
                XCTAssertEqual(arrived.minY, footerTop, accuracy: 4.5, "届いた項目が今の位置の下に続いていません (\(name))")
            } else {
                XCTFail("届いた項目の位置を取得できませんでした (\(name))")
            }
            // 残りの項目の数がしきい値を超えるため、続けて頼まない。
            await Support.yield()
            XCTAssertEqual(probe.loadMoreCount, 0, "スクロールしていないのに次ページ要求が続いています (\(name))")
        }
    }

    func test最後のページが届くのと同時に終端になっても末尾へ送らない() async {
        for (name, layout) in Self.layouts {
            var rows = makeRows(0..<40)
            let controller = makeController(rows: rows, state: .appending, layout: layout)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)
            await Support.scrollToBottom(controller)
            let offset = controller.collectionView.contentOffset.y

            rows += makeRows(40..<60)
            controller.update(configuration: makeConfiguration(rows: rows, state: .endReached, layout: layout))
            await Support.waitForItems(60, in: controller)
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 1, "末尾へ送っています (\(name))")
        }
    }

    func test終端の後に末尾へ足した項目は末尾に留まって現れる() async {
        for (name, layout) in Self.layouts {
            var rows = makeRows(0..<40)
            let controller = makeController(rows: rows, state: .endReached, layout: layout)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)
            await Support.scrollToBottom(controller)

            rows += makeRows(40..<41)
            controller.update(configuration: makeConfiguration(rows: rows, state: .endReached, layout: layout))
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                Support.bottomOffset(in: controller),
                accuracy: 0.5,
                "差分の適用で末尾へ留まっていません (\(name))"
            )
            await Support.waitForItems(41, in: controller)
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, Support.bottomOffset(in: controller), accuracy: 1, "\(name)")
            if let last = Support.itemFrame(offset: 40, in: controller) {
                XCTAssertTrue(controller.collectionView.bounds.insetBy(dx: 0, dy: -0.5).contains(last), "足した項目が見えていません (\(name))")
            } else {
                XCTFail("足した項目の位置を取得できませんでした (\(name))")
            }
        }
    }

    // MARK: - 取り直し

    func test途中で取り直すと差し替えと同時に先頭を表示し次ページ要求がすぐ呼ばれない() async {
        for (name, layout) in Self.layouts {
            let probe = KsPagingProbe()
            let rows = makeRows(0..<500)
            let controller = makeController(rows: rows, state: .idle, layout: layout, probe: probe)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(500, in: controller)
            await Support.settleLayout(controller)
            Support.scroll(controller, to: 6_000)
            await Support.settleLayout(controller)

            controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing, layout: layout, probe: probe))
            let refreshed = makeRows(1_000..<1_050)
            controller.update(configuration: makeConfiguration(rows: refreshed, state: .idle, layout: layout, probe: probe))
            let top = -controller.collectionView.adjustedContentInset.top
            XCTAssertEqual(controller.collectionView.contentOffset.y, top, accuracy: 0.5, "差分の適用で先頭になっていません (\(name))")
            await Support.waitForItems(50, in: controller)
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, top, accuracy: 0.5, "先頭にありません (\(name))")
            await Support.yield()
            XCTAssertEqual(probe.loadMoreCount, 0, "末尾に張り付いて次ページ要求が呼ばれています (\(name))")
        }
    }

    // 取り直しの結果が前と同じ ID で始まる (後ろの項目が消えるだけの差分になる) 取り直し。
    // 状態を取り直し中にした回と差し替えの回の間に、描画の機会を挟む場合と挟まない場合の両方で確かめる。
    func test前と同じIDを返す取り直しでも差し替えと同時に先頭を表示する() async {
        for (name, layout) in Self.layouts {
            for waitsBetweenUpdates in [false, true] {
                let label = "\(name) / 間に描画 \(waitsBetweenUpdates)"
                let probe = KsPagingProbe()
                let rows = makeRows(0..<500)
                let controller = makeController(rows: rows, state: .idle, layout: layout, probe: probe)
                let window = Support.show(controller, size: Self.size)
                defer { window.isHidden = true }
                await Support.waitForItems(500, in: controller)
                await Support.settleLayout(controller)
                Support.scroll(controller, to: 6_000)
                await Support.settleLayout(controller)

                controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing, layout: layout, probe: probe))
                if waitsBetweenUpdates {
                    await Support.settleLayout(controller)
                }
                controller.update(
                    configuration: makeConfiguration(rows: makeRows(0..<50), state: .idle, layout: layout, probe: probe)
                )
                await Support.waitForItems(50, in: controller)
                await Support.settleLayout(controller)
                XCTAssertEqual(
                    controller.collectionView.contentOffset.y,
                    -controller.collectionView.adjustedContentInset.top,
                    accuracy: 0.5,
                    "先頭にありません (\(label))"
                )
                await Support.yield()
                XCTAssertEqual(probe.loadMoreCount, 0, "末尾に張り付いて次ページ要求が呼ばれています (\(label))")
            }
        }
    }

    // 取り直しの結果が前と同じ配列 (1 ページ目まで読んだところで取り直した等) で、状態だけが取り直し中から
    // 抜ける回も、取り直しの結果が届いた回として先頭を表示する。
    func test前と同じ配列を返す取り直しでも取り直し中から抜ける回に先頭を表示する() async {
        for (name, layout) in Self.layouts {
            let probe = KsPagingProbe()
            let rows = makeRows(0..<50)
            let controller = makeController(rows: rows, state: .idle, layout: layout, probe: probe)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(50, in: controller)
            await Support.scrollToBottom(controller)
            controller.update(configuration: makeConfiguration(rows: rows, state: .appending, layout: layout, probe: probe))
            await Support.settleLayout(controller)

            controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing, layout: layout, probe: probe))
            await Support.settleLayout(controller)
            // 取り直し中のまま配列も同じ更新 (画面の別の値の変化による描き直し) では動かさない。
            let offset = controller.collectionView.contentOffset.y
            controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing, layout: layout, probe: probe))
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 0.5, "取り直し中の描き直しで動いています (\(name))")

            controller.update(configuration: makeConfiguration(rows: rows, state: .idle, layout: layout, probe: probe))
            await Support.settleLayout(controller)
            XCTAssertEqual(
                controller.collectionView.contentOffset.y,
                -controller.collectionView.adjustedContentInset.top,
                accuracy: 0.5,
                "先頭にありません (\(name))"
            )
        }
    }

    func test大きな一覧を取り直すと先頭を表示する() async {
        let rows = makeRows(0..<10_000)
        let controller = makeController(rows: rows, state: .idle, layout: .list)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(10_000, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 400_000)
        await Support.settleLayout(controller)

        controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing, layout: .list))
        controller.update(configuration: makeConfiguration(rows: makeRows(20_000..<20_050), state: .idle, layout: .list))
        await Support.waitForItems(50, in: controller)
        await Support.settleLayout(controller)
        XCTAssertEqual(
            controller.collectionView.contentOffset.y,
            -controller.collectionView.adjustedContentInset.top,
            accuracy: 0.5
        )
    }

    func testアニメーションを切る差し替えで取り直しても先頭を表示する() async {
        // 列数が変わると内部の塊の件数が変わり、差分の適用はアニメーションなしになる。
        let rows = makeRows(0..<600)
        let controller = makeController(rows: rows, state: .idle, layout: .grid(columns: .fixed(2)))
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(600, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 8_000)
        await Support.settleLayout(controller)
        let chunkRebuilds = controller.snapshotApplyCount

        controller.update(configuration: makeConfiguration(rows: rows, state: .refreshing, layout: .grid(columns: .fixed(2))))
        controller.update(configuration: makeConfiguration(rows: makeRows(2_000..<2_550), state: .idle, layout: .grid(columns: .fixed(3))))
        await Support.waitForItems(550, in: controller)
        await Support.settleLayout(controller)
        XCTAssertGreaterThan(controller.snapshotApplyCount, chunkRebuilds)
        XCTAssertEqual(
            controller.collectionView.contentOffset.y,
            -controller.collectionView.adjustedContentInset.top,
            accuracy: 0.5,
            "先頭にありません"
        )
    }

    func testPullToRefreshの取り直しでは先頭のまま新しい項目が見える() async {
        for (name, layout) in Self.layouts {
            let rows = makeRows(0..<40)
            let controller = makeController(rows: rows, state: .refreshing, layout: layout)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)
            await Support.settleLayout(controller)

            let refreshed = makeRows(500..<502) + rows
            controller.update(configuration: makeConfiguration(rows: refreshed, state: .idle, layout: layout))
            await Support.waitForItems(42, in: controller)
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, -controller.collectionView.adjustedContentInset.top, accuracy: 0.5, "\(name)")
            if let first = Support.itemFrame(offset: 0, in: controller) {
                XCTAssertTrue(controller.collectionView.bounds.intersects(first), "新しい項目が見えていません (\(name))")
            }
            XCTAssertEqual(controller.appliedItemIdentifiers.first, AnyHashable(500))
        }
    }

    func test状態を取り直し中にしない差し替えでは先頭に戻さない() async {
        for (name, layout) in Self.layouts {
            var rows = makeRows(0..<500)
            let controller = makeController(rows: rows, state: .idle, layout: layout)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(500, in: controller)
            await Support.settleLayout(controller)
            Support.scroll(controller, to: 6_000)
            await Support.settleLayout(controller)
            let offset = controller.collectionView.contentOffset.y

            // 状態は待機のまま、配列だけを差し替える (見ている位置より後ろを入れ替える)。
            rows = Array(rows.prefix(300)) + makeRows(3_000..<3_200)
            controller.update(configuration: makeConfiguration(rows: rows, state: .idle, layout: layout))
            await Support.waitForItems(500, in: controller)
            await Support.settleLayout(controller)
            XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 1, "表示範囲が動いています (\(name))")
        }
    }

    // MARK: - 部品

    private func makeRows(_ range: Range<Int>) -> [KsPagingRow] {
        range.map { KsPagingRow(id: $0) }
    }

    private func makeConfiguration(
        rows: [KsPagingRow],
        state: KsPagingState,
        layout: KsCollectionLayout,
        probe: KsPagingProbe? = nil
    ) -> KsCollectionConfiguration<KsPagingRow> {
        let action = (probe ?? KsPagingProbe()).loadMoreAction
        var configuration = KsCollectionView(rows, layout: layout) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .paging(state, onLoadMore: action)
        .configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func makeController(
        rows: [KsPagingRow],
        state: KsPagingState,
        layout: KsCollectionLayout,
        probe: KsPagingProbe? = nil
    ) -> KsCollectionViewController<KsPagingRow> {
        KsCollectionViewController(configuration: makeConfiguration(rows: rows, state: state, layout: layout, probe: probe))
    }
}
#endif
