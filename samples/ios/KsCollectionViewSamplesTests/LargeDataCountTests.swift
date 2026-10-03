import XCTest
@testable import KsCollectionViewSamples

/// 「大量件数」画面の件数指定 (`--large-count`) の解釈と、件数ごとの項目の生成を確かめます。
///
/// 受け取れない値を黙って既定の 10,000 件へ戻すと、指定したつもりの件数と実際に測った件数が食い違うため、
/// 受け取れない値は受け取れないものとして読み取ることを確かめます。
final class LargeDataCountTests: XCTestCase {
    /// 件数を指定すると、その件数として読み取り、その件数で項目を作ります。
    @MainActor
    func test件数を指定するとその件数で項目を作る() {
        let resolution = LargeDataCount.resolve(arguments: ["app", "--screen", "大量件数", "--large-count", "2000"])

        XCTAssertEqual(resolution, .specified(2_000))
        XCTAssertEqual(LargeDataCount.value(for: resolution), 2_000)

        // 生成規則は件数によらず同じ。先頭の項目は「Item 1」で、指定した件数で終わる。
        let items = DemoData.makeLargeItems(count: LargeDataCount.value(for: resolution))
        XCTAssertEqual(items.count, 2_000)
        XCTAssertEqual(items.first?.title, "Item 1")
        XCTAssertEqual(items.last?.title, "Item 2000")
        XCTAssertEqual(items.first, DemoData.largeItem(1))
    }

    /// 指定が無いときは既定の 10,000 件です。
    @MainActor
    func test指定が無いときは既定の件数() {
        let resolution = LargeDataCount.resolve(arguments: ["app", "--screen", "大量件数"])

        XCTAssertEqual(resolution, .unspecified)
        XCTAssertEqual(LargeDataCount.value(for: resolution), 10_000)
    }

    /// 件数に 0 を指定すると、受け取れないものとして読み取ります (起動時にこの結果で起動を止める)。
    @MainActor
    func test件数に0を指定すると受け取れない() {
        assertInvalid(count: "0")
    }

    /// 件数に数値でない値を指定すると、受け取れないものとして読み取ります。
    @MainActor
    func test件数に数値でない値を指定すると受け取れない() {
        assertInvalid(count: "たくさん")
    }

    /// 指定した件数が、受け取れないものとして読み取られることを確かめる。
    @MainActor
    private func assertInvalid(count: String, file: StaticString = #filePath, line: UInt = #line) {
        let resolution = LargeDataCount.resolve(arguments: ["app", "--screen", "大量件数", "--large-count", count])

        guard case .invalid = resolution else {
            XCTFail("受け取れない件数なのに \(resolution) と読み取りました", file: file, line: line)
            return
        }
    }
}
