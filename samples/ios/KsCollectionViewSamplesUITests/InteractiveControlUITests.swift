import XCTest

final class InteractiveControlUITests: XCTestCase {
    @MainActor
    func testセル内Buttonの実座標タップを優先する() {
        let app = launchVerification(
            argument: "--verify-interactive-control",
            rootIdentifier: "verification.expectedResult"
        )

        let button = app.buttons["verification.cellButton"]
        XCTAssertTrue(button.waitUntilHittable(timeout: 30))
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.staticTexts["verification.buttonActionCount"]
            .waitForLabel("Button action count: 1", timeout: 10))
        XCTAssertEqual(
            app.staticTexts["verification.itemTapCount"].label,
            "Item tap count: 0"
        )
    }

    @MainActor
    func test長押し宣言時は同一タッチの通常タップを発火しない() {
        let app = launchLongPressVerification(argument: "--verify-long-press", declaresLongTap: true)
        pressCell(in: app)

        XCTAssertTrue(app.staticTexts["longPress.itemLongTapCount"]
            .waitForLabel("Item long tap count: 1", timeout: 10))
        XCTAssertEqual(
            app.staticTexts["longPress.itemTapCount"].label,
            "Item tap count: 0"
        )
    }

    @MainActor
    func test長押し未宣言時は長押し相当の保持でも通常タップを発火する() {
        let app = launchLongPressVerification(argument: "--verify-tap-only", declaresLongTap: false)
        pressCell(in: app)

        XCTAssertTrue(app.staticTexts["longPress.itemTapCount"]
            .waitForLabel("Item tap count: 1", timeout: 10))
    }

    /// 検証画面を起動し、カウント表示とセルが実座標入力を受け取れる状態になるまで待ちます。
    @MainActor
    private func launchLongPressVerification(
        argument: String,
        declaresLongTap: Bool
    ) -> XCUIApplication {
        let app = launchVerification(argument: argument, rootIdentifier: "longPress.declaresLongTap")

        XCTAssertTrue(app.staticTexts["longPress.declaresLongTap"]
            .waitForLabel("Long tap declared: \(declaresLongTap ? "yes" : "no")", timeout: 30))
        XCTAssertTrue(app.staticTexts["longPress.itemTapCount"]
            .waitForLabel("Item tap count: 0", timeout: 30))
        XCTAssertTrue(app.staticTexts["longPress.cell"].waitUntilHittable(timeout: 30))
        return app
    }

    /// 起動引数に対応する検証画面が出るまで、終了させてから起動し直します。
    /// 前回の実行で残ったインスタンスに `launch()` が束縛されると、起動引数と違う画面のまま進んでしまいます。
    @MainActor
    private func launchVerification(argument: String, rootIdentifier: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [argument]
        let attemptLimit = 2
        for attempt in 1...attemptLimit {
            app.terminate()
            app.launch()
            if app.descendants(matching: .any)[rootIdentifier].waitForExistence(timeout: 30) {
                return app
            }
            XCTAssertLessThan(
                attempt,
                attemptLimit,
                "起動引数 \(argument) の検証画面 (\(rootIdentifier)) が \(attemptLimit) 回の起動で現れませんでした"
            )
        }
        return app
    }

    /// セル中央の実座標を保持します。要素経由の press は保持中に要素を解決し直すため、座標を先に確定させます。
    @MainActor
    private func pressCell(in app: XCUIApplication) {
        app.staticTexts["longPress.cell"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1)
    }
}
