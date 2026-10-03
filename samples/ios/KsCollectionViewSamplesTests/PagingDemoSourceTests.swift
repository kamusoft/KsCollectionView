import XCTest
@testable import KsCollectionViewSamples

/// 「ページング」画面の偽の取得元と、取得の遅延の指定 (`--paging-delay-ms`) の解釈を確かめます。
final class PagingDemoSourceTests: XCTestCase {
    /// 遅延に 0 を指定すると遅延なしとして読み取り、取得元は待たずに最初のページを返します。
    @MainActor
    func test遅延に0を指定すると待たずに最初のページを返す() async throws {
        let resolution = PagingDelay.resolve(
            arguments: ["app", "--screen", "ページング", "--paging-delay-ms", "0"]
        )
        XCTAssertEqual(resolution, .specified(0))
        XCTAssertEqual(PagingDelay.milliseconds(for: resolution), 0)

        let source = PagingDemoSource(delayMilliseconds: PagingDelay.milliseconds(for: resolution))
        let started = Date()
        let page = try await source.fetch(page: 0, fails: false, isEmpty: false)

        // 既定の遅延 (1 秒) では間に合わない短さで返る。
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.9, "取得が遅延なしで返っていません")
        XCTAssertEqual(page.items.first?.title, "Item 1")
        XCTAssertEqual(page.items.count, 50)
        XCTAssertFalse(page.isLast)
    }

    /// 遅延の指定が無いときは既定の 1 秒です。
    @MainActor
    func test遅延の指定が無いときは既定の遅延() {
        let resolution = PagingDelay.resolve(arguments: ["app", "--screen", "ページング"])

        XCTAssertEqual(resolution, .unspecified)
        XCTAssertEqual(PagingDelay.milliseconds(for: resolution), 1_000)
    }

    /// 最後のページは Item 10000 で終わって最後のページとして返り、その後ろのページは 0 件です。
    @MainActor
    func test最後のページはItem10000で終わりその後ろは無い() async throws {
        let source = PagingDemoSource(delayMilliseconds: 0)

        let beforeLast = try await source.fetch(page: 198, fails: false, isEmpty: false)
        XCTAssertFalse(beforeLast.isLast, "最後より前のページが最後のページとして返っています")

        let last = try await source.fetch(page: 199, fails: false, isEmpty: false)
        XCTAssertEqual(last.items.first?.title, "Item 9951")
        XCTAssertEqual(last.items.last?.title, "Item 10000")
        XCTAssertTrue(last.isLast, "最後のページが最後のページとして返っていません")

        let beyond = try await source.fetch(page: 200, fails: false, isEmpty: false)
        XCTAssertTrue(beyond.items.isEmpty, "10,000 件を超えた項目を返しています")
        XCTAssertTrue(beyond.isLast)
    }
}
