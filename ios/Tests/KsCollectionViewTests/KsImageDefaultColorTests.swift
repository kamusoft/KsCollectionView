import Nuke
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// `KsImage` の既定の表示 (読み込み中の無地、失敗の下地と印) が、置かれた場所の外観 (ライト / ダーク) の
/// 側の色で描かれることを、画面へ載せて描いた結果の画素で確かめる。
///
/// 取得層は `URLProtocol` のスタブに差し替え、応答を保留して読み込み中の状態を保つ。外観の切り替えで
/// 取得が取り消されたり始め直されたりしないことは、ローダーへ出た要求と取り消しの数で確かめる
/// (`KsDefaultColorTaskRecorder`)。ローダーは同じ URL の取得を 1 本にまとめるため、取得層の数だけでは、
/// 表示が要求を出し直しても見分けられない。
///
/// テストは同期の関数にして、実行ループを回して待つ。ローダーは読み込みの結果をメインアクターの仕事として
/// 届けるため、`async` のテストの中で実行ループを回して待つと、テスト自身がメインアクターを占めたままになり、
/// 結果が表示に届かない。
@MainActor
final class KsImageDefaultColorTests: XCTestCase {
    private typealias Support = KsDefaultColorTestSupport
    private typealias Expected = KsDefaultColorTestSupport.Expected

    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    /// 表示枠 (ポイント)。失敗の印が画素で読める大きさにする。
    private static let side: CGFloat = 120
    /// 取得が成功したときに返す画像の色。既定の色のどれとも違う。
    private static let payloadRGB: [Int] = [255, 0, 0]
    /// 利用者が差し替えた表示の色。
    private static let customLoadingRGB: [Int] = [0, 128, 0]
    private static let customFailureRGB: [Int] = [0, 0, 255]

    private var pipeline: ImagePipeline!
    private var tasks: KsDefaultColorTaskRecorder!
    private var originalPipeline: ImagePipeline!
    private var windows: [UIWindow] = []
    // 先読みの層は解放されると未完了の取得を止めるため、テストの間は保持する。
    private var prefetching: KsNukeImageLoading?

    private let target = URL(string: "https://images.example.com/default-color.png")!

    override func setUp() async throws {
        try await super.setUp()
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        KsImageMemoryIndex.shared.removeAll()
        KsDefaultColorURLProtocol.reset()
        KsDefaultColorURLProtocol.payload = Self.makePNG()

        var configuration = ImagePipeline.Configuration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [KsDefaultColorURLProtocol.self]
        configuration.dataLoader = DataLoader(configuration: sessionConfiguration)
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        tasks = KsDefaultColorTaskRecorder()
        pipeline = ImagePipeline(configuration: configuration, delegate: tasks)
        originalPipeline = ImagePipeline.shared
        ImagePipeline.shared = pipeline
    }

    override func tearDown() async throws {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
        prefetching = nil
        // 保留したままの応答を流して、待っているスレッドを残さない。
        KsDefaultColorURLProtocol.releaseAll()
        ImagePipeline.shared = originalPipeline
        originalPipeline = nil
        pipeline = nil
        tasks = nil
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        KsImageMemoryIndex.shared.removeAll()
        try await super.tearDown()
    }

    // MARK: - 一覧の外に置いた KsImage: ライト / ダーク

    func test一覧の外に置いたKsImageの既定の読み込み中はライトではライト用ダークではダーク用の色で描かれる() {
        KsDefaultColorURLProtocol.holdsResponses = true
        for style in [UIUserInterfaceStyle.light, .dark] {
            let url = URL(string: "https://images.example.com/loading-\(style.rawValue).png")!
            let window = show(KsImage(.remote(url)), style: style)

            waitForRequest(to: url)
            assertFill(of: window, is: Expected.imageLoading(style), "\(Support.name(style)) の読み込み中")
            window.isHidden = true
        }
    }

