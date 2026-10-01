import UIKit

// 並べ替えのドラッグ & ドロップ (ios/ADR-0011)。
//
// UIKit 標準のドラッグ & ドロップの delegate と、差分データソースの並べ替えハンドラで作る。一覧は
// reorder-capable な置き先になり、置いた位置への移動は UIKit が確定する (置く動きと、隙間が動く速さ
// `reorderingCadence` が UIKit 標準の並べ替えと同じになる)。確定した後に知らせを求め、受け入れたら置いた
// 並びのまま配列を待ち、受け入れなければドロップのセッションが終わってから元の並びへ動かして戻す
// (core/ADR-0026、core/ADR-0027)。元の位置・取りやめたドラッグ・隙間が動く前に指を離したときは、UIKit は
// 並びを動かさず置く処理 (performDropWith) を呼ぶ。元の位置と取りやめでは持ち上げた項目を元の位置へ動かして
// 戻し、隙間が動く前に別の位置で離したときは、その位置で知らせを求めて置く。
// 持ち上げ・置く先の隙間・置けない場所の見え方・下端の自動スクロールは UIKit に任せる。上端の自動スクロールは、
// 一覧をバーの裏まで広げた置き方で UIKit の反応の帯がバーの裏に入るため、指が一覧の中の帯にある間だけ
// ライブラリが足す (KsReorderTopAutoScroll)。ドラッグ中の行き先 (内部の塊のセクションとその中の番号) は、
// 配列の並びとグループの区切りから求める行き先に読み替える (core/ADR-0028)。
extension KsCollectionViewController: KsReorderInteractionOwner {
    // 適用済みの並びとグループの区切りで行き先を求める部品。
    // ドラッグ中は何度も引くため、並びか塊の表が変わるまで控えを使う。
    var reorderPlanner: KsReorderPlanner {
        if let cached = reorderPlannerCache {
            return cached
        }
        let planner = KsReorderPlanner(
            identifiers: appliedIdentifiers.map(\.value),
            groups: appliedChunkTable.groups.map { KsReorderGroupSpan(value: $0.value, itemRange: $0.itemRange) }
        )
        reorderPlannerCache = planner
        return planner
    }

    // 行き先を、利用者へ渡す知らせに読み替える。項目は配列の要素そのもの (解決済みの要素) を渡す。
    func reorderMove(
        moving source: Int,
        to placement: KsReorderPlacement,
        planner: KsReorderPlanner
    ) -> KsReorderMove<Item>? {
        guard
            planner.identifiers.indices.contains(source),
            planner.groups.indices.contains(placement.groupIndex),
            let item = itemsByID[planner.identifiers[source]]
        else {
            return nil
        }
        let destination: KsReorderDestination<Item>
        switch placement.target {
        case let .before(identifier):
            guard let target = itemsByID[identifier] else { return nil }
            destination = .before(target)
        case .end:
            destination = .end
        }
        return KsReorderMove(item: item, destination: destination, group: planner.groups[placement.groupIndex].value)
    }

    // UIKit の行き先 (塊のセクションとその中の番号) を行き先に読み替える。UIKit の番号は、動かした項目を
    // 元の位置から抜いたうえで入れる位置を表すため、動かした項目を除いてグループの先頭から数え直す。
    func reorderPlacement(
        forDestination indexPath: IndexPath,
        moving source: Int,
        planner: KsReorderPlanner
    ) -> KsReorderPlacement? {
        let table = appliedChunkTable
        guard let chunk = table.chunk(at: indexPath.section) else { return nil }
        let group = table.groups[chunk.groupIndex]
        var position = 0
        for section in group.sectionRange.lowerBound..<indexPath.section {
            let range = table.sectionItemRanges[section]
            position += range.count - (range.contains(source) ? 1 : 0)
        }
        position += max(0, indexPath.item)
        return planner.placement(moving: source, toGroup: chunk.groupIndex, at: position)
    }

    // 行き先に置けるか。元の位置はいつでも戻せるため判定しない。判定を渡していなければ置ける (core/ADR-0030)。
    func canDropReorder(_ placement: KsReorderPlacement, moving source: Int, planner: KsReorderPlanner) -> Bool {
        guard placement != planner.originalPlacement(of: source) else { return true }
        guard let canDrop = configuration.reorder?.canDrop else { return true }
        guard let move = reorderMove(moving: source, to: placement, planner: planner) else { return false }
        return canDrop(move)
    }

