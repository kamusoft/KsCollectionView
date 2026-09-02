import KsCollectionView
import SwiftUI

struct OrientationGridDemoView: View {
    var body: some View {
        KsCollectionView(
            DemoData.gridItems,
            layout: .grid(columns: .fixed(portrait: 2, landscape: 4))
        ) { item in
            DemoGridCell(item: item)
        }
    }
}
