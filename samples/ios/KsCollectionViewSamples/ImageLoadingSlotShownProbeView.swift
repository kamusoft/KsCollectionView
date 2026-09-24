import UIKit

/// ``ImageLoadingSlotShownProbe`` の中身。何も描かず、窓に入っている間だけ見張りの対象に載ります。
final class ImageLoadingSlotShownProbeView: UIView {
    private let onFirstShown: @MainActor () -> Void

    /// 画面に出たことを知らせ終えたか。
    private(set) var hasReported = false

    init(onFirstShown: @escaping @MainActor () -> Void) {
        self.onFirstShown = onFirstShown
        super.init(frame: .zero)
        // 下にある読み込み中の表示の見た目を変えないよう、透明にして触れても反応しないようにします。
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使いません")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !hasReported {
            ImageLoadingSlotShownMonitor.shared.watch(self)
        }
    }

    /// 今この下敷きが画面に見えているか。窓に入っていて、祖先のどれも隠れておらず透明でもなく、
    /// 見える範囲に少しでも掛かっていることを見ます。
    ///
    /// 見える範囲は、窓の範囲を、はみ出しを切り取る祖先 (コレクションのようなスクロールするビュー)
    /// の範囲ごとに狭めたものです。コレクションは表示範囲の外にあるセルを先に組み立てておくことが
    /// あり、そのセルは窓の中に位置していても表示範囲の外なので切り取られて見えません。窓との交差
    /// だけで見ると、これを画面に出たと数えてしまいます。
    var isOnScreen: Bool {
        guard let window, !bounds.isEmpty else { return false }
        var visibleRect = convert(bounds, to: window).intersection(window.bounds)
        var view: UIView? = self
        while let current = view {
            if current.isHidden || current.alpha < 0.01 { return false }
            if current.clipsToBounds {
                visibleRect = visibleRect.intersection(current.convert(current.bounds, to: window))
            }
            view = current.superview
        }
        return !visibleRect.isEmpty
    }

    /// 画面に出たことを 1 度だけ知らせます。
    func reportShown() {
        guard !hasReported else { return }
        hasReported = true
        onFirstShown()
    }
}
