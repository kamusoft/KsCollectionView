import SwiftUI

/// プレーンな配列をリストまたはグリッドとして表示します。
///
/// テンプレートのクロージャの中で配列の項目以外の状態 (展開中の ID の集合、選択中の ID など) を
/// 読むときは、その状態を ``observedValue(_:)`` に渡してください。渡さないと、状態が変わっても
/// 表示が追従しないことがあります。
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
        @KsTemplateBuilder<Item, Key> templates: () -> [KsTemplate<Item, Key>]
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
        @KsTemplateBuilder<Item, Key> templates: () -> [KsTemplate<Item, Key>]
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
            separatorColor: nil,
            header: nil,
            footer: nil,
            onItemTap: nil,
            onItemLongTap: nil,
            touchFeedbackColor: nil,
            scrollController: nil,
            prefetcher: nil,
            observedValue: nil
        )
    }

    /// テンプレートの中で読む呼び出し側の状態を、観測する値として渡します。
    ///
    /// テンプレートのクロージャは表示するビューの `body` の評価が終わったあとに呼ばれるため、
    /// クロージャの中だけで読んでいる `@State` などの状態は変化しても表示へ届きません。
    /// その状態をこの modifier に渡すと、値が変わったときに表示中のセルの内容が作り直されます。
    ///
    /// 渡した値が変わったときだけ作り直すため、配列が同じ更新では、渡した値以外の変化
    /// (テンプレートのクロージャの差し替えや、クロージャの中で読んでいる別の状態) は
    /// 表示中のセルへ届きません。テンプレートの中で読む状態は、すべてこの値にまとめて渡してください。
    /// 状態が複数あるときは、`Hashable` に準拠した 1 つの値 (構造体など) にまとめます。
    ///
    /// ```swift
    /// KsCollectionView(items) { item in
    ///     RowBody(item: item, isExpanded: expandedIDs.contains(item.id))
    /// }
    /// .observedValue(expandedIDs)
    /// ```
    ///
    /// 渡さない場合は、配列が同じまま表示するビューが再評価されるたびに、表示中のセルの内容を作り直します
    /// (配列が変わる更新では、内容の変わった項目だけが作り直されます)。
    /// Jetpack Compose 版では合成が状態を自動で購読するため、対応する指定はありません。
    public func observedValue<Value: Hashable>(_ value: Value) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.observedValue = AnyHashable(value)
        return copy
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

    /// list の区切り線の色を設定します。指定しない場合は既定の色で描かれます。
    public func listSeparatorColor(_ color: Color) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.separatorColor = UIColor(color)
        return copy
    }

    /// もうすぐ表示される項目の画像を、表示より前に取得しておくことを宣言します。
    ///
    /// クロージャには項目を渡し、その項目の表示に必要なリモート画像の URL を返します。返す URL が
    /// 無い項目では空の配列を返してください。この宣言をしないコレクションでは画像の先読みは
    /// 一切行われません。
    ///
    /// ```swift
    /// KsCollectionView(photos) { photo in
    ///     KsImage(photo.thumbnailURL)
    /// }
    /// .prefetchResources { [$0.thumbnailURL] }
    /// ```
    ///
    /// 先読みした画像は、同じ URL を表示するときに再ダウンロードなしで使われます。`destination` に
    /// ``KsPrefetchDestination/memory`` を指定すると、ディスクへの保存に加えてデコード済みの画像を
    /// メモリにも載せ、表示までの待ちをさらに短くします。
    ///
    /// 既定の ``KsPrefetchDestination/disk`` が働くには、ディスクのキャッシュが有効になっている
    /// 必要があります。アプリの起動時に ``KsImagePipeline/enableSharedDiskCache()`` を一度呼んで
    /// ください。呼ばない場合、先読みした元データは残らず表示のときに取得し直しになります。
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
    ///
    /// クロージャと `destination` は表示中に差し替えない前提の宣言です。差し替えた場合、以後に
    /// 始まる取得にだけ反映されます。
    public func prefetchResources(
        destination: KsPrefetchDestination = .disk,
        _ resources: @escaping (Item) -> [URL]
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.prefetchResources = resources
        copy.configuration.prefetchDestination = destination
        return copy
    }

    /// スクロール命令を受け取るコントローラを接続します。
    public func scrollController(_ controller: KsScrollController) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.scrollController = controller
        return copy
    }
}
