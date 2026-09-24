package jp.kamusoft.kscollectionview

import coil3.ImageLoader
import coil3.SingletonImageLoader

/** 画像キャッシュを消す範囲を表します。 */
public enum class KsImageCacheScope {
    /** メモリ上のデコード済みの画像だけを消します。ディスク上の元データは残ります。 */
    Memory,

    /** メモリ上の画像とディスク上の元データの両方を消します。 */
    All,
}

/**
 * 画像キャッシュの操作。
 *
 * 対象は画像の共有キャッシュなので、同じ画像を使う他の画面の表示にも影響します。
 * 呼び出しから戻った時点で削除は完了しており、以後の取得はキャッシュに当たりません。
 *
 * ただし、これはライブラリの起動時の初期化 (androidx.startup の `InitializationProvider`) が
 * 動いていることが前提です。初期化を無効にしている構成では、[clear] も [remove] も警告を
 * 記録するだけで**何もしません** (画像の表示自体は初期化が無効でも動くため、消えないキャッシュが
 * 残ります)。初期化を外していないか AndroidManifest.xml を確認してください。
 */
public object KsImageCache {

    /**
     * 指定した範囲のキャッシュを消します。
     *
     * [KsImageCacheScope.All] では、表示中の [KsImage] が読み込み中の表示に戻って取得を
     * やり直します。[KsImageCacheScope.Memory] は表示中の画像を置き換えず、次に表示するときに
     * ディスクの元データから読み直します。
     */
    public fun clear(scope: KsImageCacheScope) {
        val loader = sharedLoader("clear") ?: return
        // 消す前に始まった先読みが、消した後にキャッシュへ書き戻すのを防ぐ。到達点をメモリまでに
        // した先読みはデコード済みの画像をメモリへ載せるため、範囲がメモリだけでも止める必要がある。
        KsImagePrefetchRegistry.fenceAll()
        when (scope) {
            KsImageCacheScope.Memory -> loader.memoryCache?.clear()
            KsImageCacheScope.All -> {
                loader.memoryCache?.clear()
                loader.diskCache?.clear()
            }
        }
        // 表示の引き当ての手掛かりも捨てる。ローダーのキャッシュを消した後に捨てるので、戻った
        // 時点では両方とも消えている。
        KsImageMemoryIndex.shared.removeAll()
        if (scope == KsImageCacheScope.All) KsImageInvalidation.invalidateAll()
    }

    /**
     * 画像ソース 1 つ分のキャッシュを消します。
     *
     * 消えるのはメモリ上のあらゆる表示サイズの画像と、ディスク上の元データです。表示中の
     * そのソースの [KsImage] は読み込み中の表示に戻って取得をやり直し、他のソースの表示は
     * そのまま残ります。アプリに同梱したリソースの画像に対しては何もしません。
     *
     * キーを指定したネットワーク上の画像は、同じキーを指定したソースを渡すと消えます (URL は
     * 違っていても構いません)。キーを指定していないソースでは、同じ URL でもキー付きの画像は
     * 消えません。
     */
    public fun remove(source: KsImageSource) {
        val identifier = source.identifier ?: return
        source.emptyKeyMessage?.let { message ->
            // 空文字のキーは誤り。落とさない構成ではキーなし (URL) として消す (core/ADR-0011)。
            KsAppContext.currentOrNull?.let { KsDiagnostics.invalidInput(it, message) }
                ?: KsDiagnostics.warn(message)
        }
        val loader = sharedLoader("remove") ?: return
        // 削除前に始まったこの画像の取得を、幅に関わらず止める。止めないと、削除の後で完了した
        // 取得が削除前の内容を同じ鍵へ書き戻せる。
        KsImagePrefetchRegistry.fence(identifier)

        loader.memoryCache?.let { memory ->
            // 表示サイズなどの付随情報は鍵の本体と別に持たれるため、リモートの画像は鍵の
            // 完全一致だけで表示サイズ違いまで消える。接頭辞まで広げると、別のソース
            // (`.../a` に対する `.../a-preview` など) を巻き添えで消してしまう。
            val matches: (String) -> Boolean = when (source) {
                is KsImageSource.Remote -> { key -> key == identifier }
                // 端末内のファイルは鍵にライブラリ側の接尾辞が付くことがあるため、
                // 接頭辞の一致も拾う。
                else -> { key -> key == identifier || key.startsWith("$identifier-") }
            }
            // 表示サイズ違いは鍵の本体が同じで付随情報だけが違うため、鍵の一覧を走査しないと
            // 拾えない (ローダーが本体での引き当てを公開していない)。呼び出しスレッドを
            // メモリキャッシュの項目数に比例して止めるので、1 ソースあたりの費用は O(項目数)
            // になる。項目数はメモリの上限で頭打ちになる (数百件規模) ため走査のままにしている。
            for (key in memory.keys.toList()) {
                if (matches(key.key)) {
                    memory.remove(key)
                }
            }
        }
        // キーのある画像はディスクの鍵も識別子にしているため、同じ識別子で消える。
        loader.diskCache?.remove(identifier)

        // 表示の引き当ての手掛かりを捨ててから世代を進める。
        KsImageMemoryIndex.shared.remove(identifier)
        KsImageInvalidation.invalidateSource(identifier)
    }

    /**
     * 共有ローダーを引く。起動時の初期化が動いていない構成では引けないので null を返す。
     *
     * 落とさずに戻るのは、初期化が走らない構成 (androidx.startup の InitializationProvider を
     * マニフェストから外している等) でも利用者のアプリを止めないため。この構成で引けないのは
     * 共有ローダーを安全に特定する手段 (アプリケーションの Context) であって、キャッシュが
     * 無いわけではない — [KsImage] は表示のたびに自分の Context から共有ローダーを引けるため、
     * 初期化が無効でも表示によってキャッシュは作られる。したがってここで戻ることは「戻った
     * 時点で削除は完了している」の例外であり、公開 doc にもその旨を書いてある。
     * 落ちずに警告だけを残すのは core/ADR-0011 の「落とさず・黙らず」に従うもので、ビルド種別の
     * 判定に要る Context 自体が無い局面のため debug での停止は掛けられない。
     */
    private fun sharedLoader(operation: String): ImageLoader? {
        val context = KsAppContext.currentOrNull
        if (context == null) {
            KsDiagnostics.warn(
                "KsCollectionView が初期化されていないため KsImageCache.$operation は何もしません。" +
                    "androidx.startup の InitializationProvider が " +
                    "AndroidManifest.xml から取り除かれていないか確認してください。",
            )
            return null
        }
        return SingletonImageLoader.get(context)
    }
}
