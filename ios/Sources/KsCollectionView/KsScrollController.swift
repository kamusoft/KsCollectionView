import Foundation
import os

/// コレクションへスクロール命令を送るハンドルです。
@MainActor
public final class KsScrollController {
    private weak var receiver: (any KsScrollCommandReceiver)?
    private let logger = Logger(subsystem: "jp.kamusoft.kscollectionview", category: "scroll")

    public init() {}

    /// 指定した ID の項目へスクロールします。
    public func scrollTo(
        id: some Hashable,
        position: KsScrollPosition = .start,
        animated: Bool = true
    ) {
        receiver?.receive(.item(id: AnyHashable(id), position: position, animated: animated))
    }

    /// コンテンツの先頭へスクロールします。
    public func scrollToStart(animated: Bool = true) {
        receiver?.receive(.start(animated: animated))
    }

    /// コンテンツの末尾へスクロールします。
    public func scrollToEnd(animated: Bool = true) {
        receiver?.receive(.end(animated: animated))
    }

    internal func attach(_ receiver: any KsScrollCommandReceiver) {
        if let current = self.receiver, current !== receiver {
            #if DEBUG
            logger.warning("1 つの KsScrollController が複数のコレクションへ接続されました。最後の接続を使用します。")
            #endif
        }
        self.receiver = receiver
    }

    internal func detach(_ receiver: any KsScrollCommandReceiver) {
        guard self.receiver === receiver else { return }
        self.receiver = nil
    }
}
