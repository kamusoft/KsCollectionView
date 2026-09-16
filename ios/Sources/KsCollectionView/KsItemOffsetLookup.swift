#if canImport(UIKit)
import UIKit

// 計測の入口のうち、この 1 本だけは Release 構成にも載せる。スクロール性能とメモリの計測は
// Release で組んだ Sample を走らせて採るため、通過件数の数え方を debug 構成に閉じると
// 計測そのものが成立しない。塊の件数・塊の順番といった内部の分け方は internal のままで、
// ここから読めるのは「画面に載っている項目の通し番号」だけにとどめる。
// 逆写像と総件数はテストからしか使わないため internal に置く。

/// 画面に載っている項目を、先頭を 0 とする通し番号で数えるための入口です。
///
/// - Important: 計測・検証のための入口であり、通常の利用者向けの API ではありません。
///   使うには専用の指定を付けて読み込む必要があります。
@_spi(KsMeasurement)
@MainActor
public enum KsItemOffsetLookup {
    /// `IndexPath` を通し番号へ変換します。
    ///
    /// - Returns: 通し番号。指し先に項目が無いときは `nil`
    @_spi(KsMeasurement)
    public static func itemOffset(
        of indexPath: IndexPath,
        in collectionView: UICollectionView
    ) -> Int? {
        guard
            indexPath.section >= 0,
            indexPath.section < collectionView.numberOfSections,
            indexPath.item >= 0,
            indexPath.item < collectionView.numberOfItems(inSection: indexPath.section)
        else {
            return nil
        }
        let precedingCount = (0..<indexPath.section).reduce(0) {
            $0 + collectionView.numberOfItems(inSection: $1)
        }
        return precedingCount + indexPath.item
    }

    /// 通し番号から `IndexPath` を求める。`itemOffset(of:in:)` の逆写像。
    ///
    /// - Returns: 位置。その番号の項目が載っていないときは `nil`
    internal static func indexPath(
        forItemOffset offset: Int,
        in collectionView: UICollectionView
    ) -> IndexPath? {
        guard offset >= 0 else { return nil }
        var remaining = offset
        for section in 0..<collectionView.numberOfSections {
            let count = collectionView.numberOfItems(inSection: section)
            if remaining < count {
                return IndexPath(item: remaining, section: section)
            }
            remaining -= count
        }
        return nil
    }

    /// セクションをまたいで載っている項目の総数。
    internal static func totalItemCount(in collectionView: UICollectionView) -> Int {
        (0..<collectionView.numberOfSections).reduce(0) {
            $0 + collectionView.numberOfItems(inSection: $1)
        }
    }
}
#endif
