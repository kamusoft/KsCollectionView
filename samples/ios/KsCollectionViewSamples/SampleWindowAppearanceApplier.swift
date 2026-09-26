import SwiftUI

/// window の `overrideUserInterfaceStyle` を設定するためだけの、描画を持たない View。
struct SampleWindowAppearanceApplier: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> SampleWindowStyleApplyingView {
        SampleWindowStyleApplyingView(style: style)
    }

    func updateUIView(_ uiView: SampleWindowStyleApplyingView, context: Context) {
        uiView.style = style
    }
}
