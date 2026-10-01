import SwiftUI

// セルの中身に読み上げの移動操作を付ける。読み上げの焦点はセルの中の SwiftUI の要素に当たるため、
// セル (UIKit の入れ物) ではなく中身の側に付ける。
internal struct KsReorderAccessibilityModifier: ViewModifier {
    @ObservedObject var model: KsReorderAccessibilityModel

    func body(content: Content) -> some View {
        content.accessibilityActions {
            ForEach(model.actions) { action in
                Button(action.name) {
                    action.perform()
                }
            }
        }
    }
}
