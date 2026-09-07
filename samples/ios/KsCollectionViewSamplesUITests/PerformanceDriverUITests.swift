import XCTest

/// 計測専用のドライバです。アサーションを持たず、Instruments からの計測窓を開くために動かします。
/// 通常のテストスイート (`KsCollectionViewSamples` スキーム) からは除外し、
/// `KsCollectionViewSamplesPerformance` スキームでのみ実行します。
final class PerformanceDriverUITests: XCTestCase {
    @MainActor
    func test大量件数を3秒間連続フリックスクロールする() {
        let app = XCUIApplication(bundleIdentifier: "jp.kamusoft.kscollectionview.samples.ios")
        let attachesToExistingApp = ProcessInfo.processInfo.environment["KS_PERF_ATTACH_EXISTING"] == "1"
        if attachesToExistingApp {
            // Instruments の接続完了後に、起動済みの Release app を前面化します。
            Thread.sleep(forTimeInterval: 20)
            app.activate()
        } else {
            app.launchArguments = ["--screen", "大量件数"]
            app.launch()
        }

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 3))
        if !attachesToExistingApp {
            // Instruments が実機プロセスへ接続するための待機窓です。
            Thread.sleep(forTimeInterval: 5)
        }
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            collection.swipeUp(velocity: .fast)
        }
    }

    /// 画像グリッドを 3 秒間フリックします。起動済みの app に接続して測る使い方も同じ環境変数で選べます。
    @MainActor
    func test画像グリッドを3秒間連続フリックスクロールする() {
        let app = XCUIApplication(bundleIdentifier: "jp.kamusoft.kscollectionview.samples.ios")
        let attachesToExistingApp = ProcessInfo.processInfo.environment["KS_PERF_ATTACH_EXISTING"] == "1"
        if attachesToExistingApp {
            // Instruments の接続完了後に、起動済みの Release app を前面化します。
            Thread.sleep(forTimeInterval: 20)
            app.activate()
        } else {
            app.launchArguments = ["--screen", "画像グリッド"]
            app.launch()
        }

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 5))
        if !attachesToExistingApp {
            // Instruments が実機プロセスへ接続するための待機窓です。
            Thread.sleep(forTimeInterval: 5)
        }
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            collection.swipeUp(velocity: .fast)
        }
    }

    /// 1 往復は端点間のジャンプではなく可視範囲の半分ずつ送る全件走査のため、往復ごとの待ち時間を長めに取ります。
    @MainActor
    func test大量件数を全件通過で2往復してメモリを表示する() {
        let app = XCUIApplication()
        app.launchArguments = ["--verify-performance"]
        app.terminate()
        app.launch()

        let roundTrip = app.buttons["performance.roundTrip"]
        XCTAssertTrue(roundTrip.waitForExistence(timeout: 10))

        // 通過件数は往復ごとに数え直されるため、各往復の直後に全項目を通過したことを確認する。
        // 刻みが可視範囲より粗いと通過しない項目が残る。
        roundTrip.tap()
        XCTAssertTrue(app.staticTexts["performance.completedRoundTrips"]
            .waitForLabel("完了: 1", timeout: 300))
        let first = app.staticTexts["performance.memory.first"].label
        XCTAssertTrue(first.hasSuffix(" bytes"), first)
        XCTAssertEqual(
            app.staticTexts["performance.visitedItems"].label,
            "直近往復の通過: 10000 / 10000"
        )

        roundTrip.tap()
        XCTAssertTrue(app.staticTexts["performance.completedRoundTrips"]
            .waitForLabel("完了: 2", timeout: 300))
        let second = app.staticTexts["performance.memory.second"].label
        XCTAssertTrue(second.hasSuffix(" bytes"), second)
        XCTAssertEqual(
            app.staticTexts["performance.visitedItems"].label,
            "直近往復の通過: 10000 / 10000"
        )
    }
}
