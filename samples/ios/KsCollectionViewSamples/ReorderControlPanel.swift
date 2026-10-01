import SwiftUI

/// 「並べ替え」画面の操作のパネル。畳むボタンと表示の形の切り替え、4 つの切り替えのボタン (2×2)、
/// 説明の一行を縦に並べる。
struct ReorderControlPanel: View {
    @Binding var layoutChoice: ReorderLayoutChoice
    @Binding var isReorderEnabled: Bool
    @Binding var isGrouped: Bool
    @Binding var keepsGroups: Bool
    @Binding var rejectsMoves: Bool

    let onFold: () -> Void

    var body: some View {
        SampleFloatingPanel {
            HStack(spacing: SamplePanelMetrics.foldButtonSpacing) {
                SamplePanelFoldButton(onFold: onFold)

                Picker(ReorderDemoText.layoutPicker, selection: $layoutChoice) {
                    ForEach(ReorderLayoutChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            }

            toggleRow(
                ReorderToggleButton(title: ReorderDemoText.reorder, isOn: $isReorderEnabled),
                ReorderToggleButton(title: ReorderDemoText.grouped, isOn: $isGrouped)
            )
            toggleRow(
                ReorderToggleButton(title: ReorderDemoText.keepsGroups, isOn: $keepsGroups),
                ReorderToggleButton(title: ReorderDemoText.rejectsMoves, isOn: $rejectsMoves)
            )

            Text(ReorderDemoText.summary)
                .font(.caption)
                .foregroundStyle(SampleTheme.secondaryText)
        }
        .font(.subheadline)
        .foregroundStyle(SampleTheme.text)
        .tint(SampleTheme.accent)
    }

    /// 切り替えのボタン 2 つを同じ幅・同じ高さで横に並べる (片方が 2 行に折り返したら、もう片方も同じ高さにする)。
    private func toggleRow(_ leading: ReorderToggleButton, _ trailing: ReorderToggleButton) -> some View {
        HStack(spacing: SamplePanelMetrics.rowSpacing) {
            leading
            trailing
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