    func test一覧の外に置いたKsImageの既定の失敗は下地と印がライトとダークそれぞれの色で描かれる() {
        KsDefaultColorURLProtocol.fails = true
        for style in [UIUserInterfaceStyle.light, .dark] {
            let url = URL(string: "https://images.example.com/failure-\(style.rawValue).png")!
            let window = show(KsImage(.remote(url)), style: style)

            assertFailure(of: window, style: style, Support.name(style))
            window.isHidden = true
        }
    }

    // MARK: - 表示中の切り替え

    func test既定の読み込み中を出したまま外観を切り替えると色が追随し読み込み中のまま変わらない() {
        KsDefaultColorURLProtocol.holdsResponses = true
        let window = show(KsImage(.remote(target)), style: .light)
        waitForRequest(to: target)
        assertFill(of: window, is: Expected.imageLoadingLight, "切り替える前のライト")

        window.overrideUserInterfaceStyle = .dark
        assertFill(of: window, is: Expected.imageLoadingDark, "ダークへ切り替えた後")
        window.overrideUserInterfaceStyle = .light
        assertFill(of: window, is: Expected.imageLoadingLight, "ライトへ戻した後")

        // 読み込み中のまま: 取得は終わっておらず、取り消されても始め直されてもいない。
        Support.pump(windows: windows, turns: 10)
        XCTAssertEqual(tasks.createdCount, 1, "外観の切り替えで要求を出し直しました")
        XCTAssertEqual(tasks.cancelledCount, 0, "外観の切り替えで要求を取り消しました")
        XCTAssertEqual(KsDefaultColorURLProtocol.requestCount, 1)
        XCTAssertEqual(KsDefaultColorURLProtocol.cancelCount, 0)
        XCTAssertEqual(KsDefaultColorURLProtocol.finishCount, 0)
    }

    func test既定の失敗を出したまま外観を切り替えると下地と印の色が追随し失敗のまま変わらない() {
        KsDefaultColorURLProtocol.fails = true
        let window = show(KsImage(.remote(target)), style: .light)
        assertFailure(of: window, style: .light, "切り替える前のライト")
        XCTAssertEqual(tasks.createdCount, 1)
        XCTAssertEqual(KsDefaultColorURLProtocol.requestCount, 1)

        window.overrideUserInterfaceStyle = .dark
        assertFailure(of: window, style: .dark, "ダークへ切り替えた後")
        window.overrideUserInterfaceStyle = .light
        assertFailure(of: window, style: .light, "ライトへ戻した後")

        // 失敗のまま: 切り替えで取得をやり直していない。
        Support.pump(windows: windows, turns: 10)
        XCTAssertEqual(tasks.createdCount, 1, "外観の切り替えで要求を出し直しました")
        XCTAssertEqual(KsDefaultColorURLProtocol.requestCount, 1, "外観の切り替えで取得をやり直しました")
    }

    // MARK: - 取得の途中の切り替え

    func test読み込みを始めてから出た読み込み中の間に外観を切り替えても取得は取り消されず始め直されず終わると画像が出る() {
        KsDefaultColorURLProtocol.holdsResponses = true
        let window = show(KsImage(.remote(target)), style: .light)
        waitForRequest(to: target)
        assertFill(of: window, is: Expected.imageLoadingLight, "切り替える前のライト")
        // この経路は先読みを待たない (ローダー付属のビューが要求を出す)。
        XCTAssertFalse(mayBeLoadingPrefetch(in: window, size: CGSize(width: Self.side, height: Self.side)))
        XCTAssertEqual(tasks.createdCount, 1)
        XCTAssertEqual(KsDefaultColorURLProtocol.requestCount, 1)

        window.overrideUserInterfaceStyle = .dark
        assertFill(of: window, is: Expected.imageLoadingDark, "ダークへ切り替えた後")
        Support.pump(windows: windows, turns: 10)

        assertNoRequestChange(created: 1, "外観の切り替え")

        KsDefaultColorURLProtocol.releaseAll()
        assertFill(of: window, isRGB: Self.payloadRGB, "取得が終わった後の画像")
        assertNoRequestChange(created: 1, "取得が終わるまで")
    }

