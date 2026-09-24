import Foundation
import Nuke

// 受け口をローダーの操作へ写像する adapter。到達点ごとに専用の `ImagePrefetcher` を持ち、
// 到達点は `ImagePrefetcher.Destination` へそのまま対応させる。
// `ImagePrefetcher` は解放時に未完了の取得を止めるため、この adapter が解放されると
// 開始済みの取得もすべて止まる。
@MainActor
internal final class KsNukeImageLoading: KsImageLoading {
    private let pipeline: ImagePipeline
    private let index: KsImageMemoryIndex
    private var prefetchers: [KsPrefetchDestination: ImagePrefetcher] = [:]

    init(pipeline: ImagePipeline, index: KsImageMemoryIndex = .shared) {
        self.pipeline = pipeline
        self.index = index
    }

    func prefetch(requests: [KsPrefetchRequest], destination: KsPrefetchDestination) {
        let imageRequests = requests.map(\.imageRequest)
        // メモリまで載せる要求は、表示のときに引き当てられるよう出した時点で索引に覚えさせる。
        // 完了は待たない (完了前は問い合わせで空になるだけ)。あわせて取得中の可能性がある先読みとして
        // 覚え、`KsImage` が画面に出る時点まで要求を待つかの判定に使わせる。
        if destination == .memory {
            imageRequests.forEach(index.registerPrefetch)
        }
        prefetcher(for: destination).startPrefetching(with: imageRequests)
    }

    func cancel(requests: [KsPrefetchRequest]) {
        let imageRequests = requests.map(\.imageRequest)
        // 取り消し通知には到達点が付かないため、作成済みのすべての到達点へ伝える。
        for prefetcher in prefetchers.values {
            prefetcher.stopPrefetching(with: imageRequests)
        }
        // 取り消した先読みは取得中ではなくなる。完了していた項目は索引に残り、引き当てには使える。
        imageRequests.forEach(index.cancelPrefetch)
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
