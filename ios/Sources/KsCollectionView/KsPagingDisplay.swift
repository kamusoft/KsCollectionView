// ページングを付けた一覧が出す 6 つの表示。状態と項目が 0 件かどうかで高々 1 つに決まる (core/ADR-0024)。
// 置き場は 3 つに分かれる。
// - 次のページの読み込み中 (`appendingIndicator`): 一覧の見えている範囲の下端に止めて重ね、項目はその裏を流れる
// - 次のページの失敗・終端 (`*Footer`): 最後の項目の後ろ・ルートのフッターの前
// - 0 件のときの 3 つ (`*Placeholder`): 一覧の見えている範囲の真ん中
internal enum KsPagingDisplay: Hashable, CaseIterable {
    // 次のページの読み込み中。
    case appendingIndicator
    // 次のページの失敗。
    case failedFooter
    // 終端。
    case endReachedFooter
    // 最初の読み込み中 (0 件)。
    case loadingPlaceholder
    // 失敗 (0 件)。
    case failedPlaceholder
    // 空 (0 件で終端)。
    case emptyPlaceholder

    // 表示の置き場。
    enum Placement: Hashable {
        // 一覧の見えている範囲の下端に止めて重ねる。
        case bottomOverlay
        // 最後の項目の後ろ (ルートのフッターの枠の中)。
        case footer
        // 一覧の見えている範囲の真ん中に重ねる。
        case center
    }

    // 状態と件数から、出す表示を決める。待機中、および項目があるときの取り直し中は何も出さない。
    // 項目があるときの取り直し中に出さないのは、利用者が自分で始めた取り直しの間は並んでいる項目に
    // 何も重ねないため (core/ADR-0024)。
    static func resolve(state: KsPagingState, isEmpty: Bool) -> KsPagingDisplay? {
        switch (state, isEmpty) {
        case (.appending, false): .appendingIndicator
        case (.appending, true), (.refreshing, true): .loadingPlaceholder
        case (.failed, false): .failedFooter
        case (.failed, true): .failedPlaceholder
        case (.endReached, false): .endReachedFooter
        case (.endReached, true): .emptyPlaceholder
        case (.refreshing, false), (.idle, _): nil
        }
    }

    var placement: Placement {
        switch self {
        case .appendingIndicator: .bottomOverlay
        case .failedFooter, .endReachedFooter: .footer
        case .loadingPlaceholder, .failedPlaceholder, .emptyPlaceholder: .center
        }
    }
}