    // ドラッグ中の項目の配列の位置。
    private var reorderSourceIndex: Int? {
        guard let identifier = reorderDrag?.identifier else { return nil }
        return appliedIdentifiers.firstIndex(of: KsItemIdentifier(identifier))
    }

    // この一覧で始めた並べ替えのセッションか。同じアプリの別の一覧から来たセッションは受けない。
    private func isOwnReorderSession(_ session: UIDropSession) -> Bool {
        (session.localDragSession?.localContext as? KsReorderDragContext) === reorderDragContext
    }

    // MARK: - ドラッグ

    // 持ち上げ。スイッチが無効の間と、動かせない項目は持ち上げない (core/ADR-0030、core/ADR-0031)。
    // ドラッグの項目はアプリの外へ渡す中身を持たず、アプリの中だけの目印 (項目の識別子) を持つ。
    func reorderItemsForBeginning(session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard
            configuration.isReorderEnabled,
            !isReorderDragging,
            let identifier = dataSource.itemIdentifier(for: indexPath)?.value,
            let item = itemsByID[identifier]
        else {
            return []
        }
        if let canMove = configuration.reorder?.canMove, !canMove(item) {
            return []
        }
        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = identifier
        session.localContext = reorderDragContext
        // 持ち上げた時点の構成を控える。指を動かし始めた時点で比べる (beginReorderDrag)。
        reorderLiftConfiguration = configuration
        return [dragItem]
    }

    func reorderDragSessionWillBegin(_ session: UIDragSession) {
        guard let identifier = session.items.first?.localObject as? AnyHashable else { return }
        beginReorderDrag(identifier: identifier)
        reorderDrag?.dragSession = ObjectIdentifier(session as AnyObject)
    }

    func reorderDragSessionDidEnd(_ session: UIDragSession) {
        endReorderDrag()
    }

    // MARK: - ドロップ

    func reorderCanHandle(_ session: UIDropSession) -> Bool {
        isOwnReorderSession(session)
    }

