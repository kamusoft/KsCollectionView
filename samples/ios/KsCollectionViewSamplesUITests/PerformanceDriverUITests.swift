import CoreFoundation
import XCTest

/// 計測専用のドライバです。アサーションを持たず、Instruments からの計測窓を開くために動かします。
/// 通常のテストスイート (`KsCollectionViewSamples` スキーム) からは除外し、
/// `KsCollectionViewSamplesPerformance` スキームでのみ実行します。
final class PerformanceDriverUITests: XCTestCase {
    @MainActor
    func test大量件数を3秒間連続フリックスクロールする() {
        let app = XCUIApplication(bundleIdentifier: Self.sampleBundleIdentifier)
        let attachesToExistingApp = ProcessInfo.processInfo.environment["KS_PERF_ATTACH_EXISTING"] == "1"
        if attachesToExistingApp {
            // 記録側の準備が済むのを待ってから、起動済みの app を前面化します。
            Thread.sleep(forTimeInterval: Self.attachWaitSeconds)
            app.activate()
        } else {
            // 起動より前に置く待ち窓です。計測では、この間に測る構成の app を入れ直します
            // (このテスト自身が入れる構成とは別の構成を測るため)。
            Thread.sleep(forTimeInterval: Self.prelaunchHoldSeconds)
            app.launchArguments = ["--screen", "大量件数", "--signpost-scroll-window"]
            app.launch()
        }

        flickForFixedWindow(in: app, waitsForRecorder: !attachesToExistingApp)
    }

    /// 画像グリッドを 3 秒間フリックします。起動済みの app に接続して測る使い方も同じ環境変数で選べます。
    @MainActor
    func test画像グリッドを3秒間連続フリックスクロールする() {
        let app = XCUIApplication(bundleIdentifier: Self.sampleBundleIdentifier)
        let attachesToExistingApp = ProcessInfo.processInfo.environment["KS_PERF_ATTACH_EXISTING"] == "1"
        if attachesToExistingApp {
            // 記録側の準備が済むのを待ってから、起動済みの app を前面化します。待ち時間は
            // 記録の接続の仕方で変わるため、環境変数で与えられるようにしています。
            Thread.sleep(forTimeInterval: Self.attachWaitSeconds)
            app.activate()
        } else {
            // 起動より前に置く待ち窓です。計測では、この間に測る構成の app を入れ直します
            // (このテスト自身が入れる構成とは別の構成を測るため)。
            Thread.sleep(forTimeInterval: Self.prelaunchHoldSeconds)
            app.launchArguments = ["--screen", "画像グリッド", "--signpost-scroll-window"]
            app.launch()
        }

        flickForFixedWindow(in: app, waitsForRecorder: !attachesToExistingApp)
    }

