import KsCollectionView
import SwiftUI

struct FixedGridDemoView: View {
    @State private var choice = FixedGridLayoutChoice.grid

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("レイアウト")
                    .foregroundStyle(SampleTheme.text)
                Spacer()
                Picker("レイアウト", selection: $choice) {
                    ForEach(FixedGridLayoutChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 150)
            }
            .padding(.horizontal, SampleTheme.horizontalPadding)
            .padding(.vertical, SampleTheme.controlVerticalPadding)
            .background(SampleTheme.cell)

            KsCollectionView(
                DemoData.fixedGridItems,
                layout: choice == .grid ? .grid(columns: .fixed(3)) : .list
            ) { item in
                if choice == .grid {
                    DemoGridCell(item: item)
                } else {
                    DemoListRow(item: item)
                }
            }
        }
    }
}
