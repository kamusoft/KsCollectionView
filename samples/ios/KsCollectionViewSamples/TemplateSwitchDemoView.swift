import KsCollectionView
import SwiftUI

struct TemplateSwitchDemoView: View {
    var body: some View {
        KsCollectionView(DemoData.templateItems, template: \.kind) {
            Template(TemplateDemoKind.message) { (item: TemplateDemoItem) in
                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundStyle(SampleTheme.text)
                    .background(SampleTheme.cell)
            }
            Template(TemplateDemoKind.notice) { (item: TemplateDemoItem) in
                Label(item.title, systemImage: "exclamationmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundStyle(SampleTheme.accent)
                    .background(SampleTheme.cell)
            }
        }
    }
}