    /// 一覧を締切まで連続フリックし、その区間を記録の中に残します。
    ///
    /// 区間は、テストの終了時刻から逆算するのではなく **アプリ自身が出す印**
    /// (`ScrollWindowSignpost`) で示します。ここでは区間の前後に Darwin 通知を送るだけで、
    /// 印が要る起動 (`--signpost-scroll-window`) でなければ誰も受け取りません。
    ///
    /// 区間の長さをそろえるための手当てが 2 つあります。
    ///
    /// - **区間を閉じるのは最後のフリックの終了ではなく締切**。フリックの呼び出しは指を離した
    ///   後の静止まで待って戻るため、呼び出しの合間に終わりの印を送ると区間が静止待ちのぶん
    ///   伸びます。終わりの印は別のスレッドの時計で締切ちょうどに送ります
    /// - **区間の外で 1 回空打ちする**。自動化の初期化にかかる一度きりの費用と、一覧が
    ///   止まっている状態から動き出す分を区間へ持ち込まないためです
    ///
    /// フリックの座標は始める前に 1 度だけ確定し、以後は絶対座標として使います。ループの中で
    /// 一覧の要素を解決すると、そのたびに画面の要素木の走査が走り、計測の足場が測る側の
    /// 主スレッドを使ってしまうためです。同じ理由で、静止を待つ `swipeUp` も使いません。
    ///
    /// 空打ちと区間内のフリック回数・各回の所要は `KS71` を先頭に付けて出力し、証跡に添えます。
    ///
    /// - Parameters:
    ///   - app: 操作する対象のアプリ
    ///   - waitsForRecorder: 記録側が接続するための待ち窓を置くなら `true`
    @MainActor
    private func flickForFixedWindow(in app: XCUIApplication, waitsForRecorder: Bool) {
        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 15))

        // 座標をここで確定する。以後は要素ではなくアプリ原点からの絶対座標として扱う。
        let frame = collection.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(
            CGVector(dx: frame.midX, dy: frame.maxY - frame.height * 0.2)
        )
        let end = origin.withOffset(
            CGVector(dx: frame.midX, dy: frame.minY + frame.height * 0.2)
        )

        if waitsForRecorder {
            // Instruments が実機プロセスへ接続するための待機窓です。
            Thread.sleep(forTimeInterval: Self.recordWaitSeconds)
        }

        let warmUpStartedAt = Date()
        flick(from: start, to: end)
        let warmUp = Date().timeIntervalSince(warmUpStartedAt)

        Self.postScrollWindow(ScrollWindowNotification.begin)
        let opened = Date()
        let deadline = opened.addingTimeInterval(Self.windowSeconds)
        DispatchQueue.global(qos: .userInitiated)
            .asyncAfter(wallDeadline: .now() + Self.windowSeconds) {
                Self.postScrollWindow(ScrollWindowNotification.end)
            }

        var durations: [TimeInterval] = []
        while Date() < deadline {
            let startedAt = Date()
            flick(from: start, to: end)
            durations.append(Date().timeIntervalSince(startedAt))
        }

        let each = durations.map { Self.seconds($0) }.joined(separator: ",")
        let touching = durations.reduce(0, +)
        print(
            "KS71 warmup=\(Self.seconds(warmUp)) flicks=\(durations.count) each=[\(each)]"
                + " spent=\(Self.seconds(touching))"
                + " elapsed=\(Self.seconds(Date().timeIntervalSince(opened)))"
        )
    }

    /// 1 回ぶんのフリックを行います。指は離し、慣性を殺しません。
    ///
    /// - Parameters:
    ///   - start: 触れ始める位置
    ///   - end: 離す位置
    @MainActor
    private func flick(from start: XCUICoordinate, to end: XCUICoordinate) {
        start.press(
            forDuration: 0.05,
            thenDragTo: end,
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
    }

    /// 秒数を小数第 3 位までの文字列にします。
    ///
    /// - Parameter value: 秒数
    /// - Returns: 出力に載せる形の文字列
    private static func seconds(_ value: TimeInterval) -> String {
        String(format: "%.3f", value)
    }

    /// 測る対象のアプリの識別子。
    private static let sampleBundleIdentifier = "jp.kamusoft.kscollectionview.samples.ios"

    /// 区間の長さ (秒)。合格基準が「3 秒間の連続フリック」で定められているため 3 に固定します。
    private static let windowSeconds: TimeInterval = 3

    /// 記録側の準備を待つ秒数。既定は 20 秒で、環境変数 `KS_PERF_ATTACH_WAIT` で変えられます。
    private static var attachWaitSeconds: TimeInterval {
        ProcessInfo.processInfo.environment["KS_PERF_ATTACH_WAIT"]
            .flatMap(TimeInterval.init) ?? 20
    }

    /// app を起動する前に待つ秒数。既定は 0 秒で、環境変数 `KS_PERF_PRELAUNCH_HOLD` で変えられます。
    private static var prelaunchHoldSeconds: TimeInterval {
        ProcessInfo.processInfo.environment["KS_PERF_PRELAUNCH_HOLD"]
            .flatMap(TimeInterval.init) ?? 0
    }

    /// 起動後に記録側の接続を待つ秒数。既定は 5 秒で、環境変数 `KS_PERF_RECORD_WAIT` で変えられます。
    private static var recordWaitSeconds: TimeInterval {
        ProcessInfo.processInfo.environment["KS_PERF_RECORD_WAIT"]
            .flatMap(TimeInterval.init) ?? 5
    }

    /// 計測窓の印を要求する通知の名前。アプリ側の `ScrollWindowSignpost` と同じ文字列です。
    private enum ScrollWindowNotification {
        static let begin = "jp.kamusoft.kscollectionview.samples.scrollWindow.begin"
        static let end = "jp.kamusoft.kscollectionview.samples.scrollWindow.end"
    }

    /// 計測窓の印を要求します。
    ///
    /// - Parameter name: 送る通知の名前
    private static func postScrollWindow(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    /// 「戻ってきたときの再表示」を、読み込み中スロットの計数の基準点機構で観測する駆動です。
    ///
    /// ①初回表示の収束を待つ ②計数の印を叩いて基準点を切る ③同じ表示サイズのまま 2 画面ほど
    /// 送る ④同じ操作を逆向きに行って戻す、の 4 段で動かします。各段の印と可視の要素は
    /// `KS74` を先頭に付けて出力し、記録側のログと突き合わせます。
    ///
    /// 判定はしません (このファイルの他の駆動と同じく、計測窓を開くために動かすだけです)。
    /// 合否は証跡の側で、印とログの両方を突き合わせて決めます。
    @MainActor
    func test画像グリッドで基準点を切り送って戻す() {
        let app = XCUIApplication()
        app.launchArguments = ["--screen", "画像グリッド", "--count-image-loading-slots"]
            + Self.requestedPrefetchArguments
        app.terminate()
        app.launch()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 30))
        let mark = app.staticTexts["imageLoadingSlot.tally"]
        XCTAssertTrue(mark.waitForExistence(timeout: 30), "計数の印が現れませんでした")

        // 記録側 (ログの採取) が付くのを待つ窓。基準点より前に付いていないと、判定する区間の
        // 行が欠けたまま揃ってしまう。既定は 0 秒で、記録を取る実行だけ環境変数で与える。
        Thread.sleep(forTimeInterval: Self.recorderHoldSeconds)

        guard waitUntilMarkSettles(mark) else { return }
        report("初回表示の収束後", mark: mark, in: app)

        mark.tap()
        report("基準点を切った直後", mark: mark, in: app)

        drag(collection, times: 3, forward: true)
        guard waitUntilMarkSettles(mark) else { return }
        report("2画面送った後", mark: mark, in: app)

        drag(collection, times: 3, forward: false)
        guard waitUntilMarkSettles(mark) else { return }
        report("同じサイズで戻した後", mark: mark, in: app)
    }

    /// 記録側が付くのを待つ秒数。既定は 0 秒で、環境変数 `KS_74_RECORDER_HOLD` で変えられます。
    private static var recorderHoldSeconds: TimeInterval {
        ProcessInfo.processInfo.environment["KS_74_RECORDER_HOLD"]
            .flatMap(TimeInterval.init) ?? 0
    }

    /// 起動引数に足すプリフェッチの到達点。環境変数 `KS_IMAGE_PREFETCH` で与えます。
    private static var requestedPrefetchArguments: [String] {
        guard let value = ProcessInfo.processInfo.environment["KS_IMAGE_PREFETCH"] else { return [] }
        return ["--prefetch", value]
    }

    /// 印の文字列が動かなくなるまで待ちます。
    ///
    /// 計数は表示の状態ではなく一定間隔で書き換えられるため、「変わらなくなったこと」でしか
    /// 収束を見分けられません。締切までに静止しなければテストを失敗させ `false` を返します
    /// (黙って戻ると、未収束のまま基準点を切っても緑になってしまうため)。
    ///
    /// - Parameters:
    ///   - mark: 計数の印
    ///   - quiet: 変化が無いと見なすまでの長さ (秒)
    ///   - timeout: 待つ上限 (秒)
    /// - Returns: 静止したら `true`、締切を過ぎたら `false`
    @MainActor
    @discardableResult
    private func waitUntilMarkSettles(
        _ mark: XCUIElement,
        quiet: TimeInterval = 3,
        timeout: TimeInterval = 60
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastLabel = mark.label
        var lastChange = Date()
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
            let label = mark.label
            if label != lastLabel {
                lastLabel = label
                lastChange = Date()
            } else if Date().timeIntervalSince(lastChange) >= quiet {
                return true
            }
        }
        XCTFail("計数の印が \(Int(timeout)) 秒以内に静止しませんでした (最後の印: \(lastLabel))")
        return false
    }

    /// 縦のドラッグを繰り返します。慣性で止まる位置が変わらないよう、指を離す前に止めます。
    ///
    /// - Parameters:
    ///   - collection: 操作する一覧
    ///   - times: 繰り返す回数
    ///   - forward: 先へ送るなら `true`、戻すなら `false`
    @MainActor
    private func drag(_ collection: XCUIElement, times: Int, forward: Bool) {
        let near = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let far = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        for _ in 0..<times {
            let start = forward ? near : far
            let end = forward ? far : near
            start.press(
                forDuration: 0.05,
                thenDragTo: end,
                withVelocity: .slow,
                thenHoldForDuration: 0.5
            )
        }
    }

    /// その時点の印と可視の要素を出力します。
    ///
    /// - Parameters:
    ///   - phase: 手順のどの時点か
    ///   - mark: 計数の印
    ///   - app: 対象のアプリ
    @MainActor
    private func report(_ phase: String, mark: XCUIElement, in app: XCUIApplication) {
        // セルは中身をまとめた 1 要素になるため、セル側と文言側の両方から拾う。
        let labels = app.cells.allElementsBoundByIndex.map(\.label)
            + app.staticTexts.allElementsBoundByIndex.map(\.label)
        let visible = Set(labels)
            .filter { $0.hasPrefix("#") }
            .compactMap { Int($0.dropFirst()) }
            .sorted()
        print("KS74 phase=\(phase) mark=[\(mark.label)] visible=\(visible)")
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
