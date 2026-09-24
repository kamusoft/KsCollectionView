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
}
