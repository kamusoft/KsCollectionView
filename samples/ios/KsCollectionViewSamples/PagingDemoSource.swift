/// 「ページング」画面の偽の取得元。
///
/// 全 ``totalCount`` 件 (「Item 1」〜「Item 10000」、ID は 1 からの整数) を 1 ページ ``pageSize`` 件で
/// 返す。取得のたびに ``PagingDelay`` の遅延を置く。Android Sample の同名の定義と同じ規則にし、
/// 同じページの番号には同じ並びを返す。
///
/// - 「中身を 0 件にする」がオンなら、どのページも 0 件・最後のページとして返す
/// - 「次の読み込みを失敗させる」がオンなら、遅延の後に失敗させる (「中身を 0 件にする」より優先)
struct PagingDemoSource: Sendable {
    /// 全件数。
    static let totalCount = 10_000

    /// 1 ページの件数。
    static let pageSize = 50

    /// 1 回の取得に置く遅延 (ミリ秒)。
    let delayMilliseconds: Int

    init(delayMilliseconds: Int = PagingDelay.milliseconds) {
        self.delayMilliseconds = delayMilliseconds
    }

    /// 指定したページを取得する。
    ///
    /// - Parameters:
    ///   - page: 0 から数えたページの番号
    ///   - fails: 失敗させるか
    ///   - isEmpty: 中身を 0 件にするか
    /// - Returns: そのページの項目と、最後のページか
    func fetch(page: Int, fails: Bool, isEmpty: Bool) async throws -> PagingDemoPage {
        if delayMilliseconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
        }
        if fails {
            throw PagingDemoFailure()
        }
        if isEmpty {
            return PagingDemoPage(items: [], isLast: true)
        }
        let first = page * Self.pageSize + 1
        let last = min(first + Self.pageSize - 1, Self.totalCount)
        guard first <= last else {
            return PagingDemoPage(items: [], isLast: true)
        }
        return PagingDemoPage(
            items: (first...last).map { DemoItem(id: $0, title: "Item \($0)") },
            isLast: last == Self.totalCount
        )
    }
}
