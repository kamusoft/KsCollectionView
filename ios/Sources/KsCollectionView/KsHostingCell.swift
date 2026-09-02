import UIKit

internal final class KsHostingCell: UICollectionViewCell {
    private let touchFeedbackView = UIView()
    private let topSeparatorView = UIView()
    private let bottomSeparatorView = UIView()
    private(set) var lastHitWasInteractive = false

    var isTopSeparatorVisible: Bool {
        !topSeparatorView.isHidden
    }

    var isBottomSeparatorVisible: Bool {
        !bottomSeparatorView.isHidden
    }

    var topSeparatorFrame: CGRect {
        topSeparatorView.frame
    }

    var bottomSeparatorFrame: CGRect {
        bottomSeparatorView.frame
    }

    var separatorZPosition: Int {
        subviews.firstIndex(of: topSeparatorView) ?? -1
    }

    var contentViewZPosition: Int {
        subviews.firstIndex(of: contentView) ?? -1
    }

    var isTouchFeedbackVisible: Bool {
        !touchFeedbackView.isHidden
    }

    var touchFeedbackColor: UIColor? {
        touchFeedbackView.backgroundColor
    }

    var touchFeedbackZPosition: Int {
        subviews.firstIndex(of: touchFeedbackView) ?? -1
    }

    var separatorColor: UIColor? {
        topSeparatorView.backgroundColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        touchFeedbackView.isHidden = true
        touchFeedbackView.isUserInteractionEnabled = false
        addSubview(touchFeedbackView)
        [topSeparatorView, bottomSeparatorView].forEach {
            $0.backgroundColor = UIColor(
                red: 217 / 255,
                green: 217 / 255,
                blue: 222 / 255,
                alpha: 1
            )
            $0.isHidden = true
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        touchFeedbackView.frame = bounds
        let separatorHeight = 1.0
        topSeparatorView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: separatorHeight
        )
        bottomSeparatorView.frame = CGRect(
            x: 0,
            y: max(0, bounds.height - separatorHeight),
            width: bounds.width,
            height: separatorHeight
        )
        bringSubviewToFront(touchFeedbackView)
        bringSubviewToFront(topSeparatorView)
        bringSubviewToFront(bottomSeparatorView)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if event != nil {
            updateInteractionTarget(hitView)
        }
        return hitView
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentConfiguration = nil
        backgroundConfiguration = nil
        touchFeedbackView.isHidden = true
        topSeparatorView.isHidden = true
        bottomSeparatorView.isHidden = true
        lastHitWasInteractive = false
    }

    func configureTouchFeedback(color: UIColor) {
        touchFeedbackView.backgroundColor = color
    }

    func setTouchFeedbackVisible(_ isVisible: Bool) {
        touchFeedbackView.isHidden = !isVisible
        setNeedsLayout()
    }

    func updateInteractionTarget(_ view: UIView?) {
        var current = view
        while let candidate = current, candidate !== self {
            if candidate is UIControl
                || candidate.accessibilityTraits.contains(.button)
                || candidate.accessibilityTraits.contains(.link)
                || candidate.accessibilityTraits.contains(.adjustable) {
                lastHitWasInteractive = true
                return
            }
            current = candidate.superview
        }
        lastHitWasInteractive = false
    }

    func configureSeparators(showsTop: Bool, showsBottom: Bool) {
        guard topSeparatorView.isHidden != !showsTop
            || bottomSeparatorView.isHidden != !showsBottom else {
            return
        }
        topSeparatorView.isHidden = !showsTop
        bottomSeparatorView.isHidden = !showsBottom
        setNeedsLayout()
    }
}
