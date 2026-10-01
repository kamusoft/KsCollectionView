#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

// 並べ替えの結合テストが共有する部品。UIKit のドラッグ & ドロップはテストから合成できないため、
// ドラッグ・ドロップのセッションと置く処理の受け手を偽物で作り、一覧が受ける呼び出しを直接渡す。
// 置いたときは UIKit と同じく、並べ替えとして隙間の位置へ並びを動かす場合 (差分データソースの並びを動かして
// から確定を知らせる) と、置く処理を呼ぶ場合 (元の位置・取りやめ・隙間を空けない提案) に分ける。

// 並べ替えの試験に使う項目。
struct KsReorderRow: Identifiable, Equatable {
    let id: String
    var group: String = ""
}

// 置いたときの知らせを数え、受け入れるかを試験の側で決める。
@MainActor
final class KsReorderProbe {
    private(set) var moves: [KsReorderMove<KsReorderRow>] = []
    private(set) var longTaps: [String] = []
    private(set) var taps: [String] = []
    var accepts = true

    func onMove(_ move: KsReorderMove<KsReorderRow>) -> Bool {
        moves.append(move)
        return accepts
    }

    func longTap(_ row: KsReorderRow) {
        longTaps.append(row.id)
    }

    func tap(_ row: KsReorderRow) {
        taps.append(row.id)
    }
}

// ドラッグのセッションの偽物。
final class KsFakeDragSession: NSObject, UIDragSession {
    var items: [UIDragItem] = []
    var localContext: Any?
    var location: CGPoint = .zero
    var allowsMoveOperation: Bool { true }
    var isRestrictedToDraggingApplication: Bool { true }

    func location(in view: UIView) -> CGPoint {
        location
    }

    func hasItemsConforming(toTypeIdentifiers typeIdentifiers: [String]) -> Bool {
        false
    }

    func canLoadObjects(ofClass aClass: any NSItemProviderReading.Type) -> Bool {
        false
    }
}

// ドロップのセッションの偽物。`localDragSession` にドラッグのセッションを持たせる。
final class KsFakeDropSession: NSObject, UIDropSession {
    let dragSession: KsFakeDragSession?
    var location: CGPoint = .zero
    var progressIndicatorStyle: UIDropSessionProgressIndicatorStyle = .none
    let progress = Progress()

    init(dragSession: KsFakeDragSession?) {
        self.dragSession = dragSession
    }

    var localDragSession: (any UIDragSession)? { dragSession }
    var items: [UIDragItem] { dragSession?.items ?? [] }
    var allowsMoveOperation: Bool { true }
    var isRestrictedToDraggingApplication: Bool { true }

    func location(in view: UIView) -> CGPoint {
        location
    }

    func hasItemsConforming(toTypeIdentifiers typeIdentifiers: [String]) -> Bool {
        false
    }

    func canLoadObjects(ofClass aClass: any NSItemProviderReading.Type) -> Bool {
        false
    }

    func loadObjects(
        ofClass aClass: any NSItemProviderReading.Type,
        completion: @escaping ([any NSItemProviderReading]) -> Void
    ) -> Progress {
        Progress()
    }
}

// 置いた項目の動きの偽物。
final class KsFakeDragAnimating: NSObject, UIDragAnimating {
    func addAnimations(_ animations: @escaping () -> Void) {}
    func addCompletion(_ completion: @escaping (UIViewAnimatingPosition) -> Void) {}
}

final class KsFakeDropItem: NSObject, UICollectionViewDropItem {
    let dragItem: UIDragItem
    let sourceIndexPath: IndexPath?
    var previewSize: CGSize { .zero }

    init(dragItem: UIDragItem, sourceIndexPath: IndexPath?) {
        self.dragItem = dragItem
        self.sourceIndexPath = sourceIndexPath
    }
}

// 置く処理の受け手の偽物。一覧が項目を置いた位置を記録する。
final class KsFakeDropCoordinator: NSObject, UICollectionViewDropCoordinator {
    let items: [any UICollectionViewDropItem]
    let destinationIndexPath: IndexPath?
    let proposal: UICollectionViewDropProposal
    let session: any UIDropSession
    private(set) var droppedIndexPaths: [IndexPath] = []
    // 項目の位置ではなく行き先の点へ置いた (持ち上げた項目を戻した) ときの点。
    private(set) var droppedTargetCenters: [CGPoint] = []
    // UIKit が並べ替えとして並びを動かした位置。このときは置く処理は呼ばれず、この受け手は一覧へ渡さない。
    var reorderedIndexPath: IndexPath?

