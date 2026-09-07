import Foundation

// 画像ソースごとの世代を持つ台帳。ソース単位でキャッシュから消したときに世代を進め、
// 以後の要求が削除前のキャッシュ項目 (表示サイズ違いの派生を含む) に当たらないようにする。
@MainActor
internal enum KsImageIdentity {
    private static var generations: [String: Int] = [:]

    // 要求に付ける識別子。世代が進んでいないソースには何も付けない。付けないことで、
    // ローダーを直接使う要求と同じキャッシュ項目を指し続ける。
    static func imageID(forKey key: String) -> String? {
        guard let generation = generations[key], generation > 0 else { return nil }
        return "\(key)#\(generation)"
    }

    // ソースの世代を 1 つ進める。
    static func advanceGeneration(forKey key: String) {
        generations[key, default: 0] += 1
    }

    // 全ソースの世代を捨てる。テストが互いの世代を持ち込まないために使う。
    static func resetGenerations() {
        generations.removeAll()
    }
}
