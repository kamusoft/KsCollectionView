import SwiftUI

/// ルートメニューの項目群の間に置く、下地の色の隙間。読み上げの対象にしない。
struct SampleMenuGapRow: View {
    var body: some View {
        Color.clear
            .frame(height: 20)
            .listRowInsets(EdgeInsets())
            .listRowBackground(SampleTheme.background)
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }
}
