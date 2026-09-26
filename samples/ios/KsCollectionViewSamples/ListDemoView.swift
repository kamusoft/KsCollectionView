import KsCollectionView
import SwiftUI

struct ListDemoView: View {
    @State private var separatorChoice = ListSeparatorChoice.standard
    @State private var lastInteraction = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("区切り線")
                    .foregroundStyle(SampleTheme.text)
                Spacer()
                Picker("区切り線", selection: $separatorChoice) {
                    ForEach(ListSeparatorChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            .padding(.horizontal, SampleTheme.horizontalPadding)
            .padding(.vertical, SampleTheme.controlVerticalPadding)
            .background(SampleTheme.cell)

            collection
                .accessibilityHint(lastInteraction)
        }
    }

    // 「既定」はライブラリ既定の色をそのまま見せるため、色の指定自体を行わない。
    private var collection: KsCollectionView<DemoItem> {
        let view = KsCollectionView(DemoData.fruits) { item in
            DemoListRow(item: item)
        }
        .listSeparators(separatorChoice != .hidden)
        .onItemTap { lastInteraction = "\($0.title) をタップ" }
        .onItemLongTap { lastInteraction = "\($0.title) を長押し" }
        .touchFeedback(color: SampleTheme.accent.opacity(0.15))

        guard separatorChoice == .accent else { return view }
        return view.listSeparatorColor(SampleTheme.accent)
    }
}
