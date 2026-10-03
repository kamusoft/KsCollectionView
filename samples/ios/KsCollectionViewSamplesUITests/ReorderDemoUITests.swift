import XCTest

/// 「並べ替え」画面で、実際の長押しからのドラッグで項目を並べ替えられることを確かめます。
///
/// iOS の並べ替えは UIKit のドラッグ & ドロップで動くため、置く先の隙間は UIKit の標準の決め方に従います。
/// 置く位置は、持ち上げた項目が抜けて開く隙間の真ん中へ指を運んで決めます。
final class ReorderDemoUITests: XCTestCase {
    /// 画面の名前 (ルートメニューの文言と同じ)。
    private static let screen = "並べ替え"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 並べ替え

    /// Item 1 を長押しして Item 3 と Item 4 の間に置くと、Item 2, 3, 1, 4 の順に並びます。
    @MainActor
    func test項目を並べ替える() {
        let app = launchReorder()

        drag(item(1, in: app), toGapBelow: item(3, in: app), in: app)

        assertOrder([2, 3, 1, 4], in: app)
    }

    // MARK: - 補助

    /// 「並べ替え」画面を直接開き、最初の項目が出るまで待つ。
    @MainActor
    private func launchReorder() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", Self.screen]
        app.launch()
        XCTAssertTrue(app.staticTexts["Item 1"].waitForExistence(timeout: 30), "最初の項目が出ていません")
        return app
    }

    @MainActor
    private func item(_ number: Int, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["Item \(number)"]
    }

    /// 上にある要素を長押しして持ち上げ、下へ運んで `upper` とその次の項目の間に置く。
    ///
    /// 持ち上げた項目が抜けると、それより下の項目は 1 行ずつ詰まり、`upper` の下に置く先の隙間が開く。
    /// 隙間の真ん中は、持ち上げる前の `upper` の真ん中に当たるため、指 (持ち上げた項目の真ん中) をそこへ運ぶ。
    @MainActor
    private func drag(_ element: XCUIElement, toGapBelow upper: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitUntilHittable(timeout: 10), "\(element) を押せません")
        XCTAssertTrue(upper.waitForExistence(timeout: 10), "\(upper) がありません")
        XCTAssertLessThan(element.frame.minY, upper.frame.minY, "\(element) が \(upper) より上にありません")
        let target = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: upper.frame.midX, dy: upper.frame.midY))
        drag(element, to: target)
    }

    /// 要素を長押しして持ち上げ、`target` へ運んで少し止めてから離す。置いた後の動きが収まるのは、並びを
    /// 確かめる側 (`assertOrder`) が条件を観測して待つ。
    @MainActor
    private func drag(_ element: XCUIElement, to target: XCUICoordinate) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 1.0,
            thenDragTo: target,
            withVelocity: .slow,
            thenHoldForDuration: 0.8
        )
    }

    /// 要素の frame を読み続け、`condition` を満たし、かつ 2 回続けて同じ frame になるまで待つ。上限は実時間で
    /// 区切り、超えたら最後に読んだ frame を返して `settled` を false にする。置いた動きの途中の位置で
    /// 判定しないために使う。
    @MainActor
    private func waitUntilSettled(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 10,
        where condition: ([CGRect]) -> Bool
    ) -> (settled: Bool, frames: [CGRect]) {
        let deadline = Date().addingTimeInterval(timeout)
        var previous: [CGRect]?
        var frames = elements.map(\.frame)
        while Date() < deadline {
            frames = elements.map(\.frame)
            if frames == previous, condition(frames) {
                return (true, frames)
            }
            previous = frames
            Thread.sleep(forTimeInterval: 0.1)
        }
        return (false, frames)
    }

    /// 項目が上から指定の順に並び、動きが収まっていることを確かめる。
    @MainActor
    private func assertOrder(_ numbers: [Int], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let elements = numbers.map { item($0, in: app) }
        for (number, element) in zip(numbers, elements) {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "Item \(number) がありません", file: file, line: line)
        }
        let result = waitUntilSettled(elements) { frames in
            let tops = frames.map(\.minY)
            return tops == tops.sorted() && Set(tops).count == tops.count
        }
        if !result.settled {
            let tops = result.frames.map(\.minY)
            XCTFail("並びが \(numbers) の順で静止しませんでした (上端: \(tops))", file: file, line: line)
        }
    }
}
