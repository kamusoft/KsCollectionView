import SwiftUI
import XCTest
@testable import KsCollectionView

@MainActor
final class KsPublicAPITests: XCTestCase {
    private struct Item: Identifiable, Equatable {
        enum Kind: Hashable {
            case message
            case ad
        }

        let id: Int
        let kind: Kind
        let title: String
    }

    private struct SharedItem: Equatable {
        let itemId: String
        let title: String
    }

    // ライブラリの型に準拠しない、既存のプロパティ (カテゴリ) を持つ項目。
    private struct Product: Identifiable, Equatable {
        let id: Int
        let category: String
    }

    func test単一テンプレートと利用者向けmodifierを組み立てられる() {
        let controller = KsScrollController()
        let view = KsCollectionView(
            [Item(id: 1, kind: .message, title: "A")],
            layout: .list(rowSpacing: 4),
            contentPadding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        ) { item in
            Text(item.title)
        }
        .header { Text("ヘッダー") }
        .footer { Text("フッター") }
        .listSeparators(false)
        .listSeparatorColor(.red)
        .onItemTap { _ in }
        .onItemLongTap { _ in }
        .touchFeedback(color: .yellow)
        .scrollController(controller)
        .observedValue(Set([1, 2]))

        XCTAssertEqual(view.configuration.items.map(\.id), [1])
        XCTAssertEqual(view.configuration.layout.rowSpacing, 4)
        XCTAssertFalse(view.configuration.showsSeparators)
        XCTAssertEqual(view.configuration.separatorColor, UIColor(Color.red))
        XCTAssertNotNil(view.configuration.header)
        XCTAssertNotNil(view.configuration.footer)
        XCTAssertNotNil(view.configuration.onItemTap)
        XCTAssertNotNil(view.configuration.onItemLongTap)
        XCTAssertNotNil(view.configuration.touchFeedbackColor)
        XCTAssertTrue(view.configuration.scrollController === controller)
        XCTAssertEqual(view.configuration.observedValue, AnyHashable(Set([1, 2])))
    }

