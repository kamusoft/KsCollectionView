#if canImport(UIKit)
import OSLog
import XCTest
@testable import KsCollectionView

/// 不正入力の窓口が、リリースビルドと同じ縮退の経路で警告をログに出すことを確かめる。
@MainActor
final class KsInvalidInputTests: XCTestCase {
    override func setUp() {
        super.setUp()
        KsInvalidInput.reset()
    }

    override func tearDown() {
        KsInvalidInput.reset()
        super.tearDown()
    }

    // どの機能の誤りも、利用者の入力の誤りを表す category に出る (画像の category には出ない)。
    func test不正入力の警告は入力の誤りのcategoryに出る() throws {
        KsInvalidInput.assertsInDebug = false
        let start = Date().addingTimeInterval(-1)
        let message = "不正入力のログの category の確認 \(UUID().uuidString)"
        KsInvalidInput.report(message)

        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries(at: store.position(date: start))
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == "jp.kamusoft.kscollectionview" && $0.composedMessage == message }
        XCTAssertEqual(entries.count, 1, "警告がログに 1 件だけ出ていません")
        XCTAssertEqual(entries.first?.category, "input")
    }
}
#endif
