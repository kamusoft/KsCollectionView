/// 「ページング」画面の偽の取得元が 1 回の取得で返す 1 ページ。
struct PagingDemoPage: Equatable, Sendable {
    /// このページの項目。
    let items: [DemoItem]

    /// このページが最後のページか (続きが無いか)。
    let isLast: Bool
}
