import KsCollectionView
import SwiftUI

struct AdaptiveGridDemoView: View {
    var body: some View {
        KsCollectionView(
            DemoData.gridItems,
            layout: .grid(columns: .adaptive(minItemWidth: 120))
        ) { item in
            DemoGridCell(item: item)
        }
    }
}
