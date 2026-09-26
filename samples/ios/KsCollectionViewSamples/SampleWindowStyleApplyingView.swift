import UIKit

/// window に載った時点と選択が変わった時点で、window の `overrideUserInterfaceStyle` を書き換える。
final class SampleWindowStyleApplyingView: UIView {
    var style: UIUserInterfaceStyle {
        didSet { applyStyle() }
    }

    init(style: UIUserInterfaceStyle) {
        self.style = style
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyStyle()
    }

    /// 同じ値の代入でも trait の再評価が走るため、変わるときだけ書き込む。
    private func applyStyle() {
        guard let window, window.overrideUserInterfaceStyle != style else { return }
        window.overrideUserInterfaceStyle = style
    }
}
