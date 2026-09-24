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
        // 表示の引き当ての手掛かりも捨てる。ローダーのキャッシュを消した後に捨てるので、戻った
        // 時点では両方とも消えている。
        defer { KsImageMemoryIndex.shared.removeAll() }
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
    /// キーを指定したリモート画像は、同じキーを指定したソースを渡すと消えます (URL は違っていても
    /// 構いません)。キーを指定していないソースでは、同じ URL でもキー付きの画像は消えません。
    ///
    /// キーを指定していないソースに限り、以後は同じ URL をローダー付属のビューで直接表示している側と
    /// キャッシュを共有しなくなります (その側には削除前の画像が残り得ます)。
    public static func remove(_ source: KsImageSource) {
        guard let resolved = KsImageIdentity.resolve(source) else { return }
        let identifier = resolved.identifier

        // 削除前に始まったこの画像の取得を、幅に関わらず止める。止めないと、削除の後で完了した
        // 取得が削除前の内容を同じ鍵へ書き戻せる。
        KsImagePrefetchRegistry.shared.fence(identifier: identifier)

        let cache = ImagePipeline.shared.cache
        // 元データは、世代が進む前の識別子と現在の世代の識別子の両方で消す。それより前の世代は
        // その世代で削除したときに消えている。
        for request in requestsForRemoval(url: resolved.url, identifier: identifier) {
            cache.removeCachedData(for: request)
            cache.removeCachedImage(for: request, caches: [.all])
        }

        // 表示の引き当ての手掛かりを捨ててから世代を進める。世代を進めると、以後の要求の識別子が
        // 変わって削除前のメモリ項目 (どの表示サイズのものも) に当たらなくなる。残った項目は
        // 使われないまま追い出される。
        KsImageMemoryIndex.shared.remove(effectiveID: KsImageIdentity.effectiveID(forIdentifier: identifier))
        KsImageIdentity.advanceGeneration(forIdentifier: identifier)
        KsImageInvalidation.shared.invalidateSource()
    }

    private static func requestsForRemoval(url: URL, identifier: String) -> [ImageRequest] {
        // 世代 0 の要求。キーなしの画像では素の URL の要求になる。
        var original = ImageRequest(url: url)
        original.imageID = identifier
        var requests = [original]
        if let currentID = KsImageIdentity.imageID(forIdentifier: identifier), currentID != identifier {
            var request = ImageRequest(url: url)
            request.imageID = currentID
            requests.append(request)
        }
        return requests
    }
}
