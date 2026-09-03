import SwiftUI

/// 展開状態に応じて高さが変わる行の本文です。
///
/// 先頭に見出しを置き、展開時だけ連番の本文行を足すことで、
/// 行の上端からのはみ出しを目視で判別できるようにしています。
struct HeightChangeRowBody: View {
    let item: HeightChangeItem
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("行 \(item.id) の先頭")
                .font(.headline)
                .foregroundStyle(SampleTheme.text)
                .accessibilityIdentifier("heightChange.rowHeading.\(item.id)")

            if isExpanded {
                ForEach(1...4, id: \.self) { line in
                    Text("行 \(item.id) 本文 \(line)")
                        .font(.body)
                        .foregroundStyle(SampleTheme.secondaryText)
                        .accessibilityIdentifier("heightChange.rowBody.\(item.id).\(line)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.rowVerticalPadding)
        .background(SampleTheme.cell)
        .accessibilityIdentifier("heightChange.row.\(item.id)")
    }
}
