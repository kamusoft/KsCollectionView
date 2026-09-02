import SwiftUI

struct DemoListRow: View {
    let item: DemoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.body)
                .foregroundStyle(SampleTheme.text)
            if let detail = item.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(SampleTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.rowVerticalPadding)
        .background(SampleTheme.cell)
    }
}
