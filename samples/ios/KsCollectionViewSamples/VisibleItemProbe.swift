@_spi(KsMeasurement) import KsCollectionView
import UIKit

/// 画面に表示中の項目を、操作したときにだけ UIKit のビュー階層から読み取る。
///
/// コレクションの公開 API は表示中の項目を知らせないため、Sample の操作 (表示中の項目を動かす) の
/// ためにここで読む。セルごとの表示・非表示を追いかけると、操作しないときにもスクロールの仕事が
/// 増えるため、読むのはボタンを押したときの 1 回だけにする。
///
/// 対象のコレクションは、``VisibleItemProbeAnchor`` をコレクションの背景に置き、同じ枠を持つ
/// `UICollectionView` として探す。
@MainActor
final class VisibleItemProbe {
    /// コレクションと同じ枠に置いた目印のビュー。
    weak var anchor: UIView?

    /// 表示中の項目の通し番号 (先頭を 0 とする) を昇順で返す。見つからなければ空。
    func visibleItemOffsets() -> [Int] {
        guard let anchor, let window = anchor.window else { return [] }
        let anchorFrame = anchor.convert(anchor.bounds, to: window)
        guard let collectionView = Self.collectionViews(in: window).first(where: {
            // bounds の原点はスクロール量なので、bounds を変換すると画面上の枠になる。
            Self.isSameFrame($0.convert($0.bounds, to: window), anchorFrame)
        }) else { return [] }
        return collectionView.indexPathsForVisibleItems
            .compactMap { KsItemOffsetLookup.itemOffset(of: $0, in: collectionView) }
            .sorted()
    }

    private static func isSameFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 1 && abs(lhs.minY - rhs.minY) < 1
            && abs(lhs.width - rhs.width) < 1 && abs(lhs.height - rhs.height) < 1
    }

    private static func collectionViews(in view: UIView) -> [UICollectionView] {
        var found: [UICollectionView] = []
        if let collectionView = view as? UICollectionView {
            found.append(collectionView)
        }
        for subview in view.subviews {
            found += collectionViews(in: subview)
        }
        return found
    }
}
