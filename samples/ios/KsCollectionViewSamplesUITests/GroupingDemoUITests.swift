import XCTest

/// 「グループ化」画面が起動引数で直接開けて、実際の操作でグループの並び順を反転できることを確かめます。
final class GroupingDemoUITests: XCTestCase {
    /// 「グループ化」を起動引数で直接開くと先頭のグループの見出しが出て、並び順の反転で
    /// 最後のグループが先頭へ来ます。
    @MainActor
    func testグループ化を起動引数で開き並び順を反転できる() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "グループ化"]
        app.launch()

        XCTAssertTrue(
            header(beginningWith: "グループ 1、1,200 件", in: app).waitForExistence(timeout: 30),
            "先頭のグループの見出し (1,200 件) が表示されていません"
        )

        app.buttons["並び順を反転"].tap()
        XCTAssertTrue(
            header(beginningWith: "グループ 378、", in: app).waitForExistence(timeout: 10),
            "反転後に最後のグループが先頭へ来ていません"
        )
        XCTAssertTrue(app.staticTexts["Item 9978"].waitForExistence(timeout: 10))
    }

    /// 見出しは名前と件数をまとめた 1 要素 (「グループ A、5 件」の形) として読まれるため、先頭一致で探します。
    @MainActor
    private func header(beginningWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }
}
