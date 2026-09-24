import SwiftUI

/// ``ImageLoadingSlotShownClippingScroll`` を SwiftUI に置くための包みです。
struct ImageLoadingSlotShownClippingRepresentable: UIViewRepresentable {
    @ObservedObject var state: ImageLoadingSlotShownClippingState

    func makeUIView(context: Context) -> ImageLoadingSlotShownClippingScroll {
        let state = state
        return ImageLoadingSlotShownClippingScroll(
            onInsideShown: { state.insideShown += 1 },
            onOutsideShown: { state.outsideShown += 1 }
        )
    }

    func updateUIView(_ uiView: ImageLoadingSlotShownClippingScroll, context: Context) {
        let state = state
        // 足した数に追いつくまで下敷きを足します。
        while context.coordinator.addedCount < state.addedCount {
            context.coordinator.addedCount += 1
            uiView.addProbe { state.addedShown += 1 }
        }
        if state.scrollsToOutside {
            uiView.scrollToOutside()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 既に足した下敷きの数を覚えます。
    @MainActor
    final class Coordinator {
        var addedCount = 0
    }
}
