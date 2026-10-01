import SwiftUI

/// 一覧の上に浮かせる操作のパネルの面。中身を縦に並べ、背景の透ける角丸の面に載せる。
///
/// 中身の並べ方 (1 行目に畳むボタンと表示の形の切り替え、最後に説明の一行) は各画面が決める。
struct SampleFloatingPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: SamplePanelMetrics.rowSpacing) {
            content()
        }
        .padding(.horizontal, SamplePanelMetrics.horizontalPadding)
        .padding(.vertical, SamplePanelMetrics.verticalPadding)
        .modifier(SamplePanelSurface(shape: RoundedRectangle(cornerRadius: SamplePanelMetrics.cornerRadius)))
    }
}
