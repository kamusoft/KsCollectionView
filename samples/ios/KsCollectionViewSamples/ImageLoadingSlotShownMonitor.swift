import QuartzCore
import UIKit

/// 読み込み中の表示の下敷き (``ImageLoadingSlotShownProbeView``) を、画面の更新の周期ごとに見張ります。
///
/// 周期ごとに、窓に入っている下敷きのうち画面に見えているものを「画面に出た」として 1 度だけ知らせます。
/// 同じ周期の中で組み立てられて取り除かれた (画面に 1 度も出なかった) 表示は、見張りの時点で窓に
/// 残っていないので数えません。数えることが要求された構成でだけ動きます。
@MainActor
final class ImageLoadingSlotShownMonitor: NSObject {
    static let shared = ImageLoadingSlotShownMonitor()

    /// 見張っている下敷き。取り除かれた下敷きを残さないよう、弱い参照で持ちます。
    private let watched = NSHashTable<ImageLoadingSlotShownProbeView>.weakObjects()

    private var displayLink: CADisplayLink?

    /// 下敷きを見張りの対象に載せます。見張りが止まっていれば始めます。
    func watch(_ view: ImageLoadingSlotShownProbeView) {
        watched.add(view)
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        for view in watched.allObjects {
            if view.hasReported || view.window == nil {
                watched.remove(view)
            } else if view.isOnScreen {
                view.reportShown()
                watched.remove(view)
            }
        }
        // 見張る相手がいなくなったら止めます。次に載せられたときに始め直します。
        if watched.allObjects.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    /// 見張りの周期が動いているか。止まることを確かめる検証画面が読みます。
    var isRunning: Bool { displayLink != nil }
}
