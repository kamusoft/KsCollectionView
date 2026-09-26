import KsCollectionView
import SwiftUI

/// 「グループ化」の土俵の宣言元。
///
/// デモ画面 (``GroupingDemoView``) と計測用の画面 (``PerformanceVerificationView``) は、配置・セル・
/// 見出しの宣言をここから取る。計測はデモ画面と同じ土俵を測って初めて意味を持つため、組み立てを
/// 1 箇所に集める。
enum GroupingFixture {
    /// 縦長 2 列・横長 4 列のグリッド。見出しと先頭行の間は行の間と同じ細い間隔にする。
    static let layout = KsCollectionLayout.grid(
        columns: .fixed(portrait: 2, landscape: 4),
        rowSpacing: GroupHeaderMetrics.gridSpacing,
        columnSpacing: GroupHeaderMetrics.gridSpacing,
        groupSpacing: GroupHeaderMetrics.groupSpacing,
        headerItemSpacing: GroupHeaderMetrics.gridSpacing
    )

    /// 土俵のコレクションを組み立てる。見出しは固定する (既定)。
    ///
    /// - Parameter items: 表示する配列。操作で組み替えた配列もそのまま渡す
    static func collection(items: [GroupingDemoItem]) -> KsCollectionView<GroupingDemoItem> {
        KsCollectionView(items, layout: layout) { item in
            DemoListRow(item: item.row)
        }
        .groups(by: \.group) { group, itemsInGroup in
            GroupHeaderBand(name: "グループ \(group)", itemCount: itemsInGroup.count)
        }
    }
}
