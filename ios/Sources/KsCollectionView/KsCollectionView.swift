import SwiftUI

/// プレーンな配列をリストまたはグリッドとして表示します。
public struct KsCollectionView<Item: Equatable>: View {
    internal var configuration: KsCollectionConfiguration<Item>

    public var body: some View {
        KsCollectionRepresentable(configuration: configuration)
    }

    /// `Identifiable` な項目を単一テンプレートで表示します。
    public init<Content: View>(
        _ items: [Item],
        layout: KsCollectionLayout = .list,
        contentPadding: EdgeInsets = EdgeInsets(),
        @ViewBuilder content: @escaping (Item) -> Content
    ) where Item: Identifiable {
        self.init(
            items: items,
            id: { AnyHashable($0.id) },
            layout: layout,
            contentPadding: contentPadding,
            registry: KsTemplateRegistry(content: content),
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) }
        )
    }

    /// キーパスで安定 ID を指定し、単一テンプレートで表示します。
    public init<ID: Hashable, Content: View>(
        _ items: [Item],
        id: KeyPath<Item, ID>,
        layout: KsCollectionLayout = .list,
        contentPadding: EdgeInsets = EdgeInsets(),
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.init(
            items: items,
            id: { AnyHashable($0[keyPath: id]) },
            layout: layout,
            contentPadding: contentPadding,
            registry: KsTemplateRegistry(content: content),
            templateKey: { _ in AnyHashable(KsSingleTemplateKey.value) }
        )
    }

    /// 値キーに対応する複数のテンプレートで表示します。
    public init<Key: Hashable>(
        _ items: [Item],
        template: KeyPath<Item, Key>,
        layout: KsCollectionLayout = .list,
        contentPadding: EdgeInsets = EdgeInsets(),
        @KsTemplateBuilder<Item, Key> templates: () -> [Template<Item, Key>]
    ) where Item: Identifiable {
        self.init(
            items: items,
            id: { AnyHashable($0.id) },
            layout: layout,
            contentPadding: contentPadding,
            registry: KsTemplateRegistry(templates: templates()),
            templateKey: { AnyHashable($0[keyPath: template]) }
        )
    }

    /// 安定 ID とテンプレートキーをそれぞれキーパスで指定して表示します。
    public init<ID: Hashable, Key: Hashable>(
        _ items: [Item],
        id: KeyPath<Item, ID>,
        template: KeyPath<Item, Key>,
        layout: KsCollectionLayout = .list,
        contentPadding: EdgeInsets = EdgeInsets(),
        @KsTemplateBuilder<Item, Key> templates: () -> [Template<Item, Key>]
    ) {
        self.init(
            items: items,
            id: { AnyHashable($0[keyPath: id]) },
            layout: layout,
            contentPadding: contentPadding,
            registry: KsTemplateRegistry(templates: templates()),
            templateKey: { AnyHashable($0[keyPath: template]) }
        )
    }

    private init(
        items: [Item],
        id: @escaping (Item) -> AnyHashable,
        layout: KsCollectionLayout,
        contentPadding: EdgeInsets,
        registry: KsTemplateRegistry<Item>,
        templateKey: @escaping (Item) -> AnyHashable
    ) {
        configuration = KsCollectionConfiguration(
            items: items,
            id: id,
            templateKey: templateKey,
            registry: registry,
            layout: layout,
            contentPadding: contentPadding,
            showsSeparators: true,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil
        )
    }

    /// コンテンツ全体の先頭に、コンテンツと一緒にスクロールするビューを追加します。
    public func header<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.header = { AnyView(content()) }
        return copy
    }

    /// コンテンツ全体の末尾に、コンテンツと一緒にスクロールするビューを追加します。
    public func footer<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.footer = { AnyView(content()) }
        return copy
    }

    /// 項目をタップしたときの処理を設定します。
    public func onItemTap(_ action: @escaping (Item) -> Void) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.onItemTap = action
        return copy
    }

    /// 項目を長押ししたときの処理を設定します。
    public func onItemLongTap(_ action: @escaping (Item) -> Void) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.onItemLongTap = action
        return copy
    }

    /// タッチ中に表示する背景色を設定します。
    public func touchFeedback(color: Color) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.touchFeedbackColor = UIColor(color)
        return copy
    }

    /// list の行の境界 (先頭行の上端・行間・最終行の下端) に表示する区切り線の有無を設定します。
    public func listSeparators(_ isVisible: Bool) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.showsSeparators = isVisible
        return copy
    }

    /// スクロール命令を受け取るコントローラを接続します。
    public func scrollController(_ controller: KsScrollController) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.scrollController = controller
        return copy
    }
}
