import XCTest

/// 「並べ替え」画面で、実際の長押しからのドラッグで項目を並べ替えられることと、操作の切り替え
/// (並べ替えのスイッチ・グループ・グループをまたがせない・置いても受け入れない) が効くことを確かめます。
///
/// iOS の並べ替えは UIKit のドラッグ & ドロップで動くため、置く先の隙間は UIKit の標準の決め方に従います。
/// 置く位置は、持ち上げた項目が抜けて開く隙間の真ん中へ指を運んで決めます。
final class ReorderDemoUITests: XCTestCase {
    /// 画面の名前 (ルートメニューの文言と同じ)。
    private static let screen = "並べ替え"

    // 画面の文言 (Sample の `ReorderDemoText` と同じ値)。
    private static let reorder = "並べ替え"
    private static let grouped = "グループ"
    private static let keepsGroups = "グループをまたがせない"
    private static let rejectsMoves = "置いても受け入れない"
    private static let summary = "全 10,000 件・10 の倍数は移動不可"
    private static let rejected = "並べ替えを受け入れませんでした"
    private static let fold = "操作を畳む"
    private static let unfold = "操作を広げる"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 構成

    /// ルートメニューで「並べ替え」が「ページング」のすぐ下にあり、開くとタイトルが「並べ替え」になります。
    @MainActor
    func testメニューでページングの次にある() {
        let app = XCUIApplication()
        app.launch()

        let previous = app.buttons["ページング"]
        let target = app.buttons[Self.screen]
        XCTAssertTrue(app.buttons["リスト"].waitForExistence(timeout: 30), "メニューが現れませんでした")
        let menu = app.collectionViews.firstMatch
        let deadline = Date().addingTimeInterval(30)
        while !(target.exists && target.isHittable && previous.exists), Date() < deadline {
            menu.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(target.isHittable, "メニューに「並べ替え」がありません")
        XCTAssertTrue(previous.exists, "メニューに「ページング」がありません")
        XCTAssertLessThan(previous.frame.minY, target.frame.minY, "「ページング」より上にあります")

        target.tap()
        XCTAssertTrue(
            app.navigationBars[Self.screen].waitForExistence(timeout: 10),
            "開いた画面のタイトルが「並べ替え」ではありません"
        )
    }

    /// 起動引数で直接開くと、グループ 1 の見出しと Item 1 から並び、10 の倍数には「(移動不可)」が添えられ、
    /// 切り替えは並べ替えとグループだけがオンです。
    @MainActor
    func test直接開くと初期の並びと切り替えが出る() {
        let app = launchReorder()

        XCTAssertTrue(app.staticTexts["Item 10 (移動不可)"].exists, "10 の倍数に「(移動不可)」が添えられていません")
        XCTAssertFalse(app.staticTexts["Item 9 (移動不可)"].exists)
        XCTAssertTrue(header("グループ 1", in: app).exists, "グループ 1 の見出しがありません")
        XCTAssertTrue(app.staticTexts[Self.summary].exists, "説明の一行がありません")
        XCTAssertTrue(toggle(Self.reorder, in: app).isSelected, "並べ替えが初めからオンではありません")
        XCTAssertTrue(toggle(Self.grouped, in: app).isSelected, "グループが初めからオンではありません")
        XCTAssertFalse(toggle(Self.keepsGroups, in: app).isSelected, "グループをまたがせないが初めからオンです")
        XCTAssertFalse(toggle(Self.rejectsMoves, in: app).isSelected, "置いても受け入れないが初めからオンです")
        assertOrder([1, 2, 3, 4, 5], in: app)
    }

    // MARK: - 並べ替え

    /// Item 1 を長押しして Item 3 と Item 4 の間に置くと、Item 2, 3, 1, 4 の順に並びます。
    @MainActor
    func test項目を並べ替える() {
        let app = launchReorder()

        drag(item(1, in: app), toGapBelow: item(3, in: app), in: app)

        assertOrder([2, 3, 1, 4], in: app)
    }

    /// グループ 1 の Item 1 をグループ 2 の Item 101 と Item 102 の間に置くと、Item 1 はグループ 2 の中の
    /// Item 101 と Item 102 の間に並びます。
    ///
    /// Item 1 と Item 101 は 1 画面に収まらないため、Item 1 をグループ 1 の中で見えている範囲の下の方へ
    /// 置き直しては一覧を送る、を Item 101 が Item 1 の下に見えるまで繰り返してから、境目へ運びます。
    ///
    /// 別のグループ (別のセクション) の項目の上で指を止めると、置く先の隙間はその項目の前に開く (UIKit 標準の
    /// 並べ替えで、隙間は指を止めてから動く)。このため Item 102 の上で指を止めて、Item 101 と Item 102 の間に置く。
    @MainActor
    func test別のグループへ動かす() {
        let app = launchReorder()
        foldPanel(in: app)

        bringItemOneAboveGroupTwo(in: app)
        drag(item(1, in: app), onto: item(102, in: app), in: app)

        assertOrder([101, 1, 102], in: app)
        XCTAssertLessThan(
            header("グループ 2", in: app).frame.maxY, item(1, in: app).frame.minY,
            "Item 1 がグループ 2 の見出しより下にありません"
        )
    }

    /// 「Item 10 (移動不可)」を長押しして指を動かしても、ドラッグは始まらず並びは変わりません。
    @MainActor
    func test動かせない項目() {
        let app = launchReorder()
        let unmovable = app.staticTexts["Item 10 (移動不可)"]

        drag(unmovable, onto: item(7, in: app), in: app)

        assertOrder([7, 8, 9], in: app)
        XCTAssertLessThan(item(9, in: app).frame.minY, unmovable.frame.minY, "動かせない項目が動いています")
        XCTAssertLessThan(item(9, in: app).frame.maxY, unmovable.frame.midY)
    }

    // MARK: - 長押し

    /// 並べ替えのスイッチをオフにして Item 5 を長押しすると「長押し: Item 5」が出て、指を動かしても
    /// ドラッグは始まりません。
    @MainActor
    func testスイッチを切ると長押しの知らせになる() {
        let app = launchReorder()
        setToggle(Self.reorder, on: false, in: app)

        // 帯は 3 秒で消えるため、まず指を動かさずに長押しして帯を見る。
        item(5, in: app).press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["長押し: Item 5"].waitForExistence(timeout: 3), "「長押し: Item 5」が出ていません")

        // 長押しから指を動かしても、ドラッグは始まらない。
        drag(item(5, in: app), onto: item(7, in: app), in: app)
        assertOrder([4, 5, 6, 7], in: app)
    }

