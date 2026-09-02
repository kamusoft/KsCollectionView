import KsCollectionView
import SwiftUI

struct HeaderFooterDemoView: View {
    var body: some View {
        KsCollectionView(DemoData.fruits) { item in
            DemoListRow(item: item)
        }
        .header {
            Text("ルートヘッダー")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .foregroundStyle(SampleTheme.secondaryText)
                .background(SampleTheme.background)
        }
        .footer {
            Text("ルートフッター")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .foregroundStyle(SampleTheme.secondaryText)
                .background(SampleTheme.background)
        }
    }
}
