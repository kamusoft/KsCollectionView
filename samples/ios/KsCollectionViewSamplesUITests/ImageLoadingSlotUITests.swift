import XCTest

/// 読み込み中の計数の分類と観測区間が、実際に動かした画像グリッドで働くことを確かめます。
///
/// 判定に使うのは枠の決まった読み込み中 (`sized`) の側で、しかも**基準点からの差分**です。
/// どちらもコード読解だけで支えられていると、枠の未確定 (`unsized`) へ倒れていても、基準点が
/// 切れていなくても気づけないため、実機と同じ経路で確かめます
/// (Android の `ImageLoadingSlotCounterTest` に対応)。
final class ImageLoadingSlotUITests: XCTestCase {
    @MainActor
    func test数える起動では画像グリッドの印に枠の決まった読み込み中が出る() {
        let app = launchCountingImageGrid()
        let mark = markElement(in: app)

        // 取得の成否に依らず、枠が決まった状態の読み込み中は現れる。取得結果を待たない。
        // `unsized=` にも "sized=" が含まれるため、直前の空白まで込みで見分ける。
        assertLabelMatches(
            mark,
            pattern: ".* sized=[1-9][0-9]* .*",
            message: "枠の決まった読み込み中が数えられませんでした"
        )
    }

    /// 印を叩くと観測区間が切り替わり、そこから先の差分だけが `sized` に出ることを確かめます。
    ///
    /// 「戻ってきたときの再表示」は初回表示を含む累計では判定できないため、この操作が実機で
    /// 効くことが計測手順そのものの前提になります。
    @MainActor
    func test印を叩くと観測区間が切り替わり差分が数え直される() {
        let app = launchCountingImageGrid()
        let mark = markElement(in: app)

        // 初回表示で数えられるのを待ってから基準点を切る (計測手順と同じ順序)。
        assertLabelMatches(
            mark,
            pattern: ".* sized=[1-9][0-9]* .*",
            message: "基準点を切る前に読み込み中が数えられませんでした"
        )
        mark.tap()

        // 区間の通し番号が進み、累計は残ったまま差分だけが 0 に戻る。差分が 0 に戻ることまで
        // 見ないと、基準点を覚えずに通し番号だけ進める実装でも通ってしまう。
        // 叩いた後にスクロールしなければ新しい読み込み中は起きないため、差分は 0 のままになる。
        assertLabelMatches(
            mark,
            pattern: "slots session=[1-9][0-9]* items=[0-9]+ sized=0 unsized=0 lines=0"
                + " total=[1-9][0-9]*/.*",
            message: "印を叩いても差分が数え直されませんでした"
        )
    }

    /// 計数の印を取り出します。
    @MainActor
    private func markElement(in app: XCUIApplication) -> XCUIElement {
        let mark = app.staticTexts["imageLoadingSlot.tally"]
        XCTAssertTrue(mark.waitForExistence(timeout: 30), "計数の印が現れませんでした")
        return mark
    }

    /// 印の文字列が指定の形になるまで待ち、ならなければ実測値を添えて失敗させます。
    ///
    /// - Parameters:
    ///   - mark: 計数の印
    ///   - pattern: 期待する形
    ///   - message: 失敗したときの説明
    @MainActor
    private func assertLabelMatches(
        _ mark: XCUIElement,
        pattern: String,
        message: String
    ) {
        let predicate = NSPredicate(format: "label MATCHES %@", pattern)
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: mark)],
            timeout: 30
        )
        XCTAssertEqual(result, .completed, "\(message): \(mark.label)")
    }

    /// 数える起動引数を付けて画像グリッドを開きます。
    ///
    /// 前回の実行で残ったインスタンスに `launch()` が束縛されると、起動引数と違う画面のまま
    /// 進んでしまうため、終了させてから起動し直します。
    @MainActor
    private func launchCountingImageGrid() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screen", "画像グリッド",
            "--count-image-loading-slots",
        ]
        app.terminate()
        app.launch()
        return app
    }
}
