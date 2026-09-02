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
        .onItemTap { _ in }
        .onItemLongTap { _ in }
        .touchFeedback(color: .yellow)
        .scrollController(controller)

        XCTAssertEqual(view.configuration.items.map(\.id), [1])
        XCTAssertEqual(view.configuration.layout.rowSpacing, 4)
        XCTAssertFalse(view.configuration.showsSeparators)
        XCTAssertNotNil(view.configuration.header)
        XCTAssertNotNil(view.configuration.footer)
        XCTAssertNotNil(view.configuration.onItemTap)
        XCTAssertNotNil(view.configuration.onItemLongTap)
        XCTAssertNotNil(view.configuration.touchFeedbackColor)
        XCTAssertTrue(view.configuration.scrollController === controller)
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
            Template(Item.Kind.message) { (item: Item) in Text(item.title) }
            Template(Item.Kind.ad) { (item: Item) in Text("広告: \(item.title)") }
        }

        XCTAssertEqual(view.configuration.items.map(\.id), [1, 2])
        XCTAssertTrue(view.configuration.registry.contains(AnyHashable(Item.Kind.message)))
        XCTAssertTrue(view.configuration.registry.contains(AnyHashable(Item.Kind.ad)))
        XCTAssertEqual(view.configuration.templateKey(items[1]), AnyHashable(Item.Kind.ad))
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
}
