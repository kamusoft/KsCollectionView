import Combine
import KsCollectionView

/// 「ページング」画面の項目・ページングの状態と、読み込み・取り直しの規則。
///
/// Android Sample の同名の定義と同じ規則にし、同じ操作の順で同じ状態と並びになる。
/// Sample の配布先の下限 (iOS 16) では `@Observable` を使えないため、`ObservableObject` で持つ。
///
/// - 次のページの読み込み (``loadNextPage()``): 状態が待機か失敗のときだけ受け付ける (失敗からの
///   再試行を含む)。受け付けたら同じ回に状態を追加読み込み中にし、取得できたら項目を末尾に足すのと
///   同じ回に、最後のページなら終端・そうでなければ待機にする。失敗したら失敗にする
/// - 取り直し (``refresh()``。Pull to Refresh と「再読み込み」): いつでも受け付け、世代を 1 つ進めて
///   状態を取り直し中にし、「更新できませんでした」を消す。取り直し中の状態が一覧に届いたと画面が
///   知らせる (``listDidReceiveRefreshing()``) まで待ってから 1 ページ目を取得する。1 ページ目を
///   取得できたら項目を置き換えるのと同じ回に、終端か待機にする。失敗したとき、項目があれば状態を取り直しの前に戻して
///   「更新できませんでした」の知らせを出し、項目が 0 件なら失敗にする。取り直しの前が追加読み込み中か
///   取り直し中なら、その読み込みの結果は捨てられて戻る先が無いため待機に戻す
/// - 「更新できませんでした」の知らせ: 出してから ``SamplePanelMetrics/bannerDuration`` (3 秒) たったら消す。
///   その間に次の取り直しを始めたら、その時点で消す。もう一度失敗したら、また 3 秒出す
/// - 取り直し中を一覧に届けてから取得する理由: 一覧は差し替えの直前の状態が取り直し中のときだけ、
///   結果を先頭から表示する。取得がすぐ終わると、取り直し中への書き換えと結果の差し替えが同じ描画の回に
///   まとまり、一覧には取り直し中が一度も届かない
/// - 世代: 読み込みと取り直しは始めたときの世代を控え、取得から戻ったときに世代が進んでいたら
///   結果を捨てて何も書き換えない (取り直しより前に始めた読み込みのページが後から混ざらないようにする)
/// - 「次の読み込みを失敗させる」: 次の取得から効き、切り替えただけでは読み込み直さない
/// - 「中身を 0 件にする」: 切り替えたら、その場で取り直す
@MainActor
final class PagingDemoModel: ObservableObject {
    /// 表示している項目。
    @Published private(set) var items: [DemoItem] = []

    /// ページングの状態。一覧はこれを読むだけで、書き換えるのはこのモデルだけ。
    @Published private(set) var state = KsPagingState.idle {
        didSet {
            if state != .refreshing {
                listHasRefreshing = false
            }
        }
    }

    /// 項目があるときの取り直しに失敗した知らせ「更新できませんでした」を出しているか。
    @Published private(set) var refreshFailed = false

    /// 「次の読み込みを失敗させる」。
    @Published var failsNextLoad = false

    /// 「中身を 0 件にする」。
    @Published private(set) var isEmpty = false

    private let source: PagingDemoSource
    private var generation = 0
    /// 「更新できませんでした」を決まった時間の後に消す処理。
    private var noticeTask: Task<Void, Never>?
    /// 取り直し中の状態が一覧に届くのを待っている取り直し。
    private var refreshingWaiters: [CheckedContinuation<Void, Never>] = []
    /// いまの取り直し中の状態が一覧に届いたか。
    private var listHasRefreshing = false

    init(source: PagingDemoSource = PagingDemoSource()) {
        self.source = source
    }

    /// 次のページを読み込む。一覧の次ページ要求と、失敗の表示の「再試行」から呼ばれる。
    func loadNextPage() async {
        guard state == .idle || state == .failed else { return }
        let started = generation
        state = .appending
        let page = items.count / PagingDemoSource.pageSize
        do {
            let result = try await source.fetch(page: page, fails: failsNextLoad, isEmpty: isEmpty)
            guard started == generation else { return }
            items += result.items
            state = result.isLast ? .endReached : .idle
        } catch is CancellationError {
            // 一覧が取り除かれて処理が取り消された。次に頼まれたら読み込めるよう待機に戻す。
            guard started == generation else { return }
            state = .idle
        } catch {
            guard started == generation else { return }
            state = .failed
        }
    }

    /// 1 ページ目から取り直す。Pull to Refresh の処理と、``reload()`` から呼ばれる。
    func refresh() async {
        generation += 1
        let started = generation
        let previous = state
        state = .refreshing
        hideRefreshFailedNotice()
        await waitUntilListReceivesRefreshing()
        do {
            let result = try await source.fetch(page: 0, fails: failsNextLoad, isEmpty: isEmpty)
            guard started == generation else { return }
            items = result.items
            state = result.isLast ? .endReached : .idle
        } catch is CancellationError {
            // 取り直しの処理が取り消された。失敗ではないため、知らせを出さずに前の状態へ戻す。
            guard started == generation else { return }
            state = Self.restoredState(from: previous)
        } catch {
            guard started == generation else { return }
            if items.isEmpty {
                state = .failed
            } else {
                state = Self.restoredState(from: previous)
                showRefreshFailedNotice()
            }
        }
    }

    /// 引っ張らずに取り直す (「再読み込み」)。取り直しは一覧の外 (このモデル) で始める。
    func reload() {
        Task { await refresh() }
    }

    /// 「中身を 0 件にする」を切り替え、その場で取り直す。
    func setEmpty(_ value: Bool) {
        guard value != isEmpty else { return }
        isEmpty = value
        reload()
    }

    /// 取り直し中の状態を受け取った一覧の画面から呼ばれる。待っている取り直しに取得を始めさせる。
    func listDidReceiveRefreshing() {
        guard state == .refreshing else { return }
        listHasRefreshing = true
        resumeRefreshingWaiters()
    }

    /// 一覧の画面が取り除かれたときに呼ばれる。待っている取り直しを止めたままにしない。
    func listDidDisappear() {
        resumeRefreshingWaiters()
    }

    /// 取り直し中の状態が一覧に届くまで待つ。取り直し中のまま重ねて取り直したときは、すでに届いていれば
    /// 待たない。
    private func waitUntilListReceivesRefreshing() async {
        guard !listHasRefreshing else { return }
        await withCheckedContinuation { refreshingWaiters.append($0) }
    }

    private func resumeRefreshingWaiters() {
        let waiters = refreshingWaiters
        refreshingWaiters = []
        waiters.forEach { $0.resume() }
    }

    /// 「更新できませんでした」を出し、決まった時間の後に消す。
    private func showRefreshFailedNotice() {
        noticeTask?.cancel()
        refreshFailed = true
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(SamplePanelMetrics.bannerDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refreshFailed = false
        }
    }

    /// 「更新できませんでした」をすぐに消す。
    private func hideRefreshFailedNotice() {
        noticeTask?.cancel()
        noticeTask = nil
        refreshFailed = false
    }

    /// 項目があるときの取り直しに失敗したときに戻す状態。
    private static func restoredState(from previous: KsPagingState) -> KsPagingState {
        switch previous {
        case .appending, .refreshing: .idle
        case .idle, .failed, .endReached: previous
        }
    }
}
