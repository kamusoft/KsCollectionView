import UIKit

// 並べ替えのドラッグ & ドロップを受け持つ一覧。型引数を持つ一覧は Objective-C の delegate に
// 直接なれないため、`KsReorderDragDropDelegate` が受けた呼び出しをこの形で一覧へ渡す。
@MainActor
internal protocol KsReorderInteractionOwner: AnyObject {
    func reorderItemsForBeginning(session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
    func reorderDragSessionWillBegin(_ session: UIDragSession)
    func reorderDragSessionDidEnd(_ session: UIDragSession)
    func reorderCanHandle(_ session: UIDropSession) -> Bool
    func reorderDropProposal(
        for session: UIDropSession,
        destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal
    func reorderPerformDrop(with coordinator: UICollectionViewDropCoordinator)
    func reorderDropSessionDidExit(_ session: UIDropSession)
    func reorderDropSessionDidEnd(_ session: UIDropSession)
}
