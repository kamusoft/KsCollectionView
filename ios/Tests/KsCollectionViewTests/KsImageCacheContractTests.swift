import Nuke
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// 到達点ごとのキャッシュ契約を、取得回数とデコード回数を数えられるローダーで確かめる。
/// 取得層は `URLProtocol` のスタブに差し替えるため、ネットワークアクセスは起きない。
@MainActor
final class KsImageCacheContractTests: XCTestCase {
    private var pipeline: ImagePipeline!
    private var dataCachePath: URL!
    private var originalPipeline: ImagePipeline!
    // 表示レベルの検査で開いた窓。テストをまたいで生き残ると、次のテストのパイプラインへ
    // 読み込みを出し続けるため、必ず片付ける。
    private var windows: [UIWindow] = []

    override func setUp() async throws {
        try await super.setUp()
        KsImageIdentity.resetGenerations()
        KsStubURLProtocol.reset()
        KsCountingImageDecoder.reset()

        var configuration = ImagePipeline.Configuration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [KsStubURLProtocol.self]
        configuration.dataLoader = DataLoader(configuration: sessionConfiguration)
        dataCachePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ks-image-cache-\(UUID().uuidString)", isDirectory: true)
        configuration.dataCache = try DataCache(path: dataCachePath)
        configuration.imageCache = ImageCache()
        configuration.makeImageDecoder = { _ in KsCountingImageDecoder() }
        pipeline = ImagePipeline(configuration: configuration)
        // `KsImageCache` は共有パイプラインを操作するため、この検査用のものを共有に据える。
        originalPipeline = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        KsImageInvalidation.shared.reset()
    }

    override func tearDown() async throws {
        dismissWindows()
        ImagePipeline.shared = originalPipeline
        originalPipeline = nil
        KsImageInvalidation.shared.reset()
        pipeline = nil
        if let dataCachePath {
            try? FileManager.default.removeItem(at: dataCachePath)
        }
        KsImageIdentity.resetGenerations()
        try await super.tearDown()
    }

    private let target = URL(string: "https://images.example.com/1.jpg")!

