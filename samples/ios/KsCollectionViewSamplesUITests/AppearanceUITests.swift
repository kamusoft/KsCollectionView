import XCTest

/// ルートメニューの「外観」で、初回は「システム」が選択中になり、選んだ値が起動し直しても残り、
/// 選択中の項目だけが「選択中」と読まれることを確かめます。
///
/// 選んだ外観は保存されて後の起動に効くため、各テストは保存を消す起動引数で始め、終わりにも
/// 保存を消して、他の UI テストや計測の起動に持ち越さないようにします。
final class AppearanceUITests: XCTestCase {
    /// 保存した外観を消す起動引数 (Sample の `SampleAppearance.resetArgument` と同じ値)。
    private static let resetArgument = "--reset-appearance"

    /// 選択中の項目で読まれる文言 (Sample の `SampleAppearance.selectedAccessibilityValue` と同じ値)。
    private static let selectedValue = "選択中"

    /// 項目名。並びはルートメニューと同じ。
    private static let titles = ["システム", "ライト", "ダーク"]

    override func tearDown() {
        // 失敗で途中終了した場合も含め、保存した外観を消してから終える。
        let app = XCUIApplication()
        app.launchArguments = [Self.resetArgument]
        app.launch()
        app.terminate()
        super.tearDown()
    }

    /// 保存が無い状態で起動すると「システム」が選択中です。
    @MainActor
    func test保存が無い状態で起動するとシステムが選択中() {
        let app = XCUIApplication()
        app.launchArguments = [Self.resetArgument]
        app.launch()

        assertSelected("システム", in: app)
    }

    /// 「ダーク」を選んで起動し直すと「ダーク」が選択中のままです。
    @MainActor
    func testダークを選んで起動し直してもダークが選択中() {
        let app = XCUIApplication()
        app.launchArguments = [Self.resetArgument]
        app.launch()

        let dark = app.buttons["ダーク"]
        XCTAssertTrue(dark.waitForExistence(timeout: 30), "メニューに「ダーク」がありません")
        dark.tap()
        assertSelected("ダーク", in: app)

        // 保存を消さずに起動し直す。
        app.terminate()
        app.launchArguments = []
        app.launch()

        assertSelected("ダーク", in: app)
    }

    /// 見出し「外観」の下に 3 項目が「システム」「ライト」「ダーク」の順で並び、デモ画面の項目より上にあります。
    @MainActor
    func test外観の見出しと3項目がデモ画面の項目より上に並ぶ() {
        let app = XCUIApplication()
        app.launchArguments = [Self.resetArgument]
        app.launch()

        let heading = app.staticTexts["外観"]
        XCTAssertTrue(heading.waitForExistence(timeout: 30), "見出し「外観」がありません")
        let items = Self.titles.map { app.buttons[$0] }
        for (title, item) in zip(Self.titles, items) {
            XCTAssertTrue(item.waitForExistence(timeout: 10), "メニューに「\(title)」がありません")
        }
        let firstDemo = app.buttons["リスト"]
        XCTAssertTrue(firstDemo.waitForExistence(timeout: 10), "メニューに「リスト」がありません")

        let tops = [heading.frame.minY] + items.map(\.frame.minY) + [firstDemo.frame.minY]
        XCTAssertEqual(tops, tops.sorted(), "「外観」「システム」「ライト」「ダーク」「リスト」の順に並んでいません")
    }

    /// 指定した項目だけが「選択中」と読まれることを確かめる。
    @MainActor
    private func assertSelected(
        _ selectedTitle: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let selected = app.buttons[selectedTitle]
        XCTAssertTrue(
            selected.waitForExistence(timeout: 30),
            "メニューに「\(selectedTitle)」がありません",
            file: file,
            line: line
        )
        let becameSelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", Self.selectedValue),
            object: selected
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [becameSelected], timeout: 10),
            .completed,
            "「\(selectedTitle)」が選択中と読まれません (value: \(String(describing: selected.value)))",
            file: file,
            line: line
        )
        for title in Self.titles where title != selectedTitle {
            let value = app.buttons[title].value as? String ?? ""
            XCTAssertNotEqual(
                value,
                Self.selectedValue,
                "選択中でない「\(title)」が選択中と読まれます",
                file: file,
                line: line
            )
        }
    }
}
