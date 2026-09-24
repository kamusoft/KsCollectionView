import Foundation

// プリフェッチ宣言の解決層。アイテム単位の開始・取り消し通知を取得単位の操作へ翻訳し、
// 2 段の台帳で寿命を管理する。
//
// - 上段「アイテム ID → 宣言と、その宣言に割り当てた取得単位」: アイテムの再評価 (通知の重複・
//   配列の差し替え) は宣言で突き合わせる。列の幅が変わっても宣言は変わらないため、回転だけでは
//   既存の取得を取り消さない。
// - 下段「取得単位 → 参照数と、取得を始めたときの要求と、持ち主が宣言している URL」: 同じ単位を
//   複数のアイテムが必要とする場合、最後のアイテムが外れるまで取り消しをローダーへ伝えない。
//   取り消しは始めたときの要求で行うので、その後に列の幅が変わっていても始めた取得が止まる。
//
// 共有中の単位の取得を始め直すきっかけは、その画像 (識別子) を宣言するアイテムの URL の変更 (署名の
// 更新など) だけである。URL の変更はアイテムと識別子の組で記録し、その識別子のすべての単位 (幅違いを
// 含む) の判定に使う。列の幅が変わった後は、同じアイテムの新しい宣言が別の幅の単位へ解けるためである。
// 通知 1 回分の処理を終えた時点で、URL を変えたアイテムがいて、かつ進行中の取得の URL が
// 「URL を変えたアイテムのどれかが直前まで宣言していた URL」か「いまその単位を持つどのアイテムも宣言
// していない URL」なら、古い要求を止めて新しい URL で始め直す。アイテムが加わる・外れるだけの処理では
// 始め直さないので、同じ画像が行ごとに違う署名で届いても、行が入るたびに取得をやり直すことはない。
@MainActor
internal final class KsImagePrefetcher<Item>: KsPrefetching, KsImagePrefetchFencing {
    private struct Assignment {
        let declaration: KsPrefetchDeclaration
        let unit: KsPrefetchUnit
    }

    // 1 回の通知の中で、ある識別子を宣言するアイテムが URL を変えたことの記録。
    private struct URLChange {
        // URL を変えたアイテムが直前まで宣言していた URL。
        var previousURLs: Set<URL> = []
        // URL を変えたアイテムのうち、直近のものの新しい URL。始め直すときに優先して使う。
        var newestURL: URL?
    }

    private struct UnitState {
        var count: Int
        // 進行中の取得の要求。始め直したときは新しい要求に置き換わる。
        var request: KsPrefetchRequest
        // この単位を持つアイテムが宣言している URL と、その URL を宣言しているアイテムの数。
        var declaredURLs: [URL: Int]
        // 直近にこの単位を確保したアイテムの要求。始め直すときに優先して使う。
        var latest: KsPrefetchRequest
    }

    // 1 回の通知で開始・取り消しする要求と、その通知の間だけ使う寸法。寸法は必要になったときに
    // 1 度だけ読む。
    private struct Batch {
        var started: [KsPrefetchRequest] = []
        var stopped: [KsPrefetchRequest] = []
        // この通知で URL を変えたアイテムがいた識別子と、その変更。通知の終わりに、その識別子の
        // すべての単位について始め直すかを決める。
        var changes: [String: URLChange] = [:]
        private let provider: () -> KsPrefetchMetrics
        private var resolved: KsPrefetchMetrics?

        init(metrics: @escaping () -> KsPrefetchMetrics) {
            provider = metrics
        }

        mutating func metrics() -> KsPrefetchMetrics {
            if let resolved { return resolved }
            let value = provider()
            resolved = value
            return value
        }
    }

    private let loading: any KsImageLoading
    private let id: (Item) -> AnyHashable

