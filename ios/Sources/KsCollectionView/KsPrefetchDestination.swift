/// プリフェッチした画像をどこまで用意しておくかを表します。
public enum KsPrefetchDestination: Hashable, Sendable {
    /// 画像の元データをディスクのキャッシュに保存するところまで行います。表示のためのデコードは行いません。
    ///
    /// ディスクのキャッシュはアプリが有効にしたときだけ働きます。アプリの起動時に
    /// ``KsImagePipeline/enableSharedDiskCache()`` を呼んでいない場合、この到達点で先読みした
    /// 元データは残らず、表示のときに取得し直しになります。
    case disk

    /// 元データの保存に加えて、デコードした画像をメモリのキャッシュにも載せます。
    case memory
}
