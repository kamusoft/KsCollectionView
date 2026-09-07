import Nuke
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// `KsImage` が組み立てる要求と、キャッシュ操作が表示へ及ぼす影響を確かめる。
@MainActor
final class KsImageTests: XCTestCase {
    private let remote = URL(string: "https://images.example.com/a.jpg")!
    private let other = URL(string: "https://images.example.com/b.jpg")!
    // 表示レベルの検査で開いた窓。テストをまたいで生き残ると、次のテストのパイプラインへ
    // 読み込みを出し続けるため、必ず片付ける。
    private var windows: [UIWindow] = []

    override func setUp() async throws {
        try await super.setUp()
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
    }

    override func tearDown() async throws {
        dismissWindows()
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        try await super.tearDown()
    }

    // MARK: - ソースの経路

    func test3種のソースがそれぞれの経路へ振り分けられる() {
        let file = URL(fileURLWithPath: "/tmp/local.jpg")

        XCTAssertEqual(KsImageRequestFactory.route(for: .remote(remote)), .loader(remote))
        XCTAssertEqual(KsImageRequestFactory.route(for: .file(file)), .loader(file))
        XCTAssertEqual(KsImageRequestFactory.route(for: .asset("logo")), .asset("logo"))
    }

    func test便宜形はリモートのソースと同じ宣言になる() {
        XCTAssertEqual(KsImage(remote).source, KsImage(.remote(remote)).source)
        XCTAssertEqual(KsImage(remote).source, .remote(remote))
    }

    func test当てはめ方の既定はfillになる() {
        XCTAssertEqual(KsImage(remote).contentMode, .fill)
        XCTAssertEqual(KsImage(.remote(remote), contentMode: .fit).contentMode, .fit)
    }

    func testアセットのソースではローダーへの要求を作らない() {
        let prepared = KsImageRequestFactory.prepare(
            source: .asset("logo"),
            size: CGSize(width: 50, height: 50),
            contentMode: .fill,
            displayScale: 2
        )

        XCTAssertNil(prepared)
    }

    // MARK: - 縮小デコード

    func testサイズが確定するまで要求を発行しない() {
        for size in [CGSize.zero, CGSize(width: 50, height: 0), CGSize(width: 0, height: 50)] {
            XCTAssertNil(
                KsImageRequestFactory.prepare(
                    source: .remote(remote),
                    size: size,
                    contentMode: .fill,
                    displayScale: 2
                ),
                "サイズ \(size) で要求が発行されました"
            )
        }

        XCTAssertNotNil(
            KsImageRequestFactory.prepare(
                source: .remote(remote),
                size: CGSize(width: 50, height: 50),
                contentMode: .fill,
                displayScale: 2
            )
        )
    }

    func test表示枠と当てはめ方から決まる縮小指定が付く() throws {
        let size = CGSize(width: 50, height: 25)

        let fit = try makeDisplayRequest(size: size, contentMode: .fit)
        let fill = try makeDisplayRequest(size: size, contentMode: .fill)

        XCTAssertEqual(
            fit.thumbnail,
            ImageRequest.ThumbnailOptions(
                size: CGSize(width: 100, height: 50), unit: .pixels, contentMode: .aspectFit
            )
        )
        XCTAssertEqual(
            fill.thumbnail,
            ImageRequest.ThumbnailOptions(
                size: CGSize(width: 100, height: 50), unit: .pixels, contentMode: .aspectFill
            )
        )
    }

