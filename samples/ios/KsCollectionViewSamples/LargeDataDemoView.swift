import KsCollectionView
import SwiftUI

struct LargeDataDemoView: View {
    var body: some View {
        KsCollectionView(
            DemoData.largeItems,
            layout: .grid(columns: .fixed(2), rowSpacing: 1, columnSpacing: 1)
        ) { item in
            DemoListRow(item: item)
        }
    }
}
