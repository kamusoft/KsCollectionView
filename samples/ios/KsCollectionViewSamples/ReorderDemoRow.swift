import SwiftUI

/// 「並べ替え」画面の 1 行。タイトル「Item n」を出し、動かせない項目には後ろに「(移動不可)」を
/// テキスト副の色で添える。
///
/// 余白と面は「リスト」画面の行 (``DemoListRow``) と同じ。タイトルと添える文言は 1 つの文として読み上げる。
struct ReorderDemoRow: View {
    let item: ReorderDemoItem

    var body: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(SampleTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SampleTheme.horizontalPadding)
            .padding(.vertical, SampleTheme.rowVerticalPadding)
            .background(SampleTheme.cell)
    }

    private var title: AttributedString {
        var title = AttributedString(item.title)
        guard !item.isMovable else { return title }
        var suffix = AttributedString(" \(ReorderDemoText.unmovable)")
        suffix.swiftUI.foregroundColor = SampleTheme.secondaryText
        suffix.swiftUI.font = .subheadline
        title += suffix
        return title
    }
}