    // 宣言は表示中に差し替えない前提だが、差し替えられた場合は以後の新しい要求にだけ反映する。
    var resources: (Item) -> [KsResource]
    var destination: KsPrefetchDestination
    // 幅をピクセルへ解くための寸法。取得を始める時点で読む。
    var metrics: () -> KsPrefetchMetrics

    private var assignmentsByItemID: [AnyHashable: [Assignment]] = [:]
    private var units: [KsPrefetchUnit: UnitState] = [:]

    init(
        loading: any KsImageLoading,
        id: @escaping (Item) -> AnyHashable,
        resources: @escaping (Item) -> [KsResource],
        destination: KsPrefetchDestination,
        metrics: @escaping () -> KsPrefetchMetrics = { KsPrefetchMetrics(columnWidth: 0, displayScale: 1) }
    ) {
        self.loading = loading
        self.id = id
        self.resources = resources
        self.destination = destination
        self.metrics = metrics
        // キャッシュを消すときに、消す前に始まった取得を止められるようにする。
        KsImagePrefetchRegistry.shared.register(self)
    }

    func prefetch(items: [Item]) {
        var batch = Batch(metrics: metrics)
        for item in items {
            reconcile(itemID: id(item), item: item, batch: &batch)
        }
        apply(batch)
    }

    func cancelPrefetching(items: [Item]) {
        cancel(itemIDs: items.map(id))
    }

    // 差し替え後の配列に残っているアイテムだけを保持し、消えたアイテムの要求を取り消す。
    // 残っているアイテムは ID が同じでも中身が変わり得るため、宣言を求め直して台帳を合わせる。
    func retain(items: [Item]) {
        var itemsByID: [AnyHashable: Item] = [:]
        itemsByID.reserveCapacity(items.count)
        for item in items {
            itemsByID[id(item)] = item
        }

        var batch = Batch(metrics: metrics)
        for (itemID, previous) in assignmentsByItemID {
            guard let item = itemsByID[itemID] else {
                assignmentsByItemID[itemID] = nil
                previous.forEach { release($0, into: &batch) }
                continue
            }
            reconcile(itemID: itemID, item: item, batch: &batch)
        }
        apply(batch)
    }

    // 台帳に残っている要求をすべて取り消す。
    func cancelAll() {
        cancel(itemIDs: Array(assignmentsByItemID.keys))
    }

    // キャッシュを消す直前に呼ばれ、進行中の取得をすべて止める。止めた取得は台帳からも
    // 外れるため、次に先読みの通知が来たときは消去後の新しい取得として始まる。
    func fenceAll() {
        cancelAll()
    }

    // キャッシュから消す画像の取得だけを、幅に関わらずすべて止める。他の画像の取得は続ける。
    func fence(identifier: String) {
        let fenced = units.filter { $0.key.identifier == identifier }
        guard !fenced.isEmpty else { return }
        for unit in fenced.keys {
            units[unit] = nil
        }
        for (itemID, assignments) in assignmentsByItemID {
            let remaining = assignments.filter { $0.unit.identifier != identifier }
            assignmentsByItemID[itemID] = remaining.isEmpty ? nil : remaining
        }
        loading.cancel(requests: fenced.values.map(\.request))
    }

    private func cancel(itemIDs: some Sequence<AnyHashable>) {
        var batch = Batch(metrics: metrics)
        for itemID in itemIDs {
            guard let assignments = assignmentsByItemID.removeValue(forKey: itemID) else { continue }
            assignments.forEach { release($0, into: &batch) }
        }
        apply(batch)
    }

