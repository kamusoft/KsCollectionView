@MainActor
internal protocol KsPrefetching<Item>: AnyObject {
    associatedtype Item

    func prefetch(items: [Item])
    func cancelPrefetching(items: [Item])
}
