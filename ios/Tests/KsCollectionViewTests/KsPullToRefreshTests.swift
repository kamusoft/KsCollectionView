#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// Pull to Refresh の接続・インジケータの規則・追加読み込みの間の引っ張りの抑止・全画面の一覧での
/// インジケータの位置を確かめる。引っ張りの操作は、標準の部品が引っ張りを認めたときと同じく、
/// 部品を取り直し中にして値の変化を送ることで表す。
@MainActor
final class KsPullToRefreshTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    private static let size = CGSize(width: 390, height: 800)
    private static let rowHeight: CGFloat = 80

    // MARK: - 接続

    func test引っ張ると取り直しの処理が呼ばれる() async {
        for paging in [false, true] {
            let probe = KsPagingProbe()
            let controller = makeController(rows: makeRows(40), probe: probe, paging: paging ? .idle : nil)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(40, in: controller)
            XCTAssertTrue(controller.collectionView.refreshControl === controller.pullRefreshControl, "ページング \(paging)")

            pull(controller)
            await Support.waitUntil("取り直しの処理 (ページング \(paging))", value: { probe.refreshCount }) { $0 == 1 }
        }
    }

    func test取り直しの処理を渡さない一覧は引っ張れない() async {
        var configuration = KsCollectionView(makeRows(5)) { row in Text("\(row.id)") }.configuration
        configuration.showsSeparators = false
        let controller = KsCollectionViewController(configuration: configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        XCTAssertNil(controller.collectionView.refreshControl)
    }

    func test0件でも引っ張れる() async {
        let probe = KsPagingProbe()
        let controller = makeController(rows: [], probe: probe, paging: .endReached)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        XCTAssertTrue(controller.collectionView.refreshControl === controller.pullRefreshControl)
        XCTAssertTrue(controller.collectionView.alwaysBounceVertical, "0 件では縦に弾まず引っ張れません")
        pull(controller)
        await Support.waitUntil("取り直しの処理", value: { probe.refreshCount }) { $0 == 1 }
    }

    func testSwiftUIのrefreshableの処理を一覧が受け取る() async {
        let probe = KsPagingProbe()
        let host = UIHostingController(rootView: KsPagingRefreshableView(probe: probe))
        let window = Support.show(host, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("SwiftUI 配下の一覧", value: { self.collectionController(in: host) != nil }) { $0 }
        guard let controller = collectionController(in: host) else { return }
        await Support.waitUntil("引っ張りの部品", value: {
            controller.collectionView.refreshControl === controller.pullRefreshControl
        }) { $0 }
        // 引っ張りの部品は一覧の 1 つだけ。
        XCTAssertEqual(refreshControlCount(in: window), 1)
        pull(controller)
        await Support.waitUntil("refreshable の処理", value: { probe.refreshCount }) { $0 == 1 }
    }

    // MARK: - インジケータの規則

    func test処理の中で待つ取り直しは処理が終わるまでインジケータを出し終わったら消す() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.refreshGate = gate
        let controller = makeController(rows: makeRows(40), probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)

        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
        XCTAssertTrue(controller.isPullRefreshing)
        XCTAssertTrue(controller.pullRefreshControl.isRefreshing)

        gate.open()
        await Support.waitUntil("インジケータが消える", value: { controller.pullRefreshControl.isRefreshing }) { !$0 }
        XCTAssertFalse(controller.isPullRefreshing)
    }

    func test処理がすぐ戻る取り直しは状態が待機に戻るまでインジケータを出し続ける() async {
        let probe = KsPagingProbe()
        let rows = makeRows(40)
        var controller: KsCollectionViewController<KsPagingRow>!
        // 処理の中で状態を取り直し中にしてすぐ戻る。
        probe.onRefresh = {
            controller.update(configuration: self.makeConfiguration(rows: rows, probe: probe, paging: .refreshing))
        }
        controller = makeController(rows: rows, probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)

        pull(controller)
        await Support.waitUntil("取り直しの処理", value: { probe.refreshCount }) { $0 == 1 }
        await Support.yield()
        XCTAssertTrue(controller.pullRefreshControl.isRefreshing, "処理が戻った時点でインジケータが消えています")

        controller.update(configuration: makeConfiguration(rows: makeRows(10), probe: probe, paging: .idle))
        await Support.waitUntil("インジケータが消える", value: { controller.pullRefreshControl.isRefreshing }) { !$0 }
    }

    func testVMが始めた取り直しではインジケータを出さない() async {
        let probe = KsPagingProbe()
        let rows = makeRows(40)
        let controller = makeController(rows: rows, probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)

        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, paging: .refreshing))
        await Support.yield()
        XCTAssertFalse(controller.pullRefreshControl.isRefreshing)
        XCTAssertFalse(controller.isPullRefreshing)
        XCTAssertEqual(probe.refreshCount, 0)
    }

    // MARK: - 追加読み込みの間は引っ張れない

    func test追加読み込み中は引っ張れない() async {
        let probe = KsPagingProbe()
        let rows = makeRows(40)
        let controller = makeController(rows: rows, probe: probe, paging: .appending)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)
        XCTAssertNil(controller.collectionView.refreshControl, "追加読み込み中に引っ張りの部品が付いています")

        // 追加読み込みが終わって待機に戻ると、また引っ張れる。
        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, paging: .idle))
        XCTAssertTrue(controller.collectionView.refreshControl === controller.pullRefreshControl)
        pull(controller)
        await Support.waitUntil("取り直しの処理", value: { probe.refreshCount }) { $0 == 1 }
    }

    func test次ページ要求の処理の実行中は引っ張れない() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.loadMoreGate = gate
        // 0 件・待機で表示すると、最初の読み込みの次ページ要求が呼ばれる。状態はまだ待機のまま。
        let controller = makeController(rows: [], probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("次ページ要求の待ち", value: { gate.waitingCount }) { $0 == 1 }
        XCTAssertEqual(controller.pagingState, .idle)
        XCTAssertNil(controller.collectionView.refreshControl, "処理の実行中に引っ張りの部品が付いています")

        gate.open()
        await Support.waitUntil("引っ張りの部品が戻る", value: {
            controller.collectionView.refreshControl === controller.pullRefreshControl
        }) { $0 }
    }

    func test引っ張って始めた取り直しの間は追加読み込み中になってもインジケータを外さない() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.refreshGate = gate
        let rows = makeRows(40)
        let controller = makeController(rows: rows, probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(40, in: controller)
        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }

        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, paging: .appending))
        XCTAssertTrue(controller.collectionView.refreshControl === controller.pullRefreshControl)
        XCTAssertTrue(controller.pullRefreshControl.isRefreshing)
        gate.open()
        await Support.waitUntil("インジケータが消えて部品が外れる", value: {
            (controller.pullRefreshControl.isRefreshing, controller.collectionView.refreshControl == nil)
        }) { !$0.0 && $0.1 }
    }

    // MARK: - 全画面の一覧

    func test全画面の一覧でも取り直し中のインジケータは上端の安全領域の下に出る() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.refreshGate = gate
        let controller = makeController(rows: makeRows(40), probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "表示先が上端の安全領域を持っていません")
        await Support.waitForItems(40, in: controller)
        await Support.settleLayout(controller)
        // 行はバーの裏を流れ、上端に安全領域の分の余白は無い。
        XCTAssertEqual(controller.collectionView.adjustedContentInset.top, 0, accuracy: 0.5)

        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
        await Support.settleLayout(controller)
        let collectionView = controller.collectionView!
        let control = controller.pullRefreshControl
        control.updateDrawingOffset()
        // 取り直しの間だけ、部品の高さと安全領域の分の余白が上端に入る。
        XCTAssertEqual(controller.refreshExtraTopInset, safeTop, accuracy: 0.5)
        XCTAssertEqual(collectionView.adjustedContentInset.top, control.frame.height + safeTop, accuracy: 0.5)
        // 部品を描く位置 (表示範囲の上端から) は安全領域の下で、コンテンツの先頭より上。
        let drawnTop = control.frame.minY - control.bounds.minY - collectionView.contentOffset.y
        XCTAssertGreaterThanOrEqual(drawnTop, safeTop - 0.5, "インジケータがバーの裏にあります")
        let contentTop = -collectionView.contentOffset.y
        XCTAssertLessThanOrEqual(drawnTop + control.frame.height, contentTop + 0.5, "インジケータがコンテンツに被っています")

        gate.open()
        await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
        await Support.settleLayout(controller)
        XCTAssertEqual(controller.refreshExtraTopInset, 0)
        XCTAssertEqual(collectionView.adjustedContentInset.top, 0, accuracy: 0.5, "取り直しの後に余白が残っています")
        // 止まっている間に取り直しが終わっても、表示範囲は先頭 (余白なし) まで戻り、上端に空白を残さない。
        XCTAssertEqual(collectionView.contentOffset.y, 0, accuracy: 0.5, "取り直しの後に上端の空白が残っています")
    }

    // 取り直しの処理の中で状態を取り直し中にし、結果の配列を届けてから処理が終わる VM。止まっている間に
    // 取り直しが終わっても、表示範囲は余白のない先頭まで戻り、上端に空白を残さない。
    func test止まっている間に結果が届いて取り直しが終わっても上端に空白を残さない() async {
        for padsTop in [false, true] {
            let gate = KsPagingGate()
            let probe = KsPagingProbe()
            probe.refreshGate = gate
            let rows = makeRows(40)
            var controller: KsCollectionViewController<KsPagingRow>!
            let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
            let padding = { (safeTop: CGFloat) in padsTop ? safeTop : 0 }
            probe.onRefresh = {
                controller.update(configuration: self.makeConfiguration(
                    rows: rows, probe: probe, paging: .refreshing, topPadding: padding(window.safeAreaInsets.top)
                ))
            }
            controller = makeController(rows: rows, probe: probe, paging: .idle)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.layoutIfNeeded()
            defer { window.isHidden = true }
            let safeTop = window.safeAreaInsets.top
            controller.update(configuration: makeConfiguration(rows: rows, probe: probe, paging: .idle, topPadding: padding(safeTop)))
            await Support.waitForItems(40, in: controller)
            await Support.settleLayout(controller)
            let collectionView = controller.collectionView!

            pull(controller)
            await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
            await Support.settleLayout(controller)
            // 結果を届ける (配列を差し替えて状態を待機にする)。処理はまだ終わっていない。
            controller.update(configuration: makeConfiguration(
                rows: makeRows(30), probe: probe, paging: .idle, topPadding: padding(safeTop)
            ))
            await Support.waitForItems(30, in: controller)
            await Support.settleLayout(controller)
            gate.open()
            await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
            await Support.settleLayout(controller)
            XCTAssertEqual(collectionView.adjustedContentInset.top, 0, accuracy: 0.5, "余白が残っています (上の余白 \(padsTop))")
            XCTAssertEqual(collectionView.contentOffset.y, 0, accuracy: 0.5, "上端に空白が残っています (上の余白 \(padsTop))")
        }
    }

    // 全画面の一覧の上の余白に安全領域の分を入れ、最初の項目をバーのすぐ下に置く形 (core/ADR-0017 の典型)。
    // 取り直し中は、インジケータがバーのすぐ下に出て、その下にすぐ最初の項目が続く (空白が二重にならない)。
    func test上の余白に安全領域の分を入れた全画面の一覧でも取り直し中の空白が二重にならない() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.refreshGate = gate
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        let safeTop = window.safeAreaInsets.top
        let controller = KsCollectionViewController(
            configuration: makeConfiguration(rows: makeRows(40), probe: probe, paging: .idle, topPadding: safeTop)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }
        XCTAssertGreaterThan(controller.collectionView.safeAreaInsets.top, 0)
        await Support.waitForItems(40, in: controller)
        await Support.settleLayout(controller)
        let collectionView = controller.collectionView!
        let control = controller.pullRefreshControl
        // 最初の項目は上の余白の分だけ下 (バーのすぐ下) にある。
        XCTAssertEqual(Support.itemFrame(offset: 0, in: controller)?.minY ?? -1, safeTop, accuracy: 0.5)

        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
        await Support.settleLayout(controller)
        control.updateDrawingOffset()
        // 上の余白が安全領域を覆っているため、取り直し中に足す余白は要らない。
        XCTAssertEqual(controller.refreshExtraTopInset, 0, accuracy: 0.5)
        let drawnTop = control.frame.minY - control.bounds.minY - collectionView.contentOffset.y
        XCTAssertEqual(drawnTop, safeTop, accuracy: 0.5, "インジケータがバーのすぐ下にありません")
        let firstItemTop = (Support.itemFrame(offset: 0, in: controller)?.minY ?? 0) - collectionView.contentOffset.y
        XCTAssertEqual(firstItemTop, drawnTop + control.frame.height, accuracy: 0.5, "インジケータと最初の項目の間に空白があります")
        gate.open()
        await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
    }

    func test上の余白に安全領域の分を入れた一覧では引っ張り始めてバーの下に隙間が空けばインジケータが見える() {
        // 安全領域 116・部品の高さ 60・上の余白 116。引っ張った量 80 (表示範囲の上端 -80、部品は -80)。
        // バーの下 (116) から 80 の隙間が空いており、部品はバーのすぐ下 (内容の座標で -80 + 116 = 36) に描く。
        let shift = KsRefreshControl.drawingOffset(
            controlTop: -80, controlHeight: 60, contentOffset: -80, topSafeArea: 116, emptyTopSpace: 116
        )
        XCTAssertEqual(shift, 116)
        // 上の余白が無い一覧では、部品はコンテンツの先頭 (0) より下へは下げない。
        XCTAssertEqual(
            KsRefreshControl.drawingOffset(controlTop: -80, controlHeight: 60, contentOffset: -80, topSafeArea: 116, emptyTopSpace: 0),
            20
        )
    }

    func test引っ張りの部品を描く位置の下げ幅() {
        // 安全領域 116・部品の高さ 60。
        // 引っ張った量が安全領域に満たない (表示範囲の上端 -89、部品は -89)。コンテンツの先頭を越えない 29 まで。
        XCTAssertEqual(KsRefreshControl.drawingOffset(controlTop: -89, controlHeight: 60, contentOffset: -89, topSafeArea: 116, emptyTopSpace: 0), 29)
        // 十分に引っ張った (表示範囲の上端 -200、部品は -200)。安全領域の分だけ下げる。
        XCTAssertEqual(KsRefreshControl.drawingOffset(controlTop: -200, controlHeight: 60, contentOffset: -200, topSafeArea: 116, emptyTopSpace: 0), 116)
        // 取り直し中に止まった位置 (上端の余白 176、部品はコンテンツの直前 -60)。下げない。
        XCTAssertEqual(KsRefreshControl.drawingOffset(controlTop: -60, controlHeight: 60, contentOffset: -176, topSafeArea: 116, emptyTopSpace: 0), 0)
        // 安全領域に重ならない置き方では下げない。
        XCTAssertEqual(KsRefreshControl.drawingOffset(controlTop: -120, controlHeight: 60, contentOffset: -120, topSafeArea: 0, emptyTopSpace: 0), 0)
    }

    func test取り直し中も固定中の見出しはインジケータの下で止まり先頭への挿入は先頭に留まる() async {
        let gate = KsPagingGate()
        let probe = KsPagingProbe()
        probe.refreshGate = gate
        var rows = (0..<60).map { KsPagingRow(id: $0, group: $0 / 20) }
        let controller = KsCollectionViewController(configuration: makeGroupedConfiguration(rows: rows, probe: probe))
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(60, in: controller)
        await Support.settleLayout(controller)
        let collectionView = controller.collectionView!

        pull(controller)
        await Support.waitUntil("取り直しの処理の待ち", value: { gate.waitingCount }) { $0 == 1 }
        await Support.settleLayout(controller)
        let adjustedTop = collectionView.adjustedContentInset.top
        XCTAssertGreaterThan(adjustedTop, 0)

        // 先頭にいる間の先頭への挿入は、取り直しの余白を含めた先頭に留まる。
        XCTAssertEqual(collectionView.contentOffset.y, -adjustedTop, accuracy: 0.5)
        rows.insert(KsPagingRow(id: 1_000, group: 0), at: 0)
        controller.update(configuration: makeGroupedConfiguration(rows: rows, probe: probe))
        await Support.waitForItems(61, in: controller)
        await Support.settleLayout(controller)
        XCTAssertEqual(collectionView.contentOffset.y, -adjustedTop, accuracy: 0.5, "先頭に留まっていません")

        // 途中までスクロールすると、固定中の見出しは表示範囲の上端 + 上端の余白 (部品の高さ + 安全領域) で止まる。
        Support.scroll(controller, to: 600)
        let bounds = collectionView.bounds
        let headers = (collectionView.collectionViewLayout.layoutAttributesForElements(in: bounds) ?? [])
            .filter { $0.representedElementKind == KsSupplementaryKind.groupHeader && $0.alpha > 0.01 }
        guard let pinned = headers.min(by: { $0.frame.minY < $1.frame.minY }) else {
            XCTFail("固定中の見出しがありません")
            return
        }
        XCTAssertEqual(pinned.frame.minY, bounds.minY + adjustedTop, accuracy: 0.5, "固定の位置が安全領域と二重に数えています")
        gate.open()
    }

    // MARK: - 引っ張って始めた取り直しの結果の置き方

    // 取り直しの処理の中で「状態を取り直し中にする」と「1 ページ目への差し替えと待機」を同じ更新の回で行う
    // (取得がすぐ終わる) VM。一覧には取り直し中が届かないが、引っ張って始めた取り直しの間の差し替えなので
    // 差し替えと同時に先頭を表示し、次ページ要求はすぐには呼ばれない。
    func test引っ張って始めた取り直しの間の差し替えは直前の状態によらず先頭を表示する() async {
        let layouts: [(String, KsCollectionLayout)] = [
            ("list", .list),
            ("grid", .grid(columns: .fixed(2))),
        ]
        for (name, layout) in layouts {
            let gate = KsPagingGate()
            let probe = KsPagingProbe()
            probe.refreshGate = gate
            var controller: KsCollectionViewController<KsPagingRow>!
            probe.onRefresh = {
                controller.update(configuration: self.makeConfiguration(
                    rows: self.makeRows(50), probe: probe, paging: .idle, layout: layout
                ))
            }
            controller = KsCollectionViewController(
                configuration: makeConfiguration(rows: makeRows(500), probe: probe, paging: .idle, layout: layout)
            )
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(500, in: controller)
            await Support.settleLayout(controller)
            Support.scroll(controller, to: 6_000)
            await Support.settleLayout(controller)
            let loadsBefore = probe.loadMoreCount

            pull(controller, restsAtTop: false)
            await Support.waitUntil("取り直しの処理の待ち (\(name))", value: { gate.waitingCount }) { $0 == 1 }
            await Support.waitForItems(50, in: controller)
            await Support.settleLayout(controller)
            let collectionView = controller.collectionView!
            XCTAssertEqual(collectionView.contentOffset.y, -collectionView.adjustedContentInset.top, accuracy: 0.5, "先頭にありません (\(name))")
            await Support.yield()
            XCTAssertEqual(probe.loadMoreCount, loadsBefore, "次ページ要求がすぐに呼ばれています (\(name))")

            // 取り直しの終わり (B-2 の戻し) でも先頭のまま。
            gate.open()
            await Support.waitUntil("取り直しの終わり (\(name))", value: { controller.isPullRefreshing }) { !$0 }
            await Support.settleLayout(controller)
            XCTAssertEqual(collectionView.contentOffset.y, -collectionView.adjustedContentInset.top, accuracy: 0.5, "取り直しの終わりで先頭から動いています (\(name))")
        }
    }

    // 同じ配列が返り、差分を適用しない取り直し (状態も取り直し中にしない VM)。取り直しの間に届いた結果として、
    // 取り直しを終えるときに先頭を表示する。
    func test引っ張って始めた取り直しの結果が同じ配列でも先頭を表示する() async {
        let probe = KsPagingProbe()
        let rows = makeRows(500)
        var controller: KsCollectionViewController<KsPagingRow>!
        probe.onRefresh = {
            controller.update(configuration: self.makeConfiguration(rows: rows, probe: probe, paging: .idle))
        }
        controller = makeController(rows: rows, probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(500, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 6_000)
        await Support.settleLayout(controller)

        pull(controller, restsAtTop: false)
        await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
        await Support.settleLayout(controller)
        let collectionView = controller.collectionView!
        XCTAssertEqual(collectionView.contentOffset.y, -collectionView.adjustedContentInset.top, accuracy: 0.5, "先頭にありません")
    }

    // ページングを付けない一覧で `.refreshable` の中で差し替えた場合も先頭を表示する。
    func testページングを付けない一覧でも引っ張って始めた取り直しの間の差し替えは先頭を表示する() async {
        let probe = KsPagingProbe()
        var controller: KsCollectionViewController<KsPagingRow>!
        probe.onRefresh = {
            controller.update(configuration: self.makeConfiguration(
                rows: (1_000..<1_300).map { KsPagingRow(id: $0) }, probe: probe, paging: nil
            ))
        }
        controller = makeController(rows: makeRows(300), probe: probe, paging: nil)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(300, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 6_000)
        await Support.settleLayout(controller)

        pull(controller, restsAtTop: false)
        await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
        await Support.settleLayout(controller)
        let collectionView = controller.collectionView!
        XCTAssertEqual(controller.appliedItemIdentifiers.first, AnyHashable(1_000))
        XCTAssertEqual(collectionView.contentOffset.y, -collectionView.adjustedContentInset.top, accuracy: 0.5, "先頭にありません")
    }

    // SwiftUI の `.refreshable` と ObservableObject の VM を通る経路。処理の中で「状態を取り直し中にする」と
    // 「1 ページ目への差し替えと待機」を同じ回に行っても、最終的に先頭が表示される。
    func testSwiftUIのrefreshableで取得がすぐ終わる取り直しでも先頭が表示される() async {
        let model = KsPagingRefreshModel(itemCount: 500)
        let host = UIHostingController(rootView: KsPagingRefreshModelView(model: model))
        let window = Support.show(host, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitUntil("SwiftUI 配下の一覧", value: { self.collectionController(in: host) != nil }) { $0 }
        guard let controller = collectionController(in: host) else { return }
        await Support.waitForItems(500, in: controller)
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 6_000)
        await Support.settleLayout(controller)
        let loadsBefore = model.loadMoreCount

        pull(controller, restsAtTop: false)
        await Support.waitUntil("取り直しの処理", value: { model.refreshCount }) { $0 == 1 }
        await Support.waitForItems(50, in: controller)
        await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
        await Support.settleLayout(controller)
        let collectionView = controller.collectionView!
        XCTAssertEqual(controller.appliedItemIdentifiers.first, AnyHashable(0))
        XCTAssertEqual(collectionView.contentOffset.y, -collectionView.adjustedContentInset.top, accuracy: 0.5, "先頭にありません")
        await Support.yield()
        XCTAssertEqual(model.loadMoreCount, loadsBefore, "次ページ要求がすぐに呼ばれています")
    }

    // インジケータを出し終えた後の差し替えには、この規則は効かない (直前の状態で決める)。
    func testインジケータを出し終えた後の差し替えでは先頭へ送らない() async {
        let probe = KsPagingProbe()
        var rows = makeRows(500)
        let controller = makeController(rows: rows, probe: probe, paging: .idle)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(500, in: controller)
        await Support.settleLayout(controller)
        pull(controller)
        await Support.waitUntil("取り直しの終わり", value: { controller.isPullRefreshing }) { !$0 }
        await Support.settleLayout(controller)
        Support.scroll(controller, to: 6_000)
        await Support.settleLayout(controller)
        let offset = controller.collectionView.contentOffset.y

        rows = Array(rows.prefix(300)) + (3_000..<3_200).map { KsPagingRow(id: $0) }
        controller.update(configuration: makeConfiguration(rows: rows, probe: probe, paging: .idle))
        await Support.waitForItems(500, in: controller)
        await Support.settleLayout(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 1, "先頭へ送っています")
    }

    // MARK: - 部品

    // 標準の部品は、試験から値の変化を送っても登録先へ届けないため、登録された処理を直接呼ぶ。
    // restsAtTop が false のときは、引っ張った後の位置を動かさない (途中の位置のまま取り直しを始めた形)。
    private func pull(_ controller: KsCollectionViewController<KsPagingRow>, restsAtTop: Bool = true) {
        let control = controller.pullRefreshControl
        let offset = controller.collectionView.contentOffset
        control.beginRefreshing()
        if !restsAtTop {
            controller.collectionView.setContentOffset(offset, animated: false)
        }
        for target in control.allTargets {
            for action in control.actions(forTarget: target, forControlEvent: .valueChanged) ?? [] {
                _ = (target as NSObject).perform(Selector(action), with: control)
            }
        }
        // 引っ張って離した一覧は、上端の余白を含めた先頭で止まる。
        let collectionView = controller.collectionView!
        guard restsAtTop else {
            collectionView.layoutIfNeeded()
            return
        }
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
        collectionView.layoutIfNeeded()
    }

    private func makeRows(_ count: Int) -> [KsPagingRow] {
        (0..<count).map { KsPagingRow(id: $0) }
    }

    private func makeConfiguration(
        rows: [KsPagingRow],
        probe: KsPagingProbe,
        paging: KsPagingState?,
        topPadding: CGFloat = 0,
        layout: KsCollectionLayout = .list
    ) -> KsCollectionConfiguration<KsPagingRow> {
        var view = KsCollectionView(
            rows,
            layout: layout,
            contentPadding: EdgeInsets(top: topPadding, leading: 0, bottom: 0, trailing: 0)
        ) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        if let paging {
            view = view.paging(paging, onLoadMore: probe.loadMoreAction)
        }
        var configuration = view.configuration
        configuration.refresh = probe.refreshAction
        configuration.showsSeparators = false
        return configuration
    }

    private func makeController(
        rows: [KsPagingRow],
        probe: KsPagingProbe,
        paging: KsPagingState?
    ) -> KsCollectionViewController<KsPagingRow> {
        KsCollectionViewController(configuration: makeConfiguration(rows: rows, probe: probe, paging: paging))
    }

    private func makeGroupedConfiguration(rows: [KsPagingRow], probe: KsPagingProbe) -> KsCollectionConfiguration<KsPagingRow> {
        var configuration = KsCollectionView(rows, layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .groups(by: \.group) { group, _ in KsPagingFixedView(text: "見出し \(group)", height: 40) }
        .configuration
        configuration.refresh = probe.refreshAction
        configuration.showsSeparators = false
        return configuration
    }

    private func refreshControlCount(in view: UIView) -> Int {
        (view is UIRefreshControl ? 1 : 0) + view.subviews.reduce(0) { $0 + refreshControlCount(in: $1) }
    }

    private func collectionController(in controller: UIViewController) -> KsCollectionViewController<KsPagingRow>? {
        if let collectionController = controller as? KsCollectionViewController<KsPagingRow> {
            return collectionController
        }
        for child in controller.children {
            if let found = collectionController(in: child) {
                return found
            }
        }
        return nil
    }
}

// 取得がすぐ終わる VM。取り直しでは、状態を取り直し中にする書き換えと、1 ページ目への差し替えと待機を
// 同じ回に行う。パッケージの対応 OS に合わせて ObservableObject で持つ。
@MainActor
final class KsPagingRefreshModel: ObservableObject {
    @Published private(set) var items: [KsPagingRow]
    @Published private(set) var state = KsPagingState.idle
    private(set) var refreshCount = 0
    private(set) var loadMoreCount = 0

    init(itemCount: Int) {
        items = (0..<itemCount).map { KsPagingRow(id: $0) }
    }

    func refresh() async {
        refreshCount += 1
        state = .refreshing
        items = (0..<50).map { KsPagingRow(id: $0) }
        state = .idle
    }

    func loadMore() async {
        loadMoreCount += 1
    }
}

// VM を持ち、一覧に `.paging` と `.refreshable` を付けた画面。
struct KsPagingRefreshModelView: View {
    @ObservedObject var model: KsPagingRefreshModel

    var body: some View {
        KsCollectionView(model.items, layout: .list) { row in
            KsPagingFixedView(text: "\(row.id)", height: 80)
        }
        .paging(model.state) {
            await model.loadMore()
        }
        .refreshable {
            await model.refresh()
        }
    }
}

// SwiftUI 標準の `.refreshable` を一覧に付けた画面。
struct KsPagingRefreshableView: View {
    let probe: KsPagingProbe

    var body: some View {
        KsCollectionView((0..<20).map { KsPagingRow(id: $0) }) { row in
            Text("\(row.id)").frame(maxWidth: .infinity, minHeight: 44)
        }
        .refreshable {
            await probe.refreshAction()
        }
    }
}
#endif
