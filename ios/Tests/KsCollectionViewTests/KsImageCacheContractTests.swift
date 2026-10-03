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
        KsImageMemoryIndex.shared.removeAll()
        KsInvalidInput.reset()
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
        configuration.makeImageDecoder = { KsCountingImageDecoder(context: $0) }
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
        KsImageMemoryIndex.shared.removeAll()
        KsInvalidInput.reset()
        try await super.tearDown()
    }

    private let target = URL(string: "https://images.example.com/1.jpg")!
    private let uncached = URL(string: "https://images.example.com/uncached.jpg")!

    func testディスク到達点の後の表示ではネットワークが走らない() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [plain(target)], destination: .disk)

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
        loading.prefetch(requests: [plain(target)], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        _ = try await pipeline.image(for: target)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)
    }

    /// 表示はメモリ到達点の先読み結果を引き当て、ローダーへの要求もデコードのやり直しも無い。
    func test表示はメモリ到達点の先読み結果を再デコードせずに使う() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [plain(target)], destination: .memory)

        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        let prepared = try prepare(.remote(target), size: CGSize(width: 4, height: 4))

        XCTAssertNotNil(prepared.matchedImage, "先読みの結果が引き当てられていません")
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1, "表示で再ダウンロードが起きました")
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1, "表示で再デコードが起きました")
    }

    /// メモリに画像がある表示は、読み込み中のスロットを一度も構成しない。
    ///
    /// 一瞬だけ挟まる読み込み中は最終状態を見るだけでは捉えられないため、スロットが構成された
    /// 回数そのものを数える。
    func test読み込み中のスロットはメモリにある画像では一度も構成されない() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [plain(target)], destination: .memory)
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
        loading.prefetch(requests: [plain(target)], destination: .memory)

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
        loading.prefetch(requests: [plain(target), plain(other)], destination: .memory)

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
        loading.prefetch(requests: [plain(target)], destination: .memory)

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
        loading.prefetch(requests: [plain(target)], destination: .memory)

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
        loading.prefetch(requests: [plain(target)], destination: .memory)
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

    /// メモリから引き当てて表示中の `KsImage` は、メモリのみ消去の後に親が組み立て直されても
    /// 読み込み中の表示へ戻らない。
    func test引き当てて表示中の画像はメモリのみ消去の後に親が組み立て直されても置き換わらない() async throws {
        let counter = KsCompositionCounter()
        let host = KsRebuildTrigger()
        let window = try await showMatchedImage(counter: counter, host: host)
        defer { window.isHidden = true }

        KsImageCache.clear(.memory)
        let decodesBeforeRebuild = KsCountingImageDecoder.decodeCount
        rebuildParent(host)

        XCTAssertEqual(counter.count, 0, "メモリのみ消去の後に読み込み中の表示へ戻りました")
        XCTAssertEqual(
            KsCountingImageDecoder.decodeCount, decodesBeforeRebuild, "表示中の画像を読み直しました"
        )
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "再ダウンロードが起きました")
    }

    /// 引き当てて表示中の `KsImage` は、メモリのみ消去の後に別のソースの削除で組み立て直されても
    /// 読み込み中の表示へ戻らない。
    func test引き当てて表示中の画像はメモリのみ消去の後に別のソースの削除があっても置き換わらない() async throws {
        let counter = KsCompositionCounter()
        let host = KsRebuildTrigger()
        let window = try await showMatchedImage(counter: counter, host: host)
        defer { window.isHidden = true }

        KsImageCache.clear(.memory)
        // 別のソースの削除は、表示中のすべての `KsImage` を組み立て直させる。
        KsImageCache.remove(.remote(uncached))
        waitPumpingRunLoop(
            "削除した別のソースの取り直し",
            value: { KsStubURLProtocol.requestCount(for: self.uncached) }
        ) { $0 >= 2 }

        XCTAssertEqual(counter.count, 0, "メモリのみ消去の後に読み込み中の表示へ戻りました")
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "再ダウンロードが起きました")
    }

    /// 表示中の画像を保持していても、ソース単位の削除では読み込み中へ戻って取得をやり直す。
    func test引き当てた画像を保持していてもソース単位の削除では取得をやり直す() async throws {
        let counter = KsCompositionCounter()
        let host = KsRebuildTrigger()
        let window = try await showMatchedImage(counter: counter, host: host)
        defer { window.isHidden = true }

        KsImageCache.clear(.memory)
        rebuildParent(host)
        KsImageCache.remove(.remote(target))

        waitPumpingRunLoop(
            "削除後の取り直し",
            value: { KsStubURLProtocol.requestCount(for: self.target) }
        ) { $0 >= 2 }
        XCTAssertGreaterThan(counter.count, 0, "削除の後に読み込み中の表示を経由していません")
    }

    /// 表示中の画像を保持していても、全消去では読み込み中へ戻って取得をやり直す。
    func test引き当てた画像を保持していても全消去では取得をやり直す() async throws {
        let counter = KsCompositionCounter()
        let host = KsRebuildTrigger()
        let window = try await showMatchedImage(counter: counter, host: host)
        defer { window.isHidden = true }

        KsImageCache.clear(.memory)
        rebuildParent(host)
        KsImageCache.clear(.all)

        waitPumpingRunLoop(
            "全消去後の取り直し",
            value: { KsStubURLProtocol.requestCount(for: self.target) }
        ) { $0 >= 2 }
        XCTAssertGreaterThan(counter.count, 0, "全消去の後に読み込み中の表示を経由していません")
    }

    /// メモリのみ消去を挟んで表示するソースを切り替えて戻したとき、切り替える前に引き当てて持っていた
    /// 画像は使わず、ディスクの元データから再デコードする。
    func test引き当てたソースからアセットへ切り替えてメモリのみ消去の後に戻すとディスクから再デコードする() async throws {
        try await assertSwitchingBackAfterClearingMemoryRedecodes(
            via: .asset("ks-nonexistent-asset")
        )
    }

    /// 別の URL を挟んだ場合も同じく、戻したソースはディスクの元データから再デコードする。
    func test引き当てたソースから別のURLへ切り替えてメモリのみ消去の後に戻すとディスクから再デコードする() async throws {
        try await assertSwitchingBackAfterClearingMemoryRedecodes(via: .remote(uncached))
    }

    // 引き当てで表示中のソースを `other` へ切り替え、メモリのみ消去してから元へ戻す。戻した表示は
    // 読み込み中を経由してディスクから再デコードされ、再ダウンロードはしない。
    private func assertSwitchingBackAfterClearingMemoryRedecodes(via other: KsImageSource) async throws {
        let counter = KsCompositionCounter()
        let host = KsRebuildTrigger()
        let target = target
        // 親の状態 1 のときだけ別のソースを表示する。同じ位置の同じ型の `KsImage` なので、状態は引き継がれる。
        let window = try await showMatchedImage(counter: counter, host: host) { tick in
            tick == 1 ? other : .remote(target)
        }
        defer { window.isHidden = true }

        rebuildParent(host)
        KsImageCache.clear(.memory)
        let decodesBeforeReturn = KsCountingImageDecoder.decodeCount
        let countBeforeReturn = counter.count
        rebuildParent(host)

        waitPumpingRunLoop(
            "戻したソースの再デコード",
            value: { KsCountingImageDecoder.decodeCount }
        ) { $0 > decodesBeforeReturn }
        XCTAssertGreaterThan(counter.count, countBeforeReturn, "消去前に持っていた画像で表示しました")
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "再ダウンロードが起きました")
    }

    /// 先読みでメモリへ載せた画像を、親を組み立て直せる形で表示し、引き当てで表示し終えるまで待つ。
    /// `source` は親の状態から表示するソースを決める。既定は常に先読みした画像。
    private func showMatchedImage(
        counter: KsCompositionCounter,
        host: KsRebuildTrigger,
        source: ((Int) -> KsImageSource)? = nil
    ) async throws -> UIWindow {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [plain(target)], destination: .memory)
        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)

        // 2 枚並べる。片方はキャッシュ済み、もう片方は未取得で、後者の取得の完了が
        // 「表示が組み上がった」ことの合図になる。
        let uncached = uncached
        let target = target
        let source = source ?? { _ in .remote(target) }
        let window = show(
            KsRebuildingParent(trigger: host) { tick in
                VStack(spacing: 0) {
                    // 読み込み中の表示が親の状態に依存する、よくある形。
                    KsImage(source(tick), loading: {
                        let _ = tick
                        let _ = counter.increment()
                        Color.clear
                    })
                    .frame(width: 4, height: 4)
                    KsImage(.remote(uncached)).frame(width: 4, height: 4)
                }
            }
        )
        waitPumpingRunLoop(
            "表示の取得の完了",
            value: { self.pipeline.cache.containsData(for: ImageRequest(url: uncached)) }
        ) { $0 }
        // 未取得の 1 枚のデコードまで待つ。待たないと、後から数えるデコードの回数にこの 1 回が混ざる。
        waitPumpingRunLoop("表示のデコードの完了", value: { KsCountingImageDecoder.decodeCount }) { $0 >= 2 }
        XCTAssertEqual(counter.count, 0, "引き当てで表示されていません")
        return window
    }

    // 親の状態を変えて本体を組み立て直させ、組み立て直しが済むまで待つ。
    private func rebuildParent(_ host: KsRebuildTrigger) {
        let before = host.buildCount
        host.tick += 1
        waitPumpingRunLoop("親の組み立て直し", value: { host.buildCount }) { $0 > before }
        // 子の `KsImage` は親と同じ更新の中で組み立て直される。その結果を描画の段まで反映させる。
        for window in windows {
            window.rootViewController?.view.setNeedsLayout()
            window.rootViewController?.view.layoutIfNeeded()
        }
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

    // 実行ループを決まった回数だけ回す。起きないことを確かめる検査で、起き得る処理に機会を与えるために使う。
    private func pumpRunLoop(turns: Int) {
        for _ in 0..<turns {
            for window in windows {
                window.rootViewController?.view.setNeedsLayout()
                window.rootViewController?.view.layoutIfNeeded()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// 消去より前に始まった先読みは、完了してもキャッシュへ書き戻さない。
    func test消去より前に始まった先読みは完了してもキャッシュへ戻らない() async throws {
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate

        let loading = KsNukeImageLoading(pipeline: pipeline)
        let prefetcher = KsImagePrefetcher<URL>(
            loading: loading,
            id: { AnyHashable($0) },
            resources: { [KsResource($0)] },
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
            resources: { [KsResource($0)] },
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

    // MARK: - 先読みの表示幅

    /// 列幅で宣言した先読みは、列幅の正方形を覆う大きさに縮小して載せ、元寸は載せない。
    func test幅つきの先読みは幅の正方形を覆う大きさで載り元寸は載らない() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 200, height: 100)
        let request = plain(target, widthPixels: 40)
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)

        await waitUntil("縮小した画像の保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }

        let image = try XCTUnwrap(pipeline.cache[request.imageRequest]?.image)
        // 200x100 を 40x40 の正方形を覆う最小の大きさへ縮めると 80x40 になる。
        XCTAssertEqual(KsImageRequestFactory.pixelSize(of: image), CGSize(width: 80, height: 40))
        XCTAssertNil(pipeline.cache[ImageRequest(url: target)], "元寸の画像がメモリに載りました")
    }

    /// 宣言した幅より元寸が小さい画像は拡大せず、元寸のまま載せる。
    func test元寸が宣言した幅より小さければ拡大せずに載る() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 8, height: 8)
        let request = plain(target, widthPixels: 100)
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)

        await waitUntil("画像の保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }

        let image = try XCTUnwrap(pipeline.cache[request.imageRequest]?.image)
        XCTAssertEqual(KsImageRequestFactory.pixelSize(of: image), CGSize(width: 8, height: 8))
    }

    /// 到達点がディスクまでのときは幅を宣言しても使わず、メモリには何も載らない。
    func test到達点diskでは幅を宣言しても元データの保存までで止まる() async throws {
        let prefetcher = KsImagePrefetcher<URL>(
            loading: KsNukeImageLoading(pipeline: pipeline),
            id: { AnyHashable($0) },
            resources: { [KsResource($0, width: .column)] },
            destination: .disk,
            metrics: { KsPrefetchMetrics(columnWidth: 20, displayScale: 2) }
        )
        prefetcher.prefetch(items: [target])

        await waitUntil("ディスクキャッシュへの保存", value: { self.cachedDataExists() }) { $0 }

        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 0, "ディスクまでの先読みでデコードしました")
        XCTAssertNil(pipeline.cache[ImageRequest(url: target)])
        XCTAssertNil(pipeline.cache[plain(target, widthPixels: 40).imageRequest])
        XCTAssertTrue(KsImageMemoryIndex.shared.requests(forEffectiveID: target.absoluteString).isEmpty)
    }

    /// 幅ありと幅なしを混ぜた宣言では、幅ありは縮小した画像、幅なしは元寸の画像が載る。
    func test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 200, height: 200)
        let banner = URL(string: "https://images.example.com/banner.jpg")!
        let prefetcher = KsImagePrefetcher<URL>(
            loading: KsNukeImageLoading(pipeline: pipeline),
            id: { AnyHashable($0) },
            resources: { [KsResource($0, width: .column), KsResource(banner)] },
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: 25, displayScale: 2) }
        )
        prefetcher.prefetch(items: [target])

        let column = plain(target, widthPixels: 50).imageRequest
        await waitUntil("2 件の保存", value: {
            self.pipeline.cache[column] != nil && self.pipeline.cache[ImageRequest(url: banner)] != nil
        }) { $0 }

        XCTAssertEqual(
            KsImageRequestFactory.pixelSize(of: try XCTUnwrap(pipeline.cache[column]?.image)),
            CGSize(width: 50, height: 50)
        )
        XCTAssertEqual(
            KsImageRequestFactory.pixelSize(of: try XCTUnwrap(pipeline.cache[ImageRequest(url: banner)]?.image)),
            CGSize(width: 200, height: 200)
        )
        XCTAssertNil(pipeline.cache[ImageRequest(url: target)], "幅ありの要素の元寸が載りました")
    }

    // MARK: - メモリ項目の引き当て

    /// 先読みの縮小済み項目で表示し、読み込み中を経由せず、ローダーへの表示の要求も出さない。
    func test先読みの縮小済み項目で表示し読み込み中も表示の要求も経由しない() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 64, height: 64)
        // 20pt の枠は表示倍率 2〜3 で 40〜60 ピクセル。64 ピクセルの項目はどちらでも許容範囲に入る。
        let request = plain(target, widthPixels: 64)
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("縮小した画像の保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        let counter = KsCompositionCounter()
        let uncached = URL(string: "https://images.example.com/uncached.jpg")!
        let window = show(
            VStack(spacing: 0) {
                KsImage(.remote(target), loading: {
                    let _ = counter.increment()
                    Color.clear
                })
                .frame(width: 20, height: 20)
                KsImage(.remote(uncached)).frame(width: 20, height: 20)
            }
        )
        defer { window.isHidden = true }

        waitPumpingRunLoop("表示の組み上がり", value: { KsStubURLProtocol.requestCount }) { $0 >= 2 }

        XCTAssertEqual(counter.count, 0, "読み込み中の表示を経由しました")
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "表示で再ダウンロードが起きました")
        // 表示の要求を出していれば、その鍵が索引に登録されている。
        XCTAssertEqual(
            KsImageMemoryIndex.shared.requests(forEffectiveID: target.absoluteString).map(\.thumbnail),
            [request.imageRequest.thumbnail],
            "引き当てたのに表示の要求を出しました"
        )
    }

    /// 画面に出る前に組み立てられた表示は、画面に出る時点でメモリを照会し直す。組み立ての時点で
    /// 先読みが未完了でも、画面に出る時点で完了していれば、その項目で表示し、読み込み中も表示の要求も
    /// 経由しない。
    ///
    /// コレクションのセルは、先読みの通知と同じ時点で前もって組み立てられ、画面に出るのは後になる。
    /// ここでは実物のコレクションビューのセルを、画面に出る直前の通知 (`willDisplay`) の中で組み立て、
    /// その後で先読みの完了に当たる「メモリへの項目の出現」を起こす。画面に出る時点の処理 (`onAppear`)
    /// はその後に走る。
    func test前もって組み立てた後に先読みが完了すれば画面に出る時点で引き当てて読み込み中を経由しない() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 64, height: 64)
        let request = plain(target, widthPixels: 64)
        // 先読みを完了させ、載った項目を控えてからメモリだけを空ける。索引は先読みの鍵を覚えたままなので、
        // 項目をメモリへ戻した時点が先読みの完了に当たる。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("縮小した画像の保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)
        let prefetched = try XCTUnwrap(pipeline.cache[request.imageRequest])
        pipeline.cache[request.imageRequest] = nil

        let counter = KsCompositionCounter()
        let target = target
        let uncached = uncached
        let pipeline = pipeline!
        let driver = KsPrebuildingCollectionDriver(
            sources: [.remote(target), .remote(uncached)],
            counter: counter,
            watchedItem: 0
        ) { cell in
            // 組み立てが枠の大きさ付きで済んだかを、引き当てに失敗した表示の要求の鍵が索引に登録されたかで見る。
            // 済んでいなければ、この検査の前提 (前もって組み立てた状態) が成り立っていない。
            let displayRegistered = KsImageMemoryIndex.shared.requests(forEffectiveID: target.absoluteString)
                .contains { $0.thumbnail != request.imageRequest.thumbnail }
            pipeline.cache[request.imageRequest] = prefetched
            return displayRegistered
        }
        let window = driver.show()
        windows.append(window)
        defer { window.isHidden = true }

        // 未取得の 1 枚の取得とデコードが済むことを「画面に出た表示が組み上がった」合図にする。
        waitPumpingRunLoop(
            "未取得の画像の取得の完了",
            value: { self.pipeline.cache.containsData(for: ImageRequest(url: uncached)) }
        ) { $0 }
        waitPumpingRunLoop("未取得の画像のデコードの完了", value: { KsCountingImageDecoder.decodeCount }) { $0 >= 2 }

        XCTAssertEqual(driver.prebuiltBeforeAppearing, true, "画面に出る前の組み立てが枠の大きさ付きで行われていません")
        XCTAssertGreaterThan(driver.compositionsBeforeAppearing, 0, "画面に出る前に読み込み中の表示が組み立てられていません")
        XCTAssertEqual(
            counter.count, driver.compositionsBeforeAppearing, "画面に出る時点で読み込み中の表示を経由しました"
        )
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 2, "画面に出る時点でデコードをやり直しました")
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "表示で再ダウンロードが起きました")
    }

    /// 画面に出る時点で引き当てた表示も、枠が変わって項目が許容範囲の外になれば、新しい枠で縮小デコードする。
    ///
    /// 64 ピクセルの項目を 20pt (表示倍率 2 で 40 ピクセル) の枠で画面に出る時点に引き当て、そのまま枠を
    /// 80pt (160 ピクセル) に広げる。64 / 160 = 0.4 で許容範囲の下限 0.5 を割るため、新しい枠の大きさで
    /// 縮小デコードの要求が出る。
    func test画面に出る時点で引き当てた後に枠が範囲外へ広がると新しい枠で縮小デコードする() async throws {
        let frame = KsWatchedFrame()
        let driver = try await showRematchedOnAppearance(frame: frame)
        let decodesBeforeResize = KsCountingImageDecoder.decodeCount

        frame.side = 80
        waitPumpingRunLoop("広げた枠での縮小デコード", value: { KsCountingImageDecoder.decodeCount }) {
            $0 > decodesBeforeResize
        }
        let resizedRequest = try displayRequest(size: CGSize(width: 80, height: 80), displayScale: frame.displayScale)
        waitPumpingRunLoop(
            "広げた枠の大きさで縮小した項目の保存",
            value: { self.pipeline.cache[resizedRequest]?.image.cgImage?.width ?? 0 }
        ) { $0 == 160 }
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "表示で再ダウンロードが起きました")
        XCTAssertTrue(driver.prebuiltBeforeAppearing == true)
    }

    /// 画面に出る時点で引き当てた表示は、枠が変わっても項目が許容範囲の内側にあれば、同じ項目で表示を続け、
    /// デコードし直さず、読み込み中も経由しない。
    ///
    /// 64 ピクセルの項目を 20pt (表示倍率 2 で 40 ピクセル) の枠で画面に出る時点に引き当て、枠を 24pt
    /// (48 ピクセル) に変える。64 / 48 ≒ 1.33 で許容範囲の内側にある。
    func test画面に出る時点で引き当てた後に枠が変わっても範囲内なら再デコードしない() async throws {
        let frame = KsWatchedFrame()
        let driver = try await showRematchedOnAppearance(frame: frame)
        let decodesBeforeResize = KsCountingImageDecoder.decodeCount
        let compositionsBeforeResize = driver.loadingCompositions

        frame.side = 24
        waitPumpingRunLoop("変えた枠での配置", value: { frame.laidOutSide }) { $0 == 24 }
        // 配置の後に表示の要求が出ていれば、その取得とデコードは実行ループの数周のうちに進む。
        // 配置を収束の合図にしたうえで、要求が進み得る周回を回してから数える。
        pumpRunLoop(turns: 20)

        XCTAssertEqual(KsCountingImageDecoder.decodeCount, decodesBeforeResize, "範囲内なのにデコードし直しました")
        XCTAssertEqual(driver.loadingCompositions, compositionsBeforeResize, "範囲内なのに読み込み中の表示を経由しました")
        let resizedRequest = try displayRequest(size: CGSize(width: 24, height: 24), displayScale: frame.displayScale)
        XCTAssertNil(pipeline.cache[resizedRequest], "範囲内なのに変えた枠の大きさで縮小した項目を載せました")
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: target), 1, "表示で再ダウンロードが起きました")
    }

    /// 元寸 400 ピクセルの画像を幅 64 ピクセルで先読みした項目を、組み立ての時点では外れ、画面に出る時点で
    /// 引き当てる形で表示する。
    /// `frame` は見張るセルの枠の大きさで、引き当てた後に変えられる。
    private func showRematchedOnAppearance(frame: KsWatchedFrame) async throws -> KsPrebuildingCollectionDriver {
        // 元寸は広げた枠より大きくし、広げた枠での縮小デコードが枠の大きさの項目を載せられるようにする。
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 400, height: 400)
        let request = plain(target, widthPixels: 64)
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("縮小した画像の保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)
        let prefetched = try XCTUnwrap(pipeline.cache[request.imageRequest])
        pipeline.cache[request.imageRequest] = nil

        let counter = KsCompositionCounter()
        let uncached = uncached
        let pipeline = pipeline!
        let driver = KsPrebuildingCollectionDriver(
            sources: [.remote(target), .remote(uncached)],
            counter: counter,
            watchedItem: 0,
            watchedFrame: frame
        ) { _ in
            pipeline.cache[request.imageRequest] = prefetched
            return true
        }
        let window = driver.show()
        windows.append(window)

        waitPumpingRunLoop(
            "未取得の画像の取得の完了",
            value: { self.pipeline.cache.containsData(for: ImageRequest(url: uncached)) }
        ) { $0 }
        waitPumpingRunLoop("未取得の画像のデコードの完了", value: { KsCountingImageDecoder.decodeCount }) { $0 >= 2 }
        waitPumpingRunLoop("見張るセルの配置", value: { frame.laidOutSide }) { $0 == 20 }

        XCTAssertEqual(driver.prebuiltBeforeAppearing, true, "画面に出る前の組み立てが行われていません")
        XCTAssertEqual(
            counter.count, driver.compositionsBeforeAppearing, "画面に出る時点で読み込み中の表示を経由しました"
        )
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 2, "画面に出る時点で引き当てていません")
        return driver
    }

    // MARK: - 画面に出る時点まで要求を待つかの判定

    /// 表示の要求を画面に出る時点まで待つのは、同じ画像のメモリまでの先読みが取得中の可能性があるときだけ。
    /// 取得中は待ち、取得が終わって項目がメモリに載れば引き当てる (待つ判定は不要になる)。
    func test取得中のメモリまでの先読みがあるときだけ表示の要求を画面に出る時点まで待つ() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 64, height: 64)
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate
        let size = CGSize(width: 20, height: 20)

        XCTAssertFalse(try prepare(.remote(target), size: size).mayBeLoadingPrefetch, "先読みが無いのに待ちました")

        let loading = KsNukeImageLoading(pipeline: pipeline)
        let request = plain(target, widthPixels: 64)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("取得の開始", value: { KsStubURLProtocol.requestCount }) { $0 >= 1 }
        XCTAssertTrue(try prepare(.remote(target), size: size).mayBeLoadingPrefetch, "取得中の先読みがあるのに待ちません")

        gate.signal()
        await waitUntil("縮小した画像の保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }
        let prepared = try prepare(.remote(target), size: size)
        XCTAssertNotNil(prepared.matchedImage, "完了した先読みの項目を引き当てませんでした")
        XCTAssertFalse(prepared.mayBeLoadingPrefetch)

        // 一度載ったのを見た先読みは、メモリから追い出された後は取得中とみなさない。
        pipeline.cache[request.imageRequest] = nil
        XCTAssertFalse(try prepare(.remote(target), size: size).mayBeLoadingPrefetch, "完了した先読みを取得中とみなしました")
    }

    /// ディスクまでの先読み・取り消した先読みでは、表示の要求を待たない。
    func testディスクまでの先読みと取り消した先読みでは表示の要求を待たない() async throws {
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate
        defer {
            gate.signal()
            gate.signal()
        }
        let size = CGSize(width: 20, height: 20)
        let loading = KsNukeImageLoading(pipeline: pipeline)

        loading.prefetch(requests: [plain(target)], destination: .disk)
        await waitUntil("ディスクまでの取得の開始", value: { KsStubURLProtocol.requestCount }) { $0 >= 1 }
        XCTAssertFalse(try prepare(.remote(target), size: size).mayBeLoadingPrefetch, "ディスクまでの先読みで待ちました")

        let request = plain(uncached, widthPixels: 64)
        loading.prefetch(requests: [request], destination: .memory)
        XCTAssertTrue(try prepare(.remote(uncached), size: size).mayBeLoadingPrefetch)
        loading.cancel(requests: [request])
        XCTAssertFalse(try prepare(.remote(uncached), size: size).mayBeLoadingPrefetch, "取り消した先読みで待ちました")
    }

    /// 先読みが取得中のまま画面に出た表示は、画面に出る時点の引き当てに外れれば、その場で表示の要求を出して
    /// 枠の大きさで縮小デコードする (待った要求を出し忘れない)。
    func test先読みが取得中のまま画面に出た表示は表示の要求を出して画像を表示する() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 64, height: 64)
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate
        let loading = KsNukeImageLoading(pipeline: pipeline)
        let request = plain(target, widthPixels: 64)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("取得の開始", value: { KsStubURLProtocol.requestCount }) { $0 >= 1 }

        let window = show(KsImage(.remote(target)).frame(width: 10, height: 10))
        defer { window.isHidden = true }
        // 画面に出た表示の組み立てが、取得中の先読みを待つ経路を通ったことを確かめる。
        let displayScale = window.traitCollection.displayScale
        XCTAssertTrue(
            try prepare(.remote(target), size: CGSize(width: 10, height: 10), displayScale: displayScale)
                .mayBeLoadingPrefetch
        )

        // 保留していた応答を、先読みの分と表示の分の両方について返す。
        for _ in 0..<4 { gate.signal() }
        let display = try displayRequest(size: CGSize(width: 10, height: 10), displayScale: displayScale)
        waitPumpingRunLoop("表示の要求で縮小した項目の保存", value: { self.pipeline.cache[display] != nil }) { $0 }
        XCTAssertNotNil(pipeline.cache[request.imageRequest], "先読みの項目が載っていません")
    }

    /// 組み立ての時点で先読みが取得中のため画面に出る時点まで待った表示が、表示の要求で読み込んだ画像は、
    /// メモリのみ消去の後に親が組み立て直されても読み込み中へ戻らず、ディスクから再デコードしない。
    func test先読みの取得中に待った表示が読み込んだ画像はメモリのみ消去の後に親が組み立て直されても置き換わらない() async throws {
        KsStubURLProtocol.payloadOverride = Self.makePNG(width: 64, height: 64)
        let gate = DispatchSemaphore(value: 0)
        KsStubURLProtocol.gate = gate
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [plain(target, widthPixels: 64)], destination: .memory)
        await waitUntil("取得の開始", value: { KsStubURLProtocol.requestCount }) { $0 >= 1 }

        let host = KsRebuildTrigger()
        let target = target
        let window = show(
            KsRebuildingParent(trigger: host) { tick in
                KsImage(.remote(target), loading: {
                    let _ = tick
                    Color.clear
                })
                .frame(width: 10, height: 10)
            }
        )
        defer { window.isHidden = true }
        // 画面に出た表示の組み立てが、取得中の先読みを待つ経路を通ったことを確かめる。
        let displayScale = window.traitCollection.displayScale
        XCTAssertTrue(
            try prepare(.remote(target), size: CGSize(width: 10, height: 10), displayScale: displayScale)
                .mayBeLoadingPrefetch
        )

        // 保留していた応答を、先読みの分と表示の分の両方について返し、両方のデコードまで待つ。
        for _ in 0..<4 { gate.signal() }
        let display = try displayRequest(size: CGSize(width: 10, height: 10), displayScale: displayScale)
        waitPumpingRunLoop("表示の要求で縮小した項目の保存", value: { self.pipeline.cache[display] != nil }) { $0 }
        waitPumpingRunLoop("先読みと表示のデコードの完了", value: { KsCountingImageDecoder.decodeCount }) { $0 >= 2 }
        pumpRunLoop(turns: 10)

        KsImageCache.clear(.memory)
        let decodesBeforeRebuild = KsCountingImageDecoder.decodeCount
        let requestsBeforeRebuild = KsStubURLProtocol.requestCount(for: target)
        rebuildParent(host)
        pumpRunLoop(turns: 30)

        XCTAssertEqual(
            KsCountingImageDecoder.decodeCount, decodesBeforeRebuild, "表示中の画像を読み直しました"
        )
        XCTAssertEqual(
            KsStubURLProtocol.requestCount(for: target), requestsBeforeRebuild, "再ダウンロードが起きました"
        )
    }

    /// メモリから追い出された項目は、索引に残っていても引き当てず、ディスクの元データから再デコードする。
    func test追い出された項目はディスクの元データから再デコードする() async throws {
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [plain(target)], destination: .memory)
        await waitUntil("メモリキャッシュへの保存", value: { self.cachedImageExists() }) { $0 }
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 1)

        // ローダーの LRU による追い出しに相当する。ライブラリの消去操作は通さない。
        pipeline.cache.removeAll(caches: [.memory])

        let prepared = try prepare(.remote(target), size: CGSize(width: 4, height: 4))
        XCTAssertNil(prepared.matchedImage, "追い出された項目が引き当てられました")
        _ = try await pipeline.image(for: prepared.request)

        XCTAssertEqual(KsStubURLProtocol.requestCount, 1, "再ダウンロードが起きました")
        XCTAssertEqual(KsCountingImageDecoder.decodeCount, 2, "ディスクからの再デコードが起きていません")
    }

    // MARK: - 任意キー

    private let signedA = URL(string: "https://images.example.com/photo.jpg?sig=a")!
    private let signedB = URL(string: "https://images.example.com/photo.jpg?sig=b")!

    /// 署名だけが違う URL でも、同じキーなら先読みの項目で表示し、ネットワークを使わない。
    func test署名が変わっても同じキーなら先読みの項目で表示する() async throws {
        let request = keyed(signedA, key: "p1", widthPixels: 8)
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("先読みの保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }

        let prepared = try prepare(.remote(signedB, key: "p1"), size: CGSize(width: 4, height: 4))

        XCTAssertNotNil(prepared.matchedImage, "同じキーの先読みの項目が使われていません")
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedB), 0)
    }

    /// 起動をまたいでも、同じキーならディスクに保存した元データから表示し、ネットワークを使わない。
    func test起動をまたいでも同じキーならディスクの元データから表示する() async throws {
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [keyed(signedA, key: "p1")], destination: .disk)
        await waitUntil("ディスクキャッシュへの保存", value: {
            self.pipeline.cache.containsData(for: self.keyed(self.signedA, key: "p1").imageRequest)
        }) { $0 }
        (pipeline.configuration.dataCache as? DataCache)?.flush()

        // 起動し直しに相当する。メモリは空で、同じ保存先を読む新しいパイプラインになる。
        relaunchPipeline()

        let prepared = try prepare(.remote(signedB, key: "p1"), size: CGSize(width: 4, height: 4))
        XCTAssertNil(prepared.matchedImage)
        _ = try await pipeline.image(for: prepared.request)

        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedB), 0, "署名の違う URL を取得しました")
        XCTAssertEqual(KsStubURLProtocol.requestCount, 1)
    }

    /// キーを付けない画像は URL で見分けるので、URL が違えば別の画像として取得する。
    func testキーなしは別のURLを別の画像として取得する() async throws {
        let first = try prepare(.remote(signedA), size: CGSize(width: 4, height: 4))
        _ = try await pipeline.image(for: first.request)

        let second = try prepare(.remote(signedB), size: CGSize(width: 4, height: 4))
        XCTAssertNil(second.matchedImage)
        _ = try await pipeline.image(for: second.request)

        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedB), 1)
    }

    /// キーを付けて先読みした画像は、ローダー付属のビューが URL で直接引く項目とは共有しない。
    func testキー付きの先読みはローダー付属のビューの要求と共有しない() async throws {
        let request = keyed(signedA, key: "p1")
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("先読みの保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }

        let plainRequest = ImageRequest(url: signedA)
        XCTAssertNil(pipeline.cache[plainRequest], "付属ビューの要求がキー付きの項目に当たりました")
        XCTAssertFalse(pipeline.cache.containsData(for: plainRequest))

        // 付属ビュー側は通常どおり取得し、キー付きの項目はそのまま残る。
        _ = try await pipeline.image(for: plainRequest)
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedA), 2)
        XCTAssertNotNil(pipeline.cache[request.imageRequest])
    }

    /// キーに別の画像の URL と同じ文字列を付けても、その URL の画像とは別の画像として扱う。
    func testキーとURLが同じ文字列でも衝突しない() async throws {
        // 画像 A を URL (キーなし) で表示して載せる。
        let a = try prepare(.remote(signedA), size: CGSize(width: 4, height: 4))
        _ = try await pipeline.image(for: a.request)
        // 画像 B は別の URL で、キーに A の URL と同じ文字列を付ける。
        let bSource = KsImageSource.remote(signedB, key: signedA.absoluteString)

        let b = try prepare(bSource, size: CGSize(width: 4, height: 4))
        XCTAssertNil(b.matchedImage, "B が A の項目を使いました")
        _ = try await pipeline.image(for: b.request)
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedB), 1)

        KsImageCache.remove(.remote(signedA))

        XCTAssertFalse(pipeline.cache.containsData(for: ImageRequest(url: signedA)), "A が消えていません")
        XCTAssertTrue(
            pipeline.cache.containsData(for: keyed(signedB, key: signedA.absoluteString).imageRequest),
            "A の削除で B まで消えました"
        )
    }

    /// 削除で進んだ世代は、世代の区切りらしき文字を含む別のキーと衝突しない。
    func test削除の世代は別のキーと衝突しない() async throws {
        let size = CGSize(width: 4, height: 4)
        // P を表示し、削除してから表示し直す。
        let p = KsImageSource.remote(signedA, key: "p1")
        _ = try await pipeline.image(for: try prepare(p, size: size).request)
        KsImageCache.remove(p)
        _ = try await pipeline.image(for: try prepare(p, size: size).request)
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedA), 2)

        // Q は P のキーに世代の区切りらしき文字を連ねたキーを持つ別の画像。
        let q = KsImageSource.remote(signedB, key: "p1#1")
        let prepared = try prepare(q, size: size)
        XCTAssertNil(prepared.matchedImage, "Q が P の項目を使いました")
        _ = try await pipeline.image(for: prepared.request)
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedB), 1)

        // P は Q の項目を使わず、自分の項目で表示される。
        XCTAssertNotNil(try prepare(p, size: size).matchedImage)
        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedA), 2)
    }

    /// 取得済みの画像は、署名だけが違う配列に差し替えて出し直しても、キーでキャッシュに当たり取得しない。
    func test取得済みの画像は署名が変わっても取り直さない() async throws {
        struct Photo {
            let id: String
            let url: URL
        }
        let prefetcher = KsImagePrefetcher<Photo>(
            loading: KsNukeImageLoading(pipeline: pipeline),
            id: { AnyHashable($0.id) },
            resources: { [KsResource($0.url, width: .fixed(4), key: $0.id)] },
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: 4, displayScale: 2) }
        )
        prefetcher.prefetch(items: [Photo(id: "p1", url: signedA)])
        let done = keyed(signedA, key: "p1", widthPixels: 8).imageRequest
        await waitUntil("先読みの保存", value: { self.pipeline.cache[done] != nil }) { $0 }

        // 署名だけが違う配列へ差し替える。続けて出す対照の取得が終われば、差し替えで出し直した
        // 要求の処理 (キャッシュに当たれば取得しない) も済んでいる。
        let control = URL(string: "https://images.example.com/control.jpg")!
        prefetcher.retain(items: [Photo(id: "p1", url: signedB)])
        prefetcher.prefetch(items: [Photo(id: "control", url: control)])
        await waitUntil("対照の取得", value: { KsStubURLProtocol.requestCount(for: control) }) { $0 >= 1 }

        XCTAssertEqual(KsStubURLProtocol.requestCount(for: signedB), 0, "取得済みの画像を取り直しました")
    }

    /// キーを付けて保存した画像は、URL が違っても同じキーのソースで消え、キーなしのソースでは消えない。
    func testキー付きの画像は同じキーのソースで消えキーなしでは消えない() async throws {
        let request = keyed(signedA, key: "p1")
        // 先読みの層は解放されると未完了の取得を止めるため、完了を待つ間は保持しておく。
        let loading = KsNukeImageLoading(pipeline: pipeline)
        loading.prefetch(requests: [request], destination: .memory)
        await waitUntil("先読みの保存", value: { self.pipeline.cache[request.imageRequest] != nil }) { $0 }

        KsImageCache.remove(.remote(signedA))
        XCTAssertNotNil(pipeline.cache[request.imageRequest], "キーなしのソースでキー付きの画像が消えました")
        XCTAssertTrue(pipeline.cache.containsData(for: request.imageRequest))

        KsImageCache.remove(.remote(signedB, key: "p1"))
        XCTAssertNil(pipeline.cache[request.imageRequest], "同じキーのソースで消えていません")
        XCTAssertFalse(pipeline.cache.containsData(for: request.imageRequest))
        XCTAssertNil(try prepare(.remote(signedA, key: "p1"), size: CGSize(width: 4, height: 4)).matchedImage)
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

    /// 表示と同じ入口で要求を組み立て、引き当ての結果を返す。
    private func prepare(_ source: KsImageSource, size: CGSize, displayScale: CGFloat = 2) throws -> KsPreparedImageRequest {
        try XCTUnwrap(
            KsImageRequestFactory.prepare(
                source: source,
                size: size,
                contentMode: .fill,
                displayScale: displayScale,
                pipeline: pipeline
            )
        )
    }

    /// キーなしの先読みの要求。
    private func plain(_ url: URL, widthPixels: Int? = nil) -> KsPrefetchRequest {
        KsPrefetchRequest(
            url: url,
            imageID: KsImageIdentity.imageID(forIdentifier: url.absoluteString),
            widthPixels: widthPixels
        )
    }

    /// キーを付けた先読みの要求。
    private func keyed(_ url: URL, key: String, widthPixels: Int? = nil) -> KsPrefetchRequest {
        KsPrefetchRequest(
            url: url,
            imageID: KsImageIdentity.imageID(forIdentifier: KsImageIdentity.identifier(url: url, key: key)),
            widthPixels: widthPixels
        )
    }

    /// アプリの起動し直しに相当する状態を作る。同じ保存先のディスクキャッシュを読む新しい
    /// パイプラインに替え、メモリと索引は空にする。
    private func relaunchPipeline() {
        var configuration = pipeline.configuration
        configuration.imageCache = ImageCache()
        configuration.dataCache = try? DataCache(path: dataCachePath)
        pipeline = ImagePipeline(configuration: configuration)
        ImagePipeline.shared = pipeline
        KsImageMemoryIndex.shared.removeAll()
    }

    /// 指定した大きさの不透明な PNG。
    private static func makePNG(width: Int, height: Int) -> Data? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }.pngData()
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
        return prepared.matchedImage != nil
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

