import UIKit

internal final class KsHostingSupplementaryView: UICollectionReusableView {
    private var hostedView: UIView?

    var hostedContentView: UIView? {
        hostedView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
    }

    // レイアウトが透明にした補助ビューは読み上げの対象から外す。塊に割れたグループでは同じ見出しが
    // 塊ごとに置かれ、見せる 1 つ以外は透明にしてあるため、外さないと同じ見出しが重ねて読まれる。
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        accessibilityElementsHidden = layoutAttributes.alpha < 0.01
    }

    // 上端・下端の安全領域を中身へ渡さない。一覧が画面上端の安全領域に重なって置かれると、
    // 重なった位置のセル・補助ビューに安全領域が伝わり、SwiftUI の中身がその分だけ押し下げられて
    // 高さも増える。行と補助ビューは安全領域に被ったまま中身どおりの大きさで流すため、上下は 0 にする
    // (core/ADR-0017)。
    // 左右 (横向きの切り欠き等) は変えずに渡す。
    override var safeAreaInsets: UIEdgeInsets {
        var insets = super.safeAreaInsets
        insets.top = 0
        insets.bottom = 0
        return insets
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostedView?.removeFromSuperview()
        hostedView = nil
    }

    func configure(using configuration: UIContentConfiguration) {
        // 同じ構成を受け付けるホスティングビューは作り直さず、内容だけを差し替える。
        if let contentView = hostedView as? UIView & UIContentView,
           contentView.supports(configuration) {
            contentView.configuration = configuration
            return
        }

        hostedView?.removeFromSuperview()
        let view = configuration.makeContentView()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostedView = view
    }

    func clear() {
        hostedView?.removeFromSuperview()
        hostedView = nil
    }
}
