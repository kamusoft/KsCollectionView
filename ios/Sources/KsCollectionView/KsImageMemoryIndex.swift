import Foundation
import Nuke

// ライブラリがメモリへ載せるよう要求した項目の鍵を、識別子ごとに覚えておく索引 (core/ADR-0013)。
//
// ローダーのメモリキャッシュは要求 (鍵) 単位でしか引けず、同じ画像の別の大きさの項目を探す手段も
// 鍵を列挙する手段も持たない。そこで、先読みと `KsImage` が要求を出した時点でその要求を覚えておき、
// 表示のときに候補の鍵としてローダーのキャッシュへ問い合わせる。
//
// 索引はキャッシュではなく手掛かりで、項目が実在するか・どの寸法かの正はローダーのキャッシュにある。
// 寸法は持たず、問い合わせで返った画像の実物から読む。未完了・失敗・追い出し済みの鍵は問い合わせで
// 空になるだけで候補にならず、索引には残る。未完了の鍵は完了後の問い合わせで候補になるため、問い合わせ
// では外さない (先読みの完了前に表示が照会しても、完了後に引き当てられる)。索引から鍵が外れるのは、
// キャッシュの消去 (`KsImageCache` の `clear` / `remove`) と項目数の上限だけである。
//
// 先読みが出した鍵のうち、取得が終わった形跡をまだ見ていないものを「取得中の可能性がある先読み」として
// 別に覚える (`mayBeLoadingPrefetch`)。ローダーの先読みは要求ごとの完了を知らせないため、完了は
// 「問い合わせでキャッシュに項目があった」ことで、取り消しは先読みの層からの取り消しで知る。失敗した取得は
// 区別できず、索引から鍵が外れるまで取得中の可能性ありのまま残る。
//
// 項目数は上限つきで、上限を超えると最も長く使われていない鍵から外れる。上限は、ローダーの
// メモリキャッシュが実用上保持できる項目数を十分に上回る値にしている。外れた鍵の項目は引き当てられず、
// 表示は通常の縮小の要求に落ちる (壊れはしない)。
//
// 表示の組み立てと同じ主スレッドだけで読み書きする。
@MainActor
internal final class KsImageMemoryIndex {
    static let shared = KsImageMemoryIndex(capacity: 20_000)

    // 要求がキャッシュの項目を見分ける値の組。ライブラリの要求は縮小の指定だけが違うので、
    // 識別子 (`imageID`) と縮小の指定で項目が決まる。
    private struct EntryKey: Hashable {
        let effectiveID: String
        let thumbnail: ImageRequest.ThumbnailOptions?
    }

    // 使われた順に並べる双方向の連結。古い側から外していく。
    private struct Node {
        var request: ImageRequest
        var older: EntryKey?
        var newer: EntryKey?
    }

    let capacity: Int
    private var nodes: [EntryKey: Node] = [:]
    private var oldest: EntryKey?
    private var newest: EntryKey?
    private var keysByID: [String: [EntryKey]] = [:]
    // 先読みが出した鍵のうち、キャッシュに項目があるのをまだ見ておらず、取り消されてもいないもの。
    private var pendingPrefetchKeys: Set<EntryKey> = []

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    // 索引にある鍵の数。
    var count: Int { nodes.count }

    // メモリへ載せるよう要求した鍵を覚える。既に覚えている鍵なら最近使ったものとして扱い、
    // 要求は新しいもの (同じ項目を指す) に置き換える。
    func register(_ request: ImageRequest) {
        let key = Self.entryKey(for: request)
        if nodes[key] != nil {
            nodes[key]?.request = request
            moveToNewest(key)
            return
        }
        nodes[key] = Node(request: request, older: newest, newer: nil)
        if let newest {
            nodes[newest]?.newer = key
        }
        newest = key
        if oldest == nil {
            oldest = key
        }
        keysByID[key.effectiveID, default: []].append(key)
        while nodes.count > capacity, let evicted = oldest {
            remove(evicted)
        }
    }

    // 先読みが出した鍵を覚え、取得中の可能性がある先読みとして扱う。
    func registerPrefetch(_ request: ImageRequest) {
        register(request)
        let key = Self.entryKey(for: request)
        // 上限で直ちに外れた鍵は覚えない。
        guard nodes[key] != nil else { return }
        pendingPrefetchKeys.insert(key)
    }