    func test枠より大きい画像は当てはめ方に応じた寸法へ縮小される() throws {
        // 元寸 200x100 の画像を 50x50 の枠 (表示倍率 2 → 100x100 ピクセル) へ表示する。
        let data = try XCTUnwrap(Self.makePNG(width: 200, height: 100))
        let size = CGSize(width: 50, height: 50)

        let fit = try XCTUnwrap(makeDisplayRequest(size: size, contentMode: .fit).thumbnail)
        let fill = try XCTUnwrap(makeDisplayRequest(size: size, contentMode: .fill).thumbnail)

        let fitImage = try XCTUnwrap(fit.makeThumbnail(with: data)?.cgImage)
        let fillImage = try XCTUnwrap(fill.makeThumbnail(with: data)?.cgImage)

        // fit は枠に収まる最大 (100x50)、fill は枠を覆う最小 (200x100)。どちらも元寸を超えない。
        XCTAssertEqual(fitImage.width, 100)
        XCTAssertEqual(fitImage.height, 50)
        XCTAssertEqual(fillImage.width, 200)
        XCTAssertEqual(fillImage.height, 100)
    }

    /// 表示に使う要求の鍵は、元寸がメモリにあるかで変わらない。
    ///
    /// 鍵が経路ごとに変わると、その要求の結果を次の表示が引き当てられず、セルの再利用の
    /// たびに読み込み中を経由する。初回の描画に使える画像の有無だけが変わる。
    func test表示に使う要求の鍵は元寸の有無で変わらない() throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        let size = CGSize(width: 50, height: 50)
        // 元寸がメモリに無い間は、初回の描画に使える画像が無い。
        let cold = try makePrepared(size: size)
        XCTAssertNil(cold.cachedImage)
        XCTAssertNotNil(cold.request.thumbnail, "元寸をメモリに展開しない縮小指定が付いていません")

        // 到達点をメモリまでにした先読みが載せる、縮小指定の無い元寸の項目。
        let data = try XCTUnwrap(Self.makePNG(width: 200, height: 100))
        pipeline.cache[ImageRequest(url: remote)] = ImageContainer(
            image: try XCTUnwrap(UIImage(data: data))
        )