    init(
        items: [any UICollectionViewDropItem],
        destinationIndexPath: IndexPath?,
        proposal: UICollectionViewDropProposal,
        session: any UIDropSession
    ) {
        self.items = items
        self.destinationIndexPath = destinationIndexPath
        self.proposal = proposal
        self.session = session
    }

    func drop(_ dragItem: UIDragItem, toItemAt indexPath: IndexPath) -> any UIDragAnimating {
        droppedIndexPaths.append(indexPath)
        return KsFakeDragAnimating()
    }

    func drop(
        _ dragItem: UIDragItem,
        to placeholder: UICollectionViewDropPlaceholder
    ) -> any UICollectionViewDropPlaceholderContext {
        fatalError("並べ替えでは使いません")
    }

    func drop(_ dragItem: UIDragItem, intoItemAt indexPath: IndexPath, rect: CGRect) -> any UIDragAnimating {
        KsFakeDragAnimating()
    }

    func drop(_ dragItem: UIDragItem, to target: UIDragPreviewTarget) -> any UIDragAnimating {
        droppedTargetCenters.append(target.center)
        return KsFakeDragAnimating()
    }
}

// 一覧 1 つ分のドラッグの操作。持ち上げ・動かす・置く・終わるの順に、UIKit が一覧へ渡す呼び出しを渡す。
@MainActor
struct KsReorderDriver {
    let controller: KsCollectionViewController<KsReorderRow>
    let dragSession = KsFakeDragSession()
    let dropSession: KsFakeDropSession
    private(set) var sourceIndexPath: IndexPath?
    private var step: CGFloat = 0
    // 最後に一覧が返した置き先の提案。
    private(set) var lastProposal: UICollectionViewDropProposal?

    init(controller: KsCollectionViewController<KsReorderRow>) {
        self.controller = controller
        dropSession = KsFakeDropSession(dragSession: dragSession)
    }

    /// 項目を持ち上げ、指を動かし始める (ドラッグのセッションが始まる)。持ち上がらなければ false。
    mutating func lift(_ id: String) -> Bool {
        guard liftOnly(id) else { return false }
        beginMoving()
        return true
    }

    /// 項目を持ち上げるだけで、指はまだ動かさない。持ち上がらなければ false。
    mutating func liftOnly(_ id: String) -> Bool {
        guard let indexPath = controller.dataSource.indexPath(for: KsItemIdentifier(AnyHashable(id))) else {
            return false
        }
        let items = controller.reorderItemsForBeginning(session: dragSession, at: indexPath)
        guard !items.isEmpty else { return false }
        dragSession.items = items
        sourceIndexPath = indexPath
        return true
    }

    /// 持ち上げた後に指を動かし始める (UIKit はここでドラッグのセッションを始める)。
    func beginMoving() {
        controller.reorderDragSessionWillBegin(dragSession)
    }

    /// 指を一覧の枠の上端から画面に対して `y` の位置へ動かす。指の下にセルが無い所 (提案 nil) として渡す。
    @discardableResult
    mutating func moveFinger(toViewY y: CGFloat) -> UICollectionViewDropProposal {
        let offset = controller.collectionView.contentOffset.y
        dropSession.location = CGPoint(x: 10, y: y + offset)
        let result = controller.reorderDropProposal(for: dropSession, destinationIndexPath: nil)
        lastProposal = result
        return result
    }

    /// 指を動かして、UIKit の提案 (指の下のセルの位置。無ければ nil) を渡す。指の位置は呼ぶたびに変える。
    @discardableResult
    mutating func move(over proposal: IndexPath?) -> UICollectionViewDropProposal {
        step += 1
        dropSession.location = CGPoint(x: 10, y: step)
        let result = controller.reorderDropProposal(for: dropSession, destinationIndexPath: proposal)
        lastProposal = result
        // UIKit は受けた提案に合わせて隙間を動かし、レイアウトに動いた先を知らせる。
        if result.operation == .move, let gap = controller.reorderDrag?.gapTracker.gap {
            controller.reorderGapDidMove(to: [gap])
        }
        return result
    }

    /// 今見えている隙間の位置。
    var gap: IndexPath? {
        controller.reorderDrag?.gapTracker.gap
    }

