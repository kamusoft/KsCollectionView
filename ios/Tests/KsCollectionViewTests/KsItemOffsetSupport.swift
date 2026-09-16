#if canImport(UIKit)
import UIKit
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

// エンジンは配列を内部の塊に分けて載せるため、indexPath の item は塊ごとに 0 から始まる。
// テストが指す「先頭から数えて N 番目の項目」は塊をまたいだ通し番号 (全体の順番) であり、
// item へそのまま渡すことはできない。変換の規則そのものは本体の `KsItemOffsetLookup` が持ち、
// ここではテストから使いやすい形 (失敗の報告を伴う版) だけを足す。

// 全体の順番から indexPath を求める。範囲外なら失敗として報告する。
@MainActor
func ksIndexPath(
    forItemOffset offset: Int,
    in collectionView: UICollectionView,
    file: StaticString = #filePath,
    line: UInt = #line
) -> IndexPath {
    guard let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: collectionView) else {
        XCTFail("全体の順番 \(offset) に対応する項目がありません", file: file, line: line)
        return IndexPath(item: offset, section: 0)
    }
    return indexPath
}

// 全体の順番から indexPath を求める。範囲外なら nil を返す。
@MainActor
func ksIndexPathIfPresent(
    forItemOffset offset: Int,
    in collectionView: UICollectionView
) -> IndexPath? {
    KsItemOffsetLookup.indexPath(forItemOffset: offset, in: collectionView)
}

// indexPath から全体の順番を求める。`ksIndexPathIfPresent(forItemOffset:in:)` の逆写像。
@MainActor
func ksItemOffset(for indexPath: IndexPath, in collectionView: UICollectionView) -> Int? {
    KsItemOffsetLookup.itemOffset(of: indexPath, in: collectionView)
}

// 塊をまたいだ総件数。
@MainActor
func ksTotalItemCount(in collectionView: UICollectionView) -> Int {
    KsItemOffsetLookup.totalItemCount(in: collectionView)
}
#endif
