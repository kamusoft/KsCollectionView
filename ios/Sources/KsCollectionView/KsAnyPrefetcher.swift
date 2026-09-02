@MainActor
internal final class KsAnyPrefetcher<Item> {
    private let prefetchAction: ([Item]) -> Void
    private let cancelAction: ([Item]) -> Void

    init<P: KsPrefetching>(_ prefetcher: P) where P.Item == Item {
        prefetchAction = prefetcher.prefetch
        cancelAction = prefetcher.cancelPrefetching
    }

    func prefetch(items: [Item]) {
        prefetchAction(items)
    }

    func cancel(items: [Item]) {
        cancelAction(items)
    }
}
