import Foundation
import XCTest

/// Sample のユニットテストが共有する補助。
enum SampleTestSupport {
    /// 値が条件を満たすまで待ちます。
    ///
    /// 上限は実時間で区切り、待つ間は処理の機会を譲ります。上限を超えたら、その時点の値を添えて失敗させます。
    ///
    /// - Parameters:
    ///   - what: 待っているものの説明 (失敗の文言に出す)
    ///   - timeout: 待つ上限の実時間 (秒)
    ///   - value: いまの値を読む処理
    ///   - condition: 値が満たすべき条件
    @MainActor
    static func waitUntil<Value>(
        _ what: String,
        timeout: TimeInterval = 5,
        value: () -> Value,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: (Value) -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(value()) {
            guard Date() < deadline else {
                XCTFail("\(what) を待ち切れませんでした (いまの値: \(value()))", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    /// 同じグループの値が続いた 1 つの範囲にまとまっているか。
    ///
    /// 同じグループの値が離れた位置にもう一度現れる並びは、グループありの一覧に渡せません。
    ///
    /// - Parameter groups: 項目の並びの順に取り出したグループの値
    static func isContiguous<Group: Hashable>(_ groups: [Group]) -> Bool {
        var seen = Set<Group>()
        var previous: Group?
        for group in groups where group != previous {
            guard seen.insert(group).inserted else { return false }
            previous = group
        }
        return true
    }
}
