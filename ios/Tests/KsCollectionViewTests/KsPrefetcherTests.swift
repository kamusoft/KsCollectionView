import XCTest
@testable import KsCollectionView

@MainActor
final class KsPrefetcherTests: XCTestCase {
    private final class Recorder: KsPrefetching {
        var prefetched: [Int] = []
        var cancelled: [Int] = []

        func prefetch(items: [Int]) {
            prefetched = items
        }

        func cancelPrefetching(items: [Int]) {
            cancelled = items
        }
    }

    func testPrefetchとcancelを同じ項目へ変換して通知する() {
        let recorder = Recorder()
        let prefetcher = KsAnyPrefetcher(recorder)

        prefetcher.prefetch(items: [2, 5])
        prefetcher.cancel(items: [5])

        XCTAssertEqual(recorder.prefetched, [2, 5])
        XCTAssertEqual(recorder.cancelled, [5])
    }
}