    func test先読みの完了を待つ間に出た読み込み中の間に外観を切り替えても取得は取り消されず始め直されず終わると画像が出る() {
        KsDefaultColorURLProtocol.holdsResponses = true
        startPrefetch()
        let controller = KsCollectionViewController(configuration: makeConfiguration())
        let window = show(controller, style: .light)
        let cell = waitForCell(in: controller)
        // 一覧が組み立てた表示が、取得中の先読みを待つ経路を通っている。
        XCTAssertTrue(mayBeLoadingPrefetch(in: window, size: cell.bounds.size), "先読みの完了を待つ経路を通っていません")
        // 画面に出た時点の処理 (引き当てに外れて表示の要求を出す) が済むだけの周回を回す。
        Support.pump(windows: windows, turns: 10)
        assertFill(of: cell, is: Expected.imageLoadingLight, "切り替える前のライト")
        // 先読みの要求と、画面に出た時点で出した表示の要求の 2 つが、同じ 1 本の取得を待っている。
        XCTAssertEqual(tasks.createdCount, 2, "表示の要求が出ていません")
        XCTAssertEqual(KsDefaultColorURLProtocol.requestCount, 1)

        window.overrideUserInterfaceStyle = .dark
        assertFill(of: cell, is: Expected.imageLoadingDark, "ダークへ切り替えた後")
        Support.pump(windows: windows, turns: 10)

        assertNoRequestChange(created: 2, "外観の切り替え")
        XCTAssertTrue(
            controller.collectionView.cellForItem(at: ksIndexPath(forItemOffset: 0, in: controller.collectionView))
                === cell,
            "外観の切り替えでセルが作り直されました"
        )

        KsDefaultColorURLProtocol.releaseAll()
        assertFill(of: cell, isRGB: Self.payloadRGB, "取得が終わった後の画像")
        assertNoRequestChange(created: 2, "取得が終わるまで")
    }

    // MARK: - 先読みの完了を待つ間の読み込み中

    func test先読みの完了を待つ間に出る読み込み中の表示もダークの外観でダーク用の色になる() {
        KsDefaultColorURLProtocol.holdsResponses = true
        startPrefetch()
        let controller = KsCollectionViewController(configuration: makeConfiguration())
        let window = show(controller, style: .dark)
        let cell = waitForCell(in: controller)

        // 待たずに、画面に出た直後の描いた結果を見る。
        XCTAssertTrue(mayBeLoadingPrefetch(in: window, size: cell.bounds.size), "先読みの完了を待つ経路を通っていません")
        let first = Support.pixel(of: cell, at: CGPoint(x: cell.bounds.midX, y: cell.bounds.midY))
        XCTAssertTrue(
            Support.isClose(first, Support.components(Expected.imageLoadingDark)),
            "画面に出た直後の読み込み中の色がダーク用ではありません。実測値: \(String(describing: first))"
        )
        XCTAssertEqual(KsDefaultColorURLProtocol.finishCount, 0, "読み込み中の状態ではありません")
    }

    // MARK: - 上書きした外観

    func testKsImageを置いたwindowの外観だけを上書きすると既定の読み込み中が上書きした側の色になる() {
        KsDefaultColorURLProtocol.holdsResponses = true
        // 上書きしない窓の外観が、端末の表示モードである。その反対へ上書きする
        // (ライトの端末ではダークへの上書きになる)。
        let window = show(KsImage(.remote(target)), style: .unspecified)
        waitForRequest(to: target)
        let deviceStyle = window.traitCollection.userInterfaceStyle
        assertFill(of: window, is: Expected.imageLoading(deviceStyle), "上書きする前")
        let overridden = Support.opposite(of: deviceStyle)

        window.overrideUserInterfaceStyle = overridden

        assertFill(of: window, is: Expected.imageLoading(overridden), "\(Support.name(overridden)) へ上書きした後")
    }

