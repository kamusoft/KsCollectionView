import Combine
import Foundation

// キャッシュを消したことを表示中の `KsImage` へ伝える共有オブジェクト。
//
// `revision` は「何かが消えた」ことの通知で、これが変わると表示中の `KsImage` は本体を組み立て直す。
// `globalGeneration` は範囲消去の世代で、`KsImage` が読み込みをやり直すかの判定に使う識別子へ混ぜる。
// ソース単位の削除では `globalGeneration` を進めず、`KsImageIdentity` のソースごとの世代だけが
// 進むため、消したソースの `KsImage` だけが読み込み直しになる。
@MainActor
internal final class KsImageInvalidation: ObservableObject {
    static let shared = KsImageInvalidation()

    @Published private(set) var revision: Int = 0

    private(set) var globalGeneration: Int = 0

    // 範囲消去 (メモリ以外を含むもの) の世代を進める。表示中の画像はすべて読み込み直しになる。
    func invalidateAll() {
        globalGeneration += 1
        revision += 1
    }

    // ソース単位の削除を伝える。読み込み直しの対象は識別子が変わったソースだけになる。
    func invalidateSource() {
        revision += 1
    }

    // テストが互いの世代を持ち込まないために使う。
    func reset() {
        globalGeneration = 0
        revision = 0
    }
}
