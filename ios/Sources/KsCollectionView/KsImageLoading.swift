import Foundation

// 画像ローダーへの操作を集めた内部の受け口。本番は `KsNukeImageLoading`、
// テストは記録用の実装を `KsCollectionConfiguration.imageLoading` から差し込む。
// URL 単位より上の寿命管理 (アイテムとの対応・参照数) は `KsImagePrefetcher` が持ち、
// この受け口には解決済みの URL だけが届く。
@MainActor
internal protocol KsImageLoading: AnyObject {
    // 到達点を指定して URL の取得を開始する。既に開始済みの URL は無視される。
    func prefetch(urls: [URL], destination: KsPrefetchDestination)

    // 進行中の取得を取り消す。完了してキャッシュに入ったものは消さない。
    func cancel(urls: [URL])
}
