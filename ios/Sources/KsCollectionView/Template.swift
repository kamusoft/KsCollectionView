import SwiftUI

/// 値キーに対応するセルの表示内容です。
public struct Template<Item, Key: Hashable> {
    internal let key: Key
    internal let content: (Item) -> AnyView

    /// キーと、そのキーを持つ項目の表示内容を登録します。
    public init<Content: View>(
        _ key: Key,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.key = key
        self.content = { AnyView(content($0)) }
    }
}
