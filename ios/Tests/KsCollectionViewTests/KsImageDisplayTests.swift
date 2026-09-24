import Nuke
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// `KsImage` を実際に画面へ載せ、ソースの種別ごとに画像が出るところまでを確かめる。
///
/// 要求の組み立てだけを見ると、ファイルの読み込み・バンドル済みリソースの解決・状態の
/// 切り替えのいずれもが未検証のまま緑になる。ここでは 2 段で確かめる。
/// 1. 画面へ載せた `KsImage` 自身が出した要求が成功で終わり、失敗のスロットを構成しないこと
/// 2. その結果を描いた絵の色が、ソースの画像の色と一致すること
@MainActor
final class KsImageDisplayTests: XCTestCase {
    private var pipeline: ImagePipeline!
    private var originalPipeline: ImagePipeline!
    private var windows: [UIWindow] = []
    private var temporaryFiles: [URL] = []

    private let remote = URL(string: "https://images.example.com/display.jpg")!
    /// 表示枠。ポイント単位。
    private let frame = CGSize(width: 20, height: 20)

    override func setUp() async throws {
        try await super.setUp()
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        KsImageMemoryIndex.shared.removeAll()
        KsRemoteOnlyURLProtocol.reset()

        var configuration = ImagePipeline.Configuration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [KsRemoteOnlyURLProtocol.self]
        configuration.dataLoader = DataLoader(configuration: sessionConfiguration)
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        pipeline = ImagePipeline(configuration: configuration)
        originalPipeline = ImagePipeline.shared
        ImagePipeline.shared = pipeline
    }

    override func tearDown() async throws {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
        for file in temporaryFiles {
            try? FileManager.default.removeItem(at: file)
        }
        temporaryFiles.removeAll()
        ImagePipeline.shared = originalPipeline
        originalPipeline = nil
        pipeline = nil
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        KsImageMemoryIndex.shared.removeAll()
        try await super.tearDown()
    }

    // MARK: - 3 種のソースの表示

    func testリモートのソースは画像が表示される() throws {
        let color = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        KsRemoteOnlyURLProtocol.payload = try XCTUnwrap(Self.makePNG(color: color))

        let scale = try display(source: .remote(remote), label: "リモートの画像")

        XCTAssertEqual(KsRemoteOnlyURLProtocol.requestCount, 1)
        try assertCenterColor(of: .remote(remote), displayScale: scale, matches: color)
    }

    func testファイルのソースは画像が表示される() throws {
        let color = UIColor(red: 0, green: 0, blue: 1, alpha: 1)
        let file = try makeTemporaryPNG(color: color)

        let scale = try display(source: .file(file), label: "ファイルの画像")

        // ファイルの読み込みはネットワークを通らない。
        XCTAssertEqual(KsRemoteOnlyURLProtocol.requestCount, 0)
        try assertCenterColor(of: .file(file), displayScale: scale, matches: color)
    }

    func testバンドル済みリソースのソースはローダーを通らずに表示が決まる() throws {
        let color = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        // 解決できないリソース名では失敗の表示になる。読み込み中を経由しないので、
        // 描いた時点で結果が出ている。
        let rendered = try render(
            KsImage(.asset("ks-nonexistent-asset"), failure: { Color(uiColor: color) }),
            displayScale: 2
        )

        try assertApproximately(rendered, color, label: "リソースの失敗の表示")
        XCTAssertEqual(KsRemoteOnlyURLProtocol.requestCount, 0, "リソースの表示でローダーが動きました")
        XCTAssertNil(
            KsImageRequestFactory.prepare(
                source: .asset("ks-nonexistent-asset"),
                size: frame,
                contentMode: .fill,
                displayScale: 2,
                pipeline: pipeline
            ),
            "リソースのソースでローダーへの要求が組み立てられました"
        )
    }

    // MARK: - 補助

