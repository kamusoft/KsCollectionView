/// 並べ替えを有効にした一覧で、読み上げ (VoiceOver) 用に出す移動の操作の文言です。
///
/// 文言を渡すと、動かせる項目に「1 つ前へ動かす」「1 つ後ろへ動かす」の 2 つの操作が出ます。
public struct KsReorderAccessibilityActions: Equatable, Sendable {
    /// 1 つ前へ動かす操作の文言です (例: 「前へ移動」)。
    public let previous: String
    /// 1 つ後ろへ動かす操作の文言です (例: 「後ろへ移動」)。
    public let next: String

    /// 文言を指定して作ります。
    public init(previous: String, next: String) {
        self.previous = previous
        self.next = next
    }
}
