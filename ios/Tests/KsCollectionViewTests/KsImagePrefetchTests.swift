import Nuke
import SwiftUI
import XCTest
@testable import KsCollectionView

/// プリフェッチ宣言が受け口へどう伝わるかを、記録用の受け口で確かめる。
@MainActor
final class KsImagePrefetchTests: XCTestCase {
    private struct Item: Identifiable, Equatable {
        let id: Int
        let title: String
    }

    /// 受け口へ届いた開始・取り消しをそのまま記録する。
    private final class LoadingRecorder: KsImageLoading {
        struct Start: Equatable {
            let requests: [KsPrefetchRequest]
            let destination: KsPrefetchDestination
            var urls: [URL] { requests.map(\.url) }
        }

        var starts: [Start] = []
        var cancels: [[KsPrefetchRequest]] = []

        var startedRequests: [KsPrefetchRequest] { starts.flatMap(\.requests) }
        var cancelledRequests: [KsPrefetchRequest] { cancels.flatMap { $0 } }
        var startedURLs: [URL] { startedRequests.map(\.url) }
        var cancelledURLs: [URL] { cancelledRequests.map(\.url) }

        func prefetch(requests: [KsPrefetchRequest], destination: KsPrefetchDestination) {
            starts.append(Start(requests: requests, destination: destination))
        }

        func cancel(requests: [KsPrefetchRequest]) {
            cancels.append(requests)
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        KsInvalidInput.reset()
        KsImageIdentity.resetGenerations()
    }

    override func tearDown() async throws {
        KsInvalidInput.reset()
        KsImageIdentity.resetGenerations()
        try await super.tearDown()
    }

    private func url(_ path: String) -> URL {
        URL(string: "https://example.com/\(path)")!
    }

    private func makePrefetcher(
        loading: LoadingRecorder,
        destination: KsPrefetchDestination = .disk,
        metrics: @escaping () -> KsPrefetchMetrics = { KsPrefetchMetrics(columnWidth: 100, displayScale: 2) },
        resources: @escaping (Item) -> [KsResource]
    ) -> KsImagePrefetcher<Item> {
        KsImagePrefetcher(
            loading: loading,
            id: { AnyHashable($0.id) },
            resources: resources,
            destination: destination,
            metrics: metrics
        )
    }

    private func resource(_ path: String, width: KsWidth? = nil, key: String? = nil) -> KsResource {
        KsResource(url(path), width: width, key: key)
    }

    // MARK: - URL 解決層

    func test先読み対象の項目がURLへ解決されて到達点付きで開始される() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { [self.resource("\($0.id).jpg")] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])

