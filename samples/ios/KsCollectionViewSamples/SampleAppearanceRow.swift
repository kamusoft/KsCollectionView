import SwiftUI

/// ルートメニューの「外観」の 1 項目。選択中の項目にだけ印を付け、読み上げでは項目名に続けて
/// 「選択中」と読ませる。
struct SampleAppearanceRow: View {
    let appearance: SampleAppearance
    @Binding var selection: SampleAppearance

    private var isSelected: Bool { appearance == selection }

    var body: some View {
        Button {
            selection = appearance
        } label: {
            HStack {
                Text(appearance.title)
                    .foregroundStyle(SampleTheme.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SampleTheme.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        // 既定の Button は文言全体をアクセントで描くため、項目名は文字の色のまま、印だけをアクセントにする。
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? SampleAppearance.selectedAccessibilityValue : "")
        .accessibilityIdentifier("appearance.\(appearance.rawValue)")
    }
}
