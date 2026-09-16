import XCTest

extension XCUIElement {
    /// label が期待値に変わるまで待ちます。
    func waitForLabel(_ expectedLabel: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// label が条件を満たすまで待ちます。
    ///
    /// 操作は配送までしか保証されず、表示とアクセシビリティ情報の更新はその後に起きます。
    /// 期待値を 1 つに書けない (数値が 0 より大きくなる等の) 待ちに使います。
    ///
    /// - Parameters:
    ///   - timeout: 待つ上限の実時間
    ///   - condition: label が満たすべき条件
    /// - Returns: 条件を満たしたかどうか
    func waitForLabel(timeout: TimeInterval, where condition: @escaping (String) -> Bool) -> Bool {
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return condition(element.label)
        }
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