/// 親ビューの状態。値を変えると親の本体が組み立て直され、その回数を数える。
@MainActor
private final class KsRebuildTrigger: ObservableObject {
    @Published var tick = 0
    var buildCount = 0
}

/// 状態の変化で本体を組み立て直す親ビュー。子の `KsImage` の組み立て直しを起こすために使う。
private struct KsRebuildingParent<Content: View>: View {
    @ObservedObject var trigger: KsRebuildTrigger
    // 親の状態を受け取って子を組み立てる。子が親の状態に依存するので、状態が変わると子も組み立て直される。
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        let _ = trigger.buildCount += 1
        VStack(spacing: 0) {
            content(trigger.tick)
            Text("\(trigger.tick)").font(.system(size: 1))
        }
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
        payloadOverride = nil
    }

    /// 応答の中身を差し替える。設定しなければ ``payload`` を返す。
    nonisolated(unsafe) static var payloadOverride: Data?

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
            client?.urlProtocol(self, didLoad: Self.payloadOverride ?? Self.payload)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        stopped.withLock { isStopped = true }
    }
}

/// 既定のデコーダに数えるだけを足した実装。縮小の指定 (サムネイル) の扱いは既定のデコーダに任せる。
private struct KsCountingImageDecoder: ImageDecoding {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0

