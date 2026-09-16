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
            let urls: [URL]
            let destination: KsPrefetchDestination
        }

        var starts: [Start] = []
        var cancels: [[URL]] = []

        var startedURLs: [URL] { starts.flatMap(\.urls) }
        var cancelledURLs: [URL] { cancels.flatMap { $0 } }

        func prefetch(urls: [URL], destination: KsPrefetchDestination) {
            starts.append(Start(urls: urls, destination: destination))
        }

        func cancel(urls: [URL]) {
            cancels.append(urls)
        }
    }

    private func url(_ path: String) -> URL {
        URL(string: "https://example.com/\(path)")!
    }

    private func makePrefetcher(
        loading: LoadingRecorder,
        destination: KsPrefetchDestination = .disk,
        resources: @escaping (Item) -> [URL]
    ) -> KsImagePrefetcher<Item> {
        KsImagePrefetcher(
            loading: loading,
            id: { AnyHashable($0.id) },
            resources: resources,
            destination: destination
        )
    }

    // MARK: - URL 解決層

    func test先読み対象の項目がURLへ解決されて到達点付きで開始される() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) { [self.url("\($0.id).jpg")] }

        prefetcher.prefetch(items: [Item(id: 1, title: "A"), Item(id: 2, title: "B")])

        XCTAssertEqual(recorder.starts.count, 1)
        XCTAssertEqual(recorder.starts.first?.urls, [url("1.jpg"), url("2.jpg")])
        XCTAssertEqual(recorder.starts.first?.destination, .disk)
    }

    func test1項目に複数のURLを宣言すると両方の取得が始まる() {
        let recorder = LoadingRecorder()
        let prefetcher = makePrefetcher(loading: recorder) {
            [self.url("\($0.id)-a.jpg"), self.url("\($0.id)-b.jpg")]
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
            [self.url("\($0.id).jpg")]
        }

        prefetcher.prefetch(items: [Item(id: 1, title: "A")])

        XCTAssertEqual(recorder.starts.first?.destination, .memory)
    }

    func test共有URLは最後の項目が外れるまで取り消さない() {
        let recorder = LoadingRecorder()
        let shared = url("shared.jpg")
        let prefetcher = makePrefetcher(loading: recorder) { _ in [shared] }
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
        let prefetcher = makePrefetcher(loading: recorder) { [self.url("\($0.id).jpg")] }
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
        let prefetcher = makePrefetcher(loading: recorder) { [self.url("\($0.title).jpg")] }

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
            item.title.split(separator: ",").map { self.url("\($0).jpg") }
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
        resources: ((Item) -> [URL])?
    ) -> KsCollectionConfiguration<Item> {
        var configuration = KsCollectionConfiguration(
            items: items,
            id: { AnyHashable($0.id) },
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) },
            registry: KsTemplateRegistry<Item>(content: { item in
                Text(item.title).frame(maxWidth: .infinity, minHeight: 44)
            }),
            layout: .list,
            contentPadding: EdgeInsets(),
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
            makeConfiguration(items: items, loading: recorder) { [self.url("\($0.id).jpg")] }
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
            [self.url("\($0.id).jpg")]
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
            [self.url("\($0.title).jpg")]
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
            makeConfiguration(items: items, loading: recorder) { [self.url("\($0.id).jpg")] }
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
            [self.url("\($0.id).jpg")]
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
        let prefetcher = makePrefetcher(loading: recorder) { [self.url("\($0.id).jpg")] }
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
            [self.url("\($0.id).jpg")]
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
        let prefetcher = makePrefetcher(loading: recorder) { [self.url("\($0.id).jpg")] }
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

    // MARK: - 受け口の要求の組み立て

    func test世代が進んでいないソースの要求はURLをそのまま識別子にする() {
        KsImageIdentity.resetGenerations()
        let target = url("1.jpg")
        let request = KsNukeImageLoading.makeRequest(url: target)

        // ローダーを直接使う素の要求と同じ識別子になり、同じキャッシュ項目を指す。
        XCTAssertEqual(request.imageID, ImageRequest(url: target).imageID)
    }

    func test世代が進んだソースの要求は世代付きの識別子になる() {
        KsImageIdentity.resetGenerations()
        let target = url("1.jpg")
        KsImageIdentity.advanceGeneration(forKey: target.absoluteString)

        let request = KsNukeImageLoading.makeRequest(url: target)
        let other = KsNukeImageLoading.makeRequest(url: url("2.jpg"))

        XCTAssertEqual(request.imageID, "\(target.absoluteString)#1")
        XCTAssertEqual(other.imageID, ImageRequest(url: url("2.jpg")).imageID)
        KsImageIdentity.resetGenerations()
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
