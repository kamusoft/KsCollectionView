import XCTest
@testable import KsCollectionViewSamples

/// 外観の選択の初期値と、保存した選択を起動引数で消す処理を確かめます。
final class SampleAppearanceTests: XCTestCase {
    /// このテストだけが使う保存先の名前。アプリの保存先には触れません。
    private static let suiteName = "SampleAppearanceTests"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        super.tearDown()
    }

    /// 保存が無いときの選択は「システム」です。
    @MainActor
    func test保存が無いときの選択はシステム() {
        XCTAssertEqual(SampleAppearance.initial, .system)
        XCTAssertEqual(SampleAppearance.initial.title, "システム")
    }

    /// 保存を消す起動引数があると、保存した選択が消えます。
    @MainActor
    func test保存を消す起動引数があると保存した選択を消す() throws {
        let defaults = try makeDefaults(stored: .dark)

        SampleAppearance.resetIfRequested(arguments: ["app", "--reset-appearance"], defaults: defaults)

        XCTAssertNil(defaults.object(forKey: SampleAppearance.storageKey), "保存した選択が残っています")
    }

    /// 保存を消す起動引数が無いと、保存した選択は残ります (起動し直しても選んだ外観のまま)。
    @MainActor
    func test保存を消す起動引数が無いと保存した選択は残る() throws {
        let defaults = try makeDefaults(stored: .dark)

        SampleAppearance.resetIfRequested(arguments: ["app", "--screen", "リスト"], defaults: defaults)

        let stored = defaults.string(forKey: SampleAppearance.storageKey)
        XCTAssertEqual(stored.flatMap(SampleAppearance.init(rawValue:)), .dark)
    }

    /// 選択を 1 つ保存した、このテスト専用の保存先を作る。
    @MainActor
    private func makeDefaults(stored appearance: SampleAppearance) throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        defaults.set(appearance.rawValue, forKey: SampleAppearance.storageKey)
        return defaults
    }
}
