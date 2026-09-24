import Foundation

/// 先読みするリモート画像 1 つ分の宣言です。
///
/// URL に加えて、表示するときのおおよその幅と、画像を見分けるためのキーを任意で指定できます。
///
/// ```swift
/// .prefetchResources(destination: .memory) { photo in
///     [
///         KsResource(photo.thumbnailURL, width: .column),
///         KsResource(photo.avatarURL, width: .fixed(40)),
///         KsResource(photo.bannerURL),
///         KsResource(photo.signedURL, width: .column, key: photo.id),
///     ]
/// }
/// ```
///
/// 幅を指定しない画像は、先読みの到達点がメモリのとき元の大きさのままメモリに載ります。
///
/// キーを指定した画像は、取得には URL を使い、キャッシュの項目はキーで見分けます。署名付きの
/// URL のように取得のたびに URL が変わる画像でも、同じキーなら先読みした画像や保存済みの画像が
/// 使われます。キーを使うときは次の点に注意してください。
///
/// - 表示する ``KsImage`` にも同じキーを指定してください (`KsImage(url, key: photo.id)`)。
///   先読みと表示でキーが食い違うと、別の画像として扱われます。
/// - キーは画像の中身を一意に特定する値にしてください。違う画像に同じキーを付けると、
///   一方の画像がもう一方の表示に使われます。
/// - 空文字はキーとして使えません。誤りとして扱い、デバッグビルドでは停止し、リリースビルドでは
///   警告を記録してキーを指定しなかったものとして扱います。
public struct KsResource: Hashable, Sendable {
    /// 画像を取得する URL。
    public let url: URL

    /// 表示するときのおおよその幅。`nil` は元の大きさのまま扱うことを表します。
    public let width: KsWidth?

    /// 画像を見分けるキー。`nil` のときは URL で見分けます。
    public let key: String?

    /// 先読みするリモート画像を宣言します。
    ///
    /// - Parameters:
    ///   - url: 画像を取得する URL。
    ///   - width: 表示するときのおおよその幅。省略すると元の大きさのまま扱います。
    ///   - key: 画像を見分けるキー。省略すると URL で見分けます。
    public init(_ url: URL, width: KsWidth? = nil, key: String? = nil) {
        self.url = url
        self.width = width
        self.key = key
    }
}