        let warm = try makePrepared(size: size)
        XCTAssertNotNil(warm.cachedImage, "元寸がメモリにあるのに初回の描画に使える画像がありません")
        XCTAssertEqual(
            pipeline.cache.makeImageCacheKey(for: cold.request),
            pipeline.cache.makeImageCacheKey(for: warm.request),
            "元寸の有無で表示に使う鍵が変わりました"
        )
    }

    func test元寸から縮小する経路でも当てはめ方に応じた寸法になる() throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        // 元寸 200x100 の画像をメモリへ置き、50x50 の枠 (表示倍率 2 → 100x100 ピクセル) へ表示する。
        let data = try XCTUnwrap(Self.makePNG(width: 200, height: 100))
        let source = try XCTUnwrap(UIImage(data: data))
        pipeline.cache[ImageRequest(url: remote)] = ImageContainer(image: source)

        let size = CGSize(width: 50, height: 50)
        let fitImage = try XCTUnwrap(
            makePrepared(size: size, contentMode: .fit).cachedImage?.cgImage
        )
        let fillImage = try XCTUnwrap(
            makePrepared(size: size, contentMode: .fill).cachedImage?.cgImage
        )

        // fit は枠に収まる最大 (100x50)、fill は枠を覆う最小 (200x100)。
        XCTAssertEqual(fitImage.width, 100)
        XCTAssertEqual(fitImage.height, 50)
        XCTAssertEqual(fillImage.width, 200)
        XCTAssertEqual(fillImage.height, 100)
    }

    // MARK: - キャッシュのクリアと世代

    func test全消去は世代を進めメモリのみ消去は進めない() {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 0)

        KsImageCache.clear(.memory)
        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 0, "メモリのみ消去で世代が進みました")

        KsImageCache.clear(.all)
        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 1)
    }

    func testソース単位の削除は対象のソースの識別子だけを変える() throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        XCTAssertNil(KsImageIdentity.imageID(forKey: remote.absoluteString))

        KsImageCache.remove(.remote(remote))

        XCTAssertEqual(KsImageIdentity.imageID(forKey: remote.absoluteString), "\(remote.absoluteString)#1")
        XCTAssertNil(KsImageIdentity.imageID(forKey: other.absoluteString), "他のソースの識別子が変わりました")
        // 範囲消去ではないので、他のソースの表示は読み込み直しにならない。
        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 0)
    }

    func testアセットの削除は何もしない() {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        KsImageCache.remove(.asset("logo"))

        XCTAssertNil(KsImageIdentity.imageID(forKey: "logo"))
        XCTAssertEqual(KsImageInvalidation.shared.revision, 0)
    }

    func test削除後はどの表示サイズの要求も削除前の項目に当たらない() throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        let sizes = [CGSize(width: 50, height: 50), CGSize(width: 120, height: 90)]
        let before = try sizes.map { try makeDisplayRequest(size: $0) }
        // 削除前の項目をメモリへ置く。
        for request in before {
            pipeline.cache[request] = ImageContainer(image: UIImage())
            XCTAssertNotNil(pipeline.cache[request])
        }

        KsImageCache.remove(.remote(remote))

        for size in sizes {
            let after = try makeDisplayRequest(size: size)
            XCTAssertEqual(after.imageID, "\(remote.absoluteString)#1")
            XCTAssertNil(pipeline.cache[after], "サイズ \(size) の要求が削除前の項目に当たりました")
        }
    }

    /// 本番の表示と同じ入口で組み立てた、表示に使う要求と初回描画用の画像。
    private func makePrepared(
        size: CGSize,
        contentMode: KsImageContentMode = .fill
    ) throws -> KsPreparedImageRequest {
        try XCTUnwrap(
            KsImageRequestFactory.prepare(
                source: .remote(remote), size: size, contentMode: contentMode, displayScale: 2
            )
        )
    }

    private func makeDisplayRequest(
        size: CGSize,
        contentMode: KsImageContentMode = .fill
    ) throws -> ImageRequest {
        try makePrepared(size: size, contentMode: contentMode).request
    }

    // MARK: - 失敗後の再試行

    func test失敗した表示はビューが作り直されると再び取得を試みる() async {
        KsFailingURLProtocol.reset()
        let original = ImagePipeline.shared
        ImagePipeline.shared = Self.makeFailingPipeline()
        defer { ImagePipeline.shared = original }

        let firstWindow = show(KsImage(.remote(remote)))
        await waitUntil("1 回目の取得", value: { KsFailingURLProtocol.requestCount }) { $0 >= 1 }
        firstWindow.isHidden = true

        // セルの再利用・画面への再入場に相当する、同じソースの新しいビュー。
        let secondWindow = show(KsImage(.remote(remote)))
        await waitUntil("再生成後の取得", value: { KsFailingURLProtocol.requestCount }) { $0 >= 2 }
        secondWindow.isHidden = true

        XCTAssertEqual(KsFailingURLProtocol.requestCount, 2)
    }

    private func show(_ view: some View) -> UIWindow {
        let host = UIHostingController(rootView: view.frame(width: 50, height: 50))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
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

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        while clock.now < deadline {
            if predicate(value()) {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))")
    }

    // MARK: - 補助

    /// 取得が必ず失敗するパイプライン。
    private static func makeFailingPipeline() -> ImagePipeline {
        var configuration = ImagePipeline.Configuration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [KsFailingURLProtocol.self]
        configuration.dataLoader = DataLoader(configuration: sessionConfiguration)
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        return ImagePipeline(configuration: configuration)
    }

    /// 他のテストのキャッシュを持ち込まない、この場限りのパイプライン。
    private static func makeIsolatedPipeline() -> ImagePipeline {
        var configuration = ImagePipeline.Configuration()
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        return ImagePipeline(configuration: configuration)
    }

    /// 指定した大きさの不透明な PNG。
    private static func makePNG(width: Int, height: Int) -> Data? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }
}

/// 常に失敗を返し、取得の回数を数える取得層。
private final class KsFailingURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0

    static var requestCount: Int {
        lock.withLock { count }
    }

    static func reset() {
        lock.withLock { count = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() { }
}
