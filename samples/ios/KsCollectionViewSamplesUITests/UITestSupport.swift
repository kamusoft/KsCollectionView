import XCTest

extension XCUIElement {
    /// label が期待値に変わるまで待ちます。
    func waitForLabel(_ expectedLabel: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// タッチを受け取れる状態になるまで待ちます。存在だけでは、載せた直後の要素へ実座標入力を送れません。
    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
