import XCTest

/// 件数を指定して開いた「大量件数」画面の計測の帯で、実際に一覧を送って計数を読み、数え直せることを
/// 確かめます。
final class LargeDataCountUITests: XCTestCase {
    #if DEBUG
    /// Debug 構成では帯に計数と操作が出て、数え直しで区間を切れることを確かめます。
    ///
    /// 計数は区間を切って読めることが値の前提です。数え直しが効いていないと、読んだ値に
    /// 操作列より前の表示分が混ざり、不一致率が操作量に依らない値として読めなくなります。
    @MainActor
    func test数え直すと読み直した計数に数え直す前の分が入らない() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "大量件数", "--large-count", "2000"]
        app.launch()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 30), "一覧が現れませんでした")
        let tally = app.staticTexts["largeData.selfSizingTally"]
        let read = app.buttons["largeData.readTally"]
        let reset = app.buttons["largeData.resetTally"]
        XCTAssertTrue(tally.waitForExistence(timeout: 30), "計数が表示されていません")
        XCTAssertTrue(read.waitUntilHittable(timeout: 30), "計数を読む操作がありません")
        XCTAssertTrue(reset.waitUntilHittable(timeout: 30), "計数を数え直す操作がありません")

        // 先に長めに送って、数え直しの前の分を十分に貯める。
        // 操作の反映は配送より後に起きるため、読む前に帯の文言が動くのを実時間の期限付きで待つ。
        swipeUp(collection, times: 6)
        // 帯は画面が現れた時点の計数を出しているため、送った分が入ったことは文言が変わることで見る。
        let labelBeforeRead = tally.label
        read.tap()
        XCTAssertTrue(
            tally.waitForLabel(timeout: 10) {
                $0 != labelBeforeRead && Self.selfSizedCellCount(in: $0) > 0
            },
            "送った後の計数が帯に現れていません: \(tally.label)"
        )
        let beforeReset = Self.selfSizedCellCount(in: tally.label)

        reset.tap()
        XCTAssertTrue(
            tally.waitForLabel(timeout: 10) { Self.selfSizedCellCount(in: $0) == 0 },
            "数え直した直後に計数が 0 に戻っていません: \(tally.label)"
        )

        // 数え直した後の区間はさっきより短くする。読んだ値が前の分を含んでいれば、
        // 短い区間なのに前の値より大きくなる。
        swipeUp(collection, times: 1)
        read.tap()
        XCTAssertTrue(
            tally.waitForLabel(timeout: 10) { Self.selfSizedCellCount(in: $0) > 0 },
            "数え直した後の送りが計数に現れていません: \(tally.label)"
        )
        let afterReset = Self.selfSizedCellCount(in: tally.label)
        XCTAssertLessThan(
            afterReset,
            beforeReset,
            "数え直した後の計数に、数え直す前の分が残っています: \(tally.label)"
        )
    }

    /// 一覧を上へ送ります。慣性で止まる位置が揺れないよう、指を離す前に止めます。
    ///
    /// - Parameters:
    ///   - collection: 操作する一覧
    ///   - times: 繰り返す回数
    @MainActor
    private func swipeUp(_ collection: XCUIElement, times: Int) {
        let near = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let far = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        for _ in 0..<times {
            near.press(
                forDuration: 0.05,
                thenDragTo: far,
                withVelocity: .slow,
                thenHoldForDuration: 0.5
            )
        }
    }

    /// 帯の文言から、自己サイズを返したセル数を取り出します。
    ///
    /// - Parameter label: 帯の文言 (`自己サイズ: N / 不一致: M (R)`)
    /// - Returns: セル数。読み取れなければ `-1`
    private static func selfSizedCellCount(in label: String) -> Int {
        guard let range = label.range(of: "自己サイズ: ") else { return -1 }
        let rest = label[range.upperBound...]
        return Int(rest.prefix { $0.isNumber }) ?? -1
    }
    #endif
}