    // MARK: - 差し替えた表示

    func test読み込み中と失敗を差し替えたKsImageはライトでもダークでも利用者の表示のまま出る() {
        let loading = Color(red: 0, green: 128 / 255.0, blue: 0)
        let failure = Color(red: 0, green: 0, blue: 1)

        KsDefaultColorURLProtocol.holdsResponses = true
        let loadingURL = URL(string: "https://images.example.com/custom-loading.png")!
        let loadingWindow = show(
            KsImage(.remote(loadingURL), loading: { loading }, failure: { failure }), style: .light
        )
        waitForRequest(to: loadingURL)
        assertFill(of: loadingWindow, isRGB: Self.customLoadingRGB, "ライトの差し替えた読み込み中")
        loadingWindow.overrideUserInterfaceStyle = .dark
        waitForStyle(.dark, in: loadingWindow)
        Support.pump(windows: windows, turns: 10)
        assertFill(of: loadingWindow, isRGB: Self.customLoadingRGB, "ダークの差し替えた読み込み中")
        loadingWindow.isHidden = true

        KsDefaultColorURLProtocol.holdsResponses = false
        KsDefaultColorURLProtocol.fails = true
        let failureURL = URL(string: "https://images.example.com/custom-failure.png")!
        let failureWindow = show(
            KsImage(.remote(failureURL), loading: { loading }, failure: { failure }), style: .light
        )
        assertFill(of: failureWindow, isRGB: Self.customFailureRGB, "ライトの差し替えた失敗")
        failureWindow.overrideUserInterfaceStyle = .dark
        waitForStyle(.dark, in: failureWindow)
        Support.pump(windows: windows, turns: 10)
        assertFill(of: failureWindow, isRGB: Self.customFailureRGB, "ダークの差し替えた失敗")
        // 既定の失敗の印は描かれていない。
        XCTAssertFalse(
            Support.containsPixel(of: failureWindow, matching: Support.components(Expected.imageFailureMarkDark))
        )
    }

    // MARK: - 部品

    // `KsImage` を表示枠いっぱいの窓に出す。`style` が `.unspecified` 以外なら、出す前に窓の外観を上書きしておく。
    private func show(_ view: some View, style: UIUserInterfaceStyle) -> UIWindow {
        let host = UIHostingController(
            rootView: view
                .frame(width: Self.side, height: Self.side)
                .ignoresSafeArea()
        )
        return show(host, style: style, size: CGSize(width: Self.side, height: Self.side))
    }

    private func show(_ controller: UIViewController, style: UIUserInterfaceStyle) -> UIWindow {
        show(controller, style: style, size: CGSize(width: 320, height: 480))
    }

    private func show(_ controller: UIViewController, style: UIUserInterfaceStyle, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        windows.append(window)
        return window
    }

    // 行の中身が `KsImage` だけの一覧。区切り線は画素の検査に混ざらないよう出さない。
    private func makeConfiguration() -> KsCollectionConfiguration<Item> {
        let target = target
        return KsCollectionConfiguration(
            items: [Item(id: 0)],
            id: { AnyHashable($0.id) },
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry(content: { (_: Item) in
                KsImage(.remote(target))
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.side)
            }),
            layout: .list,
            contentPadding: EdgeInsets(),
            showsSeparators: false,
            separatorColor: nil,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
    }

    // 同じ画像のメモリまでの先読みを始め、応答を保留させたまま取得中にする。
    private func startPrefetch() {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        prefetching = loading
        let request = KsPrefetchRequest(
            url: target,
            imageID: KsImageIdentity.imageID(forIdentifier: target.absoluteString),
            widthPixels: 64
        )
        loading.prefetch(requests: [request], destination: .memory)
        waitForRequest(to: target)
    }