    static var decodeCount: Int {
        lock.withLock { count }
    }

    static func reset() {
        lock.withLock { count = 0 }
    }

    private let base: ImageDecoders.Default

    init(context: ImageDecodingContext) {
        base = ImageDecoders.Default(context: context) ?? ImageDecoders.Default()
    }

    var isAsynchronous: Bool { base.isAsynchronous }

    func decode(_ data: Data) throws -> ImageContainer {
        Self.lock.withLock { Self.count += 1 }
        return try base.decode(data)
    }
}

/// 実物のコレクションビューで `KsImage` のセルを表示し、見張るセルだけを画面に出る直前に前もって組み立てる。
///
/// セルの中身は `UIHostingConfiguration` で、画面に出る時点の処理 (`onAppear`) は画面に出る直前の通知
/// (`willDisplay`) より後に走る。見張るセルは、その通知の中で配置を確定させて中身を組み立て、
/// 続けて `onPrebuilt` を呼ぶ。`onPrebuilt` は組み立てが枠の大きさ付きで済んだかを返す。
@MainActor
private final class KsPrebuildingCollectionDriver: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    private let sources: [KsImageSource]
    private let counter: KsCompositionCounter
    private let watchedItem: Int
    private let watchedFrame: KsWatchedFrame
    private let onPrebuilt: (UICollectionViewCell) -> Bool

    /// 見張るセルの読み込み中の表示の、これまでの組み立て回数。
    var loadingCompositions: Int { counter.count }

    /// 見張るセルを前もって組み立て終えた時点の、読み込み中の表示の組み立て回数。
    private(set) var compositionsBeforeAppearing = 0

    /// 見張るセルを、画面に出る前に枠の大きさ付きで組み立てられたか。見張るセルが画面に出る処理を
    /// 前もって組み立てるより先に済ませていた場合も false にする。
    private(set) var prebuiltBeforeAppearing: Bool?

    private var watchedAppeared = false

    init(
        sources: [KsImageSource],
        counter: KsCompositionCounter,
        watchedItem: Int,
        watchedFrame: KsWatchedFrame = KsWatchedFrame(),
        onPrebuilt: @escaping (UICollectionViewCell) -> Bool
    ) {
        self.sources = sources
        self.counter = counter
        self.watchedItem = watchedItem
        self.watchedFrame = watchedFrame
        self.onPrebuilt = onPrebuilt
    }

    func show() -> UIWindow {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 20, height: 20)
        layout.minimumLineSpacing = 0
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 20, height: 40))
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let collectionView = UICollectionView(frame: controller.view.bounds, collectionViewLayout: layout)
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        controller.view.addSubview(collectionView)
        // 窓が閉じるまで自分を保持させる。データの供給元と委譲先は弱参照のため。
        objc_setAssociatedObject(window, &Self.retainKey, self, .OBJC_ASSOCIATION_RETAIN)
        collectionView.layoutIfNeeded()
        return window
    }

    nonisolated(unsafe) private static var retainKey: UInt8 = 0

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sources.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        let source = sources[indexPath.item]
        let counter = counter
        if indexPath.item == watchedItem {
            let watchedFrame = watchedFrame
            cell.contentConfiguration = UIHostingConfiguration {
                KsWatchedImage(source: source, counter: counter, frame: watchedFrame)
                    .onAppear { [weak self] in self?.watchedAppeared = true }
            }
            .margins(.all, 0)
        } else {
            cell.contentConfiguration = UIHostingConfiguration { KsImage(source).frame(width: 20, height: 20) }.margins(.all, 0)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard indexPath.item == watchedItem, prebuiltBeforeAppearing == nil else { return }
        cell.layoutIfNeeded()
        compositionsBeforeAppearing = counter.count
        let prebuilt = onPrebuilt(cell)
        prebuiltBeforeAppearing = prebuilt && !watchedAppeared
    }
}

/// 見張るセルの `KsImage` の枠の大きさ。値を変えると、セルを画面に出したまま枠だけを変えられる。
@MainActor
private final class KsWatchedFrame: ObservableObject {
    /// 枠の 1 辺 (ポイント)。
    @Published var side: CGFloat = 20
    /// 表示倍率。実行する Simulator の機種に左右されないよう、表示に環境の値として与える。
    let displayScale: CGFloat = 2
    /// 枠の大きさが変わった後に、`KsImage` の中身が実際にその大きさで配置された 1 辺 (ポイント)。
    var laidOutSide: CGFloat = 0
}

/// 見張るセルの中身。読み込み中の表示の組み立て回数を数え、枠の大きさは `KsWatchedFrame` に従う。
private struct KsWatchedImage: View {
    let source: KsImageSource
    let counter: KsCompositionCounter
    @ObservedObject var frame: KsWatchedFrame

    var body: some View {
        KsImage(source, loading: {
            let _ = counter.increment()
            Color.clear
        })
        .frame(width: frame.side, height: frame.side)
        .environment(\.displayScale, frame.displayScale)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { [frame] width in
            frame.laidOutSide = width
        }
    }
}
