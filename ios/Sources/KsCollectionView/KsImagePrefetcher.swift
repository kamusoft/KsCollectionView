import Foundation

// プリフェッチ宣言の URL 解決層。アイテム単位の開始・取り消し通知を URL 単位の操作へ翻訳し、
// 「アイテム ID → 解決した URL」と「URL → 参照数」の台帳で寿命を管理する。
// 同じ URL を複数のアイテムが返す場合、最後のアイテムが外れるまで取り消しをローダーへ伝えない。
@MainActor
internal final class KsImagePrefetcher<Item>: KsPrefetching, KsImagePrefetchFencing {
    private let loading: any KsImageLoading
    private let id: (Item) -> AnyHashable

    // 宣言は表示中に差し替えない前提だが、差し替えられた場合は以後の新しい要求にだけ反映する。
    var resources: (Item) -> [URL]
    var destination: KsPrefetchDestination

    private var urlsByItemID: [AnyHashable: [URL]] = [:]
    private var referenceCounts: [URL: Int] = [:]

    init(
        loading: any KsImageLoading,
        id: @escaping (Item) -> AnyHashable,
        resources: @escaping (Item) -> [URL],
        destination: KsPrefetchDestination
    ) {
        self.loading = loading
        self.id = id
        self.resources = resources
        self.destination = destination
        // キャッシュを消すときに、消す前に始まった取得を止められるようにする。
        KsImagePrefetchRegistry.shared.register(self)
    }

    func prefetch(items: [Item]) {
        var started: [URL] = []
        var stopped: [URL] = []
        for item in items {
            reconcile(itemID: id(item), item: item, started: &started, stopped: &stopped)
        }
        apply(started: started, stopped: stopped)
    }

    func cancelPrefetching(items: [Item]) {
        cancel(itemIDs: items.map(id))
    }

    // 差し替え後の配列に残っているアイテムだけを保持し、消えたアイテムの要求を取り消す。
    // 残っているアイテムは ID が同じでも中身が変わり得るため、URL を解決し直して台帳を合わせる。
    func retain(items: [Item]) {
        var itemsByID: [AnyHashable: Item] = [:]
        itemsByID.reserveCapacity(items.count)
        for item in items {
            itemsByID[id(item)] = item
        }

        var started: [URL] = []
        var stopped: [URL] = []
        for (itemID, previous) in urlsByItemID {
            guard let item = itemsByID[itemID] else {
                urlsByItemID[itemID] = nil
                stopped.append(contentsOf: release(urls: previous))
                continue
            }
            reconcile(itemID: itemID, item: item, started: &started, stopped: &stopped)
        }
        apply(started: started, stopped: stopped)
    }

    // 台帳に残っている要求をすべて取り消す。
    func cancelAll() {
        cancel(itemIDs: Array(urlsByItemID.keys))
    }

    // キャッシュを消す直前に呼ばれ、進行中の取得をすべて止める。止めた取得は台帳からも
    // 外れるため、次に先読みの通知が来たときは消去後の新しい取得として始まる。
    func fenceAll() {
        cancelAll()
    }

    // キャッシュから消すソースの取得だけを止める。他のソースの取得は続ける。
    func fence(url: URL) {
        guard referenceCounts[url] != nil else { return }
        referenceCounts[url] = nil
        for (itemID, urls) in urlsByItemID {
            let remaining = urls.filter { $0 != url }
            if remaining.isEmpty {
                urlsByItemID[itemID] = nil
            } else {
                urlsByItemID[itemID] = remaining
            }
        }
        loading.cancel(urls: [url])
    }

    private func cancel(itemIDs: some Sequence<AnyHashable>) {
        var stopped: [URL] = []
        for itemID in itemIDs {
            guard let urls = urlsByItemID.removeValue(forKey: itemID) else { continue }
            stopped.append(contentsOf: release(urls: urls))
        }
        guard !stopped.isEmpty else { return }
        loading.cancel(urls: stopped)
    }

    // アイテム 1 件分の台帳を、いま解決できる URL 集合へ合わせ直す。集合が変わらなければ
    // 何もしないため、同じアイテムの重複した通知では要求を積み増さない。
    private func reconcile(
        itemID: AnyHashable,
        item: Item,
        started: inout [URL],
        stopped: inout [URL]
    ) {
        let previous = urlsByItemID[itemID]
        let urls = deduplicated(resources(item))
        guard previous != urls else { return }

        urlsByItemID[itemID] = urls
        // 両方に残る URL は参照数を動かさない。動かすと、他のアイテムと共有していない URL が
        // 取り消しと開始を往復してしまう。
        stopped.append(contentsOf: release(urls: (previous ?? []).filter { !urls.contains($0) }))
        started.append(contentsOf: acquire(urls: urls.filter { !(previous ?? []).contains($0) }))
    }

    // 参照数を増やし、0 から 1 になった URL (取得を始めるべき URL) を返す。
    private func acquire(urls: [URL]) -> [URL] {
        urls.filter { url in
            let count = referenceCounts[url, default: 0] + 1
            referenceCounts[url] = count
            return count == 1
        }
    }

    // 参照数を減らし、1 から 0 になった URL (取得を止めるべき URL) を返す。
    private func release(urls: [URL]) -> [URL] {
        urls.filter { url in
            guard let count = referenceCounts[url] else { return false }
            if count <= 1 {
                referenceCounts[url] = nil
                return true
            }
            referenceCounts[url] = count - 1
            return false
        }
    }

    private func apply(started: [URL], stopped: [URL]) {
        if !stopped.isEmpty {
            loading.cancel(urls: stopped)
        }
        if !started.isEmpty {
            loading.prefetch(urls: started, destination: destination)
        }
    }

    // 1 アイテムが同じ URL を重ねて返しても参照数は 1 として数える。
    private func deduplicated(_ urls: [URL]) -> [URL] {
        var seen: Set<URL> = []
        return urls.filter { seen.insert($0).inserted }
    }
}
