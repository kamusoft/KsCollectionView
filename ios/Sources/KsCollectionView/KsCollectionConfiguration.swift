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
}
