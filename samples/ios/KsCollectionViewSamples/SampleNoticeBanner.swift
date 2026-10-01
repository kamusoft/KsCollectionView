import SwiftUI

/// 画面の上 (バーのすぐ下) に一覧の上へ浮かせて出す知らせの帯。
///
/// セル背景の不透明な面に区切り線の色の枠を付け、操作のパネルと同じ影を落とす。文言はテキスト主の太字。
/// 出す位置と消すまでの時間は ``SamplePanelMetrics`` の帯の値を使う。
struct SampleNoticeBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SampleTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SamplePanelMetrics.bannerVerticalPadding)
            .background(SampleTheme.cell, in: RoundedRectangle(cornerRadius: SamplePanelMetrics.bannerCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SamplePanelMetrics.bannerCornerRadius)
                    .strokeBorder(SampleTheme.separator, lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(SamplePanelMetrics.shadowOpacity),
                radius: SamplePanelMetrics.shadowRadius,
                y: SamplePanelMetrics.shadowOffset
            )
    }
}