    // アイテム 1 件分の台帳を、いま求まる宣言へ合わせ直す。宣言が変わらなければ何もしないため、
    // 同じアイテムの重複した通知では要求を積み増さない。
    private func reconcile(itemID: AnyHashable, item: Item, batch: inout Batch) {
        let previous = assignmentsByItemID[itemID] ?? []
        let declarations = deduplicated(resources(item).map(KsPrefetchDeclaration.init))
        guard previous.map(\.declaration) != declarations else { return }

        // 先に手放してから確保する。同じ識別子を違う URL で宣言し直していれば URL の変更として記録する
        // (始め直すかは通知の終わりに決める)。
        // 両方に残る宣言は参照数を動かさない。動かすと、他のアイテムと共有していない取得が
        // 取り消しと開始を往復してしまう。
        for assignment in previous where !declarations.contains(assignment.declaration) {
            release(assignment, into: &batch)
        }
        recordURLChanges(from: previous.map(\.declaration), to: declarations, into: &batch)
        var next: [Assignment] = []
        for declaration in declarations {
            if let kept = previous.first(where: { $0.declaration == declaration }) {
                next.append(kept)
                continue
            }
            // 列の幅が解けない間は、列の幅で宣言した画像の取得を始めない。台帳にも載せないので、
            // 列の幅が解けた後にこのアイテムが改めて対象になったときに始まる。
            guard let unit = unit(for: declaration, batch: &batch) else { continue }
            let request = KsPrefetchRequest(
                url: declaration.url,
                imageID: KsImageIdentity.imageID(forIdentifier: declaration.identifier),
                widthPixels: unit.widthPixels
            )
            acquire(unit, request: request, into: &batch)
            next.append(Assignment(declaration: declaration, unit: unit))
        }
        assignmentsByItemID[itemID] = next.isEmpty ? nil : next
    }

    // アイテム 1 件の宣言の変化から、識別子ごとの URL の変更を記録する。直前まで宣言していて今は
    // 宣言していない URL を直前の URL、今は宣言していて直前には宣言していなかった URL を新しい URL とし、
    // 両方がそろった識別子だけを変更とみなす (宣言が加わる・消えるだけなら変更ではない)。
    // 単位ではなく識別子で見るので、列の幅が変わって新しい宣言が別の幅の単位へ解けても記録が漏れない。
    private func recordURLChanges(
        from previous: [KsPrefetchDeclaration],
        to declarations: [KsPrefetchDeclaration],
        into batch: inout Batch
    ) {
        let previousURLsByID = Dictionary(grouping: previous, by: \.identifier).mapValues { Set($0.map(\.url)) }
        for (identifier, previousURLs) in previousURLsByID {
            let current = declarations.filter { $0.identifier == identifier }
            let dropped = previousURLs.subtracting(current.map(\.url))
            guard !dropped.isEmpty,
                  let newest = current.last(where: { !previousURLs.contains($0.url) })
            else { continue }
            batch.changes[identifier, default: URLChange()].previousURLs.formUnion(dropped)
            batch.changes[identifier, default: URLChange()].newestURL = newest.url
        }
    }

    // 宣言を取得単位へ解く。到達点がディスクまでのときは幅を使わない。
    private func unit(for declaration: KsPrefetchDeclaration, batch: inout Batch) -> KsPrefetchUnit? {
        let widthPixels: Int?
        switch declaration.width {
        case nil:
            widthPixels = nil
        case .column:
            let resolved = batch.metrics()
            guard resolved.columnWidth.isFinite, resolved.columnWidth > 0 else { return nil }
            widthPixels = resolved.pixels(forPoints: resolved.columnWidth)
        case .fixed(let points):
            widthPixels = batch.metrics().pixels(forPoints: points)
        }
        return KsPrefetchUnit(
            identifier: declaration.identifier,
            widthPixels: destination == .memory ? widthPixels : nil
        )
    }

    // 参照数を増やし、0 から 1 になった単位の要求を開始の対象にする。既に進行中の単位では
    // 宣言した URL を数えるだけで、始め直すかは通知の終わりに決める (`settle`)。
    private func acquire(_ unit: KsPrefetchUnit, request: KsPrefetchRequest, into batch: inout Batch) {
        guard var state = units[unit] else {
            units[unit] = UnitState(count: 1, request: request, declaredURLs: [request.url: 1], latest: request)
            batch.started.append(request)
            return
        }
        state.count += 1
        state.declaredURLs[request.url, default: 0] += 1
        state.latest = request
        units[unit] = state
    }

