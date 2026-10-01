import SwiftUI

/// 操作のパネル左上の畳むボタン。押すとパネルを左端の丸いボタン (``SamplePanelHandle``) に畳む。
struct SamplePanelFoldButton: View {
    let onFold: () -> Void

    var body: some View {
        Button(action: onFold) {
            Text("‹")
                .font(.headline)
                .foregroundStyle(SampleTheme.accent)
                .frame(width: SamplePanelMetrics.foldButtonSize, height: SamplePanelMetrics.foldButtonSize)
                .background(SampleTheme.background, in: Circle())
        }
        .accessibilityLabel(SamplePanelText.fold)
    }
}
