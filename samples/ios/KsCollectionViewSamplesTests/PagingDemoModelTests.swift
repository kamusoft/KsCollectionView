import KsCollectionView
import XCTest
@testable import KsCollectionViewSamples

/// 「ページング」画面のモデルの、読み込み・失敗と再試行・0 件・取り直しの規則を確かめます。
///
/// 取得の遅延は 0 にします。読み込みの途中の状態を見るテストだけ、短い遅延を置きます。
final class PagingDemoModelTests: XCTestCase {
    // MARK: - 読み込み

    /// 最後のページまで読むと Item 10000 で終わって終端になり、その後は読み込みを受け付けません。
    @MainActor
    func test最後まで読むと終端になりそれ以上読み込まない() async {
        let model = PagingDemoModel(source: PagingDemoSource(delayMilliseconds: 0))
        let pageCount = PagingDemoSource.totalCount / PagingDemoSource.pageSize

        for page in 1...pageCount {
            XCTAssertEqual(model.state, .idle, "\(page) ページ目の前に待機に戻っていません")
            await model.loadNextPage()
        }

        XCTAssertEqual(model.state, .endReached)
        XCTAssertEqual(model.items.count, 10_000)
        XCTAssertEqual(model.items.last?.title, "Item 10000")

        await model.loadNextPage()
        XCTAssertEqual(model.items.count, 10_000, "10,000 件を超えて読み込んでいます")
        XCTAssertEqual(model.state, .endReached)
    }

    // MARK: - 失敗と空

    /// 次のページの読み込みに失敗すると項目はそのままで失敗になり、失敗させるのをやめて再試行すると続きが
    /// 読み込まれます。
    @MainActor
    func test次のページの失敗と再試行() async {
        let model = PagingDemoModel(source: PagingDemoSource(delayMilliseconds: 0))
        await model.loadNextPage()
        XCTAssertEqual(model.items.map(\.id), Array(1...50))

        model.failsNextLoad = true
        await model.loadNextPage()

        XCTAssertEqual(model.state, .failed)
        XCTAssertEqual(model.items.map(\.id), Array(1...50), "失敗したのに次のページが入っています")

        model.failsNextLoad = false
        await model.loadNextPage()

        XCTAssertEqual(model.state, .idle, "再試行の後も失敗のままです")
        XCTAssertEqual(model.items.map(\.id), Array(1...100), "再試行で次のページが読み込まれません")
    }

    /// 0 件にした後に失敗させて再読み込みすると、0 件のまま失敗になり、「更新できませんでした」は出ません。
    @MainActor
    func test0件のときの取り直しの失敗は失敗になり更新できませんでしたを出さない() async {
        let model = PagingDemoModel(source: PagingDemoSource(delayMilliseconds: 0))
        let list = PagingListStub(model: model)
        await model.loadNextPage()
        model.setEmpty(true)
        await waitForState(.endReached, of: model)
        XCTAssertTrue(model.items.isEmpty, "0 件になっていません")

        model.failsNextLoad = true
        model.reload()
        await waitForState(.failed, of: model)

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.refreshFailed, "0 件の失敗なのに「更新できませんでした」が出ています")
        withExtendedLifetime(list) {}
    }

    /// 「中身を 0 件にする」をオンにすると、その場で取り直して 0 件の終端 (空の表示が出る状態) になります。
    @MainActor
    func test0件にするとその場で取り直して0件の終端になる() async {
        let model = PagingDemoModel(source: PagingDemoSource(delayMilliseconds: 0))
        let list = PagingListStub(model: model)
        await model.loadNextPage()
        XCTAssertFalse(model.items.isEmpty)

        model.setEmpty(true)
        await waitForState(.endReached, of: model)

        XCTAssertTrue(model.isEmpty)
        XCTAssertTrue(model.items.isEmpty, "0 件なのに項目が残っています")
        withExtendedLifetime(list) {}
    }

    // MARK: - 取り直し

    /// 次のページの読み込み中に取り直すと、先に始めた読み込みのページは戻ってきても捨てられ、取り直しの
    /// 後は Item 1〜Item 50 だけが並びます。
    @MainActor
    func test追加読み込み中に取り直すと古いページが混ざらない() async {
        // 取り直しを始めるまで次のページの読み込みが終わらない長さの遅延を置く。
        let model = PagingDemoModel(source: PagingDemoSource(delayMilliseconds: 100))
        await model.loadNextPage()
        XCTAssertEqual(model.items.map(\.id), Array(1...50))

        let staleLoad = Task { await model.loadNextPage() }
        await waitForState(.appending, of: model)

        // 取り直しは、取り直し中の状態が一覧に届いたと知らせるまで取得を始めない。知らせる前に、
        // 先に始めた読み込みを戻らせる。
        let refresh = Task { await model.refresh() }
        await waitForState(.refreshing, of: model)
        await staleLoad.value

        XCTAssertEqual(model.items.map(\.id), Array(1...50), "先に始めた読み込みのページが混ざっています")
        // 状態が取り直し中でなくなっていると、取り直しは一覧の知らせを受け取れず終わらない。待たずに終える。
        guard model.state == .refreshing else {
            XCTFail("先に始めた読み込みが取り直し中の状態を書き換えています (いまの状態: \(model.state))")
            return
        }

        model.listDidReceiveRefreshing()
        await refresh.value

        XCTAssertEqual(model.items.map(\.id), Array(1...50), "取り直しの後に Item 1〜Item 50 だけが並んでいません")
        XCTAssertEqual(model.state, .idle)
    }

    // MARK: - 補助

    /// モデルが指定の状態になるまで待つ。
    @MainActor
    private func waitForState(
        _ state: KsPagingState,
        of model: PagingDemoModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await SampleTestSupport.waitUntil("状態 \(state)", value: { model.state }, file: file, line: line) {
            $0 == state
        }
    }
}
