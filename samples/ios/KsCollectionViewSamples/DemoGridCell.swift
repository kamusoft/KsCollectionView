import SwiftUI

struct DemoGridCell: View {
    let item: DemoItem

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(SampleTheme.swatches[(item.id - 1) % SampleTheme.swatches.count])
                .frame(width: SampleTheme.swatchSize, height: SampleTheme.swatchSize)
                .accessibilityHidden(true)
            Text(item.title)
                .font(.caption)
                .foregroundStyle(SampleTheme.text)
        }
        .frame(maxWidth: .infinity, minHeight: SampleTheme.gridMinimumHeight)
        .background(SampleTheme.cell)
        .accessibilityElement(children: .combine)
    }
}
