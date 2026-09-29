import XCTest
@testable import KsCollectionView

/// 次ページ要求の判定の式と、頼んだ後の待ち方・再試行・取り消しを、画面の部品なしで確かめる。
@MainActor
final class KsPagingRequesterTests: XCTestCase {
    // 処理の終わりを試験の側で決めるための門。`open()` を呼ぶまで処理は戻らない。
    @MainActor
    private final class Gate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var isOpen = false
        private(set) var cancelledWhileWaiting = false

        func wait() async {
            guard !isOpen else { return }
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    self.continuation = continuation
                }
            } onCancel: {
                Task { @MainActor in
                    self.cancelledWhileWaiting = true
                    self.open()
                }
            }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }

    private var callCount = 0

    // MARK: - 発火の式

    func test既定のしきい値で1画面分手前で頼む() {
        // 100 件・画面に 10 件。いちばん後ろが 88 番目までは頼まず、89 番目で頼む。
        for last in 0...88 {
            XCTAssertFalse(
                KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: last, threshold: 1),
                "いちばん後ろが \(last) 番目で頼んでいます"
            )
        }
        XCTAssertTrue(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 89, threshold: 1))

        let requester = KsPagingRequester()
        XCTAssertFalse(request(requester, lastVisibleIndex: 88))
        XCTAssertTrue(request(requester, lastVisibleIndex: 89))
        XCTAssertEqual(requester.requestCount, 1)
    }

    func testしきい値2では2画面分手前で頼む() {
        XCTAssertFalse(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 78, threshold: 2))
        XCTAssertTrue(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 79, threshold: 2))
    }

    func testしきい値0では最後の項目が画面に入ったときだけ頼む() {
        XCTAssertFalse(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 98, threshold: 0))
        XCTAssertTrue(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 99, threshold: 0))
    }

    func test端数は切り上げて数える() {
        // 0.25 × 10 = 2.5 → 3 件まで。
        XCTAssertTrue(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 96, threshold: 0.25))
        XCTAssertFalse(KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 95, threshold: 0.25))
    }

    func test空で待機ならしきい値によらず頼む() {
        let requester = KsPagingRequester()
        XCTAssertTrue(
            requester.requestIfNeeded(
                state: .idle,
                itemsVersion: 0,
                itemCount: 0,
                visibleItemCount: 0,
                lastVisibleIndex: nil,
                threshold: 0,
                action: countingAction()
            )
        )
        XCTAssertEqual(requester.requestCount, 1)
    }

    func test項目があるのに画面に項目が出ていなければ頼まない() {
        let requester = KsPagingRequester()
        XCTAssertFalse(
            requester.requestIfNeeded(
                state: .idle,
                itemsVersion: 0,
                itemCount: 3,
                visibleItemCount: 0,
                lastVisibleIndex: nil,
                threshold: 1,
                action: countingAction()
            )
        )
    }

    // MARK: - 待機のときだけ自動で頼む

    func test待機以外の状態では条件を満たしても頼まない() {
        for state in [KsPagingState.refreshing, .appending, .failed, .endReached] {
            let requester = KsPagingRequester()
            XCTAssertFalse(request(requester, state: state, lastVisibleIndex: 99), "\(state) で頼んでいます")
            XCTAssertFalse(
                requester.requestIfNeeded(
                    state: state,
                    itemsVersion: 0,
                    itemCount: 0,
                    visibleItemCount: 0,
                    lastVisibleIndex: nil,
                    threshold: 1,
                    action: countingAction()
                ),
                "0 件の \(state) で頼んでいます"
            )
        }
    }

    // MARK: - 頼んだ後の待ち方

    func testVMが状態の書き換えを遅らせても二重に頼まない() async {
        // 処理はすぐ戻り、状態はまだ待機のまま。スクロールを続けても 2 回目は頼まない。
        let requester = KsPagingRequester()
        XCTAssertTrue(request(requester, lastVisibleIndex: 95))
        await waitUntilFinished(requester)
        for last in 95...99 {
            XCTAssertFalse(request(requester, lastVisibleIndex: last))
        }
        // 少し後で状態が追加読み込み中になり、待機に戻った (配列は同じ)。状態が変わったので次を頼める。
        requester.observe(state: .appending, itemsVersion: 0)
        XCTAssertTrue(request(requester, lastVisibleIndex: 99))
        XCTAssertEqual(requester.requestCount, 2)
    }

    func test処理の中で待つVMは処理が終わるまで次を頼まない() async {
        let requester = KsPagingRequester()
        let gate = Gate()
        XCTAssertTrue(request(requester, lastVisibleIndex: 95, action: { await gate.wait() }))
        XCTAssertTrue(requester.isRunning)
        // 実行中は、配列が変わっても頼まない。
        XCTAssertFalse(request(requester, itemsVersion: 1, itemCount: 150, lastVisibleIndex: 149))
        gate.open()
        await waitUntilFinished(requester)
        // 処理が終わり、配列の版が進んでいるので頼める。
        XCTAssertTrue(request(requester, itemsVersion: 1, itemCount: 150, lastVisibleIndex: 149))
        XCTAssertEqual(requester.requestCount, 2)
    }

    func test頼みが無視されたら状態か配列が変わるまで頼まない() async {
        let requester = KsPagingRequester()
        XCTAssertTrue(request(requester, lastVisibleIndex: 95))
        await waitUntilFinished(requester)
        for _ in 0..<5 {
            XCTAssertFalse(request(requester, lastVisibleIndex: 99))
        }
        XCTAssertTrue(request(requester, itemsVersion: 1, lastVisibleIndex: 99), "配列が変わったのに頼みません")
    }

    func test処理が終わるとonFinishを呼ぶ() async {
        let requester = KsPagingRequester()
        var finished = 0
        requester.onFinish = { finished += 1 }
        XCTAssertTrue(request(requester, lastVisibleIndex: 99))
        await waitUntilFinished(requester)
        XCTAssertEqual(finished, 1)
    }

    // MARK: - 再試行

    func test再試行は状態が失敗なら待ち方の控えによらず頼む() async {
        let requester = KsPagingRequester()
        XCTAssertTrue(request(requester, lastVisibleIndex: 99))
        await waitUntilFinished(requester)
        // 状態が失敗になった (控えは状態の変化で捨てられる)。自動では頼まない。
        XCTAssertFalse(request(requester, state: .failed, lastVisibleIndex: 99))
        XCTAssertTrue(requester.retry(state: .failed, itemsVersion: 0, action: countingAction()))
        await waitUntilFinished(requester)
        // 失敗のまま戻っても、再試行はまた頼める。
        XCTAssertTrue(requester.retry(state: .failed, itemsVersion: 0, action: countingAction()))
        XCTAssertEqual(requester.requestCount, 3)
    }

    func test再試行は失敗以外の状態では何もしない() {
        for state in [KsPagingState.idle, .refreshing, .appending, .endReached] {
            let requester = KsPagingRequester()
            XCTAssertFalse(requester.retry(state: state, itemsVersion: 0, action: countingAction()), "\(state)")
        }
    }

    func test再試行は処理の実行中なら何もしない() async {
        let requester = KsPagingRequester()
        let gate = Gate()
        XCTAssertTrue(requester.retry(state: .failed, itemsVersion: 0, action: { await gate.wait() }))
        XCTAssertFalse(requester.retry(state: .failed, itemsVersion: 0, action: countingAction()))
        XCTAssertEqual(requester.requestCount, 1)
        gate.open()
        await waitUntilFinished(requester)
    }

    // MARK: - 取り消し

    func test取り消すと実行中の処理が取り消される() async {
        let requester = KsPagingRequester()
        let gate = Gate()
        var finished = 0
        requester.onFinish = { finished += 1 }
        XCTAssertTrue(request(requester, lastVisibleIndex: 99, action: { await gate.wait() }))
        // 処理が待ちに入るまで進める。
        await Task.yield()
        requester.cancel()
        XCTAssertFalse(requester.isRunning)
        await waitUntil("処理の取り消し") { gate.cancelledWhileWaiting }
        // 取り消した処理が戻っても、終わりの知らせは出さない。
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(finished, 0)
    }

    // MARK: - 大きなしきい値

    // 有効なしきい値 (0 以上の有限の数) は、どれだけ大きくても判定で落ちずに「頼む」側に倒れる。
    func test大きな有限のしきい値と掛け算で無限大になるしきい値でも落ちずに頼む() {
        for threshold in [1e19, Double(Int.max), Double.greatestFiniteMagnitude] {
            XCTAssertTrue(KsPagingRequester.isValidThreshold(threshold), "\(threshold)")
            XCTAssertTrue(
                KsPagingRequester.isNearEnd(itemCount: 100, visibleItemCount: 10, lastVisibleIndex: 0, threshold: threshold),
                "\(threshold)"
            )
            let requester = KsPagingRequester()
            XCTAssertTrue(request(requester, lastVisibleIndex: 0, threshold: threshold), "\(threshold)")
        }
    }

    // MARK: - 状態と配列の版の知らせ

    // 判定をしない間も状態と配列の版を知らせていれば、「待機 → 追加読み込み中 → 待機」の往復で控えが捨てられ、
    // 配列が変わらなくても次を頼める。
    func test判定をしない間に知らせた状態の往復で控えを捨てる() async {
        let requester = KsPagingRequester()
        XCTAssertTrue(request(requester, lastVisibleIndex: 99))
        await waitUntilFinished(requester)
        requester.observe(state: .appending, itemsVersion: 0)
        requester.observe(state: .idle, itemsVersion: 0)
        XCTAssertTrue(request(requester, lastVisibleIndex: 99), "往復を知らせたのに頼みません")
    }

    // MARK: - 不正なしきい値

    func test負と有限でないしきい値は不正として0で判定する() {
        for value in [-1, -0.5, Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertFalse(KsPagingRequester.isValidThreshold(value), "\(value)")
            XCTAssertEqual(KsPagingRequester.effectiveThreshold(value), 0)
        }
        XCTAssertTrue(KsPagingRequester.isValidThreshold(0))
        XCTAssertTrue(KsPagingRequester.isValidThreshold(2.5))
        // 負のしきい値は 0 として扱うため、最後の項目が画面に入ったときにだけ頼む。
        let requester = KsPagingRequester()
        XCTAssertFalse(request(requester, lastVisibleIndex: 98, threshold: -3))
        XCTAssertTrue(request(requester, lastVisibleIndex: 99, threshold: -3))
    }

    // MARK: - 部品

    private func countingAction() -> @MainActor () async -> Void {
        { [weak self] in self?.callCount += 1 }
    }

    // 100 件・画面に 10 件の一覧として判定する。
    private func request(
        _ requester: KsPagingRequester,
        state: KsPagingState = .idle,
        itemsVersion: Int = 0,
        itemCount: Int = 100,
        lastVisibleIndex: Int,
        threshold: Double = 1,
        action: (@MainActor () async -> Void)? = nil
    ) -> Bool {
        requester.requestIfNeeded(
            state: state,
            itemsVersion: itemsVersion,
            itemCount: itemCount,
            visibleItemCount: 10,
            lastVisibleIndex: lastVisibleIndex,
            threshold: threshold,
            action: action ?? countingAction()
        )
    }

    private func waitUntilFinished(_ requester: KsPagingRequester) async {
        await waitUntil("処理の終わり") { !requester.isRunning }
    }

    private func waitUntil(_ label: String, _ condition: () -> Bool) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(2)
        while clock.now < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("\(label) が期限内に起きませんでした")
    }
}
