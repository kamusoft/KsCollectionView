import UIKit

// 項目が 0 件のときのページングの表示 (最初の読み込み中・失敗・空) を載せる入れ物。一覧の表示範囲に
// 固定して重ね、中身を上下の安全領域を除いた範囲の真ん中に置く (core/ADR-0025)。
//
// ルートのヘッダー / フッターより手前に描き、重なったときも中の操作 (再試行) を押せるようにする。
// 中身の外のタッチは受けず、下の一覧 (ヘッダー / フッターへの操作・引っ張り) へ通す。
internal final class KsPagingPlaceholderView: UIView {
    // 補助ビュー (グループの見出しは zIndex 2) とセルより手前に描くための奥行き。
    static let zPosition: CGFloat = 1_000

    private var hostedView: UIView?
    // 真ん中を求める範囲の上下の縮め幅 (上下の安全領域)。
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private let area = UILayoutGuide()

    var hostedContentView: UIView? {
        hostedView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.zPosition = Self.zPosition
        addLayoutGuide(area)
        let top = area.topAnchor.constraint(equalTo: topAnchor)
        let bottom = area.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            top,
            bottom,
            area.leadingAnchor.constraint(equalTo: leadingAnchor),
            area.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        topConstraint = top
        bottomConstraint = bottom
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
    }

    // 中身の外のタッチは下の一覧へ通す。
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    // 上下の安全領域を中身へ渡さない。真ん中は入れ物の側で安全領域を除いて求めるため、中身が
    // さらに押し下げられないようにする。左右は変えずに渡す。
    override var safeAreaInsets: UIEdgeInsets {
        var insets = super.safeAreaInsets
        insets.top = 0
        insets.bottom = 0
        return insets
    }

    // 真ん中を求める範囲から除く上下の幅を設定する。
    func setExcludedVerticalInsets(top: CGFloat, bottom: CGFloat) {
        if topConstraint?.constant != top {
            topConstraint?.constant = top
        }
        if bottomConstraint?.constant != -bottom {
            bottomConstraint?.constant = -bottom
        }
    }

    // 中身を差し替える。同じ構成を受け付けるホスティングビューは作り直さない。
    func configure(using configuration: UIContentConfiguration) {
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
            view.centerXAnchor.constraint(equalTo: area.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: area.centerYAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: area.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: area.trailingAnchor),
            view.topAnchor.constraint(greaterThanOrEqualTo: area.topAnchor),
            view.bottomAnchor.constraint(lessThanOrEqualTo: area.bottomAnchor),
        ])
        hostedView = view
    }

    func clear() {
        hostedView?.removeFromSuperview()
        hostedView = nil
    }
}
