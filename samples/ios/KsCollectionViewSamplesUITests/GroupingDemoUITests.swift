import XCTest

/// 「グループ化」「差分更新」の 2 画面が、メニューの決まった位置にあり、起動引数で直接開けて、
/// 操作で配列を組み替えられることを確かめます。
final class GroupingDemoUITests: XCTestCase {
    /// メニューで「画像グリッド」の次に「グループ化」、その次に「差分更新」が並びます
    /// (Android Sample と同じ位置)。
    @MainActor
    func testメニューの画像グリッドの次にグループ化と差分更新が並ぶ() {
        let app = XCUIApplication()
        app.launch()

        let titles = ["画像グリッド", "グループ化", "差分更新"]
        let items = titles.map { app.buttons[$0] }
        for (title, item) in zip(titles, items) {
            XCTAssertTrue(item.waitForExistence(timeout: 30), "メニューに「\(title)」がありません")
        }
        let tops = items.map(\.frame.minY)
        XCTAssertEqual(tops, tops.sorted(), "メニューの並びが「画像グリッド」「グループ化」「差分更新」の順ではありません")
    }

    /// 「グループ化」を起動引数で直接開くと先頭のグループの見出しが出て、並び順の反転で
    /// 最後のグループが先頭へ来ます。
    @MainActor
    func testグループ化を起動引数で開き並び順を反転できる() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "グループ化"]
        app.launch()

        XCTAssertTrue(
            header(beginningWith: "グループ 1、1,200 件", in: app).waitForExistence(timeout: 30),
            "先頭のグループの見出し (1,200 件) が表示されていません"
        )

        app.buttons["並び順を反転"].tap()
        XCTAssertTrue(
            header(beginningWith: "グループ 378、", in: app).waitForExistence(timeout: 10),
            "反転後に最後のグループが先頭へ来ていません"
        )
        XCTAssertTrue(app.staticTexts["Item 9978"].waitForExistence(timeout: 10))
    }

    /// 表示中の項目を別のグループへ移すと、移した先と元のグループの見出しの件数が変わります。
    @MainActor
    func testグループ化で表示中の項目を別のグループへ移すと件数が変わる() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "グループ化"]
        app.launch()

        // 反転して小さいグループを先頭に出し、見出しを 2 つ以上画面に載せる。
        app.buttons["並び順を反転"].tap()
        let first = header(beginningWith: "グループ 378、", in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 30))
        let before = headerLabels(in: app)

        app.buttons["項目を別のグループへ"].tap()
        let changed = expectation(for: NSPredicate { _, _ in
            self.headerLabels(in: app) != before
        }, evaluatedWith: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [changed], timeout: 10),
            .completed,
            "見出しの件数が変わりませんでした (操作前: \(before))"
        )
    }

    /// 「差分更新」を起動引数で直接開き、挿入・更新・グループの切り替え・元に戻すが反映されます。
    @MainActor
    func test差分更新を起動引数で開き操作が反映される() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "差分更新"]
        app.launch()

        XCTAssertTrue(
            header(beginningWith: "グループ A、", in: app).waitForExistence(timeout: 30),
            "グループ A の見出しが表示されていません"
        )
        XCTAssertTrue(app.staticTexts["Item 1"].exists)

        // 先頭への挿入。新しい ID は 21 から振られ、先頭のグループに入る。
        app.buttons["挿入"].tap()
        XCTAssertTrue(app.staticTexts["Item 21"].waitForExistence(timeout: 10), "挿入した項目が見えません")
        XCTAssertTrue(header(beginningWith: "グループ A、6 件", in: app).waitForExistence(timeout: 10))

        // 更新は同じ位置の項目の文言に印を付ける。
        app.buttons["更新"].tap()
        XCTAssertTrue(app.staticTexts["Item 21 ★"].waitForExistence(timeout: 10), "更新が反映されていません")

        // グループなしに切り替えると見出しが消える。
        // スイッチの要素は文言とつまみを含むため、つまみの側 (右端寄り) を押す。
        app.switches["グループ"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            .tap()
        let noHeader = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: header(beginningWith: "グループ A、", in: app)
        )
        XCTAssertEqual(XCTWaiter.wait(for: [noHeader], timeout: 10), .completed, "見出しが消えていません")

        // 元に戻すと初期の 20 件に戻る。
        app.buttons["元に戻す"].tap()
        let removed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.staticTexts["Item 21 ★"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 10), .completed, "元に戻っていません")
        XCTAssertTrue(app.staticTexts["Item 1"].exists)
    }

    /// グループありで全ての位置の全ての操作を繰り返しても、同じグループが離れて現れる不正な入力に
    /// ならないことを確かめます。Debug 構成では不正な入力でアプリが停止するため、操作の後も画面が
    /// 残っていることで確かめます。
    @MainActor
    func test差分更新でグループありの操作を繰り返しても不正な入力にならない() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "差分更新"]
        app.launch()
        XCTAssertTrue(app.buttons["挿入"].waitForExistence(timeout: 30))

        for _ in 0..<2 {
            for position in ["先頭", "中ほど", "末尾"] {
                app.buttons[position].tap()
                for operation in ["挿入", "移動", "更新", "削除", "移動"] {
                    app.buttons[operation].tap()
                }
            }
            app.buttons["反転"].tap()
            app.buttons["シャッフル"].tap()
            app.buttons["移動"].tap()
        }

        XCTAssertEqual(app.state, .runningForeground, "操作の途中でアプリが停止しました")
        XCTAssertTrue(
            header(beginningWith: "グループ ", in: app).waitForExistence(timeout: 10),
            "操作の後に見出しが表示されていません"
        )
    }

    /// グループなしで配列を崩す操作 (シャッフル・移動) をしてからグループありに切り替えても、
    /// 同じグループが離れて現れる不正な入力にならないことを確かめます。切り替えと並べ直しが
    /// 別の更新だと、並べ直す前の配列が一度グループありで渡り、Debug 構成ではアプリが停止します。
    @MainActor
    func test差分更新でグループなしで崩してからグループありにしても不正な入力にならない() {
        // 停止した後の操作で失敗を重ねないよう、最初の失敗で止める。
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "差分更新"]
        app.launch()
        XCTAssertTrue(
            header(beginningWith: "グループ A、", in: app).waitForExistence(timeout: 30),
            "グループ A の見出しが表示されていません"
        )

        // シャッフルで崩す経路と、移動で崩す経路の 2 周。グループなしでは、移動は項目を
        // 件数の半分先 (末尾を越えたら先頭から数える) へ移す。グループ単位に並んだ 20 件で
        // 中ほど (10 番目) の項目を 1 回移すと配列の先頭へ入り、その項目のグループが離れて現れる
        // (続けて先頭の項目を移すと元の並びに戻るため、移動は 1 回だけにする)。
        for breaking in [["シャッフル"], ["中ほど", "移動"]] {
            toggleGrouping(in: app)
            let noHeader = expectation(
                for: NSPredicate(format: "exists == false"),
                evaluatedWith: header(beginningWith: "グループ ", in: app)
            )
            XCTAssertEqual(XCTWaiter.wait(for: [noHeader], timeout: 10), .completed, "見出しが消えていません")

            for operation in breaking {
                app.buttons[operation].tap()
            }
            toggleGrouping(in: app)

            XCTAssertTrue(
                header(beginningWith: "グループ ", in: app).waitForExistence(timeout: 10),
                "グループありに切り替えた後に見出しが表示されていません (崩した操作: \(breaking))"
            )
            XCTAssertEqual(app.state, .runningForeground, "グループありへの切り替えでアプリが停止しました")
        }
    }

    /// 「グループ」のスイッチを切り替えます。スイッチの要素は文言とつまみを含むため、つまみの側
    /// (右端寄り) を押します。
    @MainActor
    private func toggleGrouping(in app: XCUIApplication) {
        app.switches["グループ"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            .tap()
    }

    /// 見出しは名前と件数をまとめた 1 要素 (「グループ A、5 件」の形) として読まれるため、先頭一致で探します。
    @MainActor
    private func header(beginningWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }

    /// 画面に載っている見出しの文言。
    @MainActor
    private func headerLabels(in app: XCUIApplication) -> [String] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "グループ "))
            .allElementsBoundByIndex
            .map(\.label)
            .sorted()
    }
}
