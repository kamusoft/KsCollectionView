import SwiftUI

// 利用者が差し替えた 6 つのページングの表示。差し替えていない表示は nil で、既定の見え方になる。
// 既定で出すのは 2 つの読み込み中 (標準の読み込み中の表示、文言なし) だけで、失敗・終端・空は
// 差し替えたときだけ出す (core/ADR-0024)。
internal struct KsPagingDisplays {
    typealias Retry = @MainActor () -> Void

    var appendingIndicator: (() -> AnyView)?
    var failedFooter: ((@escaping Retry) -> AnyView)?
    var endReachedFooter: (() -> AnyView)?
    var loadingPlaceholder: (() -> AnyView)?
    var failedPlaceholder: ((@escaping Retry) -> AnyView)?
    var emptyPlaceholder: (() -> AnyView)?

    // 表示の中身。何も出さない表示 (差し替えていない失敗・終端・空) は nil。
    // 失敗の表示には、次ページ要求を呼び直す再試行の操作を渡す (core/ADR-0019)。
    func content(for display: KsPagingDisplay, retry: @escaping Retry) -> AnyView? {
        switch display {
        case .appendingIndicator:
            appendingIndicator?() ?? AnyView(KsPagingDefaultIndicator())
        case .failedFooter:
            failedFooter?(retry)
        case .endReachedFooter:
            endReachedFooter?()
        case .loadingPlaceholder:
            loadingPlaceholder?() ?? AnyView(KsPagingDefaultProgress())
        case .failedPlaceholder:
            failedPlaceholder?(retry)
        case .emptyPlaceholder:
            emptyPlaceholder?()
        }
    }

    // 利用者が差し替えた表示か。差し替えていない既定の表示は nil を返す差し替え口を持たない。
    func isReplaced(_ display: KsPagingDisplay) -> Bool {
        switch display {
        case .appendingIndicator: appendingIndicator != nil
        case .failedFooter: failedFooter != nil
        case .endReachedFooter: endReachedFooter != nil
        case .loadingPlaceholder: loadingPlaceholder != nil
        case .failedPlaceholder: failedPlaceholder != nil
        case .emptyPlaceholder: emptyPlaceholder != nil
        }
    }
}