    // ドラッグ中。行き先に置けなければ禁止、置けるなら置く先に隙間を空ける。
    func reorderDropProposal(
        for session: UIDropSession,
        destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard isOwnReorderSession(session), let drag = reorderDrag else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // 上端の自動スクロールの判定に使う、画面に対しての指の位置。
        reorderFingerY = session.location(in: collectionView).y - collectionView.contentOffset.y
        // 取りやめたドラッグは、隙間を空けない提案にする。UIKit は空けていた隙間を閉じ、指を離すと
        // 置く処理が呼ばれるので、置いた場合と同じく持ち上げた項目を元の位置へ動かして戻す。
        guard !drag.isCancelled, configuration.isReorderEnabled else {
            return UICollectionViewDropProposal(operation: .move, intent: .unspecified)
        }
        guard let source = reorderSourceIndex else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // 提案の位置ではなく、この提案を受けたときに見える隙間の位置で置けるかを判定する
        // (見えている隙間と判定を一致させる)。
        let gap = reorderDrag?.gapTracker.candidate(
            for: destinationIndexPath,
            at: session.location(in: collectionView),
            itemCount: { [collectionView] in collectionView?.numberOfItems(inSection: $0) ?? 0 }
        ) ?? drag.gapTracker.gap
        let planner = reorderPlanner
        guard
            let placement = reorderPlacement(forDestination: gap, moving: source, planner: planner),
            canDropReorder(placement, moving: source, planner: planner)
        else {
            reorderDrag?.gapTracker.refuse()
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        reorderDrag?.gapTracker.accept(gap)
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    // UIKit が並びを動かさずに置く処理を呼んだとき。元の位置に置いたとき・取りやめたドラッグでは、知らせずに
    // 終え、持ち上げた項目を元の位置へ動かして戻す。持ち上げてから隙間が動く前に (指を止めずに) 別の位置で
    // 離したときも UIKit は並べ替えとして扱わずにここを呼ぶため、その位置で置いたときの処理を 1 回呼び、
    // 受け入れたら置いた並びを当てて項目をそこへ置く (core/ADR-0026、core/ADR-0027)。受け入れなければ置かずに、
    // 元の位置へ動かして戻す。
    func reorderPerformDrop(with coordinator: UICollectionViewDropCoordinator) {
        // 置く動き・戻る動きの間は上端の自動スクロールで送らない。
        reorderFingerY = nil
        guard let drag = reorderDrag, let dropItem = coordinator.items.first else { return }
        guard acceptDrop(from: coordinator, drag: drag) else {
            returnDraggedItemToSource(dropItem.dragItem, with: coordinator, drag: drag)
            return
        }
        guard let indexPath = dataSource.indexPath(for: KsItemIdentifier(drag.identifier)) else { return }
        coordinator.drop(dropItem.dragItem, toItemAt: indexPath)
    }

    // UIKit が置いた位置へ項目を動かし、差分データソースの並びを確定した (置いた位置が元の位置と違うとき)。
    // `finalIndexPath` は差分データソースが確定した並びでの項目の位置。
    //
    // 行き先は、UIKit が見せていた隙間 (レイアウトが知らせた位置) から求める。セクションをまたいで後ろへ動かすと、
    // 差分データソースが確定した位置が見せていた隙間より 1 つ後ろになる (iOS 18.6・26.5 で観測。見た目は隙間の
    // 位置に置かれ、データソースの並びとセルの中身が食い違う)。その場合は、結果を当てる直前に差分データソースの
    // 並びを見せていた並びへ揃える。
    //
    // 行き先の知らせを求めて置いたときの処理を 1 回呼び、受け入れたら置いた並びと塊の表を当てる (次の周回)。
    // 知らせない場合 (取りやめ・置けない行き先) と受け入れなかった場合は、ドロップのセッションが終わるのを
    // 待ってから、元の並びへ動かして戻す。並びを揃える場合も、セッションが終わってから揃える。UIKit は置いた項目の
    // 絵をセッションが終わるまで置いた位置に残し、動かした項目のセルを隠すため、その前に戻すと項目が置いた位置に
    // 止まったまま元の位置に現れる。当て終わるまではドラッグ中の扱いを続ける (控えた配列・溜めたスクロール命令・
    // 次ページ要求の判定は、当て終わった後に行う)。
    func reorderDidReorder(movingTo finalIndexPath: IndexPath) {
        reorderFingerY = nil
        guard let drag = reorderDrag else { return }
        reorderDrag?.isResolving = true
        let destination = drag.shownGap
        let alignment = destination != finalIndexPath
            ? (identifier: KsItemIdentifier(drag.identifier), indexPath: destination)
            : nil
        // 揃えるまでの間、項目の位置から項目を引く処理 (タップ・読み上げの操作) は見せている並びで引く。
        if let alignment {
            reorderDrag?.shownSnapshot = alignedReorderSnapshot(moving: alignment.identifier, to: alignment.indexPath)
        }
        let finish: () -> Void = { [weak self] in
            self?.finishReorderResolution()
        }
        guard
            !drag.isCancelled,
            let reorder = configuration.reorder,
            reorder.isEnabled,
            let source = reorderSourceIndex
        else {
            revertReorderedSnapshot(aligning: alignment, completion: finish)
            return
        }
        let planner = reorderPlanner
        guard
            let placement = reorderPlacement(forDestination: destination, moving: source, planner: planner),
            placement != planner.originalPlacement(of: source),
            canDropReorder(placement, moving: source, planner: planner),
            let move = reorderMove(moving: source, to: placement, planner: planner)
        else {
            revertReorderedSnapshot(aligning: alignment, completion: finish)
            return
        }
        // 受け入れた時点に届いていた最新の配列 (acceptDrop と同じ)。
        let latestItems = deferredConfiguration?.items ?? reorderAwaitedItems ?? configuration.items
        guard reorder.onMove(move) else {
            revertReorderedSnapshot(aligning: alignment, completion: finish)
            return
        }
        applyAcceptedReorder(
            moving: source,
            to: placement,
            planner: planner,
            latestItems: latestItems,
            destinationSection: destination.section,
            snapshotTiming: alignment == nil ? .nextRunLoop : .afterDropSession,
            aligning: alignment,
            completion: finish
        )
    }

    // ドロップのセッションが終わった後に行う処理を控える。すでに終わっていれば次の周回で行う。
    func runAfterReorderDropSession(_ work: @escaping () -> Void) {
        guard let drag = reorderDrag, !drag.hasDropSessionEnded else {
            DispatchQueue.main.async(execute: work)
            return
        }
        reorderDrag?.workAfterDropSession.append(work)
    }

    // 置いた結果を表示に当て終えた。ドラッグのセッションが先に終わっていれば、ここでドラッグを終える。
    private func finishReorderResolution() {
        guard reorderDrag?.isResolving == true else { return }
        reorderDrag?.isResolving = false
        if reorderDrag?.isSessionEnded == true {
            endReorderDrag()
        }
    }

    // 指が一覧の外へ出たら、上端の自動スクロールを止める。一覧へ戻って指の位置が控え直されたら再開する。
    func reorderDropSessionDidExit(_ session: UIDropSession) {
        reorderFingerY = nil
    }

    // ドロップのセッションが終わったら (一覧の外で離した場合を含む)、戻る動きの間は送らない。UIKit が並べ替えで
    // 置いた後なら、置いた項目の絵が消えるのはこの時点なので、控えていた処理 (受け入れなかった並びの戻しなど) を
    // ここで行う。前のドラッグのドロップのセッションの終わりが次のドラッグの間に届いた場合は、次のドラッグの
    // 状態 (指の位置を含む) に入れない。
    func reorderDropSessionDidEnd(_ session: UIDropSession) {
        if let own = reorderDrag?.dragSession,
           let ended = session.localDragSession,
           ObjectIdentifier(ended as AnyObject) != own {
            return
        }
        reorderFingerY = nil
        guard reorderDrag != nil else { return }
        reorderDrag?.hasDropSessionEnded = true
        let works = reorderDrag?.workAfterDropSession ?? []
        reorderDrag?.workAfterDropSession = []
        works.forEach { $0() }
    }

    // 置いた位置の知らせを求めて置いたときの処理を呼び、受け入れたら置いた並びを当てる。知らせない場合
    // (取りやめ・元の位置・置けない場所) と、受け入れなかった場合は false。
    private func acceptDrop(from coordinator: UICollectionViewDropCoordinator, drag: KsReorderDrag) -> Bool {
        guard
            !drag.isCancelled,
            let reorder = configuration.reorder,
            reorder.isEnabled,
            let destinationIndexPath = coordinator.destinationIndexPath,
            let source = reorderSourceIndex
        else {
            return false
        }
        let planner = reorderPlanner
        guard
            let placement = reorderPlacement(forDestination: destinationIndexPath, moving: source, planner: planner),
            placement != planner.originalPlacement(of: source),
            canDropReorder(placement, moving: source, planner: planner),
            let move = reorderMove(moving: source, to: placement, planner: planner)
        else {
            return false
        }
        // 受け入れた時点に届いていた最新の配列。ドラッグ中に控えた構成があればその配列、前の並べ替えの配列を
        // 待っている間ならその待っている配列 (表示している並びは受け入れた並びで、届いた配列ではないため)。
        let latestItems = deferredConfiguration?.items ?? reorderAwaitedItems ?? configuration.items
        guard reorder.onMove(move) else { return false }
        applyAcceptedReorder(moving: source, to: placement, planner: planner, latestItems: latestItems)
        return true
    }

    // 置かずに終えるとき、持ち上げた項目を元の位置へ動かして戻す。何もせずに返すと、UIKit は置いた場所で
    // 縮めて消す既定の置き方にし、一覧の元の位置の項目と 2 つ同時に見える。配列は変えないので、元の位置の
    // 中心 (持ち上げたときに控えた位置) を行き先にする。元の位置のセルは戻る動きが終わるまで隠し、動いている
    // 項目と 2 つ同時に見せない。
    private func returnDraggedItemToSource(
        _ dragItem: UIDragItem,
        with coordinator: UICollectionViewDropCoordinator,
        drag: KsReorderDrag
    ) {
        guard let center = drag.sourceCenter else { return }
        let animator = coordinator.drop(dragItem, to: UIDragPreviewTarget(container: collectionView, center: center))
        guard let layout = compositionalLayout, let indexPath = dataSource.indexPath(for: KsItemIdentifier(drag.identifier)) else {
            return
        }
        // セルの見え方は UIKit がレイアウトの属性で当て直すため、セルではなくレイアウトの側で隠す。
        layout.hiddenItemIndexPath = indexPath
        layout.invalidateLayout()
        animator.addCompletion { [weak self, weak layout] _ in
            guard let layout, layout.hiddenItemIndexPath == indexPath else { return }
            layout.hiddenItemIndexPath = nil
            layout.invalidateLayout()
            self?.collectionView.layoutIfNeeded()
        }
    }

    // MARK: - 読み上げの移動操作

    // セルの中身に出す「前へ / 後ろへ移動」の操作を付け直す (core/ADR-0032)。スイッチが有効で文言が渡され、
    // 動かせる項目の、行き先があって置ける向きにだけ出す。並び・スイッチ・判定が変わるたびに世代が進み、
    // 表示中のセルと、これから表示に入るセルで求め直す。
    func updateReorderAccessibility(of cell: KsHostingCell, at indexPath: IndexPath) {
        guard
            let reorder = configuration.reorder,
            reorder.isEnabled,
            let texts = reorder.accessibilityActions,
            let identifier = shownItemIdentifier(at: indexPath)?.value,
            appliedChunkTable.sectionItemRanges.indices.contains(indexPath.section)
        else {
            cell.reorderAccessibility.clear()
            return
        }
        let generation = reorderAccessibilityGeneration
        guard cell.reorderAccessibility.needsUpdate(generation: generation, identifier: identifier) else { return }
        let source = appliedChunkTable.sectionItemRanges[indexPath.section].lowerBound + indexPath.item
        // SwiftUI の要素には付けた順の逆に並ぶため、「後ろへ」を先に付けて「前へ」「後ろへ」の順に出す。
        let directions: [(KsReorderAccessibilityAction.Direction, String)] = [
            (.next, texts.next),
            (.previous, texts.previous),
        ]
        let actions = directions.compactMap { direction, name -> KsReorderAccessibilityAction? in
            guard reorderAccessibilityPlacement(moving: source, direction: direction) != nil else { return nil }
            return KsReorderAccessibilityAction(direction: direction, name: name) { [weak self] in
                self?.performReorderAccessibilityMove(identifier: identifier, direction: direction)
            }
        }
        cell.reorderAccessibility.update(actions, generation: generation, identifier: identifier)
    }

    // 読み上げの操作で動かす先。スイッチが無効・ドラッグ中・動かせない項目・行き先の無い端 (一覧の先頭の
    // 前・最後の後ろ)・置けない行き先では nil。
    func reorderAccessibilityPlacement(
        moving source: Int,
        direction: KsReorderAccessibilityAction.Direction
    ) -> KsReorderPlacement? {
        guard
            let reorder = configuration.reorder,
            reorder.isEnabled,
            !isReorderDragging,
            appliedIdentifiers.indices.contains(source),
            let item = itemsByID[appliedIdentifiers[source].value],
            reorder.canMove?(item) ?? true
        else {
            return nil
        }
        let planner = reorderPlanner
        let placement: KsReorderPlacement?
        switch direction {
        case .previous:
            placement = planner.previousPlacement(of: source)
        case .next:
            placement = planner.nextPlacement(of: source)
        }
        guard let placement, canDropReorder(placement, moving: source, planner: planner) else { return nil }
        return placement
    }

    // 読み上げの操作で 1 つ前 / 後ろへ動かす。ドラッグと同じく置いたときの処理を 1 回呼び、受け入れたら
    // 動かして配列を待ち、受け入れなければ動かさない。動かした後は読み上げの焦点を動かした項目に残す。
    @discardableResult
    func performReorderAccessibilityMove(
        identifier: AnyHashable,
        direction: KsReorderAccessibilityAction.Direction
    ) -> Bool {
        guard
            let reorder = configuration.reorder,
            let source = appliedIdentifiers.firstIndex(of: KsItemIdentifier(identifier)),
            let placement = reorderAccessibilityPlacement(moving: source, direction: direction)
        else {
            return false
        }
        let planner = reorderPlanner
        guard let move = reorderMove(moving: source, to: placement, planner: planner) else { return false }
        let latestItems = reorderAwaitedItems ?? configuration.items
        guard reorder.onMove(move) else { return false }
        applyAcceptedReorder(moving: source, to: placement, planner: planner, latestItems: latestItems) { [weak self] in
            guard
                let self,
                let indexPath = dataSource.indexPath(for: KsItemIdentifier(identifier)),
                let cell = collectionView.cellForItem(at: indexPath)
            else {
                return
            }
            UIAccessibility.post(notification: .layoutChanged, argument: cell)
        }
        return true
    }
}
