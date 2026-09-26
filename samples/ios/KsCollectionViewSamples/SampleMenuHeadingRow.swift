import SwiftUI

/// ルートメニューの項目群の見出し。下地の色の帯に補助の文字で置き、選べない。
struct SampleMenuHeadingRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote)
            .foregroundStyle(SampleTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .listRowBackground(SampleTheme.background)
            .listRowSeparator(.hidden)
            .accessibilityAddTraits(.isHeader)
    }
}
