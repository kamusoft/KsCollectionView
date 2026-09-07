import Foundation
import Nuke
import os

/// 画像の共有キャッシュの設定。
public enum KsImagePipeline {
    /// 画像の共有キャッシュにディスクキャッシュを足す。
    ///
    /// 呼び出すと、以後に取得した画像の元データがディスクに残り、アプリを再起動しても
    /// 再ダウンロードなしで表示できるようになる。Nuke の共有パイプライン
    /// (`ImagePipeline.shared`) に既にディスクキャッシュが設定されているときは何もしない。
    ///
    /// 画像の先読みの到達点 (`prefetchResources` の `destination`) にディスクを選ぶ場合は、
    /// この呼び出しが前提になる。呼ばない限り元データはディスクに残らない。
    ///
    /// 差し替えでは現在の構成 (通信層・URL キャッシュ・デコーダなど) を引き継ぐが、
    /// 共有パイプラインに設定した `ImagePipeline.Delegate` は既定に戻る。要求の加工を
    /// delegate で行っているアプリは、この呼び出しの代わりに自分でディスクキャッシュを
    /// 設定した `ImagePipeline` を `ImagePipeline.shared` に置く。
    ///
    /// 呼び出しより前に作られたコレクションの読み込み経路は差し替え前のパイプラインを
    /// 使い続けるため、アプリの起動時に一度だけ呼ぶ。
    ///
    /// ```swift
    /// @main
    /// struct PhotoApp: App {
    ///     init() {
    ///         KsImagePipeline.enableSharedDiskCache()
    ///     }
    ///
    ///     var body: some Scene {
    ///         WindowGroup { ContentView() }
    ///     }
    /// }
    /// ```
    @MainActor
    public static func enableSharedDiskCache() {
        let current = ImagePipeline.shared
        // アプリが先に構成していればそれを尊重し、共有インスタンスの性質を変えない。
        guard current.configuration.dataCache == nil else { return }
        // 保存先を用意できない環境ではディスクキャッシュ無しのまま動かす。有効にしたつもりの
        // 利用者が気づけるよう、黙って戻らず記録を残す (core/ADR-0011 の「黙らず」と同じ性質)。
        guard let dataCache = try? DataCache(name: diskCacheName) else {
            #if DEBUG
            assertionFailure("ディスクキャッシュの保存先を作れませんでした。メモリキャッシュのみで動きます")
            #else
            logger.warning("ディスクキャッシュの保存先を作れませんでした。メモリキャッシュのみで動きます")
            #endif
            return
        }

        var configuration = current.configuration
        configuration.dataCache = dataCache
        // Nuke 13 は共有パイプラインの delegate を外から読めない (宣言が internal) ため、
        // 引き継げるのは configuration だけになる。
        ImagePipeline.shared = ImagePipeline(configuration: configuration)
    }

    // ディスクキャッシュのディレクトリ名。所有主体と製品を表す reverse-DNS を使う (cross/ADR-0003)。
    static let diskCacheName = "jp.kamusoft.kscollectionview"

    private static let logger = Logger(subsystem: "jp.kamusoft.kscollectionview", category: "image")
}
