import SwiftUI
import UIKit

/// ``VisibleItemProbe`` が対象のコレクションを見分けるための目印。コレクションの背景に置く。
///
/// 触れても何も起きない、描画しない空のビューを置くだけで、表示やスクロールには関わらない。
struct VisibleItemProbeAnchor: UIViewRepresentable {
    let probe: VisibleItemProbe

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        probe.anchor = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        probe.anchor = uiView
    }
}
