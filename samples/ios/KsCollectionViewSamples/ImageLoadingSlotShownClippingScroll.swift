import UIKit

/// はみ出しを切り取るスクロールするビューに、読み込み中の表示の下敷き
/// (``ImageLoadingSlotShownProbeView``) を内側と外側に置いたものです。
///
/// 外側の下敷きは窓の中に位置しますが、スクロールするビューの表示範囲の外なので切り取られて
/// 見えません。コレクションが表示範囲の外に先に組み立てておくセルと同じ状況です。
final class ImageLoadingSlotShownClippingScroll: UIScrollView {
    /// 下敷きの高さ。
    static let probeHeight: CGFloat = 40

    /// 外側の下敷きの縦位置。表示範囲の高さより下に置きます。
    static let outsideOffset: CGFloat = 400

    /// 内容の高さ。外側の下敷きまで送れるだけの長さにします。
    private static let contentHeight: CGFloat = 1000

    private let inside: ImageLoadingSlotShownProbeView
    private let outside: ImageLoadingSlotShownProbeView
    private var added: [ImageLoadingSlotShownProbeView] = []

    init(onInsideShown: @escaping @MainActor () -> Void, onOutsideShown: @escaping @MainActor () -> Void) {
        inside = ImageLoadingSlotShownProbeView(onFirstShown: onInsideShown)
        outside = ImageLoadingSlotShownProbeView(onFirstShown: onOutsideShown)
        super.init(frame: .zero)
        // スクロールするビューの既定の切り取りを、意図として明示します。
        clipsToBounds = true
        backgroundColor = .secondarySystemBackground
        addSubview(inside)
        addSubview(outside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使いません")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentSize = CGSize(width: bounds.width, height: Self.contentHeight)
        let width = bounds.width
        inside.frame = CGRect(x: 0, y: 0, width: width, height: Self.probeHeight)
        outside.frame = CGRect(x: 0, y: Self.outsideOffset, width: width, height: Self.probeHeight)
        for probe in added {
            probe.frame = CGRect(x: 0, y: Self.outsideOffset, width: width, height: Self.probeHeight)
        }
    }

    /// 外側の下敷きと同じ位置に下敷きを 1 つ足します。窓に入った時点で見張りの対象に載ります。
    ///
    /// 外側の下敷きまで送った後に足すと、足した下敷きは表示範囲の中に置かれます。
    ///
    /// - Parameter onFirstShown: 足した下敷きが画面に出たときに呼ばれます
    func addProbe(onFirstShown: @escaping @MainActor () -> Void) {
        let probe = ImageLoadingSlotShownProbeView(onFirstShown: onFirstShown)
        added.append(probe)
        addSubview(probe)
        setNeedsLayout()
    }

    /// 外側の下敷きが表示範囲に入るところまで送ります。
    func scrollToOutside() {
        setContentOffset(CGPoint(x: 0, y: Self.outsideOffset), animated: false)
    }
}
