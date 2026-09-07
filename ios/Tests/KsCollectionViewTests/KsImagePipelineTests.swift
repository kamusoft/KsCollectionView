import Nuke
import XCTest
@testable import KsCollectionView

/// 共有パイプラインの差し替え条件を確かめる。`ImagePipeline.shared` は全体で 1 つなので、
/// 各テストは元の共有パイプラインを退避して復元する。
@MainActor
final class KsImagePipelineTests: XCTestCase {
    private var originalPipeline: ImagePipeline!

    override func setUp() async throws {
        try await super.setUp()
        originalPipeline = ImagePipeline.shared
        removeDiskCacheDirectory()
    }

    override func tearDown() async throws {
        ImagePipeline.shared = originalPipeline
        originalPipeline = nil
        removeDiskCacheDirectory()
        try await super.tearDown()
    }

    func testディスクキャッシュ未設定なら有効にした構成で差し替える() {
        var configuration = ImagePipeline.Configuration()
        configuration.dataCache = nil
        let before = ImagePipeline(configuration: configuration)
        ImagePipeline.shared = before

        KsImagePipeline.enableSharedDiskCache()

        XCTAssertFalse(ImagePipeline.shared === before, "共有パイプラインが差し替えられていません")
        XCTAssertNotNil(ImagePipeline.shared.configuration.dataCache)
    }

    func testディスクキャッシュが設定済みなら変更しない() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("ks-image-pipeline-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: path) }

        var configuration = ImagePipeline.Configuration()
        let existingCache = try DataCache(path: path)
        configuration.dataCache = existingCache
        let before = ImagePipeline(configuration: configuration)
        ImagePipeline.shared = before

        KsImagePipeline.enableSharedDiskCache()

        XCTAssertTrue(ImagePipeline.shared === before, "設定済みの共有パイプラインが差し替えられました")
        XCTAssertTrue((ImagePipeline.shared.configuration.dataCache as? DataCache) === existingCache)
    }

    func test独自のDataLoaderを持つ構成は差し替え後も引き継がれる() {
        var configuration = ImagePipeline.Configuration()
        let loader = KsRecordingDataLoader()
        configuration.dataLoader = loader
        configuration.dataCache = nil
        configuration.dataCachePolicy = .storeAll
        ImagePipeline.shared = ImagePipeline(configuration: configuration)

        KsImagePipeline.enableSharedDiskCache()

        let applied = ImagePipeline.shared.configuration
        XCTAssertNotNil(applied.dataCache)
        XCTAssertTrue((applied.dataLoader as? KsRecordingDataLoader) === loader, "独自の DataLoader が失われました")
        guard case .storeAll = applied.dataCachePolicy else {
            XCTFail("保存方針が引き継がれていません")
            return
        }
    }

    func test二度呼んでも最初に足したディスクキャッシュを保つ() {
        var configuration = ImagePipeline.Configuration()
        configuration.dataCache = nil
        ImagePipeline.shared = ImagePipeline(configuration: configuration)

        KsImagePipeline.enableSharedDiskCache()
        let afterFirst = ImagePipeline.shared

        KsImagePipeline.enableSharedDiskCache()

        XCTAssertTrue(ImagePipeline.shared === afterFirst, "2 回目の呼び出しで差し替えが起きました")
    }

    private func removeDiskCacheDirectory() {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        try? FileManager.default.removeItem(
            at: root.appendingPathComponent(KsImagePipeline.diskCacheName, isDirectory: true)
        )
    }
}

/// 差し替えの前後で同一性を見るためだけの通信層。読み込みは行わない。
private final class KsRecordingDataLoader: DataLoading, @unchecked Sendable {
    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> any Cancellable {
        completion(URLError(.cancelled))
        return KsNoopCancellable()
    }
}

private struct KsNoopCancellable: Cancellable {
    func cancel() { }
}
