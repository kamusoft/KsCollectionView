#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// 並べ替えを一覧の実レイアウトの上で確かめる。UIKit のドラッグ & ドロップはテストから合成できないため、
/// 一覧が UIKit から受ける呼び出し (持ち上げ・ドラッグ中の提案・置く・終わる) を偽物のセッションで直接渡す。
@MainActor
final class KsReorderEngineTests: XCTestCase {
    private typealias Support = KsReorderTestSupport

    override func setUp() {
        super.setUp()
        KsInvalidInput.reset()
    }

    override func tearDown() {
        KsInvalidInput.reset()
        super.tearDown()
    }

    private func path(_ section: Int, _ item: Int) -> IndexPath {
        IndexPath(item: item, section: section)
    }

    // MARK: - 並べ替えのスイッチ

    func testスイッチが有効なら長押しで持ち上がり無効なら持ち上がらない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        XCTAssertTrue(controller.collectionView.dragInteractionEnabled)
        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        XCTAssertTrue(controller.isReorderDragging)
        driver.end()

        controller.update(configuration: Support.view(rows, probe: probe, isEnabled: false).configuration)
        XCTAssertFalse(controller.collectionView.dragInteractionEnabled)
        var disabled = KsReorderDriver(controller: controller)
        XCTAssertFalse(disabled.lift("A"), "スイッチが無効なのに持ち上がりました")
    }

    func test並べ替えを設定していない一覧は持ち上がらない() async {
        let rows = Support.rows(["A", "B"])
        let view = KsCollectionView(rows) { row in Text(row.id) }
        let controller = KsCollectionViewController(configuration: view.configuration)
        let window = KsPagingTestSupport.show(controller, size: Support.size)
        defer { window.isHidden = true }
        await KsPagingTestSupport.waitForItems(2, in: controller)

        XCTAssertFalse(controller.collectionView.dragInteractionEnabled)
        let items = controller.reorderItemsForBeginning(session: KsFakeDragSession(), at: path(0, 0))
        XCTAssertTrue(items.isEmpty)
    }

    func testドラッグ中にスイッチが無効になると取りやめて知らせない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 1))
        controller.update(configuration: Support.view(rows, probe: probe, isEnabled: false).configuration)

        // 取りやめた後は隙間を空けない提案になり、指を離しても置いたときの処理は呼ばれない。
        XCTAssertEqual(driver.move(over: path(0, 2)).intent, .unspecified)
        let coordinator = driver.drop(at: path(0, 2))
        driver.end()
        await Support.settle(controller)

        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertTrue(coordinator.droppedIndexPaths.isEmpty)
        XCTAssertEqual(coordinator.droppedTargetCenters, [Support.center("A", in: controller)].compactMap { $0 })
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C"])
        XCTAssertFalse(controller.collectionView.dragInteractionEnabled)
    }

    func testドラッグ中にlayoutが変わると取りやめて終わった後に新しいlayoutで表示する() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 1))
        let grid = KsCollectionLayout.grid(columns: .fixed(2))
        controller.update(configuration: Support.view(rows, probe: probe, layout: grid).configuration)
        // ドラッグ中は新しい構成を控え、並べ替えの仮の並びと行き先の対応を崩さない。
        XCTAssertEqual(controller.configuration.layout.kind, KsCollectionLayout.list.kind)

        XCTAssertEqual(driver.move(over: path(0, 2)).intent, .unspecified)
        driver.drop(at: path(0, 2))
        driver.end()
        await Support.settle(controller)

        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertEqual(controller.configuration.layout.kind, grid.kind)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"])
    }

    func testドラッグ中にグループの宣言が変わると取りやめる() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        controller.update(configuration: Support.view(rows, probe: probe, groups: false).configuration)
        XCTAssertEqual(driver.move(over: path(1, 0)).intent, .unspecified)
        driver.drop(at: path(1, 1))
        driver.end()
        await Support.settle(controller)

        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertEqual(Support.sections(controller), [["A", "B", "C", "D"]])
    }

    func testグリッドでも並べ替えられ置いたときに知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let grid = KsCollectionLayout.grid(columns: .fixed(2))
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, layout: grid))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 2))
        driver.move(over: path(0, 3))
        XCTAssertEqual(driver.gap, path(0, 3))
        driver.drop()
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.map(Support.destinationDescription), ["end"])
        XCTAssertEqual(Support.ids(controller), ["B", "C", "D", "A"])
    }

    // 持ち上げてから指を動かし始めるまでの間に layout が変わると、指を動かし始めた時点で取りやめる。
    func test持ち上げた直後にlayoutが変わると動かし始めた時点で取りやめる() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.liftOnly("A"))
        let grid = KsCollectionLayout.grid(columns: .fixed(2))
        controller.update(configuration: Support.view(rows, probe: probe, layout: grid).configuration)
        await Support.settle(controller)
        // 持ち上げの間の変化は控えに回らず、そのまま当たっている。
        XCTAssertEqual(controller.configuration.layout.kind, grid.kind)
        driver.beginMoving()

        XCTAssertEqual(controller.reorderDrag?.isCancelled, true, "持ち上げた直後の layout の変化で取りやめていません")
        XCTAssertEqual(driver.move(over: path(0, 2)).intent, .unspecified)
        let coordinator = driver.drop(at: path(0, 2))
        driver.end()
        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertTrue(coordinator.droppedIndexPaths.isEmpty)
        XCTAssertEqual(coordinator.droppedTargetCenters.count, 1, "元の位置へ戻していません")
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"])
    }

    func test持ち上げた直後にスイッチが無効になると動かし始めた時点で取りやめる() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.liftOnly("A"))
        controller.update(configuration: Support.view(rows, probe: probe, isEnabled: false).configuration)
        driver.beginMoving()

        XCTAssertEqual(controller.reorderDrag?.isCancelled, true, "持ち上げた直後のスイッチの無効化で取りやめていません")
        driver.drop(at: path(0, 2))
        driver.end()
        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C"])
    }

    func test持ち上げた後に構成が変わらなければ取りやめない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.liftOnly("A"))
        // 並べ替えに関わらない描き直し (同じ構成) は取りやめの理由にならない。
        controller.update(configuration: Support.view(rows, probe: probe).configuration)
        driver.beginMoving()
        XCTAssertEqual(controller.reorderDrag?.isCancelled, false)
        driver.move(over: path(0, 1))
        driver.drop()
        driver.end()
        XCTAssertEqual(probe.moves.count, 1)
    }

    // MARK: - 上端の自動スクロール

    // iOS 26 より前は、指が帯に入ってから待って送り始める。その待ちを越えてさらに 10 フレーム進める
    // (送ることの確かめにも、送らないことの確かめにも使う)。
    private func advancePastStartDelay(_ controller: KsCollectionViewController<KsReorderRow>) {
        let delay = KsReorderTopAutoScroll.profile(
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        ).startDelay
        for _ in 0..<(Int((delay * 60).rounded(.up)) + 10) {
            controller.advanceReorderAutoScroll(elapsed: 1.0 / 60)
        }
    }

    // バーの裏まで広げた一覧 (安全領域の上が 0 より大きい) で、指を安全領域の境目のすぐ下の帯に置くと、
    // フレームごとに上へ送り、先頭で止まる。
    func test上端の帯に指を置くとフレームごとに上へ送り先頭で止まる() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0, "一覧が上端の安全領域に重なっていません")
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("20"))
        XCTAssertTrue(controller.isReorderAutoScrollRunning)
        driver.moveFinger(toViewY: safeTop + 20)
        let start = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertLessThan(controller.collectionView.contentOffset.y, start, "上へ送っていません")

        let top = -controller.collectionView.adjustedContentInset.top
        for _ in 0..<600 where controller.collectionView.contentOffset.y > top {
            driver.moveFinger(toViewY: safeTop + 20)
            controller.advanceReorderAutoScroll(elapsed: 1.0 / 60)
        }
        XCTAssertEqual(controller.collectionView.contentOffset.y, top, accuracy: 0.5, "先頭で止まっていません")
        controller.advanceReorderAutoScroll(elapsed: 1.0 / 60)
        XCTAssertEqual(controller.collectionView.contentOffset.y, top, accuracy: 0.5, "先頭より上へ行き過ぎました")
        driver.end()
    }

    // 前のドラッグのドロップのセッションの終わりが次のドラッグの間に届いても、次のドラッグの指の位置を消さず、
    // 上端の自動スクロールは送り続ける。
    func test前のドロップのセッションの終わりが届いても次のドラッグの上端の送りは止まらない() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var first = KsReorderDriver(controller: controller)
        XCTAssertTrue(first.lift("20"))
        first.move(over: path(0, 21))
        first.drop()
        controller.reorderDragSessionDidEnd(first.dragSession)
        await Support.settle(controller)
        XCTAssertFalse(controller.isReorderDragging)

        var second = KsReorderDriver(controller: controller)
        XCTAssertTrue(second.lift("22"))
        second.moveFinger(toViewY: safeTop + 20)
        // 前のドラッグのドロップのセッションがここで終わる。
        first.endDropSession()
        XCTAssertNotNil(controller.reorderFingerY, "前のセッションの終わりで次のドラッグの指の位置を消しました")
        let start = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertLessThan(controller.collectionView.contentOffset.y, start, "上へ送っていません")
        second.end()
    }

    func test上端の帯の外では送らない() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("20"))
        let band = KsReorderTopAutoScroll.profile(
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        ).bandHeight
        driver.moveFinger(toViewY: safeTop + band + 20)
        let start = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, start, accuracy: 0.01)
        driver.end()
    }

    // 帯から一覧の外 (バーの上) へ出ると、控えた指の位置を捨てて送らない。一覧へ戻って帯の中の位置を
    // 知らせ直すと再開する。
    func test上端の帯から一覧の外へ出ると止まり帯へ戻ると再開する() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("20"))
        driver.moveFinger(toViewY: safeTop + 10)
        var before = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertLessThan(controller.collectionView.contentOffset.y, before, "帯の中で上へ送っていません")

        driver.exitList()
        before = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, before, accuracy: 0.01, "一覧の外へ出ても送っています")
        XCTAssertTrue(controller.isReorderAutoScrollRunning, "ドラッグの間は回し続けます")

        driver.moveFinger(toViewY: safeTop + 10)
        advancePastStartDelay(controller)
        XCTAssertLessThan(controller.collectionView.contentOffset.y, before, "帯へ戻っても再開していません")
        driver.end()
    }

    // 一覧の外で離すと、ドロップのセッションが終わった時点で送らなくなる (持ち上げた項目が戻る動きの間、
    // ドラッグのセッションはまだ続く)。
    func test上端の帯を通って一覧の外で離すとすぐ止まる() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("20"))
        driver.moveFinger(toViewY: safeTop + 10)
        driver.endDropSession()
        let before = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, before, accuracy: 0.01, "離した後も送っています")
        driver.end()
        XCTAssertFalse(controller.isReorderAutoScrollRunning)
        XCTAssertTrue(probe.moves.isEmpty)
    }

    // 帯の中で置いた後、ドラッグのセッションが終わるまで (置く動きの間) は送らない。
    func test上端の帯の中で置いた後は終わりの前でも送らない() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("20"))
        driver.moveFinger(toViewY: safeTop + 10)
        _ = driver.drop()
        let before = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, before, accuracy: 0.01, "置いた後も送っています")
        driver.end()
    }

    func test上端の自動スクロールはドラッグの終わりで止まり取りやめた間は送らない() async {
        let probe = KsReorderProbe()
        probe.accepts = false
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        let safeTop = controller.collectionView.safeAreaInsets.top
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        // 受け入れないで終わる。
        var rejected = KsReorderDriver(controller: controller)
        XCTAssertTrue(rejected.lift("20"))
        XCTAssertTrue(controller.isReorderAutoScrollRunning)
        rejected.move(over: path(0, 21))
        rejected.drop()
        rejected.end()
        XCTAssertFalse(controller.isReorderAutoScrollRunning, "ドラッグが終わっても回っています")
        // 元の並びへ戻し終えるまで待つ (戻し終えるまではドラッグ中の扱いで、次の持ち上げを受けない)。
        await Support.settle(controller)

        // 取りやめたドラッグでは、帯の中でも送らない。終わりで止まる。
        var cancelled = KsReorderDriver(controller: controller)
        XCTAssertTrue(cancelled.lift("20"))
        controller.update(configuration: Support.view(rows, probe: probe, isEnabled: false).configuration)
        cancelled.moveFinger(toViewY: safeTop + 20)
        let start = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, start, accuracy: 0.01)
        cancelled.end()
        XCTAssertFalse(controller.isReorderAutoScrollRunning)
    }

    func test安全領域の上が0の一覧では上端の自動スクロールを足さない() async {
        let probe = KsReorderProbe()
        let rows = (0..<60).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.showInsideSafeArea(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        XCTAssertEqual(controller.collectionView.safeAreaInsets.top, 0, accuracy: 0.5)
        KsPagingTestSupport.scroll(controller, to: 600)
        await Support.settle(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("20"))
        driver.moveFinger(toViewY: 20)
        let start = controller.collectionView.contentOffset.y
        advancePastStartDelay(controller)
        XCTAssertEqual(controller.collectionView.contentOffset.y, start, accuracy: 0.01)
        driver.end()
    }

    // MARK: - 置いたときの知らせ

    func test置いたときに1回だけ動かした項目と後ろの項目で知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        // B と C を越える (途中で項目が入れ替わっても知らせない)。
        driver.move(over: path(0, 1))
        driver.move(over: path(0, 2))
        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertEqual(driver.gap, path(0, 2))
        driver.drop()
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.count, 1)
        XCTAssertEqual(probe.moves.first?.item, rows[0])
        XCTAssertEqual(probe.moves.first?.destination, .before(rows[3]))
        XCTAssertNil(probe.moves.first?.group)
        XCTAssertEqual(Support.ids(controller), ["B", "C", "A", "D"])
    }

    func test最後に置くと末尾で知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 1))
        driver.move(over: path(0, 2))
        driver.drop()
        driver.end()

        XCTAssertEqual(probe.moves.map(\.destination), [.end])
    }

    // 持ち上げてから隙間が動く前に別の位置で離すと、UIKit は並べ替えとして扱わずに置く処理を呼ぶ。その位置で
    // 知らせを 1 回求め、受け入れたら置いた並びを当ててそこへ置く。
    func test隙間が動く前に離すと置く処理で知らせて受け入れたら置く() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        let coordinator = driver.dropBeforeGapMoves(at: path(0, 2))
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.map(Support.destinationDescription), ["before D"])
        XCTAssertEqual(Support.ids(controller), ["B", "C", "A", "D"])
        XCTAssertEqual(coordinator.droppedIndexPaths, [path(0, 2)])
        XCTAssertTrue(coordinator.droppedTargetCenters.isEmpty)
    }

    func test隙間が動く前に離して受け入れないと元の位置へ戻す() async {
        let probe = KsReorderProbe()
        probe.accepts = false
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        let coordinator = driver.dropBeforeGapMoves(at: path(0, 2))
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.count, 1)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"])
        XCTAssertTrue(coordinator.droppedIndexPaths.isEmpty)
        XCTAssertEqual(coordinator.droppedTargetCenters, [Support.center("A", in: controller)].compactMap { $0 })
    }

    func test隙間が動く前に置けない位置で離すと知らせない() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(
            Support.view(rows, probe: probe, groups: true, canDrop: { move in
                move.group == AnyHashable(move.item.group)
            })
        )
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        let coordinator = driver.dropBeforeGapMoves(at: path(1, 1))
        driver.end()
        await Support.settle(controller)

        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"])
        XCTAssertEqual(coordinator.droppedTargetCenters.count, 1)
    }

    func test元の位置に置くと知らせない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("B"))
        driver.move(over: path(0, 2))
        driver.move(over: path(0, 2))
        // 行き来して元の位置に戻る。
        XCTAssertEqual(driver.gap, path(0, 1))
        let coordinator = driver.drop()
        driver.end()

        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertTrue(coordinator.droppedIndexPaths.isEmpty)
        // 持ち上げた項目は元の位置へ動かして戻す (置いた場所で縮めて消さない)。
        XCTAssertEqual(coordinator.droppedTargetCenters, [Support.center("B", in: controller)].compactMap { $0 })
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"])
    }

    // MARK: - 並べ替えは一覧の中だけ

    func test別の一覧のセッションは受けずどちらの処理も呼ばれない() async {
        let probeP = KsReorderProbe()
        let probeQ = KsReorderProbe()
        let (listP, windowP) = await Support.show(Support.view(Support.rows(["A", "B"]), probe: probeP))
        defer { windowP.isHidden = true }
        let (listQ, windowQ) = await Support.show(Support.view(Support.rows(["X", "Y"]), probe: probeQ))
        defer { windowQ.isHidden = true }

        var driver = KsReorderDriver(controller: listP)
        XCTAssertTrue(driver.lift("A"))
        // P で持ち上げたセッションを Q が受けるか。
        XCTAssertFalse(listQ.reorderCanHandle(driver.dropSession))
        XCTAssertTrue(listP.reorderCanHandle(driver.dropSession))
        // 同じアプリの外から来たセッション (一覧の目印が無い) も受けない。
        XCTAssertFalse(listQ.reorderCanHandle(KsFakeDropSession(dragSession: nil)))
        // P の側では、Q の上にいる間は P へ提案が届かず、指を離しても置かれない。
        driver.end()

        XCTAssertTrue(probeP.moves.isEmpty)
        XCTAssertTrue(probeQ.moves.isEmpty)
        XCTAssertEqual(Support.ids(listP), ["A", "B"])
        XCTAssertEqual(Support.ids(listQ), ["X", "Y"])
    }

    // 置いた項目の絵には影を付けず、背景も足さない (置く動きの後に影が残らないようにする)。
    func test置く絵は影を付けず背景を足さない() async {
        let probe = KsReorderProbe()
        let (controller, window) = await Support.show(Support.view(Support.rows(["A", "B"]), probe: probe))
        defer { window.isHidden = true }

        let parameters = KsReorderDragDropDelegate().collectionView(
            controller.collectionView,
            dropPreviewParametersForItemAt: path(0, 0)
        )
        XCTAssertEqual(parameters?.shadowPath?.isEmpty, true)
        XCTAssertEqual(parameters?.backgroundColor, .clear)
        XCTAssertNil(parameters?.visiblePath, "置く絵の形はセル全体のまま")
    }

    func testドラッグの項目はアプリの外へ渡す中身を持たない() async {
        let probe = KsReorderProbe()
        let (controller, window) = await Support.show(Support.view(Support.rows(["A", "B"]), probe: probe))
        defer { window.isHidden = true }

        let session = KsFakeDragSession()
        let items = controller.reorderItemsForBeginning(session: session, at: path(0, 0))
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].itemProvider.registeredTypeIdentifiers.isEmpty)
        XCTAssertEqual(items[0].localObject as? AnyHashable, AnyHashable("A"))
        XCTAssertTrue((session.localContext as? KsReorderDragContext) === controller.reorderDragContext)
        XCTAssertTrue(
            KsReorderDragDropDelegate().collectionView(
                controller.collectionView,
                dragSessionIsRestrictedToDraggingApplication: session
            )
        )
    }

    // MARK: - 受け入れと元に戻す

    // UIKit が置いた位置へ並びを動かした後に受け入れないと、置いた位置から元の位置へ動かして戻す。
    func test受け入れないと置いた位置から元の並びへ戻る() async {
        let probe = KsReorderProbe()
        probe.accepts = false
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 1))
        driver.move(over: path(0, 2))
        let coordinator = driver.drop()
        XCTAssertEqual(coordinator.reorderedIndexPath, path(0, 2))
        XCTAssertEqual(probe.moves.count, 1)
        // 知らせの中では並びを当てず、ドロップのセッションが終わって (置いた項目の絵が消えて) から元の並びへ戻す。
        XCTAssertEqual(Support.ids(controller), ["B", "C", "A"])
        controller.reorderDragSessionDidEnd(driver.dragSession)
        await KsPagingTestSupport.yield()
        XCTAssertEqual(Support.ids(controller), ["B", "C", "A"], "ドロップのセッションが終わる前に戻しました")
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.count, 1)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C"])
        XCTAssertFalse(controller.isReorderDragging)
    }

    func test受け入れたら配列が届くまで置いた並びのままで同じ配列の描き直しでも戻らない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 1))
        let coordinator = driver.drop()
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(coordinator.reorderedIndexPath, path(0, 1))
        XCTAssertTrue(coordinator.droppedIndexPaths.isEmpty)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
        // 置いた時点と同じ配列のまま、ほかの状態の変化で描き直される。
        controller.update(configuration: Support.view(rows, probe: probe).configuration)
        await Support.settle(controller)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
        // 時間が経っても戻らない。
        await KsPagingTestSupport.yield()
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
        // VM が並べ替えた配列を渡しても位置は変わらない。
        controller.update(configuration: Support.view(Support.rows(["B", "A", "C"]), probe: probe).configuration)
        await Support.settle(controller)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
    }

    func test保存に失敗して元の並びの配列が渡されると元の並びに戻る() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(0, 1))
        driver.drop()
        driver.end()
        controller.update(configuration: Support.view(Support.rows(["B", "A", "C"]), probe: probe).configuration)
        await Support.settle(controller)
        controller.update(configuration: Support.view(rows, probe: probe).configuration)
        await Support.settle(controller)

        XCTAssertEqual(Support.ids(controller), ["A", "B", "C"])
    }

    // MARK: - グループをまたぐ移動

    func test別のグループの途中へ置くとそのグループの値で知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(1, 0))
        driver.move(over: path(1, 0))
        XCTAssertEqual(driver.gap, path(1, 1))
        driver.drop()
        driver.end()

        XCTAssertEqual(probe.moves.first?.destination, .before(rows[3]))
        XCTAssertEqual(probe.moves.first?.group, AnyHashable("Y"))
    }

    // セクションをまたいで後ろへ置いたとき、差分データソースが確定した位置が見せていた隙間とずれても、見せていた
    // 位置で知らせ、表示もその位置に揃える。揃えるまでの間のタップは、見えている項目を渡す。
    func test確定した位置が見せていた隙間とずれても見せていた位置で知らせて揃える() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D", "E"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true, tap: true))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        // 見せていた隙間は C と D の間、差分データソースは D と E の間で確定した。
        driver.dropWithMismatchedFinalPosition(shown: path(1, 1), final: path(1, 2))
        // 揃える前 (ドロップのセッションが終わる前) に、見えている A の行 (C の次) をタップする。
        XCTAssertEqual(controller.dataSource.itemIdentifier(for: path(1, 1))?.value, AnyHashable("D"))
        controller.collectionView(controller.collectionView, didSelectItemAt: path(1, 1))
        XCTAssertEqual(probe.taps, ["A"], "見えている項目と別の項目を渡しました")
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.map(Support.destinationDescription), ["before D"])
        XCTAssertEqual(probe.moves.first?.group, AnyHashable("Y"))
        XCTAssertEqual(Support.ids(controller), ["B", "C", "A", "D", "E"])
        XCTAssertEqual(Support.sections(controller), [["B"], ["C", "A", "D", "E"]])
    }

    // 受け入れたドラッグのドロップのセッションが終わる前に次のドラッグを始め、前のセッションの終わりが次の
    // ドラッグの間に届いても、次のドラッグの戻しは次のドラッグのセッションが終わるまで待つ。
    func test前のドロップのセッションの終わりは次のドラッグに入らない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C", "D"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var first = KsReorderDriver(controller: controller)
        XCTAssertTrue(first.lift("A"))
        first.move(over: path(0, 1))
        first.drop()
        controller.reorderDragSessionDidEnd(first.dragSession)
        await Support.settle(controller)
        XCTAssertFalse(controller.isReorderDragging)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C", "D"])

        probe.accepts = false
        var second = KsReorderDriver(controller: controller)
        XCTAssertTrue(second.lift("C"))
        second.move(over: path(0, 3))
        second.drop()
        controller.reorderDragSessionDidEnd(second.dragSession)
        // 前のドラッグのドロップのセッションがここで終わる。
        first.endDropSession()
        await KsPagingTestSupport.yield()
        XCTAssertEqual(Support.ids(controller), ["B", "A", "D", "C"], "前のセッションの終わりで次のドラッグの並びを戻しました")
        XCTAssertTrue(controller.isReorderDragging)
        second.endDropSession()
        await Support.settle(controller)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C", "D"])
        XCTAssertFalse(controller.isReorderDragging)
    }

    // iOS では見出しとグループの間の間隔の上 (提案が nil) では隙間が直前の位置を保つ。
    // 下から運んで見出しの上で離すと次のグループの先頭、前のグループの最後の項目の上を通ってから下げると
    // 前のグループの末尾になる。
    func test見出しの上では直前の隙間の位置で知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true))
        defer { window.isHidden = true }

        // D を C の上へ運び、そのまま見出しの上 (提案 nil) で離す → C の前・Y。
        var below = KsReorderDriver(controller: controller)
        XCTAssertTrue(below.lift("D"))
        below.move(over: path(1, 0))
        below.move(over: nil)
        XCTAssertEqual(below.gap, path(1, 0))
        below.drop()
        below.end()
        XCTAssertEqual(probe.moves.last?.destination, .before(rows[2]))
        XCTAssertEqual(probe.moves.last?.group, AnyHashable("Y"))

        // 知らせを受け入れた並び (D が C の前) で、今度は D を B の上へ運び、もう一度 B の上へ動かして
        // (隙間が B の後ろへ移る)、見出しの上で離す → 末尾・X。
        await Support.settle(controller)
        controller.update(
            configuration: Support.view(Support.grouped([("X", ["A", "B"]), ("Y", ["D", "C"])]), probe: probe, groups: true)
                .configuration
        )
        await Support.settle(controller)
        var above = KsReorderDriver(controller: controller)
        XCTAssertTrue(above.lift("D"))
        above.move(over: path(0, 1))
        above.move(over: path(0, 1))
        above.move(over: nil)
        XCTAssertEqual(above.gap, path(0, 2))
        above.drop()
        above.end()
        XCTAssertEqual(probe.moves.last?.destination, .end)
        XCTAssertEqual(probe.moves.last?.group, AnyHashable("X"))
    }

    func test見出しの無いグループでも隙間の位置のグループで知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true, headers: false))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("D"))
        driver.move(over: path(0, 1))
        driver.move(over: path(0, 1))
        // グループの間の間隔の上 (提案 nil) で離す。
        driver.move(over: nil)
        driver.drop()
        driver.end()

        XCTAssertEqual(probe.moves.first?.destination, .end)
        XCTAssertEqual(probe.moves.first?.group, AnyHashable("X"))
    }

    func test最後の1件をドラッグしている間も見出しは残り受け入れると消える() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A"]), ("Y", ["B", "C"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(1, 0))
        driver.move(over: path(1, 0))
        // ドラッグの間はセクション (と見出し) を変えない。
        XCTAssertEqual(Support.sections(controller), [["A"], ["B", "C"]])
        driver.drop()
        driver.end()
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.first?.destination, .before(rows[2]))
        XCTAssertEqual(Support.sections(controller), [["B", "A", "C"]])
        XCTAssertEqual(controller.appliedSectionIdentifiers.map(\.group), [AnyHashable("Y")])
        let headers = controller.collectionView.indexPathsForVisibleSupplementaryElements(ofKind: KsSupplementaryKind.groupHeader)
        XCTAssertEqual(headers.count, 1)
        // VM が A のグループの値を Y に書き換えた配列を渡しても X は出ない。
        controller.update(
            configuration: Support.view(Support.grouped([("Y", ["B", "A", "C"])]), probe: probe, groups: true).configuration
        )
        await Support.settle(controller)
        XCTAssertEqual(controller.appliedSectionIdentifiers.map(\.group), [AnyHashable("Y")])
    }

    func testドラッグ中にもとのグループへ戻して置ける() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A"]), ("Y", ["B", "C"])])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, groups: true))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(1, 0))
        XCTAssertEqual(driver.gap, path(1, 0))
        // 空になった X の見出しの上から、隙間を X へ戻す (提案は X の元の位置 = 持ち上げた項目の位置)。
        driver.drop(at: path(0, 0))
        driver.end()
        XCTAssertTrue(probe.moves.isEmpty, "元のグループの元の位置に戻したのに知らせました")
    }

    // MARK: - 動かせるかと置けるかの判定

    func test動かせない項目は持ち上がらない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(
            Support.view(rows, probe: probe, canMove: { $0.id != "B" })
        )
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertFalse(driver.lift("B"))
        var other = KsReorderDriver(controller: controller)
        XCTAssertTrue(other.lift("A"))
        other.end()
    }

    func test置けない行き先では隙間を空けず離しても知らせない() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(
            Support.view(rows, probe: probe, groups: true, canDrop: { move in
                move.group == AnyHashable(move.item.group)
            })
        )
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        // Y の中へ動かす: 見える隙間になる位置で判定し、置けないので断る。
        XCTAssertEqual(driver.move(over: path(1, 0)).operation, .forbidden)
        XCTAssertEqual(driver.gap, path(0, 0), "置けない位置に隙間が動きました")
        // 断った提案は持ち越され、項目の無い所へ動いてもその位置で判定される。
        XCTAssertEqual(driver.move(over: nil).operation, .forbidden)
        XCTAssertEqual(driver.gap, path(0, 0))
        // X の中へ戻すと置ける。
        XCTAssertEqual(driver.move(over: path(0, 1)).operation, .move)
        XCTAssertEqual(driver.gap, path(0, 1))
        // 置けない位置で離しても知らせない (UIKit が置けない位置へ並べ替えた場合も含む)。UIKit が動かした並びは
        // 元の並びへ戻す。
        let coordinator = driver.drop(at: path(1, 1))
        driver.end()
        XCTAssertEqual(coordinator.reorderedIndexPath, path(1, 1))
        XCTAssertTrue(probe.moves.isEmpty)
        await Support.settle(controller)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"], "置けない位置で離したのに元の並びへ戻していません")
        XCTAssertFalse(controller.isReorderDragging)
    }

    func test判定には知らせと同じ形の行き先が渡る() async {
        let probe = KsReorderProbe()
        var candidates: [String] = []
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(
            Support.view(rows, probe: probe, groups: true, canDrop: { move in
                candidates.append("\(move.item.id) \(Support.destinationDescription(move)) \(move.group?.base as? String ?? "-")")
                return true
            })
        )
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.move(over: path(1, 0))
        driver.move(over: path(1, 0))
        XCTAssertEqual(candidates, ["A before C Y", "A before D Y"])
        driver.end()
    }

    // MARK: - 読み上げの移動操作

    private func visibleCell(_ id: String, in controller: KsCollectionViewController<KsReorderRow>) -> KsHostingCell? {
        guard let indexPath = Support.indexPath(id, in: controller) else { return nil }
        return controller.collectionView.cellForItem(at: indexPath) as? KsHostingCell
    }

    private func actionNames(_ id: String, in controller: KsCollectionViewController<KsReorderRow>) -> [String] {
        visibleCell(id, in: controller)?.reorderAccessibility.actions.map(\.name) ?? []
    }

    private let texts = KsReorderAccessibilityActions(previous: "前へ移動", next: "後ろへ移動")

    func test操作で1つ後ろへ動かすと後ろの後ろの項目の前で知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, accessibility: texts))
        defer { window.isHidden = true }

        XCTAssertEqual(actionNames("A", in: controller), ["後ろへ移動"])
        XCTAssertTrue(controller.performReorderAccessibilityMove(identifier: AnyHashable("A"), direction: .next))
        await Support.settle(controller)

        XCTAssertEqual(probe.moves.count, 1)
        XCTAssertEqual(probe.moves.first?.item, rows[0])
        XCTAssertEqual(probe.moves.first?.destination, .before(rows[2]))
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
    }

    func testグループの先頭の前へ移動は前のグループの末尾で知らせる() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(
            Support.view(rows, probe: probe, groups: true, accessibility: texts)
        )
        defer { window.isHidden = true }

        XCTAssertTrue(controller.performReorderAccessibilityMove(identifier: AnyHashable("C"), direction: .previous))
        XCTAssertEqual(probe.moves.first?.destination, .end)
        XCTAssertEqual(probe.moves.first?.group, AnyHashable("X"))
    }

    func test操作はスイッチが無効の間と動かせない項目と端と置けない行き先には出ない() async {
        let probe = KsReorderProbe()
        let rows = Support.grouped([("X", ["A", "B"]), ("Y", ["C", "D"])])
        let (controller, window) = await Support.show(
            Support.view(
                rows,
                probe: probe,
                groups: true,
                canMove: { $0.id != "B" },
                canDrop: { move in move.group == AnyHashable(move.item.group) },
                accessibility: texts
            )
        )
        defer { window.isHidden = true }

        // 一覧の先頭の A には前へ移動が無い。
        XCTAssertEqual(actionNames("A", in: controller), ["後ろへ移動"])
        // 動かせない B には無い。
        XCTAssertEqual(actionNames("B", in: controller), [])
        // C の前へ移動は X の末尾 (置けない) なので無い。
        XCTAssertEqual(actionNames("C", in: controller), ["後ろへ移動"])
        // 一覧の最後の D には後ろへ移動が無い。
        XCTAssertEqual(actionNames("D", in: controller), ["前へ移動"])

        controller.update(
            configuration: Support.view(rows, probe: probe, isEnabled: false, groups: true, accessibility: texts)
                .configuration
        )
        await Support.settle(controller)
        for id in ["A", "B", "C", "D"] {
            XCTAssertEqual(actionNames(id, in: controller), [], "スイッチが無効なのに \(id) に操作があります")
        }
        XCTAssertFalse(controller.performReorderAccessibilityMove(identifier: AnyHashable("A"), direction: .next))
        XCTAssertTrue(probe.moves.isEmpty)
    }

    func test文言を渡さなければ操作を出さない() async {
        let probe = KsReorderProbe()
        let (controller, window) = await Support.show(Support.view(Support.rows(["A", "B"]), probe: probe))
        defer { window.isHidden = true }

        XCTAssertEqual(actionNames("A", in: controller), [])
        XCTAssertEqual(actionNames("B", in: controller), [])
    }

    // 読み上げの部品は並べ替えを付けて文言を渡した構成でだけ中身に付ける。表示に入る項目ごとに組み立てが走るため、
    // 使わない一覧には付けない。スイッチが無効の間は付けたまま操作を空にする。
    func test並べ替えを付けていない一覧と文言を渡さない一覧の中身には読み上げの部品を付けない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let plain = KsCollectionView(rows, layout: .list) { row in
            Text(row.id).frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        }
        let cases: [(String, KsCollectionView<KsReorderRow>, Bool)] = [
            ("並べ替えを付けていない一覧", plain, false),
            ("文言を渡さない一覧", Support.view(rows, probe: probe), false),
            ("スイッチが無効で文言を渡した一覧", Support.view(rows, probe: probe, isEnabled: false, accessibility: texts), true),
            ("スイッチが有効で文言を渡した一覧", Support.view(rows, probe: probe, accessibility: texts), true),
        ]
        for (label, view, attached) in cases {
            let (controller, window) = await Support.show(view)
            for id in ["A", "B", "C"] {
                XCTAssertEqual(
                    visibleCell(id, in: controller)?.hasReorderAccessibilityContent,
                    attached,
                    "\(label) の \(id) の部品の有無が違います"
                )
            }
            window.isHidden = true
        }
    }

    func test文言を後から渡すと表示中の項目に部品を付けて操作を出す() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }
        XCTAssertEqual(visibleCell("A", in: controller)?.hasReorderAccessibilityContent, false)

        controller.update(configuration: Support.view(rows, probe: probe, accessibility: texts).configuration)
        await Support.settle(controller)
        for id in ["A", "B", "C"] {
            XCTAssertEqual(visibleCell(id, in: controller)?.hasReorderAccessibilityContent, true, "\(id) に部品が付いていません")
        }
        XCTAssertEqual(actionNames("B", in: controller), ["後ろへ移動", "前へ移動"])

        // 文言を外すと部品も外す。
        controller.update(configuration: Support.view(rows, probe: probe).configuration)
        await Support.settle(controller)
        for id in ["A", "B", "C"] {
            XCTAssertEqual(visibleCell(id, in: controller)?.hasReorderAccessibilityContent, false, "\(id) に部品が残っています")
            XCTAssertEqual(actionNames(id, in: controller), [])
        }
    }

    // 操作は中身を作る前に入れるので、作った後に操作が入れ替わって作ったばかりの中身が描き直されることはない。
    func testスクロールで表示に入る項目は中身を作った後に操作を入れ替えない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows((0..<200).map { "R\($0)" })
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, accessibility: texts))
        defer { window.isHidden = true }

        let collectionView: UICollectionView = controller.collectionView
        var checkedCells = 0
        for step in 1...30 {
            collectionView.contentOffset.y = CGFloat(step) * 200
            collectionView.layoutIfNeeded()
            for case let cell as KsHostingCell in collectionView.visibleCells {
                checkedCells += 1
                XCTAssertTrue(cell.hasReorderAccessibilityContent)
                XCTAssertFalse(cell.reorderAccessibility.actions.isEmpty, "動かせる項目に操作がありません")
                XCTAssertEqual(
                    cell.reorderAccessibility.actionsChangeCount,
                    cell.reorderAccessibilityChangeCountAtContentApply,
                    "中身を作った後に操作が入れ替わりました (オフセット \(collectionView.contentOffset.y))"
                )
            }
        }
        XCTAssertGreaterThan(checkedCells, 0)
    }

    func test操作で受け入れなければ動かさない() async {
        let probe = KsReorderProbe()
        probe.accepts = false
        let (controller, window) = await Support.show(
            Support.view(Support.rows(["A", "B", "C"]), probe: probe, accessibility: texts)
        )
        defer { window.isHidden = true }

        XCTAssertFalse(controller.performReorderAccessibilityMove(identifier: AnyHashable("A"), direction: .next))
        await Support.settle(controller)
        XCTAssertEqual(probe.moves.count, 1)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C"])
    }

    // MARK: - ドラッグ中に届いた配列

    func testドラッグ中の配列は指を離すまで当たらない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        let changed = [KsReorderRow(id: "A"), KsReorderRow(id: "B", group: "変更"), KsReorderRow(id: "C")]
        controller.update(configuration: Support.view(changed, probe: probe).configuration)
        XCTAssertEqual(controller.configuration.items, rows, "ドラッグ中に配列を当てました")
        driver.end()
        await Support.settle(controller)
        XCTAssertEqual(controller.configuration.items, changed)
    }

    func test受け入れたら控えた配列を捨てて置いた並びのまま待つ() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        // 並べ替えを含まない配列 (B の中身だけ違う) が届いて控えられる。
        let held = [KsReorderRow(id: "A"), KsReorderRow(id: "B", group: "変更"), KsReorderRow(id: "C")]
        controller.update(configuration: Support.view(held, probe: probe).configuration)
        driver.move(over: path(0, 1))
        driver.drop()
        driver.end()
        await Support.settle(controller)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"], "控えた配列の並びに戻りました")
        // 同じ配列の描き直しでも待ち続ける。
        controller.update(configuration: Support.view(held, probe: probe).configuration)
        await Support.settle(controller)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
        // VM が並べ替えを含む配列を渡すと、その並びと中身になる。
        let reordered = [KsReorderRow(id: "B", group: "変更"), KsReorderRow(id: "A"), KsReorderRow(id: "C")]
        controller.update(configuration: Support.view(reordered, probe: probe).configuration)
        await Support.settle(controller)
        XCTAssertEqual(controller.configuration.items, reordered)
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"])
    }

    func test受け入れなければ元の位置に戻してから最新の配列を当てる() async {
        let probe = KsReorderProbe()
        probe.accepts = false
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        controller.update(configuration: Support.view(Support.rows(["A", "B", "C", "D"]), probe: probe).configuration)
        driver.move(over: path(0, 1))
        driver.drop()
        // ドラッグのセッションが終わっても、UIKit が動かした並びを元の並びへ戻すまで (ドロップのセッションの
        // 終わりまで) は控えた配列を当てない。
        controller.reorderDragSessionDidEnd(driver.dragSession)
        await KsPagingTestSupport.yield()
        XCTAssertEqual(Support.ids(controller), ["B", "A", "C"], "元の並びへ戻す前に配列を当てました")
        driver.endDropSession()
        await KsPagingTestSupport.waitForItems(4, in: controller)
        XCTAssertEqual(Support.ids(controller), ["A", "B", "C", "D"])
    }

    func testドラッグ中の項目が消えた配列を控えて受け入れなければ元に戻してから消える() async {
        let probe = KsReorderProbe()
        probe.accepts = false
        let rows = Support.rows(["A", "B", "C"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe))
        defer { window.isHidden = true }

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("B"))
        controller.update(configuration: Support.view(Support.rows(["A", "C"]), probe: probe).configuration)
        driver.move(over: path(0, 2))
        driver.drop()
        controller.reorderDragSessionDidEnd(driver.dragSession)
        await KsPagingTestSupport.yield()
        XCTAssertEqual(Support.ids(controller), ["A", "C", "B"], "元の並びへ戻す前に配列を当てました")
        driver.endDropSession()
        await KsPagingTestSupport.waitForItems(2, in: controller)
        XCTAssertEqual(Support.ids(controller), ["A", "C"])
    }

    // MARK: - ドラッグ中のページングとスクロール命令

    func testドラッグ中は次のページを頼まず終わった後に判定し直す() async {
        let probe = KsReorderProbe()
        let paging = KsPagingProbe()
        let rows = (0..<30).map { KsReorderRow(id: "\($0)") }
        let view = Support.view(rows, probe: probe).paging(.idle, threshold: 0, onLoadMore: paging.loadMoreAction)
        let (controller, window) = await Support.show(view)
        defer { window.isHidden = true }
        XCTAssertEqual(paging.loadMoreCount, 0)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("0"))
        // 端での自動スクロールで末尾の近くまで運ぶ。
        await KsPagingTestSupport.scrollToBottom(controller)
        await KsPagingTestSupport.yield()
        XCTAssertEqual(paging.loadMoreCount, 0, "ドラッグ中に次のページを頼みました")
        driver.end()
        await KsPagingTestSupport.waitUntil("次ページ要求", value: { paging.loadMoreCount }) { $0 == 1 }
    }

    func testドラッグ中のスクロール命令は配列を当てた後に実行する() async {
        let probe = KsReorderProbe()
        let scroll = KsScrollController()
        let rows = (0..<40).map { KsReorderRow(id: "\($0)") }
        let (controller, window) = await Support.show(Support.view(rows, probe: probe).scrollController(scroll))
        defer { window.isHidden = true }
        await KsPagingTestSupport.scrollToBottom(controller)

        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("39"))
        let before = controller.processedCommandCount
        scroll.scrollToStart(animated: false)
        await KsPagingTestSupport.yield()
        XCTAssertEqual(controller.processedCommandCount, before, "ドラッグ中にスクロール命令を実行しました")
        XCTAssertGreaterThan(controller.collectionView.contentOffset.y, 100)
        driver.end()
        await KsPagingTestSupport.waitUntil("スクロール命令の実行", value: { controller.processedCommandCount }) {
            $0 == before + 1
        }
        XCTAssertLessThan(abs(controller.collectionView.contentOffset.y + controller.collectionView.adjustedContentInset.top), 1)
    }

    // ドラッグの間に控えた配列を終わった後に当てるときも、端の留め方は差し替えの直前の (ドラッグの前に当てていた)
    // ページングの状態で決まる。終端まで読み込んだ一覧で末尾を表示中に末尾へ足された項目は、末尾に留めて見せる。
    func testドラッグの後に控えた配列を当てるとき直前のページングの状態で末尾に留める() async {
        for (state, keepsBottom) in [(KsPagingState.endReached, true), (.idle, false)] {
            let probe = KsReorderProbe()
            probe.accepts = false
            let rows = (0..<30).map { KsReorderRow(id: "\($0)") }
            let view = { (rows: [KsReorderRow]) in
                Support.view(rows, probe: probe).paging(state, threshold: 0, onLoadMore: {})
            }
            let (controller, window) = await Support.show(view(rows))
            await KsPagingTestSupport.scrollToBottom(controller)

            var driver = KsReorderDriver(controller: controller)
            XCTAssertTrue(driver.lift("29"))
            controller.update(configuration: view(rows + [KsReorderRow(id: "30")]).configuration)
            driver.end()
            await KsPagingTestSupport.waitForItems(31, in: controller)
            await KsPagingTestSupport.settleLayout(controller)

            let bottom = KsPagingTestSupport.bottomOffset(in: controller)
            let atBottom = abs(controller.collectionView.contentOffset.y - bottom) < 1
            XCTAssertEqual(atBottom, keepsBottom, "状態 \(state) で末尾に留めるかが違います")
            window.isHidden = true
        }
    }

    // MARK: - 長押しとタップ

    func test並べ替えが有効な間は長押しの知らせを呼ばない() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B"])
        let (controller, window) = await Support.show(
            Support.view(rows, probe: probe, canMove: { $0.id != "B" }, longTap: true)
        )
        defer { window.isHidden = true }

        XCTAssertEqual(controller.longPressRecognizer?.isEnabled, false)
        controller.performLongPress(at: path(0, 0))
        controller.performLongPress(at: path(0, 1))
        XCTAssertTrue(probe.longTaps.isEmpty)
        var driver = KsReorderDriver(controller: controller)
        XCTAssertTrue(driver.lift("A"))
        driver.end()
    }

    func test並べ替えが有効な間もタップの知らせは呼ぶ() async {
        let probe = KsReorderProbe()
        let (controller, window) = await Support.show(
            Support.view(Support.rows(["A", "B"]), probe: probe, tap: true)
        )
        defer { window.isHidden = true }

        controller.collectionView(controller.collectionView, didSelectItemAt: path(0, 1))
        XCTAssertEqual(probe.taps, ["B"])
        XCTAssertTrue(controller.handlesItemTouch)
    }

    func test長押しの知らせだけを宣言した一覧は並べ替えが有効な間タップしても強調しない() async {
        let probe = KsReorderProbe()
        let (controller, window) = await Support.show(
            Support.view(Support.rows(["A", "B"]), probe: probe, longTap: true)
        )
        defer { window.isHidden = true }

        XCTAssertFalse(controller.handlesItemTouch)
        XCTAssertFalse(controller.collectionView(controller.collectionView, shouldHighlightItemAt: path(0, 0)))
        controller.collectionView(controller.collectionView, didSelectItemAt: path(0, 0))
        XCTAssertTrue(probe.taps.isEmpty)
        XCTAssertTrue(probe.longTaps.isEmpty)
    }

    func testスイッチを無効に戻すと長押しの知らせが戻る() async {
        let probe = KsReorderProbe()
        let rows = Support.rows(["A", "B"])
        let (controller, window) = await Support.show(Support.view(rows, probe: probe, longTap: true))
        defer { window.isHidden = true }

        controller.update(configuration: Support.view(rows, probe: probe, isEnabled: false, longTap: true).configuration)
        XCTAssertEqual(controller.longPressRecognizer?.isEnabled, true)
        XCTAssertTrue(controller.handlesItemTouch)
        controller.performLongPress(at: path(0, 1))
        XCTAssertEqual(probe.longTaps, ["B"])
    }
}
#endif