    // 参照数を減らし、1 から 0 になった単位の、始めたときの要求を取り消しの対象にする。
    private func release(_ assignment: Assignment, into batch: inout Batch) {
        let unit = assignment.unit
        guard var state = units[unit] else { return }
        if state.count <= 1 {
            units[unit] = nil
            batch.stopped.append(state.request)
            return
        }
        state.count -= 1
        let url = assignment.declaration.url
        if let declared = state.declaredURLs[url], declared > 1 {
            state.declaredURLs[url] = declared - 1
        } else {
            state.declaredURLs[url] = nil
        }
        units[unit] = state
    }

    // 通知 1 回分の処理を終えた時点で、URL を変えたアイテムがいた識別子の単位 (幅違いを含む) について
    // 始め直すかを決める。進行中の取得の URL が、URL を変えたアイテムの直前の URL か、どのアイテムも
    // 宣言していない URL なら、古い要求を止めて始め直す (失効した URL の取得が失敗したままにならないため)。
    // 始め直す URL は、URL を変えたアイテムのうち直近のものの新しい URL を、その単位で宣言されていれば
    // 優先する。そうでなければ直近に確保したアイテムの URL、それも無ければ宣言中の URL のうち文字列順で
    // 最初のものを使う (どれを選んでも同じ画像なので、決まった順にするだけ)。幅はその単位の幅のまま使う。
    // 取得済みなら始め直した要求はキーでキャッシュに当たり、ネットワークを使わない。
    private func settle(_ batch: inout Batch) {
        for (identifier, change) in batch.changes {
            for unit in units.keys.filter({ $0.identifier == identifier }) {
                guard var state = units[unit] else { continue }
                let running = state.request.url
                guard change.previousURLs.contains(running) || state.declaredURLs[running] == nil else { continue }
                let url: URL
                if let newest = change.newestURL, state.declaredURLs[newest] != nil {
                    url = newest
                } else if state.declaredURLs[state.latest.url] != nil {
                    url = state.latest.url
                } else if let first = state.declaredURLs.keys.min(by: { $0.absoluteString < $1.absoluteString }) {
                    url = first
                } else {
                    continue
                }
                guard url != running else { continue }
                let replacement = KsPrefetchRequest(
                    url: url,
                    imageID: state.request.imageID,
                    widthPixels: state.request.widthPixels
                )
                restart(from: state.request, to: replacement, into: &batch)
                state.request = replacement
                units[unit] = state
            }
        }
        batch.changes.removeAll()
    }

    // 始めたときの要求を新しい要求へ置き換える。古い要求がこの通知の中で始めたものなら、
    // まだローダーへ渡していないので開始の対象から外すだけにする (取り消しは開始より先に
    // 伝えるため、取り消しの対象に入れると止まらずに始まってしまう)。
    private func restart(from old: KsPrefetchRequest, to new: KsPrefetchRequest, into batch: inout Batch) {
        if let index = batch.started.firstIndex(of: old) {
            batch.started.remove(at: index)
        } else {
            batch.stopped.append(old)
        }
        batch.started.append(new)
    }

    private func apply(_ batch: Batch) {
        var batch = batch
        settle(&batch)
        if !batch.stopped.isEmpty {
            loading.cancel(requests: batch.stopped)
        }
        if !batch.started.isEmpty {
            loading.prefetch(requests: batch.started, destination: destination)
        }
    }

    // 1 アイテムが同じ宣言を重ねて返しても 1 つとして数える。
    private func deduplicated(_ declarations: [KsPrefetchDeclaration]) -> [KsPrefetchDeclaration] {
        var seen: Set<KsPrefetchDeclaration> = []
        return declarations.filter { seen.insert($0).inserted }
    }
}
