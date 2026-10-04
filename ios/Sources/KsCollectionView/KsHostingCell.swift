import UIKit

internal final class KsHostingCell: UICollectionViewCell {
    /// 区切り線の色を指定しなかったときに使う色。
    static let defaultSeparatorColor = UIColor(
        red: 217 / 255,
        green: 217 / 255,
        blue: 222 / 255,
        alpha: 1
    )

    /// タッチ時の背景色を指定しなかったときに使う色。プラットフォーム標準のハイライト相当の半透明色。
    /// `.systemFill` は参照のたびに同じオブジェクトを返す保証が無いため、1 つに固定して
    /// 書き込みの省略 (同じオブジェクトなら書かない) が既定色でも効くようにする。
    static let defaultTouchFeedbackColor: UIColor = .systemFill

    /// 中身に出す読み上げの移動操作。
    let reorderAccessibility = KsReorderAccessibilityModel()

    private let touchFeedbackView = UIView()
    private let topSeparatorView = UIView()
    private let bottomSeparatorView = UIView()
    private(set) var lastHitWasInteractive = false
    // 最後に書いた色。可視セルの揃え直しはスクロール中に毎フレーム走ることがあり、
    // 色の代入は同じ値でも比較・動的色の解決・レイヤの更新を伴うため、同じオブジェクトなら書かない。
    // UIColor は不変なので、同じオブジェクトであれば書かれている色も同じである。
    // 色はセルの再利用をまたいで残るため、控えも再利用で捨てない。
    private var writtenTouchFeedbackColor: UIColor?
    private var writtenSeparatorColor: UIColor = KsHostingCell.defaultSeparatorColor
    #if DEBUG
    // 最後に中身を設定したときに、読み上げの移動操作の部品を付けたか。
    private(set) var hasReorderAccessibilityContent = false
    // 最後に中身を設定した時点の、読み上げの移動操作の入れ替えの回数。この後の入れ替えは、作った中身の描き直しを起こす。
    private(set) var reorderAccessibilityChangeCountAtContentApply = 0

    func recordContentApplied(withReorderAccessibility attached: Bool) {
        hasReorderAccessibilityContent = attached
        reorderAccessibilityChangeCountAtContentApply = reorderAccessibility.actionsChangeCount
    }

    // 色を実際に書き込んだ回数。同じ構成での揃え直しが書き込みを起こさないことを観測するために読む。
    // 計測のための仕組みが計測対象に混ざらないよう、debug ビルドにだけ載せる。
    private(set) var touchFeedbackColorWriteCount = 0
    private(set) var separatorColorWriteCount = 0

    // 最後に書いたタッチ時の背景色そのもの。既定色が固定したオブジェクトで渡っていることを観測するために読む。
    var lastWrittenTouchFeedbackColor: UIColor? {
        writtenTouchFeedbackColor
    }
    #endif

    /// 自己サイズの計測結果を受け取るハンドラ。推定高さを実測へ寄せるために使う。
    /// 高さは測ったときの行の幅と対で意味を持つため、サイズごと渡す。
    /// レイアウトの解き直しが起きるかは、測った高さとこのセルに渡されていた高さの比較で
    /// 決まるため、渡されていた側 (`original`) も対で渡す。
    var onMeasuredSize: ((_ measured: CGSize, _ original: CGSize) -> Void)?

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

    var topSeparatorColor: UIColor? {
        topSeparatorView.backgroundColor
    }

    var bottomSeparatorColor: UIColor? {
        bottomSeparatorView.backgroundColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        touchFeedbackView.isHidden = true
        touchFeedbackView.isUserInteractionEnabled = false
        addSubview(touchFeedbackView)
        [topSeparatorView, bottomSeparatorView].forEach {
            $0.backgroundColor = Self.defaultSeparatorColor
            $0.isHidden = true
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
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

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        onMeasuredSize?(attributes.size, layoutAttributes.size)
        return attributes
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
        // iOS 18 以降は中身を外さない。同じ型の構成を当て直すと、中身を載せるホスティングがそのまま
        // 使われ、テンプレートの内部 state は再利用されたセルが表示される前に OS が初期値へ戻す
        // (ios/ADR-0012)。それより前の版は OS が戻さないので、中身を外してホスティングごと作り直させ、
        // 前の項目の内部 state を次の項目へ持ち越さない (ios/ADR-0002)。
        if #unavailable(iOS 18) {
            contentConfiguration = nil
        }
        backgroundConfiguration = nil
        // 内容を適用したセルの計測だけが推定高さに入るよう、次の内容を当てるまで解除する。
        onMeasuredSize = nil
        reorderAccessibility.clear()
        touchFeedbackView.isHidden = true
        topSeparatorView.isHidden = true
        bottomSeparatorView.isHidden = true
        lastHitWasInteractive = false
    }

    func configureTouchFeedback(color: UIColor) {
        guard writtenTouchFeedbackColor !== color else { return }
        writtenTouchFeedbackColor = color
        touchFeedbackView.backgroundColor = color
        #if DEBUG
        touchFeedbackColorWriteCount += 1
        #endif
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

    func configureSeparators(showsTop: Bool, showsBottom: Bool, color: UIColor) {
        let colorChanged = writtenSeparatorColor !== color
        guard colorChanged
            || topSeparatorView.isHidden != !showsTop
            || bottomSeparatorView.isHidden != !showsBottom else {
            return
        }
        if colorChanged {
            writtenSeparatorColor = color
            topSeparatorView.backgroundColor = color
            bottomSeparatorView.backgroundColor = color
            #if DEBUG
            separatorColorWriteCount += 1
            #endif
        }
        topSeparatorView.isHidden = !showsTop
        bottomSeparatorView.isHidden = !showsBottom
        setNeedsLayout()
    }
}
