import KsCollectionView
import SwiftUI

struct ListDemoView: View {
    @State private var showsSeparators = true
    @State private var lastInteraction = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("区切り線")
                Spacer()
                Toggle("区切り線", isOn: $showsSeparators)
                    .labelsHidden()
                    .tint(SampleTheme.accent)
            }
            .padding(.horizontal, SampleTheme.horizontalPadding)
            .padding(.vertical, SampleTheme.controlVerticalPadding)
            .background(SampleTheme.cell)

            KsCollectionView(DemoData.fruits) { item in
                DemoListRow(item: item)
            }
            .listSeparators(showsSeparators)
            .onItemTap { lastInteraction = "\($0.title) をタップ" }
            .onItemLongTap { lastInteraction = "\($0.title) を長押し" }
            .touchFeedback(color: SampleTheme.accent.opacity(0.15))
            .accessibilityHint(lastInteraction)
        }
    }
}
