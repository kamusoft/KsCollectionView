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
}