    func test観測する値を渡さなければ宣言なしのままになる() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }

        XCTAssertNil(view.configuration.observedValue)
    }

    func test値キーの複数テンプレートを組み立てられる() {
        let items = [
            Item(id: 1, kind: .message, title: "message"),
            Item(id: 2, kind: .ad, title: "ad"),
        ]

        let view = KsCollectionView(
            items,
            template: \.kind,
            layout: .grid(columns: .fixed(portrait: 2, landscape: 4))
        ) {
            KsTemplate(.message) { item in Text(item.title) }
            KsTemplate(.ad) { item in Text("広告: \(item.title)") }
        }

        XCTAssertEqual(view.configuration.items.map(\.id), [1, 2])
        XCTAssertTrue(view.configuration.registry.contains(AnyHashable(Item.Kind.message)))
        XCTAssertTrue(view.configuration.registry.contains(AnyHashable(Item.Kind.ad)))
        XCTAssertEqual(view.configuration.templateKey(items[1]), AnyHashable(Item.Kind.ad))
    }

    func test区切り線の色を指定しなければ既定の色になる() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }

        XCTAssertNil(view.configuration.separatorColor)
    }

    func test非Identifiable型をidキーパスで組み立てられる() {
        let items = [
            SharedItem(itemId: "shared-1", title: "共有モデル A"),
            SharedItem(itemId: "shared-2", title: "共有モデル B"),
        ]
        let view = KsCollectionView(
            items,
            id: \.itemId
        ) { item in
            Text(item.title)
        }

        XCTAssertEqual(view.configuration.items.count, 2)
        XCTAssertEqual(view.configuration.id(items[0]), AnyHashable("shared-1"))
        XCTAssertEqual(view.configuration.id(items[1]), AnyHashable("shared-2"))
    }

    func testプリフェッチを宣言しなければ到達点は既定のdiskで宣言なしのままになる() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }

        XCTAssertNil(view.configuration.prefetchResources)
        XCTAssertEqual(view.configuration.prefetchDestination, .disk)
    }

    func testプリフェッチ宣言を到達点付きで組み立てられる() {
        let item = Item(id: 1, kind: .message, title: "A")
        let expected = [
            KsResource(URL(string: "https://example.com/1-a.jpg")!, width: .column),
            KsResource(URL(string: "https://example.com/1-b.jpg")!, width: .fixed(40)),
            KsResource(URL(string: "https://example.com/1-c.jpg")!),
            KsResource(URL(string: "https://example.com/1-d.jpg?sig=x")!, width: .column, key: "photo-1"),
        ]
        let view = KsCollectionView([item]) { item in
            Text(item.title)
        }
        .prefetchResources(destination: .memory) { _ in expected }

        XCTAssertEqual(view.configuration.prefetchDestination, .memory)
        XCTAssertEqual(view.configuration.prefetchResources?(item), expected)
    }

    func test先読みの要素は幅とキーを省略すると元寸でURLで見分ける() {
        let url = URL(string: "https://example.com/1.jpg")!
        let resource = KsResource(url)

        XCTAssertEqual(resource.url, url)
        XCTAssertNil(resource.width)
        XCTAssertNil(resource.key)
        XCTAssertEqual(KsResource(url, width: .fixed(40)).width, .fixed(40))
        XCTAssertEqual(KsResource(url, width: .column, key: "k").key, "k")
    }

    func testプリフェッチ宣言の到達点を省略するとdiskになる() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }
        .prefetchResources { _ in [] }

        XCTAssertEqual(view.configuration.prefetchDestination, .disk)
        XCTAssertNotNil(view.configuration.prefetchResources)
    }

    func test画像ソースは3種を表せる() {
        let remote = KsImageSource.remote(URL(string: "https://example.com/1.jpg")!)
        let file = KsImageSource.file(URL(fileURLWithPath: "/tmp/1.jpg"))
        let asset = KsImageSource.asset("thumbnail")

        XCTAssertNotEqual(remote, file)
        // リモートは任意のキーを持てる。省略したものとは別の値になる。
        let keyed = KsImageSource.remote(URL(string: "https://example.com/1.jpg")!, key: "photo-1")
        XCTAssertNotEqual(remote, keyed)
        XCTAssertEqual(remote, KsImageSource.remote(URL(string: "https://example.com/1.jpg")!, key: nil))
        XCTAssertNotEqual(file, asset)
        XCTAssertEqual(asset, KsImageSource.asset("thumbnail"))
    }

    func test読み込み中と失敗の表示は片方だけでも差し替えられる() {
        let url = URL(string: "https://example.com/1.jpg")!
        let source = KsImageSource.remote(url)

        let bothDefault = KsImage(source)
        let loadingOnly = KsImage(source, loading: { Color.clear })
        let failureOnly = KsImage(source, failure: { Color.clear })
        let bothGiven = KsImage(source, contentMode: .fit, loading: { Color.clear }, failure: { Color.clear })

        for view in [bothDefault.source, loadingOnly.source, failureOnly.source, bothGiven.source] {
            XCTAssertEqual(view, source)
        }
        XCTAssertEqual(bothDefault.contentMode, .fill)
        XCTAssertEqual(loadingOnly.contentMode, .fill)
        XCTAssertEqual(failureOnly.contentMode, .fill)
        XCTAssertEqual(bothGiven.contentMode, .fit)

        // 便宜形の URL でも同じ 4 組を書ける。
        XCTAssertEqual(KsImage(url).source, source)
        XCTAssertEqual(KsImage(url, loading: { Color.clear }).source, source)
        XCTAssertEqual(KsImage(url, failure: { Color.clear }).source, source)
        XCTAssertEqual(KsImage(url, loading: { Color.clear }, failure: { Color.clear }).source, source)
    }

    func test項目のプロパティをグループの値にして見出しつきのグループを宣言できる() {
        let products = [
            Product(id: 1, category: "果物"),
            Product(id: 2, category: "果物"),
            Product(id: 3, category: "野菜"),
        ]
        var received: [(String, [Int])] = []
        let view = KsCollectionView(products) { product in
            Text("\(product.id)")
        }
        .groups(by: \.category) { category, productsInGroup in
            let _ = received.append((category, productsInGroup.map(\.id)))
            Text("\(category) (\(productsInGroup.count))")
        }

        guard let grouping = view.configuration.grouping else {
            XCTFail("グループの宣言が構成に渡っていません")
            return
        }
        XCTAssertEqual(grouping.value(products[0]), AnyHashable("果物"))
        XCTAssertEqual(grouping.value(products[2]), AnyHashable("野菜"))
        // 既定で見出しを固定する。
        XCTAssertTrue(grouping.pinsHeaders)
        // 見出しにはグループの値が型を保ったまま、グループ内の項目と一緒に渡る。
        _ = grouping.header?(products[0], Array(products[0..<2]))
        XCTAssertEqual(received.map(\.0), ["果物"])
        XCTAssertEqual(received.map(\.1), [[1, 2]])
    }

    func test見出しの固定を外せる() {
        let view = KsCollectionView([Product(id: 1, category: "果物")]) { product in
            Text("\(product.id)")
        }
        .groups(by: \.category, pinnedHeaders: false) { category, _ in
            Text(category)
        }

        XCTAssertEqual(view.configuration.grouping?.pinsHeaders, false)
        XCTAssertNotNil(view.configuration.grouping?.header)
    }

    func test見出しなしのグループを宣言できる() {
        let view = KsCollectionView([Product(id: 1, category: "果物")]) { product in
            Text("\(product.id)")
        }
        .groups(by: \.category)

        XCTAssertNotNil(view.configuration.grouping)
        XCTAssertNil(view.configuration.grouping?.header)
    }

    func testグループを宣言しなければ構成にグループ化は無い() {
        let view = KsCollectionView([Product(id: 1, category: "果物")]) { product in
            Text("\(product.id)")
        }

        XCTAssertNil(view.configuration.grouping)
    }

    func testグループまわりの間隔をlayout値で宣言でき既定は0になる() {
        let grid = KsCollectionLayout.grid(
            columns: .fixed(portrait: 2, landscape: 4),
            rowSpacing: 8,
            groupSpacing: 24,
            headerItemSpacing: 6
        )
        XCTAssertEqual(grid.rowSpacing, 8)
        XCTAssertEqual(grid.groupSpacing, 24)
        XCTAssertEqual(grid.headerItemSpacing, 6)

        let list = KsCollectionLayout.list(groupSpacing: 12)
        XCTAssertEqual(list.rowSpacing, 0)
        XCTAssertEqual(list.groupSpacing, 12)
        XCTAssertEqual(list.headerItemSpacing, 0)

        for layout in [KsCollectionLayout.list, .list(rowSpacing: 4), .grid(columns: .fixed(2))] {
            XCTAssertEqual(layout.groupSpacing, 0)
            XCTAssertEqual(layout.headerItemSpacing, 0)
        }
    }

    func test負の間隔を不正入力として名前を挙げ0に置き換えられる() {
        let layout = KsCollectionLayout.grid(
            columns: .fixed(2),
            rowSpacing: 4,
            columnSpacing: -2,
            groupSpacing: -10,
            headerItemSpacing: 6
        )
        XCTAssertEqual(layout.negativeSpacingNames, ["columnSpacing", "groupSpacing"])

        let clamped = layout.clampingNegativeSpacings()
        XCTAssertEqual(clamped.rowSpacing, 4)
        XCTAssertEqual(clamped.columnSpacing, 0)
        XCTAssertEqual(clamped.groupSpacing, 0)
        XCTAssertEqual(clamped.headerItemSpacing, 6)
        XCTAssertEqual(clamped.kind, layout.kind)
        XCTAssertTrue(clamped.negativeSpacingNames.isEmpty)
        XCTAssertTrue(KsCollectionLayout.list(rowSpacing: 8).negativeSpacingNames.isEmpty)
    }

    // MARK: - ページング

    func testページングの状態は付属値のない5つの値を持つ() {
        let states: Set<KsPagingState> = [.idle, .refreshing, .appending, .failed, .endReached]
        XCTAssertEqual(states.count, 5)
        // Sendable として非同期の処理へ渡せる。
        let sendable: any Sendable = KsPagingState.failed
        XCTAssertEqual(sendable as? KsPagingState, .failed)
    }

    func testページングの設定を状態と非同期の次ページ要求で組み立てしきい値の既定は1になる() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }
        .paging(.idle) {
            await Task.yield()
        }

        XCTAssertEqual(view.configuration.paging?.state, .idle)
        XCTAssertEqual(view.configuration.paging?.threshold, 1)
    }

    func testページングのしきい値を指定できる() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }
        .paging(.appending, threshold: 2.5, onLoadMore: {})

        XCTAssertEqual(view.configuration.paging?.state, .appending)
        XCTAssertEqual(view.configuration.paging?.threshold, 2.5)
    }

    func testページングを付けなければ構成にページングは無い() {
        let view = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }

        XCTAssertNil(view.configuration.paging)
        XCTAssertNil(view.configuration.refresh)
        XCTAssertNil(view.configuration.pagingDisplays.appendingIndicator)
    }

    func test6つのページングの表示をpagingの前後どちらでも差し替えられる() {
        let base = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }
        // 表示の modifier を先に付ける形。
        let before = base
            .pagingAppendingIndicator { Text("読み込み中") }
            .pagingFailedFooter { retry in Button("再試行", action: retry) }
            .pagingEndReachedFooter { Text("終端") }
            .paging(.idle) {}
        // 表示の modifier を後に付ける形。
        let after = base
            .paging(.idle) {}
            .pagingLoadingPlaceholder { Text("最初の読み込み中") }
            .pagingFailedPlaceholder { retry in Button("再試行", action: retry) }
            .pagingEmptyPlaceholder { Text("空") }

        XCTAssertNotNil(before.configuration.paging)
        XCTAssertNotNil(before.configuration.pagingDisplays.appendingIndicator)
        XCTAssertNotNil(before.configuration.pagingDisplays.failedFooter)
        XCTAssertNotNil(before.configuration.pagingDisplays.endReachedFooter)
        XCTAssertNil(before.configuration.pagingDisplays.loadingPlaceholder)
        XCTAssertNotNil(after.configuration.paging)
        XCTAssertNotNil(after.configuration.pagingDisplays.loadingPlaceholder)
        XCTAssertNotNil(after.configuration.pagingDisplays.failedPlaceholder)
        XCTAssertNotNil(after.configuration.pagingDisplays.emptyPlaceholder)
        XCTAssertNil(after.configuration.pagingDisplays.appendingIndicator)
    }

    func test差し替えていない読み込み中は既定の表示で失敗と終端と空は何も出さない() {
        let displays = KsPagingDisplays()
        XCTAssertNotNil(displays.content(for: .appendingIndicator, retry: {}, loadingIndicatorColor: nil))
        XCTAssertNotNil(displays.content(for: .loadingPlaceholder, retry: {}, loadingIndicatorColor: nil))
        XCTAssertNil(displays.content(for: .failedFooter, retry: {}, loadingIndicatorColor: nil))
        XCTAssertNil(displays.content(for: .endReachedFooter, retry: {}, loadingIndicatorColor: nil))
        XCTAssertNil(displays.content(for: .failedPlaceholder, retry: {}, loadingIndicatorColor: nil))
        XCTAssertNil(displays.content(for: .emptyPlaceholder, retry: {}, loadingIndicatorColor: nil))
    }

    func test読み込み中の表示の色を指定すると構成に入り指定しなければ無い() {
        let base = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }
        XCTAssertNil(base.configuration.loadingIndicatorColor)
        // ページングを付けない一覧にも付けられる。
        XCTAssertEqual(base.loadingIndicatorColor(.red).configuration.loadingIndicatorColor, UIColor(Color.red))
        // ページングの前後どちらに付けても同じ。
        let before = base.loadingIndicatorColor(.red).paging(.idle) {}
        let after = base.paging(.idle) {}.loadingIndicatorColor(.red)
        XCTAssertEqual(before.configuration.loadingIndicatorColor, UIColor(Color.red))
        XCTAssertEqual(after.configuration.loadingIndicatorColor, UIColor(Color.red))
    }

    // MARK: - 並べ替え

    func test並べ替えのスイッチと判定と読み上げの文言と置いたときの処理を組み立てられる() {
        let items = [Product(id: 1, category: "果物"), Product(id: 2, category: "野菜")]
        var received: [KsReorderMove<Product>] = []
        let view = KsCollectionView(items) { product in
            Text("\(product.id)")
        }
        .reorder(
            isEnabled: true,
            canMove: { $0.id != 2 },
            canDrop: { $0.group == AnyHashable("果物") },
            accessibilityActions: KsReorderAccessibilityActions(previous: "前へ移動", next: "後ろへ移動")
        ) { move in
            received.append(move)
            return true
        }

        guard let reorder = view.configuration.reorder else {
            XCTFail("並べ替えの設定が構成に渡っていません")
            return
        }
        XCTAssertTrue(reorder.isEnabled)
        XCTAssertTrue(view.configuration.isReorderEnabled)
        XCTAssertEqual(reorder.canMove?(items[0]), true)
        XCTAssertEqual(reorder.canMove?(items[1]), false)
        let move = KsReorderMove(item: items[1], destination: .before(items[0]), group: AnyHashable("果物"))
        XCTAssertEqual(reorder.canDrop?(move), true)
        XCTAssertEqual(reorder.accessibilityActions, KsReorderAccessibilityActions(previous: "前へ移動", next: "後ろへ移動"))
        XCTAssertTrue(reorder.onMove(move))
        XCTAssertEqual(received, [move])
    }

    func test並べ替えは判定と文言を省略でき付けなければ構成に無い() {
        let base = KsCollectionView([Item(id: 1, kind: .message, title: "A")]) { item in
            Text(item.title)
        }
        XCTAssertNil(base.configuration.reorder)
        XCTAssertFalse(base.configuration.isReorderEnabled)

        let disabled = base.reorder(isEnabled: false) { _ in false }
        XCTAssertNotNil(disabled.configuration.reorder)
        XCTAssertFalse(disabled.configuration.isReorderEnabled)
        XCTAssertNil(disabled.configuration.reorder?.canMove)
        XCTAssertNil(disabled.configuration.reorder?.canDrop)
        XCTAssertNil(disabled.configuration.reorder?.accessibilityActions)
    }

    func test並べ替えの知らせは項目と行き先とグループの値を持つ() {
        let a = Item(id: 1, kind: .message, title: "A")
        let b = Item(id: 2, kind: .ad, title: "B")
        let before = KsReorderMove(item: a, destination: .before(b), group: nil)
        let end = KsReorderMove(item: a, destination: KsReorderDestination<Item>.end, group: AnyHashable("X"))

        XCTAssertEqual(before.item, a)
        XCTAssertEqual(before.destination, .before(b))
        XCTAssertNil(before.group)
        XCTAssertEqual(end.destination, .end)
        XCTAssertEqual(end.group, AnyHashable("X"))
        XCTAssertNotEqual(before, end)

        let texts = KsReorderAccessibilityActions(previous: "前へ", next: "後ろへ")
        XCTAssertEqual(texts.previous, "前へ")
        XCTAssertEqual(texts.next, "後ろへ")
        // 読み上げの文言は Sendable として渡せる。
        let sendable: any Sendable = texts
        XCTAssertEqual(sendable as? KsReorderAccessibilityActions, texts)
    }
}