    /// 見えている隙間の位置で指を離す。置く処理の受け手を返す。
    ///
    /// 最後の提案が隙間を空ける提案で、置く位置が元の位置と違い、ドラッグを取りやめていなければ、UIKit と同じく
    /// 並べ替えとして差分データソースの並びを動かしてから確定を知らせる (置く処理は呼ばない。受け手には
    /// 動かした位置だけを記録する)。それ以外は置く処理を呼ぶ。
    @discardableResult
    func drop(at destination: IndexPath? = nil) -> KsFakeDropCoordinator {
        let dragItem = dragSession.items.first ?? UIDragItem(itemProvider: NSItemProvider())
        let destination = destination ?? gap
        let coordinator = KsFakeDropCoordinator(
            items: [KsFakeDropItem(dragItem: dragItem, sourceIndexPath: sourceIndexPath)],
            destinationIndexPath: destination,
            proposal: UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath),
            session: dropSession
        )
        if
            let destination,
            let sourceIndexPath,
            destination != sourceIndexPath,
            lastProposal?.operation == .move,
            lastProposal?.intent == .insertAtDestinationIndexPath,
            controller.reorderDrag?.isCancelled == false {
            // UIKit は見せている隙間の位置へ置く。置く位置を渡されたときは、その位置に隙間を見せていたことにする。
            controller.reorderGapDidMove(to: [destination])
            moveItemAsCollectionView(from: sourceIndexPath, to: destination)
            coordinator.reorderedIndexPath = destination
            controller.reorderDidReorder(movingTo: destination)
            return coordinator
        }
        controller.reorderPerformDrop(with: coordinator)
        return coordinator
    }

    /// 持ち上げてから隙間が動く前に (指を止めずに) `destination` で指を離す。UIKit は並べ替えとして扱わずに
    /// 置く処理を呼ぶ (差分データソースの並びは動かさない)。置く処理の受け手を返す。
    @discardableResult
    func dropBeforeGapMoves(at destination: IndexPath) -> KsFakeDropCoordinator {
        let dragItem = dragSession.items.first ?? UIDragItem(itemProvider: NSItemProvider())
        let coordinator = KsFakeDropCoordinator(
            items: [KsFakeDropItem(dragItem: dragItem, sourceIndexPath: sourceIndexPath)],
            destinationIndexPath: destination,
            proposal: UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath),
            session: dropSession
        )
        controller.reorderPerformDrop(with: coordinator)
        return coordinator
    }

    /// UIKit が `shown` に隙間を見せて置いたのに、差分データソースが `final` の位置で並びを確定した場合を作る
    /// (セクションをまたいで後ろへ動かしたときに観測した食い違い)。
    func dropWithMismatchedFinalPosition(shown: IndexPath, final: IndexPath) {
        guard let sourceIndexPath else { return }
        controller.reorderGapDidMove(to: [shown])
        moveItemAsCollectionView(from: sourceIndexPath, to: final)
        controller.reorderDidReorder(movingTo: final)
    }

    /// UIKit が並べ替えで行うのと同じく、差分データソースの並びの中で項目を動かす。`destination` は、動かした
    /// 項目を元の位置から抜いた並びでの位置。
    private func moveItemAsCollectionView(from source: IndexPath, to destination: IndexPath) {
        var snapshot = controller.dataSource.snapshot()
        let sourceSection = snapshot.sectionIdentifiers[source.section]
        let identifier = snapshot.itemIdentifiers(inSection: sourceSection)[source.item]
        snapshot.deleteItems([identifier])
        let destinationSection = snapshot.sectionIdentifiers[destination.section]
        let items = snapshot.itemIdentifiers(inSection: destinationSection)
        if destination.item < items.count {
            snapshot.insertItems([identifier], beforeItem: items[destination.item])
        } else {
            snapshot.appendItems([identifier], toSection: destinationSection)
        }
        controller.dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// 指が一覧の外へ出た (UIKit は一覧へ提案を求めるのをやめる)。
    func exitList() {
        controller.reorderDropSessionDidExit(dropSession)
    }

    /// ドロップのセッションが終わった (置いた後、または一覧の外で離した後。戻る動きはまだ続く)。
    func endDropSession() {
        controller.reorderDropSessionDidEnd(dropSession)
    }

    /// ドラッグのセッションが終わった (置いた・取りやめた後の元の位置へ戻る動きの後)。UIKit と同じく、続けて
    /// ドロップのセッションも終わる (置いた項目の絵が消える)。
    func end() {
        controller.reorderDragSessionDidEnd(dragSession)
        controller.reorderDropSessionDidEnd(dropSession)
    }
}