    // ローダーへ出た要求の数が `created` のままで、取り消された要求が無く、取得層でも取得が 1 本のまま
    // 取り消されていないことを確かめる。
    private func assertNoRequestChange(
        created: Int,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(tasks.createdCount, created, "\(label) で要求を出し直しました", file: file, line: line)
        XCTAssertEqual(tasks.cancelledCount, 0, "\(label) で要求を取り消しました", file: file, line: line)
        XCTAssertEqual(
            KsDefaultColorURLProtocol.requestCount, 1, "\(label) で新しい取得が始まりました", file: file, line: line
        )
        XCTAssertEqual(
            KsDefaultColorURLProtocol.cancelCount, 0, "\(label) で取得が取り消されました", file: file, line: line
        )
    }

    private func waitForCell(in controller: KsCollectionViewController<Item>) -> UICollectionViewCell {
        let cell = { controller.collectionView.cellForItem(
            at: ksIndexPath(forItemOffset: 0, in: controller.collectionView)
        ) }
        Support.waitPumping("セルの表示", windows: windows, value: { cell() != nil }) { $0 }
        guard let shown = cell() else {
            return UICollectionViewCell()
        }
        shown.layoutIfNeeded()
        return shown
    }

    // 表示と同じ入口で、表示の要求を画面に出る時点まで待つ経路かを照会する。
    private func mayBeLoadingPrefetch(in window: UIWindow, size: CGSize) -> Bool {
        KsImageRequestFactory.prepare(
            source: .remote(target),
            size: size,
            contentMode: .fill,
            displayScale: window.traitCollection.displayScale,
            pipeline: pipeline
        )?.mayBeLoadingPrefetch ?? false
    }

    private func waitForRequest(to url: URL, file: StaticString = #filePath, line: UInt = #line) {
        Support.waitPumping(
            "取得の開始", windows: windows, value: { KsDefaultColorURLProtocol.requestCount(for: url) },
            file: file, line: line
        ) { $0 >= 1 }
    }

    private func waitForStyle(_ style: UIUserInterfaceStyle, in window: UIWindow) {
        Support.waitPumping(
            "\(Support.name(style)) への切り替え", windows: windows,
            value: { window.rootViewController?.view.traitCollection.userInterfaceStyle.rawValue }
        ) { $0 == style.rawValue }
    }

    // ビューの中央と四隅の近くが、どれも `expected` の色で塗られていることを確かめる。
    private func assertFill(
        of view: UIView,
        is expected: UInt32,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertFill(of: view, isRGB: Support.components(expected), label, file: file, line: line)
    }

    private func assertFill(
        of view: UIView,
        isRGB expected: [Int],
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let points = [
            CGPoint(x: view.bounds.midX, y: view.bounds.midY),
            CGPoint(x: 4, y: 4),
            CGPoint(x: view.bounds.maxX - 4, y: view.bounds.maxY - 4),
        ]
        Support.waitPumping(
            "\(label) の色", windows: windows,
            value: { points.map { Support.pixel(of: view, at: $0) } },
            file: file, line: line
        ) { pixels in
            pixels.allSatisfy { Support.isClose($0, expected) }
        }
    }

    // 既定の失敗の表示: 四隅の近くが下地の色で、印の色の画素がある。
    private func assertFailure(
        of window: UIWindow,
        style: UIUserInterfaceStyle,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let background = Support.components(Expected.imageFailureBackground(style))
        let mark = Support.components(Expected.imageFailureMark(style))
        let corners = [
            CGPoint(x: 4, y: 4),
            CGPoint(x: window.bounds.maxX - 4, y: window.bounds.maxY - 4),
        ]
        Support.waitPumping(
            "\(label) の失敗の下地の色", windows: windows,
            value: { corners.map { Support.pixel(of: window, at: $0) } },
            file: file, line: line
        ) { pixels in
            pixels.allSatisfy { Support.isClose($0, background) }
        }
        XCTAssertTrue(
            Support.containsPixel(of: window, matching: mark),
            "\(label) の失敗の印の色の画素がありません", file: file, line: line
        )
    }

