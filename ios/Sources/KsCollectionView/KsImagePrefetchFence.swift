import Foundation

// キャッシュ操作の直前に進行中の先読みを止めるための受け口。
@MainActor
internal protocol KsImagePrefetchFencing: AnyObject {
    // 台帳に残っている取得をすべて止め、台帳も空にする。
    func fenceAll()

    // 指定した URL の取得だけを止め、台帳から外す。
    func fence(url: URL)
}

// 生存している先読み層の名簿。キャッシュを消すときに、消す前に始まった取得が
// 消した後でキャッシュへ書き戻すのを防ぐために使う。
//
// 参照は弱く持つため、コレクションが破棄されれば名簿からも自然に消える。
@MainActor
internal final class KsImagePrefetchRegistry {
    static let shared = KsImagePrefetchRegistry()

    private struct Entry {
        weak var target: (any KsImagePrefetchFencing)?
    }

    private var entries: [Entry] = []

    func register(_ target: any KsImagePrefetchFencing) {
        compact()
        guard !entries.contains(where: { $0.target === target }) else { return }
        entries.append(Entry(target: target))
    }

    // 進行中の取得をすべて止める。範囲を指定したキャッシュの消去で使う。
    func fenceAll() {
        compact()
        for entry in entries {
            entry.target?.fenceAll()
        }
    }

    // 指定した URL の取得だけを止める。ソース単位の削除で使う。
    func fence(url: URL) {
        compact()
        for entry in entries {
            entry.target?.fence(url: url)
        }
    }

    private func compact() {
        entries.removeAll { $0.target == nil }
    }
}
