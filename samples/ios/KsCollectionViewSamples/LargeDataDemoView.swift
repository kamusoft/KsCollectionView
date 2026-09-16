import KsCollectionView
import SwiftUI

struct LargeDataDemoView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 件数を指定して開いたときだけ、いま測っている件数と計数を出す。
            if LargeDataCount.isSpecified {
                LargeDataMeasurementBar()
            }
            KsCollectionView(
                DemoData.largeItems,
                layout: .grid(columns: .fixed(2), rowSpacing: 1, columnSpacing: 1)
            ) { item in
                DemoListRow(item: item)
            }
        }
    }
}
