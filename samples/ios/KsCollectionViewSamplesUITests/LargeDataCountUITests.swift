import XCTest

/// 「大量件数」画面の件数指定が、受け取れない値では起動を止めることを確かめます。
///
/// 黙って既定の 10,000 件へ戻ると、指定したつもりの件数と実際に測った件数が食い違ったまま
/// 証跡が残るため、件数間の比較が成り立たなくなります。
final class LargeDataCountUITests: XCTestCase {
    @MainActor
    func test件数を指定するとその件数で開く() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "大量件数", "--large-count", "2000"]
        app.launch()

        let count = app.staticTexts["largeData.itemCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 30), "件数の表示が現れませんでした")
        XCTAssertEqual(count.label, "件数: 2000")
        // 生成規則は件数によらず同じ。先頭の項目の文言でそれを確かめる。
        XCTAssertTrue(
            app.staticTexts["Item 1"].waitForExistence(timeout: 30),
            "既定と同じ生成規則で先頭の項目が表示されていません"
        )

        #if DEBUG
        // 自己サイズと推定高さの一致の計数は、この起動経路から読める。
        let tally = app.staticTexts["largeData.selfSizingTally"]
        XCTAssertTrue(tally.waitForExistence(timeout: 30), "自己サイズの計数が表示されていません")
        XCTAssertTrue(tally.label.hasPrefix("自己サイズ: "), tally.label)
        #endif
    }

    @MainActor
    func test件数に0を指定すると起動しない() {
        assertLaunchFails(count: "0")
    }

    @MainActor
    func test件数に数値でない値を指定すると起動しない() {
        assertLaunchFails(count: "たくさん")
    }

    /// 指定した件数で起動を試み、起動しないことを確かめます。
    ///
    /// 起動が止まると app の異常終了として失敗が記録されるため、その失敗が**記録されること**を
    /// 期待する形で書きます。起動できてしまうと期待した失敗が記録されず、このテストが落ちます。
    ///
    /// - Parameter count: 件数として渡す文字列
    @MainActor
    private func assertLaunchFails(count: String) {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            // 起動が止まったことの表現は XCTest 側の文言に依るため、止めた本人 (件数の検査) の
            // 名前と、起動できなかったことを表す語のいずれかで拾う。
            let description = issue.compactDescription
            return description.contains("failIfInvalid")
                || description.contains("crashed")
                || description.contains("Failed to launch")
                || description.contains("terminated")
        }
        XCTExpectFailure("受け取れない件数では起動が止まる", options: options)

        let app = XCUIApplication()
        app.launchArguments = ["--screen", "大量件数", "--large-count", count]
        app.launch()

        XCTAssertNotEqual(
            app.state,
            .runningForeground,
            "受け取れない件数なのに起動しています (既定の件数へ戻っていないか確認してください)"
        )
    }
}