    /// 並べ替えのスイッチがオンの間は、Item 5 を長押ししても「長押し: Item 5」は出ず、ドラッグが始まって
    /// Item 6 と Item 7 の間に置けます。
    @MainActor
    func testスイッチがオンの間は長押しの知らせが出ない() {
        let app = launchReorder()

        drag(item(5, in: app), toGapBelow: item(7, in: app), in: app)

        assertOrder([4, 6, 7, 5, 8], in: app)
        XCTAssertFalse(app.staticTexts["長押し: Item 5"].exists, "オンの間に長押しの知らせが出ています")
    }

    // MARK: - 受け入れない・またがせない

    /// 「置いても受け入れない」をオンにして Item 1 を Item 3 と Item 4 の間に置くと、「並べ替えを受け入れません
    /// でした」が出て、Item 1 は元の位置に戻ります。帯はバーのすぐ下に出て 3 秒ほどで消えます。
    @MainActor
    func test受け入れないと元に戻る() {
        let app = launchReorder()
        setToggle(Self.rejectsMoves, on: true, in: app)

        drag(item(1, in: app), toGapBelow: item(3, in: app), in: app)

        let banner = app.staticTexts[Self.rejected]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "「並べ替えを受け入れませんでした」が出ていません")
        let bar = app.navigationBars[Self.screen]
        XCTAssertGreaterThanOrEqual(banner.frame.minY, bar.frame.maxY, "帯がバーに重なっています")
        XCTAssertLessThan(banner.frame.minY, bar.frame.maxY + 40, "帯がバーのすぐ下にありません")
        assertOrder([1, 2, 3, 4], in: app)
        XCTAssertTrue(banner.waitForNonExistence(timeout: 8), "帯が消えません")
    }

    /// 「グループをまたがせない」をオンにして、グループ 1 の Item 1 をグループ 2 の中 (Item 101 と Item 102 の間)
    /// へ運んで指を離すと、Item 1 はグループ 2 に入らず、運ぶ前の位置 (グループ 1 の中) に戻ります。
    @MainActor
    func testグループをまたがせない() {
        let app = launchReorder()
        setToggle(Self.keepsGroups, on: true, in: app)
        foldPanel(in: app)

        // グループ 1 の中での置き直しは許される。
        bringItemOneAboveGroupTwo(in: app)
        let before = neighbors(of: 1, in: app)

        drag(item(1, in: app), toGapBelow: item(101, in: app), in: app)

        assertOrder([101, 102], in: app)
        let settled = waitUntilSettled([item(1, in: app), header("グループ 2", in: app)]) { _ in true }
        XCTAssertTrue(settled.settled, "Item 1 と見出しの位置が静止しませんでした (\(settled.frames))")
        XCTAssertLessThan(
            item(1, in: app).frame.maxY, header("グループ 2", in: app).frame.minY,
            "Item 1 がグループ 2 に入っています"
        )
        XCTAssertEqual(neighbors(of: 1, in: app), before, "Item 1 が運ぶ前の位置に戻っていません")
    }

    // MARK: - グリッド・グループなし

    /// 2 列のグリッドに切り替えてグループをオフにし、Item 1 を Item 3 と Item 4 の間に置くと、
    /// Item 2, 3, 1, 4 の順に並びます (2 列なので 1 行目が Item 2・Item 3、2 行目が Item 1・Item 4)。
    @MainActor
    func testグリッドとグループなしでも並べ替えられる() {
        let app = launchReorder()
        app.buttons["グリッド"].tap()
        setToggle(Self.grouped, on: false, in: app)
        XCTAssertTrue(header("グループ 1", in: app).waitForNonExistence(timeout: 10), "グループの見出しが消えません")

        let one = item(1, in: app)
        let four = item(4, in: app)
        // 2 列なので、Item 1 が抜けると Item 2・Item 3 が 1 つずつ前へ詰まり、置く先の隙間は持ち上げる前の
        // Item 3 の場所 (2 行目の左) に開く。
        drag(one, onto: item(3, in: app), in: app)

        assertGridOrder([2, 3, 1, 4], in: app)
        XCTAssertEqual(four.frame.minY, one.frame.minY, accuracy: 1, "Item 1 が Item 4 と同じ行にありません")
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

    /// 番号の項目。動かせない項目 (10 の倍数) は「(移動不可)」を添えたタイトルで探す。
    @MainActor
    private func anyItem(_ number: Int, in app: XCUIApplication) -> XCUIElement {
        number.isMultiple(of: 10) ? app.staticTexts["Item \(number) (移動不可)"] : item(number, in: app)
    }

    /// グループの見出し (名前と件数をまとめた要素)。
    @MainActor
    private func header(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name)、")).firstMatch
    }

    /// 操作のパネルの切り替えのボタン。
    @MainActor
    private func toggle(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", title)).element(boundBy: 0)
    }

    /// 切り替えのボタンを指定の状態にする。押した後は状態が変わるまで待つ。
    @MainActor
    private func setToggle(_ title: String, on: Bool, in app: XCUIApplication) {
        let element = toggle(title, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 10), "切り替え「\(title)」がありません")
        guard element.isSelected != on else { return }
        element.tap()
        let predicate = NSPredicate(format: "selected == %@", NSNumber(value: on))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 10), .completed,
            "切り替え「\(title)」が \(on ? "オン" : "オフ") になりません"
        )
    }

    /// 操作のパネルを畳み、一覧を広く見えるようにする。
    @MainActor
    private func foldPanel(in app: XCUIApplication) {
        app.buttons[Self.fold].tap()
        XCTAssertTrue(app.buttons[Self.unfold].waitForExistence(timeout: 10), "パネルを畳めません")
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

    /// 要素を長押しして、`destination` の真ん中へ指を運んで離す。動かないことを確かめる操作と、別のセクションの
    /// 項目の前に置く操作に使う。
    @MainActor
    private func drag(_ element: XCUIElement, onto destination: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitUntilHittable(timeout: 10), "\(element) を押せません")
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "\(destination) がありません")
        let target = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: destination.frame.midX, dy: destination.frame.midY))
        drag(element, to: target)
    }

    /// 要素を長押しして持ち上げ、`target` へ運んで少し止めてから離す。置いた後の動きが収まるのは、並びを
    /// 確かめる側 (`assertOrder` など) が条件を観測して待つ。
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
    /// 区切り、超えたら最後に読んだ frame を返して `settled` を false にする。置いた・戻した動きの途中の位置で
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

    /// 2 列のグリッドで、項目が左上から行ごとに指定の順に並び、動きが収まっていることを確かめる。
    @MainActor
    private func assertGridOrder(_ numbers: [Int], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let elements = numbers.map { item($0, in: app) }
        for (number, element) in zip(numbers, elements) {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "Item \(number) がありません", file: file, line: line)
        }
        let keys = { (frames: [CGRect]) in frames.map { (row: Int(($0.midY).rounded()), column: $0.midX) } }
        let isOrdered = { (frames: [CGRect]) -> Bool in
            let current = keys(frames)
            let sorted = current.sorted { $0.row != $1.row ? $0.row < $1.row : $0.column < $1.column }
            return current.map { "\($0.row):\($0.column)" } == sorted.map { "\($0.row):\($0.column)" }
        }
        let result = waitUntilSettled(elements, where: isOrdered)
        if !result.settled {
            let positions = keys(result.frames).map { "\($0.row):\($0.column)" }
            XCTFail("並びが \(numbers) の順で静止しませんでした (行:列 \(positions))", file: file, line: line)
        }
    }

    /// 見えている項目のうち、指定の項目のすぐ上と下の項目の番号 (見えていなければ nil)。
    @MainActor
    private func neighbors(of number: Int, in app: XCUIApplication) -> [Int?] {
        let target = item(number, in: app).frame
        let rows = app.staticTexts.allElementsBoundByIndex
            .filter { $0.label.hasPrefix("Item ") }
            .compactMap { element -> (Int, CGRect)? in
                let digits = element.label.dropFirst("Item ".count).prefix { $0.isNumber }
                guard let value = Int(digits), value != number else { return nil }
                return (value, element.frame)
            }
        let above = rows.filter { $0.1.maxY <= target.minY + 1 }.max { $0.1.maxY < $1.1.maxY }?.0
        let below = rows.filter { $0.1.minY >= target.maxY - 1 }.min { $0.1.minY < $1.1.minY }?.0
        return [above, below]
    }

    /// Item 1 を、グループ 1 の中で見えている範囲の下の方へ置き直しては一覧を送る、を繰り返し、Item 101 が
    /// Item 1 より下に見える位置まで運ぶ。上限は実時間で区切る。
    @MainActor
    private func bringItemOneAboveGroupTwo(in app: XCUIApplication) {
        let one = item(1, in: app)
        let deadline = Date().addingTimeInterval(240)
        let window = app.windows.firstMatch.frame
        let handleTop = app.buttons[Self.unfold].frame.minY
        while Date() < deadline {
            if item(101, in: app).exists, item(101, in: app).frame.minY > one.frame.maxY,
               item(101, in: app).frame.maxY < handleTop {
                return
            }
            // Item 1 より下で、丸いボタンより上に見えているグループ 1 の項目のうち、いちばん下のもの。
            let candidates = app.staticTexts.allElementsBoundByIndex
                .filter { $0.label.hasPrefix("Item ") }
                .compactMap { element -> (Int, CGRect)? in
                    let digits = element.label.dropFirst("Item ".count).prefix { $0.isNumber }
                    guard let value = Int(digits), value <= 100 else { return nil }
                    return (value, element.frame)
                }
                .filter { $0.1.minY > one.frame.maxY && $0.1.maxY < handleTop - 20 }
            guard let lowest = candidates.max(by: { $0.1.minY < $1.1.minY }) else {
                XCTFail("Item 1 より下に置き直せる項目が見えていません")
                return
            }
            drag(one, toGapBelow: anyItem(lowest.0, in: app), in: app)
            let settled = waitUntilSettled([one]) { _ in true }
            XCTAssertTrue(settled.settled, "置き直した Item 1 の位置が静止しませんでした (\(settled.frames))")
            // Item 1 が画面の上の方 (見出しのすぐ下) に来るまで一覧を送る。
            let distance = one.frame.minY - (window.minY + 200)
            if distance > 0 {
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: window.width - 30, dy: window.minY + 200 + distance))
                start.press(
                    forDuration: 0.05,
                    thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.5
                )
            }
        }
        XCTFail("Item 101 が Item 1 の下に見える位置まで運べませんでした")
    }
}
