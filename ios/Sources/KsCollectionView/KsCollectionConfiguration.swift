import SwiftUI

internal struct KsCollectionConfiguration<Item: Equatable> {
    var items: [Item]
    let id: (Item) -> AnyHashable
    let templateKey: (Item) -> AnyHashable
    let registry: KsTemplateRegistry<Item>
    var layout: KsCollectionLayout
    var contentPadding: EdgeInsets
    var showsSeparators: Bool
    var separatorColor: UIColor?
    var header: (() -> AnyView)?
    var footer: (() -> AnyView)?
    var onItemTap: ((Item) -> Void)?
    var onItemLongTap: ((Item) -> Void)?
    var touchFeedbackColor: UIColor?
    var scrollController: KsScrollController?
    var prefetcher: KsAnyPrefetcher<Item>?
    // テンプレートのクロージャが読む呼び出し側の状態を型消去して保持する。宣言が無い (nil) ときは
    // 配列が同値の更新が届くたびに可視セルを作り直す (ios/ADR-0006)。
    var observedValue: AnyHashable?
    // グループ化の宣言。無い (nil) ときは配列全体を 1 続きで表示する。
    var grouping: KsGrouping<Item>?
    // プリフェッチ宣言。無い (nil) ときはプリフェッチ機構を組み立てず、可視範囲の観測も行わない。
    var prefetchResources: ((Item) -> [KsResource])?
    var prefetchDestination: KsPrefetchDestination = .disk
    // 画像ローダーへの受け口の差し替え口。宣言が無いときは本番の adapter を組み立てる。
    var imageLoading: (any KsImageLoading)?
    // ページングの設定。付けていない (nil) ときは次ページ要求もページングの表示も行わない。
    var paging: KsPaging?
    // 差し替えたページングの表示。ページングを付けていない一覧では使わない。
    var pagingDisplays = KsPagingDisplays()
    // Pull to Refresh の取り直しの処理。一覧に付けた `.refreshable` の処理を読んで載せる。
    // 無い (nil) ときは引っ張れない。
    var refresh: (@MainActor () async -> Void)?
}
