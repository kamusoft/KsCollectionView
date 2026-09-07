import Foundation
import Nuke

// 受け口をローダーの操作へ写像する adapter。到達点ごとに専用の `ImagePrefetcher` を持ち、
// 到達点は `ImagePrefetcher.Destination` へそのまま対応させる。
// `ImagePrefetcher` は解放時に未完了の取得を止めるため、この adapter が解放されると
// 開始済みの取得もすべて止まる。
@MainActor
internal final class KsNukeImageLoading: KsImageLoading {
    private let pipeline: ImagePipeline
    private var prefetchers: [KsPrefetchDestination: ImagePrefetcher] = [:]

    init(pipeline: ImagePipeline) {
        self.pipeline = pipeline
    }

    func prefetch(urls: [URL], destination: KsPrefetchDestination) {
        prefetcher(for: destination).startPrefetching(with: urls.map(Self.makeRequest(url:)))
    }

    func cancel(urls: [URL]) {
        let requests = urls.map(Self.makeRequest(url:))
        // 取り消し通知には到達点が付かないため、作成済みのすべての到達点へ伝える。
        for prefetcher in prefetchers.values {
            prefetcher.stopPrefetching(with: requests)
        }
    }

    // プリフェッチの要求は縮小処理を付けず元寸のまま出す。表示側の縮小付きの要求は、
    // この元寸のキャッシュ項目から作られる。
    static func makeRequest(url: URL) -> ImageRequest {
        var request = ImageRequest(url: url)
        request.imageID = KsImageIdentity.imageID(forKey: url.absoluteString)
        return request
    }

    private func prefetcher(for destination: KsPrefetchDestination) -> ImagePrefetcher {
        if let existing = prefetchers[destination] {
            return existing
        }
        let created = ImagePrefetcher(pipeline: pipeline, destination: destination.nukeDestination)
        prefetchers[destination] = created
        return created
    }
}

extension KsPrefetchDestination {
    // disk はデコードせず元データだけを保存し、memory はデコード済みの画像もメモリへ載せる。
    var nukeDestination: ImagePrefetcher.Destination {
        switch self {
        case .disk: .diskCache
        case .memory: .memoryCache
        }
    }
}
