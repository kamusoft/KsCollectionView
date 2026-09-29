import SwiftUI

/// 「ページング」画面で、項目があるときの取り直しに失敗したことを知らせる帯。
///
/// セル背景の不透明な面に区切り線の色の枠を付け、操作のパネルと同じ影を落とす。文言はテキスト主の太字。
struct PagingRefreshFailedBanner: View {
    var body: some View {
        Text(PagingDemoText.refreshFailed)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SampleTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PagingPanelMetrics.bannerVerticalPadding)
            .background(SampleTheme.cell, in: RoundedRectangle(cornerRadius: PagingPanelMetrics.bannerCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PagingPanelMetrics.bannerCornerRadius)
                    .strokeBorder(SampleTheme.separator, lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(PagingPanelMetrics.shadowOpacity),
                radius: PagingPanelMetrics.shadowRadius,
                y: PagingPanelMetrics.shadowOffset
            )
    }
}
