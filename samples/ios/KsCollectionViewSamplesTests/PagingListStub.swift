import Combine
@testable import KsCollectionViewSamples

/// 「ページング」画面の一覧の代わり。
///
/// モデルの取り直しは、取り直し中の状態が一覧に届いたと知らされるまで取得を始めません。画面を載せない
/// テストでは、状態が取り直し中に変わった次の回に、一覧の代わりにそれを知らせます。
@MainActor
final class PagingListStub {
    private var observation: AnyCancellable?

    init(model: PagingDemoModel) {
        observation = model.$state.sink { [weak model] state in
            guard state == .refreshing else { return }
            // 知らせが届く時点ではモデルの状態が書き換わる前のため、書き換わった後の回で知らせる。
            Task { @MainActor in
                model?.listDidReceiveRefreshing()
            }
        }
    }
}
