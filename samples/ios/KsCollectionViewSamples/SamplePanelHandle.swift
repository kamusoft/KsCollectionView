import SwiftUI

/// 操作のパネルを畳んだときに残る丸いボタン。押すとパネルを広げる。
struct SamplePanelHandle: View {
    let onUnfold: () -> Void

    var body: some View {
        Button(action: onUnfold) {
            Text("›")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SampleTheme.accent)
                .frame(width: SamplePanelMetrics.handleSize, height: SamplePanelMetrics.handleSize)
                .modifier(SamplePanelSurface(shape: Circle()))
        }
        .accessibilityLabel(SamplePanelText.unfold)
    }
}
