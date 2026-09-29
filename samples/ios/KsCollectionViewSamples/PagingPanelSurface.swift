import SwiftUI

/// 「ページング」画面の操作のパネルと、畳んだときの丸いボタンに共通の面。
///
/// セル背景の色に不透明度を掛けた面で一覧を透かし、区切り線の色の枠と薄い影を付ける。ぼかしは
/// 使わない (Android Sample と同じ透け方にするため)。
struct PagingPanelSurface<SurfaceShape: InsettableShape>: ViewModifier {
    let shape: SurfaceShape

    func body(content: Content) -> some View {
        content
            .background(SampleTheme.cell.opacity(PagingPanelMetrics.surfaceOpacity), in: shape)
            .overlay(shape.strokeBorder(SampleTheme.separator, lineWidth: 1))
            .shadow(
                color: .black.opacity(PagingPanelMetrics.shadowOpacity),
                radius: PagingPanelMetrics.shadowRadius,
                y: PagingPanelMetrics.shadowOffset
            )
    }
}
