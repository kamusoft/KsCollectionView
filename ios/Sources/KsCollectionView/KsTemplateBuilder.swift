/// `KsTemplate` を並べて宣言するためのビルダーです。
@resultBuilder
public enum KsTemplateBuilder<Item, Key: Hashable> {
    // 各宣言に文脈型を与え、要素型とキー型を書かない推論形での宣言を成立させる。
    public static func buildExpression(
        _ expression: KsTemplate<Item, Key>
    ) -> KsTemplate<Item, Key> {
        expression
    }

    public static func buildBlock(_ components: KsTemplate<Item, Key>...) -> [KsTemplate<Item, Key>] {
        components
    }
}
