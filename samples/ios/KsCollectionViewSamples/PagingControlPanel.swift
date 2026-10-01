import SwiftUI

/// 「ページング」画面の操作のパネル。畳むボタンと表示の形の切り替え、2 つの切り替え、
/// 「再読み込み」、説明の一行を縦に並べる。
struct PagingControlPanel: View {
    @Binding var layoutChoice: PagingLayoutChoice
    @Binding var failsNextLoad: Bool
    @Binding var isEmpty: Bool

    let onReload: () -> Void
    let onFold: () -> Void

    var body: some View {
        SampleFloatingPanel {
            HStack(spacing: SamplePanelMetrics.foldButtonSpacing) {
                SamplePanelFoldButton(onFold: onFold)

                Picker(PagingDemoText.layoutPicker, selection: $layoutChoice) {
                    ForEach(PagingLayoutChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle(PagingDemoText.failsNextLoad, isOn: $failsNextLoad)
            Toggle(PagingDemoText.isEmpty, isOn: $isEmpty)

            Button(PagingDemoText.reload, action: onReload)
                .buttonStyle(SampleBarButtonStyle())

            Text(PagingDemoText.summary)
                .font(.caption)
                .foregroundStyle(SampleTheme.secondaryText)
        }
        .font(.subheadline)
        .foregroundStyle(SampleTheme.text)
        .tint(SampleTheme.accent)
    }
}
