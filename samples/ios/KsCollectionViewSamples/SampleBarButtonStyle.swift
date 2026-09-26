import SwiftUI

/// 下部バーに並べる操作ボタンの見た目。幅いっぱいの角丸の面に、アクセント色の太字の文言を置く。
struct SampleBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SampleTheme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SampleBarButtonStyle.verticalPadding)
            .background(SampleTheme.background, in: RoundedRectangle(cornerRadius: SampleBarButtonStyle.cornerRadius))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }

    /// 文言の上下の余白。
    private static let verticalPadding = 10.0

    /// 面の角丸の半径。
    private static let cornerRadius = 10.0
}
