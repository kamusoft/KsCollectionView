import SwiftUI

/// テンプレートのクロージャ内で自分の状態を持ち、親に知らせずに展開するセルです。
struct HeightChangeSelfStateCell: View {
    let item: HeightChangeItem

    @State private var isExpanded = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HeightChangeRowBody(item: item, isExpanded: isExpanded)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("heightChange.selfStateCell.\(item.id)")
    }
}
