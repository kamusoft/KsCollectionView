import SwiftUI

/// プレーンな配列をリストまたはグリッドとして表示します。
///
/// テンプレートのクロージャの中で配列の項目以外の状態 (展開中の ID の集合、選択中の ID など) を
/// 読むときは、その状態を ``observedValue(_:)`` に渡してください。渡さないと、状態が変わっても
/// 表示が追従しないことがあります。
///
/// 一覧に SwiftUI 標準の `.refreshable` を付けると、先頭で引っ張って取り直せるようになります
/// (Pull to Refresh)。インジケータは、引っ張ってから取り直しの処理が終わるまで出ます。
/// その間に配列を差し替えると、差し替えと同時にコンテンツの先頭を表示します。
/// ``paging(_:threshold:onLoadMore:)`` を付けた一覧では、処理が終わった後も状態が
/// ``KsPagingState/refreshing`` の間はインジケータを出し続け、状態が ``KsPagingState/appending`` の間と
/// 次のページの読み込み処理の実行中は引っ張りを受け付けません。
/// 画面の上端のバーの裏まで一覧を広げて置いた場合も、インジケータはバーの下に出ます。
///
/// ```swift
/// KsCollectionView(model.items) { item in
///     Row(item: item)
/// }
/// .refreshable {
///     await model.reload()
/// }
/// ```
public struct KsCollectionView<Item: Equatable>: View {
    internal var configuration: KsCollectionConfiguration<Item>
    // 一覧に付けた `.refreshable` の処理。Pull to Refresh の取り直しに使う (core/ADR-0023)。
    @Environment(\.refresh) private var refresh

    public var body: some View {
        KsCollectionRepresentable(configuration: resolvedConfiguration)
    }

