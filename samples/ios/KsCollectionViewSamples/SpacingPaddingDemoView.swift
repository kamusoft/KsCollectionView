import KsCollectionView
import SwiftUI

struct SpacingPaddingDemoView: View {
    @State private var spacing = 4.0
    @State private var padding = 8.0

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                LabeledContent("スペーシング") {
                    Slider(value: $spacing, in: 0...16)
                        .frame(maxWidth: 180)
                }
                LabeledContent("余白") {
                    Slider(value: $padding, in: 0...24)
                        .frame(maxWidth: 180)
                }
            }
            .padding(.horizontal, SampleTheme.horizontalPadding)
            .padding(.vertical, SampleTheme.controlVerticalPadding)
            .background(SampleTheme.cell)

            KsCollectionView(
                DemoData.gridItems,
                layout: .grid(columns: .fixed(2), rowSpacing: spacing, columnSpacing: spacing),
                contentPadding: EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding)
            ) { item in
                DemoGridCell(item: item)
            }
        }
    }
}
