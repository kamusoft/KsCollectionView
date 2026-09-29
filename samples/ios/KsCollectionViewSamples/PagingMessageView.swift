import SwiftUI

/// 「ページング」画面の失敗・終端・空の表示。文言と、失敗のときは「再試行」を縦に並べる。
///
/// 最後の項目の後ろ (失敗・終端) と、項目が 0 件のときの一覧の真ん中 (失敗・空) の両方に使う。
struct PagingMessageView: View {
    let message: String

    /// 再試行の操作。失敗の表示だけが持つ。
    var retry: (@MainActor () -> Void)?

    var body: some View {
        VStack(spacing: PagingPanelMetrics.messageSpacing) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(SampleTheme.secondaryText)
            if let retry {
                Button(PagingDemoText.retry, action: retry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SampleTheme.accent)
                    .padding(.vertical, PagingPanelMetrics.retryVerticalPadding)
                    .padding(.horizontal, PagingPanelMetrics.retryHorizontalPadding)
                    .background(
                        SampleTheme.cell,
                        in: RoundedRectangle(cornerRadius: PagingPanelMetrics.retryCornerRadius)
                    )
            }
        }
        .multilineTextAlignment(.center)
    }
}
