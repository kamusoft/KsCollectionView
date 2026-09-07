import Foundation
import Nuke

/// 画像キャッシュを消す範囲を表します。
public enum KsImageCacheScope: Hashable, Sendable {
    /// メモリ上のデコード済みの画像だけを消します。ディスク上の元データは残ります。
    case memory

    /// メモリ上の画像とディスク上の元データの両方を消します。
    case all
}

/// 画像キャッシュの操作。
///
/// 対象は画像の共有キャッシュなので、同じ画像を使う他の画面の表示にも影響します。
/// 呼び出しから戻った時点で削除は完了しており、以後の取得はキャッシュに当たりません。
@MainActor
public enum KsImageCache {
    /// 指定した範囲のキャッシュを消します。
    ///
    /// ``KsImageCacheScope/all`` では、表示中の ``KsImage`` が読み込み中の表示に戻って取得を
    /// やり直します。``KsImageCacheScope/memory`` は表示中の画像を置き換えず、次に表示するときに
    /// ディスクの元データから読み直します。
    public static func clear(_ scope: KsImageCacheScope) {
        let cache = ImagePipeline.shared.cache
        // 消す前に始まった先読みが、消した後にキャッシュへ書き戻すのを防ぐ。到達点をメモリまでに
        // した先読みはデコード済みの画像をメモリへ載せるため、範囲がメモリだけでも止める必要がある。
        KsImagePrefetchRegistry.shared.fenceAll()
        switch scope {
        case .memory:
            cache.removeAll(caches: [.memory])
        case .all:
            cache.removeAll(caches: [.all])
            KsImageInvalidation.shared.invalidateAll()
        }
    }

    /// 画像ソース 1 つ分のキャッシュを消します。
    ///
    /// ディスク上の元データを消し、以後はどの表示サイズで要求しても削除前のメモリ上の画像には
    /// 当たらなくなります (残った項目は使われないまま順次追い出されます)。表示中の
    /// そのソースの ``KsImage`` は読み込み中の表示に戻って取得をやり直し、他のソースの表示は
    /// そのまま残ります。アセットカタログの画像に対しては何もしません。
    ///
    /// このソースに限り、以後は同じ URL をローダー付属のビューで直接表示している側と
    /// キャッシュを共有しなくなります (その側には削除前の画像が残り得ます)。
    public static func remove(_ source: KsImageSource) {
        guard case .loader(let url) = KsImageRequestFactory.route(for: source) else { return }

        let key = url.absoluteString
        // 削除前に始まったこのソースの取得を止める。止めないと、削除の後で完了した取得が
        // 削除前の内容を同じ鍵へ書き戻せる。
        KsImagePrefetchRegistry.shared.fence(url: url)

        let cache = ImagePipeline.shared.cache
        // 元データは素の URL と現在の世代の識別子の両方で消す。
        for request in requestsForRemoval(url: url, key: key) {
            cache.removeCachedData(for: request)
            cache.removeCachedImage(for: request, caches: [.all])
        }

        // 世代を進めると、以後の要求の識別子が変わって削除前のメモリ項目 (どの表示サイズの
        // ものも) に当たらなくなる。残った項目は使われないまま追い出される。
        KsImageIdentity.advanceGeneration(forKey: key)
        KsImageInvalidation.shared.invalidateSource()
    }

    private static func requestsForRemoval(url: URL, key: String) -> [ImageRequest] {
        var requests = [ImageRequest(url: url)]
        if let currentID = KsImageIdentity.imageID(forKey: key) {
            var request = ImageRequest(url: url)
            request.imageID = currentID
            requests.append(request)
        }
        return requests
    }
}
