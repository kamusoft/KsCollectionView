import XCTest

/// 読み込み中の表示が画面に出たかの判定 (`shown`) が、はみ出しを切り取る祖先の表示範囲を見ることと、
/// 見張りの周期が見張る相手のいない間は止まることを確かめます。
///
/// コレクションは表示範囲の外にあるセルを先に組み立てておくことがあり、そのセルは窓の中に位置して
/// いても切り取られて見えません。窓との交差だけで判定すると、これを画面に出たと数えてしまい、
/// 先読みに当たった件数の判定 (`matchedShown`) を誤らせます。
final class ImageLoadingSlotShownClippingUITests: XCTestCase {
    @MainActor
    func test窓の中でも切り取られた範囲の外にある下敷きは数えず表示範囲に入ったら数える() {
        let app = launchClippingVerification()
        let state = stateElement(in: app)

        // 内側は数え、外側 (窓の中だが表示範囲の外) は数えない。外側は見張られたままなので周期は動いている。
        assertLabelMatches(
            state,
            pattern: "inside=1 outside=0 added=0/0 monitor=running",
            message: "表示範囲の外にある下敷きが数えられたか、内側が数えられませんでした"
        )
        // 時間が経っても外側は数えられないことを、しばらく待ってから確かめる。
        XCTAssertFalse(
            waitFor(state, pattern: ".*outside=[1-9].*", timeout: 2),
            "表示範囲の外にある下敷きが数えられました: \(state.label)"
        )

        app.buttons["slotShownClipping.scroll"].tap()
        assertLabelMatches(
            state,
            pattern: "inside=1 outside=1 added=0/0 monitor=.*",
            message: "表示範囲に入った下敷きが数えられませんでした"
        )
    }

    @MainActor
    func test見張る相手がいなくなると周期が止まり足されると再開する() {
        let app = launchClippingVerification()
        let state = stateElement(in: app)

        app.buttons["slotShownClipping.scroll"].tap()
        // 内側と外側がどちらも知らせ終えると、見張る相手がいなくなり周期が止まる。
        assertLabelMatches(
            state,
            pattern: "inside=1 outside=1 added=0/0 monitor=stopped",
            message: "見張る相手がいなくなっても周期が止まりませんでした"
        )

        // 止まった後に足した下敷きも数えられ (周期が始め直された)、知らせ終えると再び止まる。
        app.buttons["slotShownClipping.add"].tap()
        assertLabelMatches(
            state,
            pattern: "inside=1 outside=1 added=1/1 monitor=stopped",
            message: "止まった後に足した下敷きが数えられないか、周期が再び止まりませんでした"
        )
    }

    /// 状態の印を取り出します。
    @MainActor
    private func stateElement(in app: XCUIApplication) -> XCUIElement {
        let state = app.staticTexts["slotShownClipping.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 30), "状態の印が現れませんでした")
        return state
    }

    /// 印の文字列が指定の形になるまで待ち、ならなければ実測値を添えて失敗させます。
    ///
    /// - Parameters:
    ///   - state: 状態の印
    ///   - pattern: 期待する形
    ///   - message: 失敗したときの説明
    @MainActor
    private func assertLabelMatches(_ state: XCUIElement, pattern: String, message: String) {
        XCTAssertTrue(waitFor(state, pattern: pattern, timeout: 30), "\(message): \(state.label)")
    }

    /// 印の文字列が指定の形になるまで待ちます。
    ///
    /// - Parameters:
    ///   - state: 状態の印
    ///   - pattern: 期待する形
    ///   - timeout: 待つ秒数
    /// - Returns: 時間内に指定の形になったか
    @MainActor
    private func waitFor(_ state: XCUIElement, pattern: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label MATCHES %@", pattern)
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: state)],
            timeout: timeout
        )
        return result == .completed
    }

    /// 検証画面を開きます。前回の実行で残ったインスタンスに束縛されないよう、終了させてから起動し直します。
    @MainActor
    private func launchClippingVerification() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--verify-slot-shown-clipping"]
        app.terminate()
        app.launch()
        return app
    }
}
