import UIKit

// 次のページの読み込み中の表示を載せる入れ物。一覧の表示範囲に固定して重ね、中身を横方向の中央、下端から
// 決まった距離の位置に置く。項目は入れ物の裏を流れる。
//
// 中身の外のタッチは受けず、下の一覧へ通す。既定の表示は中身もタッチを受けない (中身の下の項目を押せる)。
// 利用者が差し替えた表示は、その表示の範囲だけタッチを受ける。
internal final class KsPagingIndicatorView: UIView {
    // セルと補助ビュー (グループの見出しは zIndex 2) より手前に描くための奥行き。
    static let zPosition: CGFloat = 1_000
    // 出る・消えるときのフェードの長さ。
    static let fadeDuration: TimeInterval = 0.2

    private var hostedView: UIView?
    private var bottomConstraint: NSLayoutConstraint?
    private let area = UILayoutGuide()
    // 中身がタッチを受けるか。
    private var receivesTouches = false

    var hostedContentView: UIView? {
        hostedView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.zPosition = Self.zPosition
        addLayoutGuide(area)
        let bottom = area.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            area.topAnchor.constraint(equalTo: topAnchor),
            bottom,
            area.leadingAnchor.constraint(equalTo: leadingAnchor),
            area.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        bottomConstraint = bottom
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
    }

    // 中身の外のタッチと、タッチを受けない中身へのタッチは下の一覧へ通す。
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard receivesTouches else { return nil }
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    // 上下の安全領域を中身へ渡さない。置く位置は入れ物の側で安全領域を含めて決めるため、中身がさらに
    // 押し上げられないようにする。左右は変えずに渡す。
    override var safeAreaInsets: UIEdgeInsets {
        var insets = super.safeAreaInsets
        insets.top = 0
        insets.bottom = 0
        return insets
    }

    // 中身の下端を、表示範囲の下端からこの距離だけ上に合わせる。
    func setBottomDistance(_ distance: CGFloat) {
        guard bottomConstraint?.constant != -distance else { return }
        bottomConstraint?.constant = -distance
    }

    // 中身を差し替える。同じ構成を受け付けるホスティングビューは作り直さない。
    func configure(using configuration: UIContentConfiguration, receivesTouches: Bool) {
        self.receivesTouches = receivesTouches
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
            view.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: area.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: area.trailingAnchor),
            view.topAnchor.constraint(greaterThanOrEqualTo: area.topAnchor),
        ])
        hostedView = view
    }

    func clear() {
        hostedView?.removeFromSuperview()
        hostedView = nil
    }
}
