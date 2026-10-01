import UIKit

// 一覧のドラッグ & ドロップの delegate。受けた呼び出しを一覧 (`KsReorderInteractionOwner`) へ渡し、
// 並べ替えに共通の決まり (1 項目ずつ動かす・アプリの外へ持ち出させない) だけをここで持つ。
@MainActor
internal final class KsReorderDragDropDelegate: NSObject, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    weak var owner: (any KsReorderInteractionOwner)?

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        owner?.reorderItemsForBeginning(session: session, at: indexPath) ?? []
    }

    // 並べ替えは 1 項目ずつ動かす。ドラッグ中にほかの項目を足させない。
    func collectionView(
        _ collectionView: UICollectionView,
        itemsForAddingTo session: UIDragSession,
        at indexPath: IndexPath,
        point: CGPoint
    ) -> [UIDragItem] {
        []
    }

    // iPad でもアプリの外へは持ち出させない (並べ替えは一覧の中だけ)。
    func collectionView(
        _ collectionView: UICollectionView,
        dragSessionIsRestrictedToDraggingApplication session: UIDragSession
    ) -> Bool {
        true
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
        owner?.reorderDragSessionWillBegin(session)
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        owner?.reorderDragSessionDidEnd(session)
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        owner?.reorderCanHandle(session) ?? false
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        owner?.reorderDropProposal(for: session, destinationIndexPath: destinationIndexPath)
            ?? UICollectionViewDropProposal(operation: .cancel)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        owner?.reorderPerformDrop(with: coordinator)
    }

    // 置いた項目の絵に影を付けない。UIKit は置く動きで持ち上げたときの影を薄れさせるが、行の中身に不透明な
    // 背景があると薄れずにドロップのセッションの終わり (置いてから約 0.9 秒) まで残ることがある (iOS 18.6 で
    // グループと読み上げの移動操作を付けた一覧、26.5 では UIKit 標準の並べ替えでも同じ行で観測)。置く絵の影の
    // 形を空にすると、置く動きで持ち上げた絵 (影付き) と影の無い置く先の絵が入れ替わる間に、影が途切れずに薄れる。
    // 形は既定 (セル全体) のまま。背景は透明にして、絵に背景を足さない。
    // 並べ替え (reorder-capable) で置くときにも呼ばれる (観測)。
    func collectionView(
        _ collectionView: UICollectionView,
        dropPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.shadowPath = UIBezierPath()
        return parameters
    }

    // 指が一覧の外へ出た。一覧へ戻れば、また dropSessionDidUpdate が呼ばれる。
    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        owner?.reorderDropSessionDidExit(session)
    }

    // ドロップのセッションが終わった (一覧の外で離した場合を含む)。持ち上げた項目が戻る動きの間は、
    // ドラッグのセッションの終わり (dragSessionDidEnd) より先に呼ばれる。
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        owner?.reorderDropSessionDidEnd(session)
    }
}
