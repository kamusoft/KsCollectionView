import Foundation

// 次ページ要求を頼むかどうかの判定と、頼んだ後の待ち方を持つ。画面の部品から切り離し、判定の材料
// (件数・画面に出ている項目・状態・しきい値) を受け取って決める。材料の取り方は一覧の側が持つ。
//
// 判定 (core/ADR-0020):
// - 項目が 0 件で状態が待機なら頼む (最初の読み込み。しきい値によらない)
// - 項目が 1 件以上あるのに画面に出ている項目が 1 つも無いなら頼まない
// - それ以外は、状態が待機で「件数 - 1 - いちばん後ろの位置 <= ceil(しきい値 * 画面に出ている項目の数)」なら頼む
//
// 待ち方 (core/ADR-0022): 頼んだら、処理が終わり、かつ頼んだ時点から状態か配列の版が変わるまで次を頼まない。
// 再試行 (core/ADR-0019): 状態が失敗のとき、処理が実行中でなければ頼む (待ち方の控えによらない)。
@MainActor
internal final class KsPagingRequester {
    // 次ページ要求の処理を実行中か。
    private(set) var isRunning = false
    // 頼んだ回数。判定の結果を観測するために読む。
    private(set) var requestCount = 0
    // 処理が終わったときに呼ぶ。一覧が判定をし直し、引っ張りの受け付けを戻すために使う。
    var onFinish: (() -> Void)?

    // 最後に頼んだ時点の状態と配列の版。状態か版が変わったのを見たら捨てる。
    private var latch: (state: KsPagingState, itemsVersion: Int)?
    private var task: Task<Void, Never>?

    // 残りの項目の数がしきい値以内か (発火の式そのもの)。
    // - itemCount: 配列の件数
    // - visibleItemCount: 画面に出ている項目の数
    // - lastVisibleIndex: 画面に出ている項目のうち、いちばん後ろの項目の配列上の位置 (0 始まり)
    // - threshold: 有効なしきい値 (0 以上の有限の数)
    static func isNearEnd(
        itemCount: Int,
        visibleItemCount: Int,
        lastVisibleIndex: Int,
        threshold: Double
    ) -> Bool {
        // 大きなしきい値では掛け算の結果が整数の範囲を超える (無限大にもなりうる) ため、整数に直さずに比べる。
        let remaining = Double(itemCount - 1 - lastVisibleIndex)
        let allowance = (threshold * Double(visibleItemCount)).rounded(.up)
        return remaining <= allowance
    }

    // しきい値が有効か。負の数と有限でない数は不正入力で、0 として扱う (core/ADR-0011)。
    static func isValidThreshold(_ threshold: Double) -> Bool {
        threshold.isFinite && threshold >= 0
    }

    // 判定に使うしきい値。不正な値は 0 に置き換える。
    static func effectiveThreshold(_ threshold: Double) -> Double {
        isValidThreshold(threshold) ? threshold : 0
    }

    // 状態と配列の版を知らせる。頼んだ時点から変わっていれば、待ち方の控えを捨てる。
    func observe(state: KsPagingState, itemsVersion: Int) {
        guard let latch else { return }
        if latch.state != state || latch.itemsVersion != itemsVersion {
            self.latch = nil
        }
    }

    // 判定して、条件を満たせば次ページ要求の処理を起動する。起動したら true。
    // lastVisibleIndex は画面に項目が出ていないとき nil。
    @discardableResult
    func requestIfNeeded(
        state: KsPagingState,
        itemsVersion: Int,
        itemCount: Int,
        visibleItemCount: Int,
        lastVisibleIndex: Int?,
        threshold: Double,
        action: @escaping @MainActor () async -> Void
    ) -> Bool {
        observe(state: state, itemsVersion: itemsVersion)
        guard state == .idle, !isRunning, latch == nil else { return false }
        let shouldRequest: Bool
        if itemCount == 0 {
            shouldRequest = true
        } else if let lastVisibleIndex, visibleItemCount > 0 {
            shouldRequest = Self.isNearEnd(
                itemCount: itemCount,
                visibleItemCount: visibleItemCount,
                lastVisibleIndex: lastVisibleIndex,
                threshold: Self.effectiveThreshold(threshold)
            )
        } else {
            shouldRequest = false
        }
        guard shouldRequest else { return false }
        start(state: state, itemsVersion: itemsVersion, action: action)
        return true
    }

    // 失敗の表示の再試行。状態が失敗で、処理が実行中でなければ頼む。頼んだら true。
    @discardableResult
    func retry(
        state: KsPagingState,
        itemsVersion: Int,
        action: @escaping @MainActor () async -> Void
    ) -> Bool {
        guard state == .failed, !isRunning else { return false }
        start(state: state, itemsVersion: itemsVersion, action: action)
        return true
    }

    // 実行中の処理を取り消す。一覧が破棄されたときに呼ぶ。
    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func start(
        state: KsPagingState,
        itemsVersion: Int,
        action: @escaping @MainActor () async -> Void
    ) {
        latch = (state, itemsVersion)
        isRunning = true
        requestCount += 1
        task = Task { @MainActor [weak self] in
            await action()
            // 取り消した処理が後から終わっても、次の処理の実行中の印を下ろさない。
            guard let self, !Task.isCancelled else { return }
            task = nil
            isRunning = false
            onFinish?()
        }
    }
}
