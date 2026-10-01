import QuartzCore

// CADisplayLink の受け手。CADisplayLink は受け手を強く持つため、一覧を直接受け手にせず、この入れ物から
// 弱く持った処理を呼ぶ。
@MainActor
internal final class KsDisplayLinkTarget: NSObject {
    private let onFrame: @MainActor (CADisplayLink) -> Void

    init(onFrame: @escaping @MainActor (CADisplayLink) -> Void) {
        self.onFrame = onFrame
    }

    @objc func frame(_ link: CADisplayLink) {
        onFrame(link)
    }
}