@MainActor
enum KsReorderTestSupport {
    static let size = CGSize(width: 390, height: 844)

    static func rows(_ ids: [String], group: String = "") -> [KsReorderRow] {
        ids.map { KsReorderRow(id: $0, group: group) }
    }

    // グループ (値, 項目の ID の並び) の列から配列を作る。
    static func grouped(_ groups: [(String, [String])]) -> [KsReorderRow] {
        groups.flatMap { group, ids in ids.map { KsReorderRow(id: $0, group: group) } }
    }

    static func view(
        _ rows: [KsReorderRow],
        probe: KsReorderProbe,
        isEnabled: Bool = true,
        groups: Bool = false,
        headers: Bool = true,
        layout: KsCollectionLayout = .list,
        canMove: ((KsReorderRow) -> Bool)? = nil,
        canDrop: ((KsReorderMove<KsReorderRow>) -> Bool)? = nil,
        accessibility: KsReorderAccessibilityActions? = nil,
        longTap: Bool = false,
        tap: Bool = false
    ) -> KsCollectionView<KsReorderRow> {
        var view = KsCollectionView(rows, layout: layout) { row in
            Text(row.id).frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        }
        .reorder(
            isEnabled: isEnabled,
            canMove: canMove,
            canDrop: canDrop,
            accessibilityActions: accessibility,
            onMove: { probe.onMove($0) }
        )
        if longTap {
            view = view.onItemLongTap { probe.longTap($0) }
        }
        if tap {
            view = view.onItemTap { probe.tap($0) }
        }
        guard groups else { return view }
        if headers {
            return view.groups(by: \.group) { group, _ in
                Text(group).frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
            }
        }
        return view.groups(by: \.group)
    }

    // ウインドウの安全領域の内側に載せる (一覧は安全領域に重ならない普通の置き方)。
    static func showInsideSafeArea(
        _ view: KsCollectionView<KsReorderRow>
    ) async -> (KsCollectionViewController<KsReorderRow>, UIWindow) {
        let controller = KsCollectionViewController(configuration: view.configuration)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
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
            width: size.width,
            height: size.height - safeArea.top - safeArea.bottom
        )
        root.view.addSubview(controller.view)
        controller.didMove(toParent: root)
        controller.view.layoutIfNeeded()
        await KsPagingTestSupport.waitForItems(view.configuration.items.count, in: controller)
        await settle(controller)
        return (controller, window)
    }

    static func show(_ view: KsCollectionView<KsReorderRow>) async -> (KsCollectionViewController<KsReorderRow>, UIWindow) {
        let controller = KsCollectionViewController(configuration: view.configuration)
        let window = KsPagingTestSupport.show(controller, size: size)
        await KsPagingTestSupport.waitForItems(view.configuration.items.count, in: controller)
        await settle(controller)
        return (controller, window)
    }

    // 差分の適用が終わり、レイアウトが確定するまで待つ。
    static func settle(_ controller: KsCollectionViewController<KsReorderRow>) async {
        await KsPagingTestSupport.waitUntil("差分の適用の完了", value: { controller.isApplyingSnapshot }) { !$0 }
        controller.collectionView.layoutIfNeeded()
    }

    static func ids(_ controller: KsCollectionViewController<KsReorderRow>) -> [String] {
        controller.appliedItemIdentifiers.compactMap { $0.base as? String }
    }

    // 塊のセクションごとの項目の ID。
    static func sections(_ controller: KsCollectionViewController<KsReorderRow>) -> [[String]] {
        let snapshot = controller.dataSource.snapshot()
        return snapshot.sectionIdentifiers.map { section in
            snapshot.itemIdentifiers(inSection: section).compactMap { $0.value.base as? String }
        }
    }

    static func indexPath(
        _ id: String,
        in controller: KsCollectionViewController<KsReorderRow>
    ) -> IndexPath? {
        controller.dataSource.indexPath(for: KsItemIdentifier(AnyHashable(id)))
    }

    // 項目の中心 (一覧の内容の座標)。
    static func center(
        _ id: String,
        in controller: KsCollectionViewController<KsReorderRow>
    ) -> CGPoint? {
        guard let indexPath = indexPath(id, in: controller) else { return nil }
        return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.center
    }

    static func destinationDescription(_ move: KsReorderMove<KsReorderRow>) -> String {
        switch move.destination {
        case let .before(row):
            "before \(row.id)"
        case .end:
            "end"
        }
    }
}
#endif
