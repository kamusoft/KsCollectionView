import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

@MainActor
final class KsTemplateRegistryTests: XCTestCase {
    private enum Kind: Hashable {
        case message
        case ad
    }

    func test値キーごとのテンプレートを登録する() {
        let templates: [Template<String, Kind>] = [
            Template(.message) { Text($0) },
            Template(.ad) { Text("広告: \($0)") },
        ]
        let registry = KsTemplateRegistry(templates: templates)

        XCTAssertTrue(registry.contains(AnyHashable(Kind.message)))
        XCTAssertTrue(registry.contains(AnyHashable(Kind.ad)))
    }

    func test単一テンプレートは専用キーで解決できる() {
        let registry = KsTemplateRegistry<String>(content: { Text($0) })

        XCTAssertTrue(registry.contains(AnyHashable(KsSingleTemplateKey.value)))
    }

    #if !DEBUG
    func testReleaseでは未登録キーを空セルへ解決する() {
        let templates: [Template<String, Kind>] = [
            Template(.message) { Text($0) },
        ]
        let registry = KsTemplateRegistry(templates: templates)

        let content = registry.content(for: AnyHashable(Kind.ad), item: "未登録")
        let host = UIHostingController(rootView: content)
        let size = host.sizeThatFits(in: CGSize(width: 320, height: 100))

        XCTAssertEqual(size.height, 1, accuracy: 0.01)
    }
    #endif
}
