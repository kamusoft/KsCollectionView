import XCTest

/// 「ページング」画面の読み込み・失敗と再試行・0 件・取り直し・操作の畳み方を確かめます。
///
/// 取得の遅延は起動引数で 0 にして待ち時間を縮めます。読み込み中の様子そのものを見るテスト
/// (読み込み中の表示・追加読み込み中の再読み込み) だけは、表示が消える前に観測できるよう遅延を置きます。
final class PagingDemoUITests: XCTestCase {
    /// 画面の名前 (ルートメニューの文言と同じ)。
    private static let screen = "ページング"

    // 画面の文言 (Sample の `PagingDemoText` と同じ値)。
    private static let failsNextLoad = "次の読み込みを失敗させる"
    private static let isEmpty = "中身を 0 件にする"
    private static let reload = "再読み込み"
    private static let refreshFailed = "更新できませんでした"
    private static let summary = "全 10,000 件・1 ページ 50 件"

    /// 「更新できませんでした」の帯を見るテストの取得の遅延 (ミリ秒)。引っ張りの後の静止待ちより長くする。
    private static let bannerObservationDelay = 5_000
    private static let loadFailed = "読み込めませんでした"
    private static let retry = "再試行"
    private static let endReached = "これ以上ありません"
    private static let empty = "項目がありません"
    private static let fold = "操作を畳む"
    private static let unfold = "操作を広げる"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 構成と起動引数

