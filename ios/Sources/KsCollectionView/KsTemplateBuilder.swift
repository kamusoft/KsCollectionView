/// `Template` を並べて宣言するためのビルダーです。
@resultBuilder
public enum KsTemplateBuilder<Item, Key: Hashable> {
    public static func buildBlock(_ components: Template<Item, Key>...) -> [Template<Item, Key>] {
        components
    }
}
