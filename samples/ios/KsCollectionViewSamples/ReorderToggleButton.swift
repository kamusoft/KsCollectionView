import SwiftUI

/// 「並べ替え」画面の操作のパネルに 2×2 で並べる切り替えのボタン。押すたびにオン / オフが入れ替わる。
///
/// オンはアクセントの面にアクセントの上の色の太字、オフはセル背景の面に区切り線の色の枠とテキスト主の文字。
/// 見た目は Android Sample の同名の部品とそろえる。文言はボタンの幅で 2 行に折り返してよい。
struct ReorderToggleButton: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(title)
                .font(isOn ? .caption.weight(.semibold) : .caption)
                .foregroundStyle(isOn ? SampleTheme.onAccent : SampleTheme.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, Self.verticalPadding)
                .padding(.horizontal, Self.horizontalPadding)
                .background(isOn ? SampleTheme.accent : SampleTheme.cell, in: shape)
                .overlay(shape.strokeBorder(isOn ? SampleTheme.accent : SampleTheme.separator, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        // オン / オフを読み上げでも分かるようにする (オンの間は「選択済み」と読む)。
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
    }

    /// 文言の上下の余白。
    static let verticalPadding = 7.0

    /// 文言の左右の余白。
    static let horizontalPadding = 4.0

    /// 面の角丸の半径。
    static let cornerRadius = 9.0
}