        XCTAssertEqual(recorder.starts.count, 1)
        XCTAssertEqual(recorder.starts.first?.urls, [url("1.jpg"), url("2.jpg")])
        XCTAssertEqual(recorder.starts.first?.destination, .disk)
    }

    func test1項目に複数のURLを宣言すると両方の取得が始まる() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) {
            [self.resource("\($0.id)-a.jpg"), self.resource("\($0.id)-b.jpg")]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedURLs, [url("1-a.jpg"), url("1-b.jpg")])
    }

    func test空の配列を返した項目では何も取得しない() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { _ in [] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])
        prefetcher.cancelPrefetching(items: [Item(id: 1, title: "A")])

        XCTAssertTrue(recorder.starts.isEmpty)
        XCTAssertTrue(recorder.cancels.isEmpty)
    }

    func test到達点memoryの宣言はmemoryとして受け口へ届く() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) {
            [self.resource("\($0.id).jpg")]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.starts.first?.destination, .memory)
    }

    func test共有URLは最後の項目が外れるまで取り消さない() {
        let recorder = LoadingRecorder()
        let shared = url("shared.jpg")
        let prefetcher = makePrefetcher(loading: recorder) { _ in [KsResource(shared)] }
        let a = Item(id: 1, title: "A")
        let b = Item(id: 2, title: "B")

        prefetcher.prefetch(items: [a, b])
        XCTAssertEqual(recorder.startedURLs, [shared])

        prefetcher.cancelPrefetching(items: [a])
        XCTAssertTrue(recorder.cancels.isEmpty)

        prefetcher.cancelPrefetching(items: [b])
        XCTAssertEqual(recorder.cancelledURLs, [shared])
    }

    func test取り消しの後に同じ項目を通知すると取得が始め直される() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { [self.resource("\($0.id).jpg")] }
        let item = Item(id: 1, title: "A")

        prefetcher.prefetch(items: [item])
        prefetcher.cancelPrefetching(items: [item])
        prefetcher.prefetch(items: [item])

        XCTAssertEqual(recorder.startedURLs, [url("1.jpg"), url("1.jpg")])
        XCTAssertEqual(recorder.cancelledURLs, [url("1.jpg")])
    }

    // MARK: - 項目の中身が変わったときの台帳

    func test同じIDのまま画像が差し替わると古いURLを止めて新しいURLを取りに行く() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { [self.resource("\($0.title).jpg")] }

        prefetcher.prefetch(items: [Item(id: 1, title: "old")])
        XCTAssertEqual(recorder.startedURLs, [url("old.jpg")])

        prefetcher.prefetch(items: [Item(id: 1, title: "new")])

        XCTAssertEqual(recorder.cancelledURLs, [url("old.jpg")], "古い URL の取得が続いています")
        XCTAssertEqual(recorder.startedURLs, [url("old.jpg"), url("new.jpg")])
    }

    func test画像の差し替えでも他の項目と共有中のURLは取り消さない() {
        let recorder = LoadingRecorder()
        // title のカンマ区切りをそのまま URL の並びに解決する。
        let prefetcher = makePrefetcher(loading: recorder) { item in
            item.title.split(separator: ",").map { self.resource("\($0).jpg") }
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "own,shared"), Item(id: 2, title: "shared")])
        XCTAssertEqual(recorder.startedURLs, [url("own.jpg"), url("shared.jpg")])

        // 項目 1 が共有 URL を手放しても、項目 2 が必要としている間は取り消さない。
        prefetcher.prefetch(items: [Item(id: 1, title: "own")])

        XCTAssertTrue(recorder.cancels.isEmpty, "共有中の URL まで取り消しました")

        prefetcher.cancelPrefetching(items: [Item(id: 2, title: "shared")])
        XCTAssertEqual(recorder.cancelledURLs, [url("shared.jpg")])
    }

    // MARK: - コレクションとの接続

    private func makeConfiguration(
        items: [Item],
        loading: LoadingRecorder?,
        destination: KsPrefetchDestination = .disk,
        layout: KsCollectionLayout = .list,
        contentPadding: EdgeInsets = EdgeInsets(),
        resources: ((Item) -> [KsResource])?
    ) -> KsCollectionConfiguration<Item> {
        var configuration = KsCollectionConfiguration(
            items: items,
            id: { AnyHashable($0.id) },
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry<Item>(content: { item in
                Text(item.title).frame(maxWidth: .infinity, minHeight: 44)
            }),
            layout: layout,
            contentPadding: contentPadding,
            showsSeparators: true,
            separatorColor: nil,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
        configuration.prefetchResources = resources
        configuration.prefetchDestination = destination
        configuration.imageLoading = loading
        return configuration
    }

    private func loadedController(
        _ configuration: KsCollectionConfiguration<Item>
    ) async -> KsCollectionViewController<Item> {
        let controller = KsCollectionViewController(configuration: configuration)
        controller.loadViewIfNeeded()
        await waitUntil("data source 件数", value: {
            ksTotalItemCount(in: controller.collectionView)
        }) { $0 == configuration.items.count }
        return controller
    }

    func testシステムの先読み通知で取得が始まり取り消し通知で止まる() async {
        let recorder = LoadingRecorder()
        let items = (0..<4).map { Item(id: $0, title: "項目 \($0)") }
        let controller = await loadedController(
            makeConfiguration(items: items, loading: recorder) { [self.resource("\($0.id).jpg")] }
        )

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [2, 3].map { ksIndexPath(forItemOffset: $0, in: controller.collectionView) }
        )
        XCTAssertEqual(recorder.startedURLs, [url("2.jpg"), url("3.jpg")])

        controller.collectionView(
            controller.collectionView,
            cancelPrefetchingForItemsAt: [ksIndexPath(forItemOffset: 3, in: controller.collectionView)]
        )
        XCTAssertEqual(recorder.cancelledURLs, [url("3.jpg")])
    }

    func test宣言が無ければ受け口へ何も伝わらない() async {
        let recorder = LoadingRecorder()
        let items = (0..<4).map { Item(id: $0, title: "項目 \($0)") }
        let controller = await loadedController(
            makeConfiguration(items: items, loading: recorder, resources: nil)
        )

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [ksIndexPath(forItemOffset: 0, in: controller.collectionView)]
        )
        controller.collectionView(
            controller.collectionView,
            cancelPrefetchingForItemsAt: [ksIndexPath(forItemOffset: 0, in: controller.collectionView)]
        )

        XCTAssertTrue(recorder.starts.isEmpty)
        XCTAssertTrue(recorder.cancels.isEmpty)
    }

    func test配列の差し替えで消えた項目の取得は取り消される() async {
        let recorder = LoadingRecorder()
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let configuration = makeConfiguration(items: items, loading: recorder) {
            [self.resource("\($0.id).jpg")]
        }
        let controller = await loadedController(configuration)

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [1, 2].map { ksIndexPath(forItemOffset: $0, in: controller.collectionView) }
        )
        XCTAssertEqual(recorder.startedURLs, [url("1.jpg"), url("2.jpg")])

        var next = configuration
        next.items = items.filter { $0.id != 1 }
        controller.update(configuration: next)

        XCTAssertEqual(recorder.cancelledURLs, [url("1.jpg")])
    }

    func test配列の差し替えで同じIDの画像が変わると先読みを取り直す() async {
        let recorder = LoadingRecorder()
        let items = (0..<3).map { Item(id: $0, title: "v1-\($0)") }
        let configuration = makeConfiguration(items: items, loading: recorder) {
            [self.resource("\($0.title).jpg")]
        }
        let controller = await loadedController(configuration)

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [ksIndexPath(forItemOffset: 1, in: controller.collectionView)]
        )
        XCTAssertEqual(recorder.startedURLs, [url("v1-1.jpg")])

        // ID を据え置いたまま、その項目が指す画像だけを差し替える。
        var next = configuration
        next.items = items.map { $0.id == 1 ? Item(id: 1, title: "v2-1") : $0 }
        controller.update(configuration: next)

        XCTAssertEqual(recorder.cancelledURLs, [url("v1-1.jpg")], "古い URL の取得が続いています")
        XCTAssertEqual(recorder.startedURLs, [url("v1-1.jpg"), url("v2-1.jpg")])
    }

    func test画面から消えたときに未完了の取得をすべて取り消す() async {
        let recorder = LoadingRecorder()
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let controller = await loadedController(
            makeConfiguration(items: items, loading: recorder) { [self.resource("\($0.id).jpg")] }
        )

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [0, 1].map { ksIndexPath(forItemOffset: $0, in: controller.collectionView) }
        )
        controller.disconnect()

        XCTAssertEqual(Set(recorder.cancelledURLs), Set([url("0.jpg"), url("1.jpg")]))
    }

    func test構成の差し替えでも台帳を持つ解決層は作り直されない() async {
        let recorder = LoadingRecorder()
        let items = (0..<3).map { Item(id: $0, title: "項目 \($0)") }
        let configuration = makeConfiguration(items: items, loading: recorder) {
            [self.resource("\($0.id).jpg")]
        }
        let controller = await loadedController(configuration)

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [ksIndexPath(forItemOffset: 0, in: controller.collectionView)]
        )
        // 配列が同じ更新では台帳が保たれ、開始済みの要求は取り消されない。
        controller.update(configuration: configuration)
        XCTAssertTrue(recorder.cancels.isEmpty)

        // 台帳が保たれているため、同じ項目の再通知では要求を積み増さない。
        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [ksIndexPath(forItemOffset: 0, in: controller.collectionView)]
        )
        XCTAssertEqual(recorder.startedURLs, [url("0.jpg")])
    }

    // MARK: - キャッシュ操作と進行中の先読み

    func test範囲消去は進行中の先読みを止めて台帳を空にする() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { [self.resource("\($0.id).jpg")] }
        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])
        XCTAssertEqual(recorder.startedURLs, [url("1.jpg"), url("2.jpg")])

        withIsolatedPipeline { KsImageCache.clear(.all) }

        XCTAssertEqual(Set(recorder.cancelledURLs), [url("1.jpg"), url("2.jpg")])
        // 台帳が空になっているので、同じ項目の再通知は消去後の新しい取得として始まる。
        prefetcher.prefetch(items: [Item(id: 1, title: "A")])
        XCTAssertEqual(recorder.startedURLs, [url("1.jpg"), url("2.jpg"), url("1.jpg")])
    }

    func testメモリのみの消去も進行中の先読みを止める() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) {
            [self.resource("\($0.id).jpg")]
        }
        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        withIsolatedPipeline { KsImageCache.clear(.memory) }

        // 到達点をメモリまでにした先読みはデコード済みの画像をメモリへ載せるため、
        // 止めないと消した直後にメモリを埋め戻せる。
        XCTAssertEqual(recorder.cancelledURLs, [url("1.jpg")])
        // 台帳も空になるので、同じ項目の再通知は消去後の新しい取得として始まる。
        prefetcher.prefetch(items: [Item(id: 1, title: "A")])
        XCTAssertEqual(recorder.startedURLs, [url("1.jpg"), url("1.jpg")])
    }

    func testソース単位の削除は対象のURLの先読みだけを止める() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { [self.resource("\($0.id).jpg")] }
        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])

        withIsolatedPipeline { KsImageCache.remove(.remote(url("1.jpg"))) }

        XCTAssertEqual(recorder.cancelledURLs, [url("1.jpg")])
        // 止めた URL だけが台帳から外れ、残りの取得は続く。
        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])
        XCTAssertEqual(recorder.startedURLs, [url("1.jpg"), url("2.jpg"), url("1.jpg")])
    }

    // 共有パイプラインを操作する API を、他のテストのキャッシュから切り離して呼ぶ。
    private func withIsolatedPipeline(_ body: () -> Void) {
        var configuration = ImagePipeline.Configuration()
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        let original = ImagePipeline.shared
        ImagePipeline.shared = ImagePipeline(configuration: configuration)
        defer {
            ImagePipeline.shared = original
            KsImageIdentity.resetGenerations()
            KsImageInvalidation.shared.reset()
        }
        body()
    }

    // MARK: - 表示幅と取得単位

    func test幅なしの要素は縮小の指定なしで始まる() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) {
            [self.resource("\($0.id).jpg")]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [nil])
        // 縮小の指定が無いので、元の大きさのままメモリへ載る要求になる。
        XCTAssertNil(recorder.startedRequests.first?.imageRequest.thumbnail)
    }

    func test列幅の要素はその時点の列幅のピクセルで始まる() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: 100, displayScale: 2) }
        ) { [self.resource("\($0.id).jpg", width: .column)] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [200])
        // 幅の正方形を覆う最小の大きさへ縮小する指定になる。
        XCTAssertEqual(
            recorder.startedRequests.first?.imageRequest.thumbnail,
            ImageRequest.ThumbnailOptions(
                size: CGSize(width: 200, height: 200), unit: .pixels, contentMode: .aspectFill
            )
        )
    }

    func test固定値の要素は表示倍率込みのピクセルで始まる() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: 100, displayScale: 3) }
        ) { [self.resource("\($0.id).jpg", width: .fixed(40))] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [120])
    }

    func test大きすぎる固定値は停止せず幅のピクセルの上限で始まる() {
        let recorder = LoadingRecorder()
        // 有限かつ正の値は有効な宣言なので、上限で頭打ちにして不正入力としては扱わない。
        let widths: [Double] = [1e19, .greatestFiniteMagnitude]
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: 100, displayScale: 3) }
        ) { [self.resource("\($0.id).jpg", width: .fixed(widths[$0.id]))] }

        prefetcher.prefetch(items: widths.indices.map { Item(id: $0, title: "\($0)") })

        XCTAssertEqual(
            recorder.startedRequests.map(\.widthPixels),
            [KsPrefetchMetrics.maximumPixels, KsPrefetchMetrics.maximumPixels]
        )
        XCTAssertTrue(KsInvalidInput.reportedWarnings.isEmpty, "有効な固定値を不正入力として扱いました")
    }

    func test幅のピクセルは上限の境界で頭打ちになる() {
        let metrics = KsPrefetchMetrics(columnWidth: 100, displayScale: 2)
        let limit = KsPrefetchMetrics.maximumPixels

        XCTAssertEqual(metrics.pixels(forPoints: Double(limit) / 2 - 0.5), limit - 1)
        XCTAssertEqual(metrics.pixels(forPoints: Double(limit) / 2), limit)
        XCTAssertEqual(metrics.pixels(forPoints: Double(limit) / 2 + 0.5), limit)
        // 表示倍率を掛けて整数の範囲や有限の範囲を超える値も上限になる。
        XCTAssertEqual(metrics.pixels(forPoints: Double(Int.max)), limit)
        XCTAssertEqual(metrics.pixels(forPoints: .greatestFiniteMagnitude), limit)
        // 下限は従来どおり 1。
        XCTAssertEqual(metrics.pixels(forPoints: 0.1), 1)
    }

    func test幅あり幅なしを混ぜた宣言はそれぞれの大きさで始まる() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) {
            [
                self.resource("\($0.id)-thumb.jpg", width: .column),
                self.resource("\($0.id)-banner.jpg"),
            ]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedURLs, [url("1-thumb.jpg"), url("1-banner.jpg")])
        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [200, nil])
    }

    func test到達点diskでは幅を使わない() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .disk) {
            [self.resource("\($0.id).jpg", width: .column)]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [nil])
        XCTAssertEqual(recorder.starts.first?.destination, .disk)
    }

    func test到達点memoryでは同じURLでも幅が違えば別の取得として数える() {
        let recorder = LoadingRecorder()
        let shared = url("shared.jpg")
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(shared, width: item.id == 1 ? .fixed(40) : .column)]
        }
        let a = Item(id: 1, title: "A")
        let b = Item(id: 2, title: "B")

        prefetcher.prefetch(items: [a, b])
        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [80, 200])

        prefetcher.cancelPrefetching(items: [a])

        XCTAssertEqual(recorder.cancelledRequests.map(\.widthPixels), [80], "列幅の取得まで取り消しました")
    }

    func test到達点diskでは幅違いも1つの取得にまとめる() {
        let recorder = LoadingRecorder()
        let shared = url("shared.jpg")
        let prefetcher = makePrefetcher(loading: recorder, destination: .disk) { item in
            [KsResource(shared, width: item.id == 1 ? .fixed(40) : .column)]
        }
        let a = Item(id: 1, title: "A")
        let b = Item(id: 2, title: "B")

        prefetcher.prefetch(items: [a, b])
        XCTAssertEqual(recorder.startedURLs, [shared])

        prefetcher.cancelPrefetching(items: [a])
        XCTAssertTrue(recorder.cancels.isEmpty, "まだ必要としている項目があるのに取り消しました")

        prefetcher.cancelPrefetching(items: [b])
        XCTAssertEqual(recorder.cancelledURLs, [shared])
    }

    func test列幅が変わっただけでは進行中の取得を取り消さず出し直しもしない() {
        let recorder = LoadingRecorder()
        var columnWidth = 100.0
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: columnWidth, displayScale: 2) }
        ) { [self.resource("\($0.id).jpg", width: .column)] }
        let a = Item(id: 1, title: "A")

        prefetcher.prefetch(items: [a])
        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [200])

        // 横向きになり列幅が変わる。項目は先読みの対象のまま、通知と配列の差し替えが届く。
        columnWidth = 150
        prefetcher.prefetch(items: [a])
        prefetcher.retain(items: [a, Item(id: 2, title: "B")])

        XCTAssertEqual(recorder.starts.count, 1, "列幅の変化だけで出し直しました")
        XCTAssertTrue(recorder.cancels.isEmpty, "列幅の変化だけで取り消しました")

        // その後に新しく対象になった項目は横向きの列幅で始まる。
        prefetcher.prefetch(items: [Item(id: 2, title: "B")])
        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [200, 300])
    }

    func test列幅が変わった後の取り消しは始めたときの要求で行う() {
        let recorder = LoadingRecorder()
        var columnWidth = 100.0
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: columnWidth, displayScale: 2) }
        ) { [self.resource("\($0.id).jpg", width: .column)] }
        let a = Item(id: 1, title: "A")

        prefetcher.prefetch(items: [a])
        let started = recorder.startedRequests
        columnWidth = 150
        prefetcher.cancelPrefetching(items: [a])

        XCTAssertEqual(recorder.cancelledRequests, started, "始めたときと違う要求を取り消しました")
    }

    func test列幅が解けない間は列幅の先読みを始めない() {
        let recorder = LoadingRecorder()
        var columnWidth = -10.0
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: columnWidth, displayScale: 2) }
        ) {
            [
                self.resource("\($0.id)-column.jpg", width: .column),
                self.resource("\($0.id)-fixed.jpg", width: .fixed(40)),
            ]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])
        XCTAssertEqual(recorder.startedURLs, [url("1-fixed.jpg")], "列幅が解けないのに列幅の取得を始めました")

        columnWidth = 0
        prefetcher.prefetch(items: [Item(id: 2, title: "B")])
        XCTAssertEqual(recorder.startedURLs, [url("1-fixed.jpg"), url("2-fixed.jpg")])

        // 列幅が正になった後に対象になった項目からは列幅の取得も始まる。
        columnWidth = 100
        prefetcher.prefetch(items: [Item(id: 3, title: "C")])
        XCTAssertEqual(
            recorder.startedURLs,
            [url("1-fixed.jpg"), url("2-fixed.jpg"), url("3-column.jpg"), url("3-fixed.jpg")]
        )
    }

    func test無効な固定値は警告して幅なしとして扱う() {
        // リリースビルドの縮退を確かめるため、デバッグビルドの停止を下ろす。
        KsInvalidInput.assertsInDebug = false
        let invalid: [Double] = [0, -1, .nan, .infinity]
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [self.resource("\(item.id).jpg", width: .fixed(invalid[item.id]))]
        }

        prefetcher.prefetch(items: invalid.indices.map { Item(id: $0, title: "\($0)") })

        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [nil, nil, nil, nil])
        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, invalid.count, "警告が記録されていません")
    }

    func test無効な固定値の警告は通知が重なっても同じ文面につき1回だけ記録する() {
        KsInvalidInput.assertsInDebug = false
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [self.resource("\(item.id).jpg", width: .fixed(0))]
        }

        // 同じアイテムが対象から外れては戻り、そのたびに宣言が評価し直される。
        for _ in 0..<3 {
            prefetcher.prefetch(items: [Item(id: 1, title: "A")])
            prefetcher.cancelPrefetching(items: [Item(id: 1, title: "A")])
        }
        prefetcher.prefetch(items: [Item(id: 2, title: "B")])

        // 文面が違う (別の URL の) 誤りは別に記録する。
        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, 2, "同じ警告を繰り返しました")
    }

    // MARK: - 任意キー

    func testキーを付けた要素はキーの識別子で要求を組み立てる() {
        let recorder = LoadingRecorder()
        let target = url("signed.jpg?sig=1")
        let prefetcher = makePrefetcher(loading: recorder) { _ in [KsResource(target, key: "p1")] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        let request = recorder.startedRequests.first
        // 取得には URL を使い、キャッシュの項目はキーで見分ける。
        XCTAssertEqual(request?.url, target)
        XCTAssertEqual(
            request?.imageID,
            KsImageIdentity.imageID(forIdentifier: KsImageIdentity.identifier(url: target, key: "p1"))
        )
        XCTAssertNotEqual(request?.imageRequest.imageID, target.absoluteString)
    }

    func testキーが同じでURLだけが変わった配列の差し替えでは古いURLを止めて新しいURLで出し直す() {
        let recorder = LoadingRecorder()
        // title を署名として URL に埋める。キーはアイテムの ID から決める。
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p\(item.id)")]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "old")])
        prefetcher.retain(items: [Item(id: 1, title: "new")])

        XCTAssertEqual(recorder.cancelledURLs, [url("photo.jpg?sig=old")], "古い URL の取得が続いています")
        XCTAssertEqual(recorder.startedURLs, [url("photo.jpg?sig=old"), url("photo.jpg?sig=new")])
    }

    func test同じキーを共有するアイテムの片方だけ署名が変わっても古いURLを止めて新しいURLで出し直す() {
        let recorder = LoadingRecorder()
        // 2 件のアイテムが同じキー・同じ列幅の取得を共有する。title を署名として URL に埋める。
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let old = url("photo.jpg?sig=old")
        let new = url("photo.jpg?sig=new")

        prefetcher.prefetch(items: [Item(id: 1, title: "old"), Item(id: 2, title: "old")])
        XCTAssertEqual(recorder.startedURLs, [old])

        // 片方だけが新しい署名に変わる。参照数は 0 にならないが、取得は新しい URL に移る。
        prefetcher.retain(items: [Item(id: 1, title: "old"), Item(id: 2, title: "new")])
        XCTAssertEqual(recorder.cancelledURLs, [old], "古い URL の取得が続いています")
        XCTAssertEqual(recorder.startedURLs, [old, new])

        // もう片方も同じ新しい署名に変わる。取得は既に新しい URL なので触らない。
        prefetcher.retain(items: [Item(id: 1, title: "new"), Item(id: 2, title: "new")])
        XCTAssertEqual(recorder.cancelledURLs, [old])
        XCTAssertEqual(recorder.startedURLs, [old, new])

        // 片方が外れても、残るアイテムが必要とする限り取り消さない。最後の 1 件が外れたら
        // 新しい URL の要求で取り消す。
        prefetcher.cancelPrefetching(items: [Item(id: 1, title: "new")])
        XCTAssertEqual(recorder.cancelledURLs, [old])
        prefetcher.cancelPrefetching(items: [Item(id: 2, title: "new")])
        XCTAssertEqual(recorder.cancelledURLs, [old, new])
    }

    func test同じキーを共有するアイテムの両方の署名が同時に変わっても新しいURLで1回だけ出し直す() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let old = url("photo.jpg?sig=old")
        let new = url("photo.jpg?sig=new")

        prefetcher.prefetch(items: [Item(id: 1, title: "old"), Item(id: 2, title: "old")])
        prefetcher.retain(items: [Item(id: 1, title: "new"), Item(id: 2, title: "new")])

        XCTAssertEqual(recorder.cancelledURLs, [old])
        XCTAssertEqual(recorder.startedURLs, [old, new])
        // 出し直した要求もキーで見分けるので、取得済みならキャッシュに当たる。
        XCTAssertEqual(Set(recorder.startedRequests.map(\.imageID)).count, 1)
    }

    func test同じ通知の中で共有する取得の署名が食い違っても始める要求は1つにする() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }

        // 最初の通知で、同じキーを共有する 2 件の署名が食い違う。後から加わったアイテムは先の
        // アイテムの要求を共有するので、始める要求は先の URL の 1 つだけで、取り消しも出さない。
        prefetcher.prefetch(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b")])

        XCTAssertTrue(recorder.cancels.isEmpty, "始めていない要求を取り消しました")
        XCTAssertEqual(recorder.startedURLs, [url("photo.jpg?sig=a")])
    }

    func test別のアイテムが同じキーを違う署名で共有しても進行中の取得を始め直さない() {
        let recorder = LoadingRecorder()
        // 同じ画像 (キー) が行ごとに違う署名の URL で届く。title を署名として URL に埋める。
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let a = url("photo.jpg?sig=a")
        let b = url("photo.jpg?sig=b")

        prefetcher.prefetch(items: [Item(id: 1, title: "a")])
        // 別のアイテムが違う署名で加わる。進行中の取得をそのまま共有する。
        prefetcher.prefetch(items: [Item(id: 2, title: "b")])
        XCTAssertTrue(recorder.cancels.isEmpty, "別のアイテムが加わっただけで取得を止めました")
        XCTAssertEqual(recorder.startedURLs, [a])

        // 後から加わったアイテムの署名が変わっても、進行中の取得はそのアイテムの URL ではないので触らない。
        prefetcher.retain(items: [Item(id: 1, title: "a"), Item(id: 2, title: "c")])
        XCTAssertTrue(recorder.cancels.isEmpty, "進行中の取得と関係のない署名の変化で取得を止めました")
        XCTAssertEqual(recorder.startedURLs, [a])

        // 取得を始めたアイテム自身の署名が変わったら、古い URL を止めて新しい URL で始め直す。
        prefetcher.retain(items: [Item(id: 1, title: "b"), Item(id: 2, title: "c")])
        XCTAssertEqual(recorder.cancelledURLs, [a])
        XCTAssertEqual(recorder.startedURLs, [a, b])

        // 共有するアイテムが残る間は、進行中の URL のアイテムが外れても始め直さず取り消さない。
        // 最後の 1 件が外れたら進行中の要求で取り消す。
        prefetcher.cancelPrefetching(items: [Item(id: 1, title: "b")])
        XCTAssertEqual(recorder.cancelledURLs, [a], "アイテムが外れただけで取得をやり直しました")
        XCTAssertEqual(recorder.startedURLs, [a, b])
        prefetcher.cancelPrefetching(items: [Item(id: 2, title: "c")])
        XCTAssertEqual(recorder.cancelledURLs, [a, b])
    }

    func test進行中の取得のURLを持つアイテムが変わらなければ別のアイテムの署名が変わっても始め直さない() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let a = url("photo.jpg?sig=a")

        // 同じ通知で 2 件が加わり、先の A の URL で始まる。
        prefetcher.prefetch(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b")])
        XCTAssertEqual(recorder.startedURLs, [a])

        // B の署名だけが変わる。進行中の URL は変わっていない A のものなので触らない。
        prefetcher.retain(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b2")])
        XCTAssertTrue(recorder.cancels.isEmpty, "URL を変えていないアイテムの取得を止めました")
        XCTAssertEqual(recorder.startedURLs, [a])
    }

    func test取得を始めたアイテムが外れた後に残りのアイテムの署名が変わると新しいURLで出し直す() {
        let recorder = LoadingRecorder()
        // 同じキーを 3 件が違う署名で共有する。title を署名として URL に埋める。
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let a = url("photo.jpg?sig=a")

        prefetcher.prefetch(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b"), Item(id: 3, title: "c")])
        XCTAssertEqual(recorder.startedURLs, [a])

        // 取得を始めたアイテムが外れる。アイテムが外れるだけでは始め直さない。
        prefetcher.cancelPrefetching(items: [Item(id: 1, title: "a")])
        XCTAssertTrue(recorder.cancels.isEmpty, "アイテムが外れただけで取得をやり直しました")
        XCTAssertEqual(recorder.startedURLs, [a])

        // 残る 2 件の署名が一斉に変わる。どのアイテムも宣言していない古い URL の取得を止め、
        // 新しい URL で 1 回だけ始め直す。
        prefetcher.retain(items: [Item(id: 2, title: "b2"), Item(id: 3, title: "c2")])
        XCTAssertEqual(recorder.cancelledURLs, [a], "どのアイテムも宣言していない URL の取得が続いています")
        XCTAssertEqual(recorder.startedURLs.count, 2)
        XCTAssertTrue(
            [url("photo.jpg?sig=b2"), url("photo.jpg?sig=c2")].contains(recorder.startedURLs.last),
            "宣言されていない URL で始め直しました"
        )
    }

    func test列幅が変わった後に取得を始めたアイテムの署名が変わると古い幅の共有中の取得も出し直す() {
        let recorder = LoadingRecorder()
        var columnWidth = 100.0
        // 同じキーを 2 件が違う署名で共有する。title を署名として URL に埋める。
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: columnWidth, displayScale: 2) }
        ) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let a = url("photo.jpg?sig=a")
        let b = url("photo.jpg?sig=b")
        let a2 = url("photo.jpg?sig=a2")

        prefetcher.prefetch(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b")])
        XCTAssertEqual(recorder.startedRequests.map(\.url), [a])

        // 回転などで列幅が変わる (台帳は触らない)。その後、取得を始めたアイテムの署名だけが変わる。
        columnWidth = 150
        prefetcher.retain(items: [Item(id: 1, title: "a2"), Item(id: 2, title: "b")])

        // 古い幅の単位は残るアイテムが持ち続けるので残すが、URL を変えたアイテムの直前の URL の
        // 取得は止め、残るアイテムの URL で古い幅のまま始め直す。
        XCTAssertEqual(
            recorder.cancelledRequests.map { [$0.url.absoluteString, "\($0.widthPixels ?? 0)"] },
            [[a.absoluteString, "200"]],
            "URL を変えたアイテムの直前の URL で古い幅の取得が続いています"
        )
        XCTAssertEqual(
            Set(recorder.startedRequests.dropFirst().map { [$0.url.absoluteString, "\($0.widthPixels ?? 0)"] }),
            [[a2.absoluteString, "300"], [b.absoluteString, "200"]]
        )
    }

    func test列幅が変わった後に取得を始めていないアイテムの署名が変わっても古い幅の取得は始め直さない() {
        let recorder = LoadingRecorder()
        var columnWidth = 100.0
        let prefetcher = makePrefetcher(
            loading: recorder,
            destination: .memory,
            metrics: { KsPrefetchMetrics(columnWidth: columnWidth, displayScale: 2) }
        ) { item in
            [KsResource(self.url("photo.jpg?sig=\(item.title)"), width: .column, key: "p")]
        }
        let a = url("photo.jpg?sig=a")

        prefetcher.prefetch(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b")])
        columnWidth = 150
        prefetcher.retain(items: [Item(id: 1, title: "a"), Item(id: 2, title: "b2")])

        // 進行中の取得の URL (a) は、URL を変えていないアイテムがいまも宣言している。
        XCTAssertTrue(recorder.cancels.isEmpty, "URL を変えていないアイテムの取得を止めました")
        XCTAssertEqual(
            recorder.startedRequests.map { [$0.url.absoluteString, "\($0.widthPixels ?? 0)"] },
            [[a.absoluteString, "200"], [url("photo.jpg?sig=b2").absoluteString, "300"]]
        )
    }

    func testソース単位の削除はキーの識別子で全幅の取得を止める() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder, destination: .memory) { item in
            item.id == 1
                ? [
                    KsResource(self.url("a.jpg?sig=1"), width: .fixed(40), key: "p1"),
                    KsResource(self.url("a.jpg?sig=1"), width: .column, key: "p1"),
                ]
                : [KsResource(self.url("b.jpg"), width: .column)]
        }
        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])
        XCTAssertEqual(recorder.startedRequests.count, 3)

        // URL (署名) が違っても、同じキーのソースで止まる。
        withIsolatedPipeline { KsImageCache.remove(.remote(url("a.jpg?sig=2"), key: "p1")) }

        XCTAssertEqual(Set(recorder.cancelledRequests.map(\.widthPixels)), [80, 200])
        XCTAssertEqual(Set(recorder.cancelledURLs), [url("a.jpg?sig=1")])
    }

    func testキーなしのソースの削除ではキーを付けた取得は止まらない() {
        let recorder = LoadingRecorder()
        let target = url("a.jpg")
        let prefetcher = makePrefetcher(loading: recorder) { _ in [KsResource(target, key: "p1")] }
        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        withIsolatedPipeline { KsImageCache.remove(.remote(target)) }

        XCTAssertTrue(recorder.cancels.isEmpty, "キーなしのソースでキー付きの取得を止めました")
    }

    func test空文字のキーは警告してURLで見分ける() {
        KsInvalidInput.assertsInDebug = false
        let recorder = LoadingRecorder()
        let target = url("a.jpg")
        let prefetcher = makePrefetcher(loading: recorder) { _ in [KsResource(target, key: "")] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.startedRequests.first?.imageRequest.imageID, ImageRequest(url: target).imageID)
        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, 1, "警告が記録されていません")
    }

    // MARK: - 列幅の解決

    func test列幅は表示領域から内側余白と列の間隔を引いて列数で割る() {
        let size = CGSize(width: 320, height: 600)
        let grid = KsCollectionLayout.grid(columns: .fixed(3), rowSpacing: 8, columnSpacing: 8)

        XCTAssertEqual(KsLayoutMetrics.columnWidth(for: grid, containerSize: size, horizontalPadding: 16), 96)
        XCTAssertEqual(KsLayoutMetrics.columnWidth(for: .list, containerSize: size, horizontalPadding: 16), 304)
        // 向き別の列数は、表示領域の縦横で列数が変わる。
        let oriented = KsCollectionLayout.grid(
            columns: .fixed(portrait: 2, landscape: 4), rowSpacing: 0, columnSpacing: 0
        )
        XCTAssertEqual(KsLayoutMetrics.columnWidth(for: oriented, containerSize: size, horizontalPadding: 0), 160)
        XCTAssertEqual(
            KsLayoutMetrics.columnWidth(
                for: oriented, containerSize: CGSize(width: 600, height: 320), horizontalPadding: 0
            ),
            150
        )
        // 余白と間隔が表示領域の幅を超えると 0 以下になる。
        XCTAssertLessThanOrEqual(
            KsLayoutMetrics.columnWidth(for: grid, containerSize: size, horizontalPadding: 400), 0
        )
    }

    func testコレクションの先読み通知は表示領域から解いた列幅で始まる() async {
        let recorder = LoadingRecorder()
        let items = (0..<30).map { Item(id: $0, title: "項目 \($0)") }
        let controller = await loadedController(
            makeConfiguration(
                items: items,
                loading: recorder,
                destination: .memory,
                layout: .grid(columns: .fixed(3), rowSpacing: 8, columnSpacing: 8),
                contentPadding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            ) { [self.resource("\($0.id).jpg", width: .column)] }
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        controller.view.layoutIfNeeded()
        let metrics = controller.prefetchMetrics()
        XCTAssertEqual(metrics.columnWidth, 96)

        controller.collectionView(
            controller.collectionView,
            prefetchItemsAt: [ksIndexPath(forItemOffset: 20, in: controller.collectionView)]
        )

        XCTAssertEqual(recorder.startedRequests.map(\.widthPixels), [metrics.pixels(forPoints: 96)])
    }

    // MARK: - 受け口の要求の組み立て

    func test世代が進んでいないキーなしの要求はURLをそのまま識別子にする() {
        let target = url("1.jpg")
        let request = KsPrefetchRequest(
            url: target,
            imageID: KsImageIdentity.imageID(forIdentifier: target.absoluteString),
            widthPixels: nil
        ).imageRequest

        // ローダーを直接使う素の要求と同じ識別子になり、同じキャッシュ項目を指す。
        XCTAssertEqual(request.imageID, ImageRequest(url: target).imageID)
    }

    func test世代が進んだソースの先読みは世代付きの識別子で始まる() {
        let recorder = LoadingRecorder()
        let target = url("1.jpg")
        KsImageIdentity.advanceGeneration(forIdentifier: target.absoluteString)
        let prefetcher = makePrefetcher(loading: recorder) { item in
            [KsResource(item.id == 1 ? target : self.url("2.jpg"))]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])

        let imageIDs = recorder.startedRequests.map(\.imageRequest.imageID)
        XCTAssertEqual(imageIDs.first, KsImageIdentity.effectiveID(forIdentifier: target.absoluteString))
        XCTAssertNotEqual(imageIDs.first, target.absoluteString)
        XCTAssertEqual(imageIDs.last, ImageRequest(url: url("2.jpg")).imageID)
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(2)
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
