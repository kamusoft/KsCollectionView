import SwiftUI

/// 読み込み中の表示の下敷き (``ImageLoadingSlotShownProbeView``) が、はみ出しを切り取る祖先の
/// 表示範囲の外にあるときに「画面に出た」と数えないことを確かめる検証画面です。起動引数
/// `--verify-slot-shown-clipping` で開きます (UI テスト専用。メニューには出しません)。
///
/// 切り取るスクロールするビューの内側と外側 (窓の中) に下敷きを置き、それぞれが知らせた回数と、
/// 見張り (``ImageLoadingSlotShownMonitor``) の周期が動いているかを印に出します。
struct ImageLoadingSlotShownClippingView: View {
    @StateObject private var state = ImageLoadingSlotShownClippingState()

    var body: some View {
        VStack(spacing: 16) {
            Text(state.summary)
                .font(.footnote.monospaced())
                .accessibilityIdentifier("slotShownClipping.state")
            ImageLoadingSlotShownClippingRepresentable(state: state)
                // 外側の下敷き (縦位置 400) が窓の中に収まり、表示範囲 (高さ 200) の外になる大きさ。
                .frame(height: 200)
            Button("外側の下敷きを表示範囲へ送る") {
                state.scrollsToOutside = true
            }
            .accessibilityIdentifier("slotShownClipping.scroll")
            Button("下敷きを足す") {
                state.addedCount += 1
            }
            .accessibilityIdentifier("slotShownClipping.add")
            Spacer()
        }
        .padding()
        .task {
            // 見張りの周期が動いているかを印に写し続けます。
            while !Task.isCancelled {
                state.isMonitorRunning = ImageLoadingSlotShownMonitor.shared.isRunning
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
