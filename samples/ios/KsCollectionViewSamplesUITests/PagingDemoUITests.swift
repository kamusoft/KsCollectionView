import XCTest

/// 「ページング」画面で、実際のスクロールと引っ張りで読み込み・取り直しが働くことを確かめます。
///
/// 取得の遅延は起動引数で 0 にして待ち時間を縮めます。読み込み中の様子そのものを見るテスト
/// (読み込み中の表示・取り直しの失敗の帯) だけは、表示が消える前に観測できるよう遅延を置きます。
final class PagingDemoUITests: XCTestCase {
    /// 画面の名前 (ルートメニューの文言と同じ)。
    private static let screen = "ページング"

    // 画面の文言 (Sample の `PagingDemoText` と同じ値)。
    private static let failsNextLoad = "次の読み込みを失敗させる"
    private static let refreshFailed = "更新できませんでした"
    private static let summary = "全 10,000 件・1 ページ 50 件"

    /// 「更新できませんでした」の帯を見るテストの取得の遅延 (ミリ秒)。引っ張りの後の静止待ちより長くする。
    private static let bannerObservationDelay = 5_000
    private static let loadFailed = "読み込めませんでした"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 読み込み

    /// 開いた直後は最初の読み込み中の表示が読み込み中の要素として出て、その後 Item 1 から並びます。
    @MainActor
    func test開いたら最初の読み込み中の表示のあと最初のページが出る() {
        let app = launchPaging(delayMilliseconds: 3_000)

        XCTAssertTrue(
            app.activityIndicators.firstMatch.waitForExistence(timeout: 10),
            "最初の読み込み中の表示が読み込み中の要素として出ていません"
        )
        XCTAssertFalse(app.staticTexts["Item 1"].exists, "読み込み中なのに項目が出ています")
        XCTAssertTrue(app.staticTexts["Item 1"].waitForExistence(timeout: 15), "最初のページが出ていません")
        XCTAssertTrue(
            app.activityIndicators.firstMatch.waitForNonExistence(timeout: 10),
            "最初のページが出た後も読み込み中の表示が残っています"
        )
    }

    /// 末尾に向けてスクロールすると、次のページ (Item 51 以降) が続きます。
    @MainActor
    func testスクロールで続きを読み込む() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)

        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts["Item 51"], timeout: 60),
            "Item 51 が現れませんでした"
        )
    }

    // MARK: - 取り直し

    /// 項目があるときに失敗させて Pull to Refresh すると、項目はそのまま残り、バーのすぐ下に
    /// 「更新できませんでした」の帯が出て 3 秒で消えます。失敗の表示は出ません。
    @MainActor
    func test項目があるときの取り直しの失敗() {
        // 帯は 3 秒で消える。遅延 0 では引っ張りの直後に失敗して帯が出るが、UI テストは引っ張りの後に
        // アプリの静止を 3 秒あまり待つ (取り直しのインジケータやスイッチの動きが続くため) ので、
        // その間に帯が消えてしまう。取得に遅延を置き、静止を待ち終えた後に失敗させて帯を見る。
        let app = launchPaging(delayMilliseconds: Self.bannerObservationDelay)
        waitForFirstPage(in: app)
        setSwitch(Self.failsNextLoad, on: true, in: app)

        let first = app.staticTexts["Item 1"]
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 帯は 3 秒で消えるため、引っ張りは速く済ませ、その間に見つける。
        let pulledAt = Date()
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: 450)),
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
        let banner = app.staticTexts[Self.refreshFailed]
        XCTAssertTrue(
            banner.waitForExistence(timeout: 3 + Double(Self.bannerObservationDelay) / 1_000),
            "「更新できませんでした」の帯が出ていません (引っ張りから \(Date().timeIntervalSince(pulledAt)) 秒)"
        )
        let shownAt = Date()
        XCTAssertTrue(first.exists, "項目が残っていません")
        XCTAssertFalse(app.staticTexts[Self.loadFailed].exists, "項目があるのに失敗の表示が出ています")
        // 帯はバーのすぐ下に出る。操作のパネルの説明の一行は変わらない。
        let bar = app.navigationBars[Self.screen]
        XCTAssertGreaterThanOrEqual(banner.frame.minY, bar.frame.maxY, "帯がバーに重なっています")
        XCTAssertLessThan(banner.frame.minY, bar.frame.maxY + 40, "帯がバーのすぐ下にありません")
        XCTAssertTrue(app.staticTexts[Self.summary].exists, "操作のパネルの説明の一行が変わっています")

        XCTAssertTrue(banner.waitForNonExistence(timeout: 6), "帯が消えません")
        XCTAssertGreaterThan(Date().timeIntervalSince(shownAt), 1.5, "帯がすぐに消えています")
    }

    // MARK: - 補助

    /// 「ページング」画面を、取得の遅延を指定して直接開く。
    @MainActor
    private func launchPaging(delayMilliseconds: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", Self.screen, "--paging-delay-ms", String(delayMilliseconds)]
        app.launch()
        return app
    }

    /// 最初のページが出るまで待つ。
    @MainActor
    private func waitForFirstPage(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Item 1"].waitForExistence(timeout: 30), "最初のページが出ていません")
    }

    /// 切り替えを指定の状態にする。
    ///
    /// 切り替えは文言の部分を押しても変わらないため、右端のつまみの位置を押す。押した後は値が
    /// 変わるまで待つ。
    @MainActor
    private func setSwitch(_ label: String, on: Bool, in app: XCUIApplication) {
        let element = app.switches[label]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "切り替え「\(label)」がありません")
        let expected = on ? "1" : "0"
        guard element.value as? String != expected else { return }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 10), .completed,
            "切り替え「\(label)」が \(expected) になりません (いまの値: \(String(describing: element.value)))"
        )
    }

    /// 要素が画面に現れるまで一覧を上へ送る。上限は実時間で区切る。
    ///
    /// - Returns: 期限内に現れたか
    @MainActor
    @discardableResult
    private func swipeUp(
        in app: XCUIApplication,
        until element: XCUIElement,
        timeout: TimeInterval,
        velocity: XCUIGestureVelocity = .fast
    ) -> Bool {
        let collection = app.collectionViews.firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            collection.swipeUp(velocity: velocity)
        }
        return element.exists
    }
}
