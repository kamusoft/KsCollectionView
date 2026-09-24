import XCTest

/// 「画像グリッド」の件数指定 (`--image-count`) が、指定した件数の土俵で開くことを確かめます。
///
/// メモリの読み込み待ちの往復は、キャッシュの上限に収まる件数 (60 件・600 件) にこの指定で
/// 絞って測ります。指定が届かずに既定の 10,000 件で開いても見た目では区別できないため、
/// 末尾の項目が指定した件数の位置にあることを実際に送って確かめます。
final class ImageGridCountUITests: XCTestCase {
    @MainActor
    func test件数を指定するとその件数で末尾に届く() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "画像グリッド", "--image-count", "60", "--prefetch", "none"]
        app.launch()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 30), "一覧が現れませんでした")
        // 生成規則は件数によらず同じ。先頭の項目の文言でそれを確かめる。
        XCTAssertTrue(item("#1", in: app).waitForExistence(timeout: 30), "先頭の項目が表示されていません")

        // 60 件・3 列は 20 行。末尾の項目が現れるまで、実時間の上限つきで送る。
        let last = item("#60", in: app)
        let deadline = Date().addingTimeInterval(60)
        while !last.exists, Date() < deadline {
            collection.swipeUp()
        }
        XCTAssertTrue(last.exists, "指定した件数の末尾の項目 (#60) に届きませんでした")

        // 末尾まで送り切っても、指定より後ろの項目は現れない。
        collection.swipeUp()
        collection.swipeUp()
        XCTAssertFalse(
            item("#61", in: app).exists,
            "指定した件数より後ろの項目が表示されています (既定の件数で開いていないか確認してください)"
        )
    }

    /// セルの文言で項目を探します。セルは子の要素をまとめて 1 つの要素にしているため、種類を問わず探します。
    @MainActor
    private func item(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", title))
            .firstMatch
    }
}
