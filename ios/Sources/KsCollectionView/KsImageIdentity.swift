import Foundation

// 画像の識別子と、識別子ごとの世代を扱う。
//
// 識別子は「キーがあればキー、無ければ URL」から 1 か所で求め、先読み・表示・索引・キャッシュ操作の
// すべてがこれを使う (core/ADR-0014)。どこか 1 か所でも URL が残ると、取得のたびに URL が変わる
// 画像ではそこだけ毎回食い違うためである。
//
// 識別子の形は次の 3 つで、互いに衝突しない。
// - キーなし: URL の文字列そのもの。URL の文字列は空白を含まない (含む場合は符号化される)。
// - キーあり: `keyPrefix` + キー。接頭辞に空白を含むので、URL の識別子と重ならない。
// - 世代付き: `generationPrefix` + 世代 + 空白 + 識別子。接頭辞で他の 2 つと区別でき、世代の後の
//   最初の空白で区切れるため、世代と識別子の組が違えば文字列も違う。
//   キーの文字列にどんな区切り文字を含めても、この形を作ることはできない。
//
// 世代はソース単位でキャッシュから消したときに進め、以後の要求が削除前のキャッシュ項目
// (表示サイズ違いの派生を含む) に当たらないようにする。
@MainActor
internal enum KsImageIdentity {
    private static let keyPrefix = "ks-key "
    private static let generationPrefix = "ks-gen "

    private static var generations: [String: Int] = [:]

    // URL とキーから識別子を求める。空文字のキーは誤りとして扱い、キーなしとみなす (core/ADR-0011)。
    static func identifier(url: URL, key: String?) -> String {
        guard let key else { return url.absoluteString }
        guard !key.isEmpty else {
            KsInvalidInput.report("画像のキーに空文字が指定されました。URL で見分けます: \(url.absoluteString)")
            return url.absoluteString
        }
        return keyPrefix + key
    }

    // ローダーを通すソースの取得先と識別子。アセットはローダーを通らないので nil を返す。
    static func resolve(_ source: KsImageSource) -> (url: URL, identifier: String)? {
        switch source {
        case let .remote(url, key):
            (url, identifier(url: url, key: key))
        case let .file(url):
            (url, url.absoluteString)
        case .asset:
            nil
        }
    }

    // 要求に付ける `imageID`。キーなしの識別子は、世代が進むまで何も付けない。付けないことで、
    // ローダーを直接使う要求と同じキャッシュ項目を指し続ける。キーありの識別子は常に付ける
    // (付けないとローダーは URL で項目を見分けてしまう)。
    static func imageID(forIdentifier identifier: String) -> String? {
        let generation = generations[identifier, default: 0]
        guard generation == 0 else {
            return "\(generationPrefix)\(generation) \(identifier)"
        }
        return identifier.hasPrefix(keyPrefix) ? identifier : nil
    }

    // 要求がキャッシュの項目を見分けるときに実際に使う文字列。`imageID` が無い要求では、
    // ローダーは URL の文字列 (= キーなしの識別子) で見分ける。
    static func effectiveID(forIdentifier identifier: String) -> String {
        imageID(forIdentifier: identifier) ?? identifier
    }

    // 識別子の世代を 1 つ進める。
    static func advanceGeneration(forIdentifier identifier: String) {
        generations[identifier, default: 0] += 1
    }

    // 全識別子の世代を捨てる。テストが互いの世代を持ち込まないために使う。
    static func resetGenerations() {
        generations.removeAll()
    }
}