    func testディスク到達点の後の表示ではネットワークが走らない() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .disk)

        await waitUntil("ディスクキャッシュへの保存", value: { self.cachedDataExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        // ディスク到達点はデコードしない。
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 0)

        _ = try await pipeline.image(for: target)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)
    }

    func testメモリ到達点の後の表示では再デコードしない() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        _ = try await pipeline.image(for: target)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)
    }

    /// 表示側が実際に出す縮小指定付きの要求で、メモリ到達点の先読み結果が再利用されること。
    func test表示の要求はメモリ到達点の先読み結果を再デコードせずに使う() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        let display = try displayRequest(size: CGSize(width: 4, height: 4))
        _ = try await pipeline.image(for: display)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 1, "表示の要求で再ダウンロードが起きました")
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1, "表示の要求で再デコードが起きました")
    }

    /// メモリに画像がある表示は、読み込み中のスロットを一度も構成しない。
    ///
    /// 一瞬だけ挟まる読み込み中は最終状態を見るだけでは捉えられないため、スロットが構成された
    /// 回数そのものを数える。
    func test読み込み中のスロットはメモリにある画像では一度も構成されない() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)
        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)

        let counter = KsCompositionCounter()
        // 2 枚並べる。片方はキャッシュ済み、もう片方は未取得で、後者の取得が
        // 「表示が組み上がった」ことの合図になる。
        let uncached = URL(string: "https://images.example.com/uncached.jpg")!
        let window = show(
            VStack(spacing: 0) {
                KsImage(.remote(target), loading: {
                    let _ = counter.increment()
                    Color.clear
                })
                .frame(width: 4, height: 4)
                KsImage(.remote(uncached)).frame(width: 4, height: 4)
            }
        )
        defer { window.isHidden = true }

        waitPumpingRunLoop("表示の組み上がり", value: { KsStubURLProtocol.requestCount }) { $0 >= 2 }

        XCTAssertEqual(counter.count, 0, "読み込み中の表示を経由しました")
        XCTAssertEqual(KsStubURLProtocol.requestCount, 2, "キャッシュ済みの表示で再ダウンロードが起きました")
    }

    /// 先読みを使わずに一度表示した画像は、同じ表示を作り直しても読み込み中を経由しない。
    ///
    /// セルの再利用と画面への再入場に相当する、この機能でもっとも頻繁に起きる経路。表示が
    /// 自分で載せたメモリ項目を、次の表示が同じ鍵で引き当てられることを確かめる。
    func test一度表示した画像は表示を作り直しても読み込み中を経由しない() async throws {
        let size = CGSize(width: 4, height: 4)
        let firstWindow = show(KsImage(.remote(target)).frame(width: size.width, height: size.height))
        let scale = firstWindow.traitCollection.displayScale
        // 1 回目の表示がメモリへ載せ終わるまで待つ。載る前に作り直すと、引き当ての検査にならない。
        waitPumpingRunLoop(
            "1 回目の表示のメモリへの保存",
            value: { self.displayedImageExists(size: size, displayScale: scale) }
        ) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        firstWindow.isHidden = true

        let counter = KsCompositionCounter()
        // 2 枚並べる。片方は 1 回目で表示済み、もう片方は未取得で、後者の取得が
        // 「表示が組み上がった」ことの合図になる。
        let uncached = URL(string: "https://images.example.com/uncached.jpg")!
        let secondWindow = show(
            VStack(spacing: 0) {
                KsImage(.remote(target), loading: {
                    let _ = counter.increment()
                    Color.clear
                })
                .frame(width: size.width, height: size.height)
                KsImage(.remote(uncached)).frame(width: size.width, height: size.height)
            }
        )
        defer { secondWindow.isHidden = true }

        waitPumpingRunLoop("表示の組み上がり", value: { KsStubURLProtocol.requestCount }) { $0 >= 2 }

        XCTAssertEqual(counter.count, 0, "読み込み中の表示を経由しました")
        XCTAssertEqual(
            KsStubURLProtocol.requestCount(for: target), 1, "作り直した表示で再ダウンロードが起きました"
        )
    }

    func testローダーを直接使う素の要求と同じキャッシュ項目を共有する() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }

        // ローダー付属のビューが組み立てるのと同じ、識別子を足していない要求で当たること。
        let plain = ImageRequest(url: target)
        XCTAssertNotNil(pipeline.cache[plain])
        XCTAssertNotNil(pipeline.cache.cachedData(for: plain))

        _ = try await pipeline.image(for: plain)
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)
    }

    /// ソース単位の削除は対象のソースだけを消し、他のソースの表示はキャッシュから続く。
    func testソース単位の削除では対象のソースだけが消える() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        let other = URL(string: "https://images.example.com/2.jpg")!
        loading.prefetch(urls: [target, other], destination: .memory)

        await waitUntil("2 件のメモリキャッシュへの保存", value: {
            self.cachedImageExists() && self.pipeline.cache[ImageRequest(url: other)] != nil
        }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 2)

        KsImageCache.remove(.remote(target))

        // 対象は元データもデコード済みの画像も残らない。
        XCTAssertNil(pipeline.cache[ImageRequest(url: target)])
        XCTAssertFalse(pipeline.cache.containsData(for: ImageRequest(url: target)))
        // 他のソースはそのまま残る。
        XCTAssertNotNil(pipeline.cache[ImageRequest(url: other)])
        XCTAssertTrue(pipeline.cache.containsData(for: ImageRequest(url: other)))

        // 削除したソースの表示は取得からやり直しになる。
        let removed = try displayRequest(size: CGSize(width: 50, height: 50))
        _ = try await pipeline.image(for: removed)
        XCTAssertEqual(KsStubURLProtocol.requestCount, 3)

        // 残したソースの表示は取得をやり直さない。
        _ = try await pipeline.image(for: ImageRequest(url: other))
        XCTAssertEqual(KsStubURLProtocol.requestCount, 3)
    }

    /// メモリのみの消去では元データが残り、次の表示はディスクからの再デコードで済む。
    func testメモリのみ消去してもディスクの元データから再デコードできる() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        KsImageCache.clear(.memory)

        XCTAssertNil(pipeline.cache[ImageRequest(url: target)], "メモリの項目が残っています")
        XCTAssertTrue(pipeline.cache.containsData(for: ImageRequest(url: target)), "元データまで消えました")

        _ = try await pipeline.image(for: target)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 1, "再ダウンロードが起きました")
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 2, "ディスクからの再デコードが起きていません")
    }

    /// 全消去の後は、メモリに残っていた画像に当たらず取得からやり直す。
    func test全消去の後の表示はメモリに当たらず取り直しになる() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)

        KsImageCache.clear(.all)

        XCTAssertNil(pipeline.cache[ImageRequest(url: target)], "メモリの項目が残っています")
        XCTAssertFalse(pipeline.cache.containsData(for: ImageRequest(url: target)))

        let display = try displayRequest(size: CGSize(width: 4, height: 4))
        _ = try await pipeline.image(for: display)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 2, "全消去の後に取り直されていません")
    }

    /// 表示中の `KsImage` は、全消去で読み込み中へ戻って取得をやり直す。
    func test表示中のKsImageは全消去で取得をやり直す() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(urls: [target], destination: .memory)
        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)

        // 2 枚並べる。片方はキャッシュ済み、もう片方は未取得で、後者の取得が
        // 「表示が組み上がった」ことの合図になる。
        let uncached = URL(string: "https://images.example.com/uncached.jpg")!
        let window = show(
            VStack(spacing: 0) {
                KsImage(.remote(target)).frame(width: 4, height: 4)
                KsImage(.remote(uncached)).frame(width: 4, height: 4)
            }
        )
        defer { window.isHidden = true }

        // 未取得の 1 枚がキャッシュへ入り終わるまで待つ。入り終わる前に消すと、その取得が
        // 消した後で書き戻し、消去の効き目を見る検査にならない。
        waitPumpingRunLoop(
            "表示の取得の完了",
            value: { self.pipeline.cache.containsData(for: ImageRequest(url: uncached)) }
        ) { $0 }
        // キャッシュ済みの 1 枚は取得をやり直さないので、増えたのは未取得の 1 件だけ。
        XCTAssertEqual(KsStubURLProtocol.requestCount, 2)

        KsImageCache.clear(.all)

        // 表示の作り直しは実行ループの回転で反映されるため、待ちながらループを回す。
        // 見たいのはキャッシュに載っている 1 枚が取り直されることなので、その URL だけを数える。
        waitPumpingRunLoop(
            "全消去後の取り直し",
            value: { KsStubURLProtocol.requestCount(for: self.target) }
        ) { $0 >= 2 }
    }

    // 実行ループを回しながら収束を待つ。表示の更新を伴う検証で使う。
    private func waitPumpingRunLoop<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) {
        // 表示の作り直しは何フレームもかかるため、他の待ちと同じ 10 秒まで待つ。
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if predicate(value()) {
                return
            }
            // 表示の作り直しはレイアウトの機会が来ないと進まない。実行機が混んでいると
            // 描画の周期だけでは機会が来ないことがあるため、こちらから促す。
            for window in windows {
                window.rootViewController?.view.setNeedsLayout()
                window.rootViewController?.view.layoutIfNeeded()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))")
    }

    /// 消去より前に始まった先読みは、完了してもキャッシュへ書き戻さない。
    func test消去より前に始まった先読みは完了してもキャッシュへ戻らない() async throws {
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate

        let loading = KsNukeImageLoading(pipeline: pipeline)
        let prefetcher = KsImagePrefetcher<URL>(
            loading: loading,
            id: { AnyHashable($0) },
            resources: { [$0] },
            destination: .memory
        )
        prefetcher.prefetch(items: [target])
        await waitUntil("取得の開始", value: { KsStubURLProtocol.requestCount }) { $0 >= 1 }

        KsImageCache.clear(.all)

        // 消去の後に始めた別のソースの取得を、保留していた分と一緒に進める。
        let control = URL(string: "https://images.example.com/control.jpg")!
        prefetcher.prefetch(items: [control])
        gate.signal()
        gate.signal()

        // 後から始めた取得がキャッシュへ入るところまで進んだ時点で、消去した分を検査する。
        await waitUntil("後から始めた取得の保存", value: {
            self.pipeline.cache[ImageRequest(url: control)] != nil
        }) { $0 }

        XCTAssertNil(
            pipeline.cache[ImageRequest(url: target)],
            "消去より前に始まった取得がメモリへ書き戻しました"
        )
        XCTAssertFalse(
            pipeline.cache.containsData(for: ImageRequest(url: target)),
            "消去より前に始まった取得が元データを書き戻しました"
        )
    }

    /// メモリだけを消した場合も、消去より前に始まった先読みはメモリへ書き戻さない。
    func testメモリのみの消去でも消去より前に始まった先読みはメモリへ戻らない() async throws {
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate

        let loading = KsNukeImageLoading(pipeline: pipeline)
        let prefetcher = KsImagePrefetcher<URL>(
            loading: loading,
            id: { AnyHashable($0) },
            resources: { [$0] },
            destination: .memory
        )
        prefetcher.prefetch(items: [target])
        await waitUntil("取得の開始", value: { KsStubURLProtocol.requestCount }) { $0 >= 1 }

        KsImageCache.clear(.memory)

        // 消去の後に始めた別のソースの取得を、保留していた分と一緒に進める。
        let control = URL(string: "https://images.example.com/control.jpg")!
        prefetcher.prefetch(items: [control])
        gate.signal()
        gate.signal()

        await waitUntil("後から始めた取得の保存", value: {
            self.pipeline.cache[ImageRequest(url: control)] != nil
        }) { $0 }

        XCTAssertNil(
            pipeline.cache[ImageRequest(url: target)],
            "消去より前に始まった先読みがメモリへ書き戻しました"
        )
    }

    private func show(_ view: some View) -> UIWindow {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 20))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        windows.append(window)
        return window
    }

    private func dismissWindows() {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
    }

    private func cachedDataExists() -> Bool {
        pipeline.cache.containsData(for: ImageRequest(url: target))
    }

    private func cachedImageExists() -> Bool {
        pipeline.cache[ImageRequest(url: target)] != nil
    }

    /// 本番の表示が出すのと同じ要求。
    private func displayRequest(size: CGSize, displayScale: CGFloat = 2) throws -> ImageRequest {
        try XCTUnwrap(
            KsImageRequestFactory.prepare(
                source: .remote(target),
                size: size,
                contentMode: .fill,
                displayScale: displayScale,
                pipeline: pipeline
            )
        ).request
    }

    /// 本番の表示が引き当てる鍵で、その大きさの画像がメモリにあるか。
    private func displayedImageExists(size: CGSize, displayScale: CGFloat) -> Bool {
        guard let prepared = KsImageRequestFactory.prepare(
            source: .remote(target),
            size: size,
            contentMode: .fill,
            displayScale: displayScale,
            pipeline: pipeline
        ) else {
            return false
        }
        return prepared.cachedImage != nil
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while clock.now < deadline {
            let current = value()
            if predicate(current) {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))")
    }
}

