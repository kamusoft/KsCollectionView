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