    /// ソースを画面へ載せ、`KsImage` 自身が出した要求が成功で終わるまで待つ。
    /// 失敗のスロットが一度でも構成されたら失敗とする。戻り値は表示に使われた表示倍率。
    private func display(source: KsImageSource, label: String) throws -> CGFloat {
        let failures = KsSlotCounter()
        let window = show(
            KsImage(source, failure: {
                let _ = failures.increment()
                Color.clear
            })
        )
        let scale = window.traitCollection.displayScale

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if failures.count > 0 {
                XCTFail("\(label) が失敗の表示になりました")
                return scale
            }
            if try preparedImageExists(source: source, displayScale: scale) {
                return scale
            }
            window.rootViewController?.view.setNeedsLayout()
            window.rootViewController?.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTFail(
            "\(label) の表示が期限内に収束しませんでした。"
                + "失敗のスロットの構成回数: \(failures.count)、取得回数: \(KsRemoteOnlyURLProtocol.requestCount)"
        )
        return scale
    }

    /// 表示が使う鍵で、その大きさの画像がメモリにあるか。
    private func preparedImageExists(source: KsImageSource, displayScale: CGFloat) throws -> Bool {
        let prepared = KsImageRequestFactory.prepare(
            source: source,
            size: frame,
            contentMode: .fill,
            displayScale: displayScale,
            pipeline: pipeline
        )
        return prepared?.matchedImage != nil
    }

    /// メモリにある画像を描く経路で `KsImage` を描き、中心の色を確かめる。
    private func assertCenterColor(
        of source: KsImageSource,
        displayScale: CGFloat,
        matches expected: UIColor
    ) throws {
        let rendered = try render(KsImage(source), displayScale: displayScale)
        try assertApproximately(rendered, expected, label: "描いた画像の色")
    }

    private func assertApproximately(
        _ measured: UIColor,
        _ expected: UIColor,
        label: String
    ) throws {
        XCTAssertTrue(
            Self.isApproximately(measured, expected),
            "\(label) が一致しません。期待: \(Self.describe(expected))、実測: \(Self.describe(measured))"
        )
    }

    /// `KsImage` を表示枠の大きさで描き、中心のピクセルの色を返す。
    private func render(_ view: some View, displayScale: CGFloat) throws -> UIColor {
        let renderer = ImageRenderer(
            content: view.frame(width: frame.width, height: frame.height)
        )
        renderer.scale = displayScale
        let image = try XCTUnwrap(renderer.uiImage, "表示を描けませんでした")
        let cgImage = try XCTUnwrap(image.cgImage)
        let center = try XCTUnwrap(cgImage.cropping(to: CGRect(
            x: cgImage.width / 2, y: cgImage.height / 2, width: 1, height: 1
        )))

        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try XCTUnwrap(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(center, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
    }

    private func show(_ view: some View) -> UIWindow {
        let host = UIHostingController(
            rootView: view.frame(width: frame.width, height: frame.height)
        )
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        windows.append(window)
        return window
    }

    private static func isApproximately(_ lhs: UIColor, _ rhs: UIColor) -> Bool {
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return abs(lr - rr) < 0.12 && abs(lg - rg) < 0.12 && abs(lb - rb) < 0.12
    }

    private static func describe(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "(%.2f, %.2f, %.2f)", r, g, b)
    }

    private func makeTemporaryPNG(color: UIColor) throws -> URL {
        let data = try XCTUnwrap(Self.makePNG(color: color))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ks-image-\(UUID().uuidString).png")
        try data.write(to: url)
        temporaryFiles.append(url)
        return url
    }

    /// 一色で塗りつぶした 64x64 の PNG。表示枠より大きいので縮小の経路を通る。
    private static func makePNG(color: UIColor) -> Data? {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }
}

/// スロットが構成された回数を数える。表示の組み立て中に呼ばれるため、スレッド越しに読める形にする。
private final class KsSlotCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func increment() {
        lock.withLock { value += 1 }
    }
}

/// リモートの取得だけを引き受けるスタブ。ファイルの読み込みは横取りしない。
private final class KsRemoteOnlyURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0
    nonisolated(unsafe) static var payload = Data()

    static var requestCount: Int {
        lock.withLock { count }
    }

    static func reset() {
        lock.withLock { count = 0 }
        payload = Data()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
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

    override func stopLoading() { }
}