/// スロットが構成された回数を数える。表示の組み立て中に呼ばれるため、スレッド越しに読める形にする。
private final class KsCompositionCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func increment() {
        lock.withLock { value += 1 }
    }
}

/// 取得層のスタブ。固定の PNG を返し、要求の回数を数える。
private final class KsStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0

    static var requestCount: Int {
        lock.withLock { count }
    }

    nonisolated(unsafe) private static var urls: [String] = []

    /// 特定の URL に対する取得の回数。
    static func requestCount(for url: URL) -> Int {
        lock.withLock { urls.filter { $0 == url.absoluteString }.count }
    }

    static func reset() {
        lock.withLock {
            count = 0
            urls = []
        }
        gate = nil
    }

    /// 1 辺 8 ポイントの不透明な PNG。デコードが成立する最小限の実データ。
    static let payload: Data = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.pngData()!
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// 応答を保留させる関門。設定すると、`signal` を受けるまで応答を返さない。
    nonisolated(unsafe) static var gate: DispatchSemaphore?

    private let stopped = NSLock()
    nonisolated(unsafe) private var isStopped = false

    override func startLoading() {
        Self.lock.withLock {
            Self.count += 1
            if let url = request.url?.absoluteString {
                Self.urls.append(url)
            }
        }
        let gate = Self.gate
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/png"]
        )!
        // 関門があるときは応答を保留する。取り消しと完了が競る順序を作るための口。
        DispatchQueue.global().async { [self] in
            gate?.wait()
            guard !stopped.withLock({ isStopped }) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.payload)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        stopped.withLock { isStopped = true }
    }
}

/// 既定のデコーダに数えるだけを足した実装。
private struct KsCountingImageDecoder: ImageDecoding {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0

    static var decodeCount: Int {
        lock.withLock { count }
    }

    static func reset() {
        lock.withLock { count = 0 }
    }

    private let base = ImageDecoders.Default()

    func decode(_ data: Data) throws -> ImageContainer {
        Self.lock.withLock { Self.count += 1 }
        return try base.decode(data)
    }
}
