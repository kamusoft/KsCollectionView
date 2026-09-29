import SwiftUI

/// 「ページング」画面の操作のパネルを畳んだときに残る丸いボタン。押すとパネルを広げる。
struct PagingPanelHandle: View {
    let onUnfold: () -> Void

    var body: some View {
        Button(action: onUnfold) {
            Text("›")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SampleTheme.accent)
                .frame(width: PagingPanelMetrics.handleSize, height: PagingPanelMetrics.handleSize)
                .modifier(PagingPanelSurface(shape: Circle()))
        }
        .accessibilityLabel(PagingDemoText.unfold)
    }
}