    // 先読みの取り消しを受けて、その鍵を取得中の可能性から外す。鍵そのものは索引に残す
    // (取り消しの前に完了していれば、キャッシュの項目は引き当てに使える)。
    func cancelPrefetch(_ request: ImageRequest) {
        pendingPrefetchKeys.remove(Self.entryKey(for: request))
    }

    // 識別子について、取得中の可能性がある先読みがあるか。`display` と同じ鍵の先読みは数えない
    // (表示の要求がその鍵で出るので、取得中ならローダーが同じ取得に合流し、完了済みならキャッシュに当たる)。
    // 問い合わせでキャッシュに項目があった鍵は、取得が終わったものとして以後は数えない。
    func mayBeLoadingPrefetch(
        forEffectiveID effectiveID: String,
        excluding display: ImageRequest,
        in cache: ImagePipeline.Cache
    ) -> Bool {
        guard !pendingPrefetchKeys.isEmpty, let keys = keysByID[effectiveID] else { return false }
        let excluded = Self.entryKey(for: display)
        var loading = false
        for key in keys where key != excluded && pendingPrefetchKeys.contains(key) {
            guard let request = nodes[key]?.request else { continue }
            if cache[request] != nil {
                pendingPrefetchKeys.remove(key)
            } else {
                loading = true
            }
        }
        return loading
    }

    // 識別子について覚えている鍵のうち、キャッシュに今ある項目を返す。キャッシュに無かった鍵は
    // 候補にしないだけで、索引には残す。項目があった先読みの鍵は、取得が終わったものとして
    // 取得中の可能性から外す。
    func cachedEntries(
        forEffectiveID effectiveID: String,
        in cache: ImagePipeline.Cache
    ) -> [(request: ImageRequest, container: ImageContainer)] {
        guard let keys = keysByID[effectiveID] else { return [] }
        return keys.compactMap { key in
            guard let request = nodes[key]?.request, let container = cache[request] else { return nil }
            pendingPrefetchKeys.remove(key)
            return (request, container)
        }
    }

    // 引き当てに使った鍵を最近使ったものとして扱う。
    func markUsed(_ request: ImageRequest) {
        let key = Self.entryKey(for: request)
        guard nodes[key] != nil else { return }
        moveToNewest(key)
    }

    // 識別子の鍵をすべて外す。
    func remove(effectiveID: String) {
        guard let keys = keysByID[effectiveID] else { return }
        for key in keys {
            remove(key)
        }
    }

    // すべての鍵を外す。
    func removeAll() {
        nodes.removeAll()
        keysByID.removeAll()
        pendingPrefetchKeys.removeAll()
        oldest = nil
        newest = nil
    }

    // 識別子について覚えている鍵の要求。テストが索引の中身を確かめるために読む。
    func requests(forEffectiveID effectiveID: String) -> [ImageRequest] {
        (keysByID[effectiveID] ?? []).compactMap { nodes[$0]?.request }
    }

    private static func entryKey(for request: ImageRequest) -> EntryKey {
        EntryKey(effectiveID: request.imageID ?? "", thumbnail: request.thumbnail)
    }

    private func moveToNewest(_ key: EntryKey) {
        guard newest != key else { return }
        unlink(key)
        nodes[key]?.older = newest
        nodes[key]?.newer = nil
        if let newest {
            nodes[newest]?.newer = key
        }
        newest = key
        if oldest == nil {
            oldest = key
        }
    }

    private func remove(_ key: EntryKey) {
        guard nodes[key] != nil else { return }
        unlink(key)
        nodes[key] = nil
        pendingPrefetchKeys.remove(key)
        if var keys = keysByID[key.effectiveID] {
            keys.removeAll { $0 == key }
            keysByID[key.effectiveID] = keys.isEmpty ? nil : keys
        }
    }

    // 連結から外す。節そのものは残す。
    private func unlink(_ key: EntryKey) {
        guard let node = nodes[key] else { return }
        if let older = node.older {
            nodes[older]?.newer = node.newer
        } else {
            oldest = node.newer
        }
        if let newer = node.newer {
            nodes[newer]?.older = node.older
        } else {
            newest = node.older
        }
        nodes[key]?.older = nil
        nodes[key]?.newer = nil
    }
}
