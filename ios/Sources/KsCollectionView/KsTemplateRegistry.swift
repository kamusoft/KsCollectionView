import SwiftUI
import os

internal struct KsTemplateRegistry<Item> {
    private let templates: [AnyHashable: (Item) -> AnyView]
    private let fallback: (Item) -> AnyView
    private let logger = Logger(subsystem: "jp.kamusoft.kscollectionview", category: "template")

    init<Key: Hashable>(templates: [Template<Item, Key>]) {
        // 重複したテンプレートキーは不正入力。後勝ちで 1 件へ畳み、警告ログを残して表示を継続する。
        self.templates = Dictionary(
            templates.map { (AnyHashable($0.key), $0.content) },
            uniquingKeysWith: { _, latest in latest }
        )
        fallback = { _ in AnyView(EmptyView().frame(height: 1)) }
        if self.templates.count != templates.count {
            logger.warning("重複したテンプレートキーを後勝ちで解決しました")
        }
    }

    init<Content: View>(content: @escaping (Item) -> Content) {
        templates = [AnyHashable(KsSingleTemplateKey.value): { AnyView(content($0)) }]
        fallback = { _ in AnyView(EmptyView().frame(height: 1)) }
    }

    func content(for key: AnyHashable, item: Item) -> AnyView {
        guard let content = templates[key] else {
            #if DEBUG
            assertionFailure("キー \(String(describing: key)) に対応するテンプレートが登録されていません")
            #else
            logger.warning("未登録のテンプレートキーを空セルで表示します: \(String(describing: key), privacy: .public)")
            #endif
            return fallback(item)
        }
        return content(item)
    }

    func contains(_ key: AnyHashable) -> Bool {
        templates[key] != nil
    }
}
