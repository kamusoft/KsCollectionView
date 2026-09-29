import Foundation

// 利用者が一覧に付けたページングの設定 (状態・しきい値・次ページ要求の処理)。
// 付けていない一覧では構成に載らず (nil)、次ページ要求もページングの表示も行わない。
internal struct KsPaging {
    // 利用者が持つページングの状態。一覧は読むだけで書き換えない (core/ADR-0005)。
    var state: KsPagingState
    // 何画面分手前で次のページを頼むか (core/ADR-0020)。不正な値の扱いは `KsPagingRequester` が持つ。
    var threshold: Double
    // 次ページ要求の処理。一覧の表示の中で実行し、終わるまで次を頼まない (core/ADR-0022)。
    var onLoadMore: @MainActor () async -> Void
}