    /// ルートメニューで「ページング」が「差分更新」のすぐ下にあります。
    @MainActor
    func testメニューで差分更新の次にある() {
        let app = XCUIApplication()
        app.launch()

        let previous = app.buttons["差分更新"]
        let paging = app.buttons[Self.screen]
        XCTAssertTrue(app.buttons["リスト"].waitForExistence(timeout: 30), "メニューが現れませんでした")
        // メニューの下の方にあるため、見えるところまで送る。
        let menu = app.collectionViews.firstMatch
        let deadline = Date().addingTimeInterval(30)
        while !(paging.exists && paging.isHittable && previous.exists), Date() < deadline {
            menu.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(paging.isHittable, "メニューに「ページング」がありません")
        XCTAssertTrue(previous.exists, "メニューに「差分更新」がありません")
        XCTAssertLessThan(previous.frame.minY, paging.frame.minY, "「差分更新」より上にあります")

        paging.tap()
        XCTAssertTrue(
            app.navigationBars[Self.screen].waitForExistence(timeout: 10),
            "開いた画面のタイトルが「ページング」ではありません"
        )
    }

    /// 遅延 0 を指定して起動すると「ページング」画面が直接開き、最初のページがすぐに出ます。
    @MainActor
    func test遅延を縮めて開くと直接開いてすぐ読み込む() {
        let app = launchPaging(delayMilliseconds: 0)

        XCTAssertTrue(app.navigationBars[Self.screen].waitForExistence(timeout: 30), "画面が直接開いていません")
        // 既定の遅延 (1 秒) では間に合わない短い期限で待つ。
        XCTAssertTrue(app.staticTexts["Item 1"].waitForExistence(timeout: 0.9), "取得が遅延なしで返っていません")
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

    /// Item 10000 まで読み進めると、最後の項目の後ろに「これ以上ありません」が出て、読み込み中の表示は出ません。
    @MainActor
    func test最後まで読むと終端の表示が出る() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)
        // 行の数が半分になるグリッドで送る。
        app.buttons["グリッド"].tap()

        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts[Self.endReached], timeout: 900),
            "「これ以上ありません」が現れませんでした"
        )
        XCTAssertTrue(app.staticTexts["Item 10000"].exists, "最後の項目が見えていません")
        XCTAssertFalse(app.staticTexts["Item 10001"].exists, "10,000 件を超えて読み込んでいます")
        XCTAssertFalse(app.activityIndicators.firstMatch.exists, "終端なのに読み込み中の表示が出ています")
    }

    // MARK: - 失敗と空

    /// 次のページの失敗で「読み込めませんでした」と「再試行」が出て、切り替えをオフにして再試行すると続きが読み込まれます。
    @MainActor
    func test次のページの失敗と再試行() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)
        setSwitch(Self.failsNextLoad, on: true, in: app)

        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts[Self.loadFailed], timeout: 60),
            "次のページの失敗の表示が現れませんでした"
        )
        // 表示が現れた時点では操作のパネルの裏にあることがあるため、末尾まで送り切る。
        swipeUp(in: app, times: 2)
        let retry = app.buttons[Self.retry]
        XCTAssertTrue(retry.waitUntilHittable(timeout: 10), "「再試行」を押せません")
        XCTAssertFalse(app.staticTexts["Item 51"].exists, "失敗したのに次のページが出ています")

        setSwitch(Self.failsNextLoad, on: false, in: app)
        retry.tap()
        XCTAssertTrue(app.staticTexts["Item 51"].waitForExistence(timeout: 10), "再試行で次のページが読み込まれません")
        XCTAssertFalse(app.staticTexts[Self.loadFailed].exists, "再試行の後も失敗の表示が残っています")
    }

    /// 0 件にした後に失敗させて再読み込みすると、項目の代わりに「読み込めませんでした」と「再試行」が出ます。
    @MainActor
    func test最初の読み込みの失敗() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)
        setSwitch(Self.isEmpty, on: true, in: app)
        XCTAssertTrue(app.staticTexts[Self.empty].waitForExistence(timeout: 10), "0 件になっていません")
        setSwitch(Self.failsNextLoad, on: true, in: app)

        app.buttons[Self.reload].tap()

        XCTAssertTrue(app.staticTexts[Self.loadFailed].waitForExistence(timeout: 10), "失敗の表示が出ていません")
        XCTAssertTrue(app.buttons[Self.retry].waitUntilHittable(timeout: 10), "「再試行」を押せません")
        XCTAssertFalse(app.staticTexts[Self.empty].exists, "空の表示が残っています")
        XCTAssertFalse(app.staticTexts[Self.refreshFailed].exists, "0 件の失敗なのに「更新できませんでした」が出ています")
    }

    /// 「中身を 0 件にする」をオンにすると、その場で読み込み直して「項目がありません」が出ます。
    @MainActor
    func test0件にすると空の表示が出る() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)

        setSwitch(Self.isEmpty, on: true, in: app)

        XCTAssertTrue(app.staticTexts[Self.empty].waitForExistence(timeout: 10), "空の表示が出ていません")
        XCTAssertFalse(app.staticTexts["Item 1"].exists, "0 件なのに項目が残っています")
    }

    // MARK: - 取り直し

    /// 何ページか読み進めて途中で「再読み込み」すると、取り直しが終わった後に Item 1 から表示されます。
    @MainActor
    func test途中から再読み込みすると先頭から表示される() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)
        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts["Item 120"], timeout: 60),
            "Item 120 まで読み進められませんでした"
        )

        app.buttons[Self.reload].tap()

        XCTAssertTrue(app.staticTexts["Item 1"].waitUntilHittable(timeout: 10), "取り直しの後に先頭から表示されていません")
        XCTAssertFalse(app.staticTexts["Item 120"].exists, "取り直しの前の位置が残っています")
    }

    /// 次のページの読み込み中に「再読み込み」すると、取り直しの後は Item 1〜Item 50 だけが並び、
    /// 先に始めた読み込みのページは混ざりません。
    @MainActor
    func test追加読み込み中に再読み込みすると古いページが混ざらない() {
        // 最後の項目まで送る間に次のページの読み込みが終わらない長さにする。
        let delay = 10_000
        let app = launchPaging(delayMilliseconds: delay)
        XCTAssertTrue(app.staticTexts["Item 1"].waitForExistence(timeout: 30), "最初のページが出ていません")
        // 最後の項目まで送り、次のページの読み込み中の表示を出す。
        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts["Item 50"], timeout: 30),
            "最後の項目まで送れませんでした"
        )
        XCTAssertTrue(app.activityIndicators.firstMatch.waitForExistence(timeout: 5), "次のページの読み込み中の表示が出ていません")

        app.buttons[Self.reload].tap()

        XCTAssertTrue(app.staticTexts["Item 1"].waitUntilHittable(timeout: 30), "取り直しの後に先頭から表示されていません")
        // 先に始めた読み込みが戻る時刻を過ぎるまで待ってから、末尾の様子を見る。
        Thread.sleep(forTimeInterval: Double(delay) / 1_000)
        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts["Item 50"], timeout: 30),
            "取り直しの後に最後の項目まで送れませんでした"
        )
        XCTAssertFalse(app.staticTexts["Item 51"].exists, "先に始めた読み込みのページが混ざっています")
    }

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

    // MARK: - 操作のパネル

    /// 操作を畳むと丸いボタンだけが残り、広げると切り替えの状態を保ったまま元に戻ります。
    @MainActor
    func test畳んで広げる() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)
        setSwitch(Self.failsNextLoad, on: true, in: app)

        app.buttons[Self.fold].tap()

        XCTAssertTrue(app.buttons[Self.unfold].waitForExistence(timeout: 10), "丸いボタンが残っていません")
        XCTAssertFalse(app.switches[Self.failsNextLoad].exists, "畳んだのに切り替えが残っています")
        XCTAssertFalse(app.buttons[Self.reload].exists, "畳んだのに「再読み込み」が残っています")

        app.buttons[Self.unfold].tap()

        let restored = app.switches[Self.failsNextLoad]
        XCTAssertTrue(restored.waitForExistence(timeout: 10), "広げても操作が戻りません")
        XCTAssertEqual(restored.value as? String, "1", "広げた後に切り替えの状態が保たれていません")
        XCTAssertFalse(app.buttons[Self.unfold].exists, "広げたのに丸いボタンが残っています")
    }

    /// 操作を広げたまま末尾までスクロールすると、次のページの失敗の表示は操作のパネルの下に丸ごと見え、
    /// 「再試行」を押せます。畳んだときも、失敗の表示は丸いボタンの下に見えます。
    @MainActor
    func test末尾の表示が操作に隠れない() {
        let app = launchPaging(delayMilliseconds: 0)
        waitForFirstPage(in: app)
        setSwitch(Self.failsNextLoad, on: true, in: app)
        XCTAssertTrue(
            swipeUp(in: app, until: app.staticTexts[Self.loadFailed], timeout: 60),
            "次のページの失敗の表示が現れませんでした"
        )
        // 末尾まで送り切って静止させる。
        swipeUp(in: app, times: 2)

        let message = app.staticTexts[Self.loadFailed]
        let retry = app.buttons[Self.retry]
        XCTAssertTrue(retry.waitUntilHittable(timeout: 10), "「再試行」を押せません")
        // パネルの最下行 (説明の一行) より下にあれば、パネルに重なっていない。
        let panelBottom = app.staticTexts[Self.summary].frame.maxY
        XCTAssertGreaterThan(message.frame.minY, panelBottom, "失敗の文言が操作のパネルに重なっています")
        XCTAssertGreaterThan(retry.frame.minY, panelBottom, "「再試行」が操作のパネルに重なっています")
        XCTAssertLessThanOrEqual(retry.frame.maxY, app.windows.firstMatch.frame.maxY, "「再試行」が画面の外にあります")

        // 畳んでも一覧の余白は変わらず、失敗の表示は丸いボタンの下にある。
        app.buttons[Self.fold].tap()
        let handle = app.buttons[Self.unfold]
        XCTAssertTrue(handle.waitForExistence(timeout: 10), "丸いボタンが残っていません")
        XCTAssertGreaterThan(message.frame.minY, handle.frame.maxY, "失敗の文言が丸いボタンに重なっています")
        handle.tap()

        setSwitch(Self.failsNextLoad, on: false, in: app)
        XCTAssertTrue(retry.waitUntilHittable(timeout: 10), "広げ直した後に「再試行」を押せません")
        retry.tap()
        XCTAssertTrue(app.staticTexts["Item 51"].waitForExistence(timeout: 10), "「再試行」が効いていません")
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

    /// 一覧を決まった回数だけ上へ送る。
    @MainActor
    private func swipeUp(in app: XCUIApplication, times: Int) {
        let collection = app.collectionViews.firstMatch
        for _ in 0..<times {
            collection.swipeUp(velocity: .fast)
        }
    }
}