    // 環境から読む値を載せた構成。
    private var resolvedConfiguration: KsCollectionConfiguration<Item> {
        var resolved = configuration
        if let refresh {
            resolved.refresh = { await refresh() }
        }
        return resolved
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

    /// 項目をグループに分け、各グループの先頭に見出しを表示します。
    ///
    /// 配列の順に、`by` で指したグループの値が等しい項目が続く範囲が 1 つのグループになります。
    /// 配列は平らなまま渡し、項目の型を変える必要はありません。同じグループの値を持つ項目は
    /// 配列の中で続けて並べてください。離れた位置に同じ値が再び現れると、デバッグビルドでは
    /// 停止して知らせ、リリースビルドでは配列の順のまま別々のグループとして表示します。
    /// 表示中に `by` を別のキーパスへ切り替えると、配列が同じでも新しいグループの値でグループを
    /// 組み直します (グループの値の並びが変わらなければ組み直しません)。
    ///
    /// 見出しのクロージャには、グループの値とそのグループの項目が渡されます。見出しの高さは
    /// 中身から決まり、グリッドでは全幅に表示されます。見出しは既定でスクロール時に表示範囲の
    /// 上端へ固定されます。固定しない場合は `pinnedHeaders` に `false` を渡してください。
    ///
    /// ```swift
    /// KsCollectionView(products) { product in ProductRow(product) }
    ///     .groups(by: \.category) { category, productsInGroup in
    ///         Text("\(category) (\(productsInGroup.count))")
    ///     }
    /// ```
    ///
    /// グループとグループの間の間隔と、見出しと先頭行の間の間隔は、``KsCollectionLayout`` の
    /// `groupSpacing` と `headerItemSpacing` で指定します。
    public func groups<Group: Hashable, Header: View>(
        by group: KeyPath<Item, Group>,
        pinnedHeaders: Bool = true,
        @ViewBuilder header: @escaping (Group, [Item]) -> Header
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.grouping = KsGrouping(
            value: { AnyHashable($0[keyPath: group]) },
            valueSource: AnyHashable(group),
            header: { first, items in AnyView(header(first[keyPath: group], items)) },
            pinsHeaders: pinnedHeaders
        )
        return copy
    }

    /// 項目を見出しなしのグループに分けます。
    ///
    /// 配列の順に、`by` で指したグループの値が等しい項目が続く範囲が 1 つのグループになります。
    /// グループの区切りに見出しは表示されず、グループとグループの間の間隔 (``KsCollectionLayout``
    /// の `groupSpacing`) と、リストの区切り線の単位としてだけ使われます。`pinnedHeaders` は
    /// 見出しを宣言しないこの形では使われません。
    /// 表示中に `by` を別のキーパスへ切り替えたときの扱いは、見出しつきの形と同じです。
    public func groups<Group: Hashable>(
        by group: KeyPath<Item, Group>,
        pinnedHeaders: Bool = true
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.grouping = KsGrouping(
            value: { AnyHashable($0[keyPath: group]) },
            valueSource: AnyHashable(group),
            header: nil,
            pinsHeaders: pinnedHeaders
        )
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

    /// 一覧が出す読み込み中の表示の色を設定します。
    ///
    /// 色は次の 3 つの表示に同時に効きます。
    ///
    /// - 次のページの読み込み中の表示 (``pagingAppendingIndicator(_:)`` で差し替えていない場合)
    /// - 項目が 1 件も無いときの読み込み中の表示 (``pagingLoadingPlaceholder(_:)`` で差し替えていない場合)
    /// - Pull to Refresh (`.refreshable`) のインジケータ
    ///
    /// ``paging(_:threshold:onLoadMore:)`` を付けていない一覧でも、Pull to Refresh のインジケータに効きます。
    /// 差し替えた表示には効きません。差し替えた表示の色は、その表示の中で決めてください。
    ///
    /// 指定しない場合は、3 つとも標準の色のままです。読み込み中の表示は親の View に付けた `tint` の色、
    /// Pull to Refresh のインジケータはシステムの標準の色で描かれます。
    ///
    /// Pull to Refresh のインジケータは、システムの標準のインジケータの描き方に従うため、指定した色の
    /// 色みのまま、読み込み中の表示より薄く出ます (濃さは、色を指定しないときの Pull to Refresh と同じです)。
    ///
    /// ```swift
    /// KsCollectionView(model.items) { item in
    ///     Row(item: item)
    /// }
    /// .paging(model.pagingState) {
    ///     await model.loadNextPage()
    /// }
    /// .loadingIndicatorColor(.secondary)
    /// .refreshable {
    ///     await model.reload()
    /// }
    /// ```
    public func loadingIndicatorColor(_ color: Color) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.loadingIndicatorColor = UIColor(color)
        return copy
    }

    /// もうすぐ表示される項目の画像を、表示より前に取得しておくことを宣言します。
    ///
    /// クロージャには項目を渡し、その項目の表示に必要なリモート画像を ``KsResource`` の配列で
    /// 返します。返す画像が無い項目では空の配列を返してください。この宣言をしないコレクションでは
    /// 画像の先読みは一切行われません。
    ///
    /// ```swift
    /// KsCollectionView(photos) { photo in
    ///     KsImage(photo.thumbnailURL)
    /// }
    /// .prefetchResources { [KsResource($0.thumbnailURL)] }
    /// ```
    ///
    /// 先読みした画像は、同じ画像を表示するときに再ダウンロードなしで使われます。`destination` に
    /// ``KsPrefetchDestination/memory`` を指定すると、ディスクへの保存に加えてデコード済みの画像を
    /// メモリにも載せ、表示までの待ちをさらに短くします。
    ///
    /// メモリまで載せるときは、``KsResource`` に表示するときのおおよその幅を指定できます。幅を
    /// 指定した画像はその幅に縮小してから載せるので、元の大きさのままよりメモリを使いません。
    /// 列の幅 (``KsWidth/column``) はコレクションの 1 列分の幅として求められます。
    ///
    /// ```swift
    /// .prefetchResources(destination: .memory) { photo in
    ///     [KsResource(photo.thumbnailURL, width: .column)]
    /// }
    /// ```
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
        _ resources: @escaping (Item) -> [KsResource]
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
