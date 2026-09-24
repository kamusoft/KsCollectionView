import Combine

/// ``ImageLoadingSlotShownClippingView`` の状態。下敷きが画面に出たと知らせた回数と、見張りの周期が
/// 動いているかを持ちます。
///
/// Sample の配布先の下限 (iOS 16) では `@Observable` を使えないため、`ObservableObject` で持ちます。
@MainActor
final class ImageLoadingSlotShownClippingState: ObservableObject {
    /// 切り取る範囲の内側に置いた下敷きが知らせた回数。
    @Published var insideShown = 0

    /// 切り取る範囲の外側 (窓の中) に置いた下敷きが知らせた回数。
    @Published var outsideShown = 0

    /// 後から足した下敷きが知らせた回数。
    @Published var addedShown = 0

    /// 後から足した下敷きの数。
    @Published var addedCount = 0

    /// 外側の下敷きを見える範囲へ送ることが求められたか。
    @Published var scrollsToOutside = false

    /// 見張りの周期が動いているか。
    @Published var isMonitorRunning = false

    /// 画面の印に出す文字列。UI テストはこの形を読みます。
    var summary: String {
        "inside=\(insideShown) outside=\(outsideShown) added=\(addedShown)/\(addedCount) "
            + "monitor=\(isMonitorRunning ? "running" : "stopped")"
    }
}
