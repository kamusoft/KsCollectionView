import XCTest

/// 計測専用のドライバです。Instruments からの計測窓を開くため、または計測そのものを自動で
/// 回すために動かします。通常のテストスイート (`KsCollectionViewSamples` スキーム) からは
/// 除外し、`KsCollectionViewSamplesPerformance` スキームでのみ実行します。
///
/// 合否の持ち方は駆動ごとに違います。画像の読み込みのような**観測のための駆動**は判定を持たず、
/// 緑は「駆動が最後まで動いた」ことしか意味しません (合否は記録側のログと画面の印を突き合わせて
/// 証跡の側で決めます)。一方、メモリの往復は**判定を持ち**、定常化に届かなかった走行を失敗させます。
/// したがってこのスキームの成功件数には、判定を持つテストと持たない駆動の両方が含まれます。
///
/// スクロールの滑らかさは自動では駆動しません。自動駆動は主スレッドを占めて計測の土俵そのものを
/// 汚すため、フリックはオーナーが固定の操作列で行い、ここに置くのは足場の問題が無い駆動だけです。
final class PerformanceDriverUITests: XCTestCase {
    /// 「戻ってきたときの再表示」を、読み込み中スロットの計数の基準点機構で観測する駆動です。
    ///
    /// ①初回表示の収束を待つ ②計数の印を叩いて基準点を切る ③同じ表示サイズのまま 2 画面ほど
    /// 送る ④同じ操作を逆向きに行って戻す、の 4 段で動かします。各段の印と可視の要素は
    /// `KS74` を先頭に付けて出力し、記録側のログと突き合わせます。
    ///
    /// 判定はしません (観測のための駆動であり、動かすこと自体が目的です)。
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

    /// メモリの自動往復です。定常化するまで往復を重ね、往復ごとの記録を残します。
    ///
    /// 定常の規則 (連続する 2 往復の増分がいずれも 1 往復後の値の 2% 以内) は app 側が持ち、
    /// ここはその判定を読んで往復を止めます。規則を両側に書くと、片方だけ直したときに
    /// 判定が食い違ったまま緑になります。
    ///
    /// 上限まで重ねても定常化しなければ**失敗**させます。未判定は証跡に使えない結果であり、
    /// 緑として通すと「定常化を確かめた」ことにされてしまうためです。
    ///
    /// 1 往復は端点間のジャンプではなく可視範囲の半分ずつ送る全件走査のため、往復ごとの待ち時間を長めに取ります。
    @MainActor
    func test大量件数を全件通過で定常化するまで往復してメモリを記録する() {
        assertSteadies(within: Self.maximumRoundTrips)
    }

    /// 上限までに定常化しなかった走行が、成功として終わらないことを確かめます。
    ///
    /// 定常の判定には 3 往復ぶんの実測が要るため、上限を 1 往復にすれば定常化に届かない状態を
    /// 作れます。このときドライバが緑で終わると、証跡に使えない走行が「定常化を確かめた」
    /// 結果として通ってしまいます。
    /// 「グループ化」の土俵 (固定される見出しつきで大小のグループに分けたグリッド) で、同じ往復を
    /// 定常化するまで重ねます。判定の規則と失敗の扱いは「大量件数」と同じです。
    @MainActor
    func testグループ化を全件通過で定常化するまで往復してメモリを記録する() {
        assertSteadies(
            within: Self.maximumRoundTrips,
            launchArguments: ["--verify-performance", "--performance-fixture", "グループ化"]
        )
    }

    @MainActor
    func test上限までに定常化しなければ未判定として失敗する() {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.compactDescription.contains("定常化しませんでした") }
        XCTExpectFailure("上限までに定常化しない走行は失敗する", options: options)

        assertSteadies(within: 1)
    }

    /// 定常化するまで往復を重ね、往復ごとの記録を出して、定常化したことを確かめます。
    ///
    /// - Parameters:
    ///   - limit: 重ねる往復数の上限
    ///   - launchArguments: 計測の画面を開く起動引数 (既定は「大量件数」の土俵)
    @MainActor
    private func assertSteadies(
        within limit: Int,
        launchArguments: [String] = ["--verify-performance"]
    ) {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        app.terminate()
        app.launch()

        let roundTrip = app.buttons["performance.roundTrip"]
        XCTAssertTrue(roundTrip.waitForExistence(timeout: 10))
        let completed = app.staticTexts["performance.completedRoundTrips"]
        let memory = app.staticTexts["performance.memory.last"]
        let visited = app.staticTexts["performance.visitedItems"]
        let judgement = app.staticTexts["performance.judgement"]

        var lastJudgement = ""
        for round in 1...limit {
            roundTrip.tap()
            XCTAssertTrue(
                completed.waitForLabel("完了: \(round)", timeout: Self.roundTripTimeout),
                "\(round) 往復目が \(Int(Self.roundTripTimeout)) 秒以内に終わりませんでした"
            )

            // 通過件数は往復ごとに数え直されるため、各往復の直後に全項目を通過したことを確認する。
            // 刻みが可視範囲より粗いと通過しない項目が残る。
            XCTAssertEqual(visited.label, "直近往復の通過: 10000 / 10000")
            let footprint = memory.label
            XCTAssertTrue(footprint.hasSuffix(" bytes"), footprint)

            lastJudgement = Self.judgementValue(in: judgement.label)
            // 証跡に転記する数値はこの行から採る。
            print("KS_PERF_ROUND=\(round) \(footprint) \(visited.label) 判定=\(lastJudgement)")
            XCTAssertNotEqual(lastJudgement, "無効", "\(round) 往復目の走査が成立しませんでした")
            if lastJudgement == "定常" { break }
        }

        print("KS_PERF_JUDGEMENT=\(lastJudgement) 往復=\(completed.label)")
        XCTAssertEqual(
            lastJudgement,
            "定常",
            "上限 \(limit) 往復までに定常化しませんでした (未判定)"
        )
    }

    /// 定常化を待つ往復数の上限です。app 側の上限と同じ値にします。
    private static let maximumRoundTrips = 10

    /// 1 往復あたりの待ち上限です。
    private static let roundTripTimeout: TimeInterval = 300

    /// 判定の表示から判定そのものを取り出します。
    ///
    /// - Parameter label: 判定の表示 (`判定: 定常` の形)
    /// - Returns: 判定の文字列。読み取れなければ表示のまま
    private static func judgementValue(in label: String) -> String {
        guard let range = label.range(of: "判定: ") else { return label }
        return String(label[range.upperBound...])
    }
}