    /// 一色で塗りつぶした 64x64 の PNG。
    private static func makePNG() -> Data {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 1, green: 0, blue: 0, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }.pngData() ?? Data()
    }
}

/// ローダーへ出た要求 (表示の要求と先読みの要求) と、そのうち取り消された要求を数える。
private final class KsDefaultColorTaskRecorder: ImagePipeline.Delegate, @unchecked Sendable {
    private let lock = NSLock()
    private var created = 0
    private var cancelled = 0

    var createdCount: Int {
        lock.withLock { created }
    }

    var cancelledCount: Int {
        lock.withLock { cancelled }
    }

    func imageTaskCreated(_ task: ImageTask, pipeline: ImagePipeline) {
        lock.withLock { created += 1 }
    }

    func imageTask(_ task: ImageTask, didReceiveEvent event: ImageTask.Event, pipeline: ImagePipeline) {
        if case .finished(.failure(.cancelled)) = event {
            lock.withLock { cancelled += 1 }
        }
    }
}

/// 取得層のスタブ。応答を保留する・失敗させる・固定の PNG を返すを切り替えられ、要求・取り消し・完了の
/// 数を数える。取り消しは、応答を返し終える前に止められた数である。
private final class KsDefaultColorURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var urls: [String] = []
    nonisolated(unsafe) private static var cancels = 0
    nonisolated(unsafe) private static var finishes = 0
    nonisolated(unsafe) private static var held: [DispatchSemaphore] = []
    nonisolated(unsafe) private static var holds = false
    nonisolated(unsafe) private static var failing = false
    nonisolated(unsafe) static var payload = Data()

    /// 応答を保留させるか。保留した応答は ``releaseAll()`` で流す。
    static var holdsResponses: Bool {
        get { lock.withLock { holds } }
        set { lock.withLock { holds = newValue } }
    }

    /// 取得を失敗させるか。
    static var fails: Bool {
        get { lock.withLock { failing } }
        set { lock.withLock { failing = newValue } }
    }

    static var requestCount: Int {
        lock.withLock { urls.count }
    }

    static func requestCount(for url: URL) -> Int {
        lock.withLock { urls.filter { $0 == url.absoluteString }.count }
    }

    static var cancelCount: Int {
        lock.withLock { cancels }
    }

    static var finishCount: Int {
        lock.withLock { finishes }
    }

    static func reset() {
        releaseAll()
        lock.withLock {
            urls = []
            cancels = 0
            finishes = 0
            holds = false
            failing = false
        }
        payload = Data()
    }

    /// 保留している応答をすべて流し、以後の応答は保留しない。
    static func releaseAll() {
        let waiting = lock.withLock { () -> [DispatchSemaphore] in
            holds = false
            let waiting = held
            held = []
            return waiting
        }
        waiting.forEach { $0.signal() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private let state = NSLock()
    nonisolated(unsafe) private var isStopped = false
    nonisolated(unsafe) private var isFinished = false

    override func startLoading() {
        let (gate, fails) = Self.lock.withLock { () -> (DispatchSemaphore?, Bool) in
            if let url = request.url?.absoluteString {
                Self.urls.append(url)
            }
            guard Self.holds else { return (nil, Self.failing) }
            let gate = DispatchSemaphore(value: 0)
            Self.held.append(gate)
            return (gate, Self.failing)
        }
        DispatchQueue.global().async { [self] in
            gate?.wait()
            let proceeds = state.withLock { () -> Bool in
                guard !isStopped else { return false }
                isFinished = true
                return true
            }
            guard proceeds else { return }
            Self.lock.withLock { Self.finishes += 1 }
            if fails {
                client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
                return
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "image/png"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.payload)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        let cancelled = state.withLock { () -> Bool in
            isStopped = true
            return !isFinished
        }
        if cancelled {
            Self.lock.withLock { Self.cancels += 1 }
        }
    }
}
