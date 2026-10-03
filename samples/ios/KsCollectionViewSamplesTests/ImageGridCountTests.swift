import XCTest
@testable import KsCollectionViewSamples

/// 「画像グリッド」の件数指定 (`--image-count`) の解釈と、件数ごとの項目の生成を確かめます。
///
/// メモリの読み込み待ちの往復は、キャッシュの上限に収まる件数にこの指定で絞って測ります。指定が届かずに
/// 既定の 10,000 件で開いても見た目では区別できないため、指定した件数で項目が終わることを確かめます。
final class ImageGridCountTests: XCTestCase {
    /// 件数を指定すると、その件数として読み取り、末尾の項目が指定した件数の位置になります。
    @MainActor
    func test件数を指定するとその件数で項目が終わる() {
        let resolution = ImageGridCount.resolve(
            arguments: ["app", "--screen", "画像グリッド", "--image-count", "60", "--prefetch", "none"]
        )

        XCTAssertEqual(resolution, .specified(60))
        XCTAssertEqual(ImageGridCount.value(for: resolution), 60)

        // 生成規則は件数によらず同じ。先頭は「#1」、末尾は「#60」で、それより後ろの項目は無い。
        let items = DemoData.makeImageGridItems(count: ImageGridCount.value(for: resolution))
        XCTAssertEqual(items.count, 60)
        XCTAssertEqual(items.first?.title, "#1")
        XCTAssertEqual(items.last?.title, "#60")
        XCTAssertFalse(items.contains { $0.title == "#61" }, "指定した件数より後ろの項目があります")
    }

    /// 指定が無いときは既定の 10,000 件です。
    @MainActor
    func test指定が無いときは既定の件数() {
        let resolution = ImageGridCount.resolve(arguments: ["app", "--screen", "画像グリッド"])

        XCTAssertEqual(resolution, .unspecified)
        XCTAssertEqual(ImageGridCount.value(for: resolution), 10_000)
    }
}
