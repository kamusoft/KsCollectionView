import KsCollectionView
import SwiftUI

struct TemplateSwitchDemoView: View {
    var body: some View {
        KsCollectionView(DemoData.templateItems, template: \.kind) {
            KsTemplate(.message) { item in
                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundStyle(SampleTheme.text)
                    .background(SampleTheme.cell)
            }
            KsTemplate(.notice) { item in
                Label(item.title, systemImage: "exclamationmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundStyle(SampleTheme.accent)
                    .background(SampleTheme.cell)
            }
        }
    }
}
