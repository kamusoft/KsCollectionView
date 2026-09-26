/// コレクションの表示形態です。
public struct KsCollectionLayout: Equatable, Sendable {
    internal enum Kind: Equatable, Sendable {
        case list
        case grid(KsGridColumns)
    }

    internal let kind: Kind

    /// 行と行の間隔です。
    public let rowSpacing: Double

    /// 列と列の間隔です。
    public let columnSpacing: Double

    /// グループとグループの間の間隔です。
    ///
    /// 前のグループの最終行と次のグループの見出しの間に入り、コンテンツ全体の先頭と末尾には入りません。
    /// グループを宣言しない場合は使われません。
    public let groupSpacing: Double

    /// グループの見出しと、そのグループの先頭行の間の間隔です。
    ///
    /// 見出しを宣言しない場合は使われません。行間 (``rowSpacing``) は行と行の間にだけ入り、
    /// 見出しの前後には入りません。
    public let headerItemSpacing: Double

    /// 1 列のリストを作成します。
    public static let list = KsCollectionLayout(kind: .list)

    /// 間隔を指定した 1 列のリストを作成します。
    ///
    /// 間隔はいずれも 0 以上で指定します。省略した間隔は 0 です。負の値は誤りで、デバッグビルドでは
    /// 停止して知らせ、リリースビルドでは警告を記録して 0 として表示します。
    public static func list(
        rowSpacing: Double = 0,
        groupSpacing: Double = 0,
        headerItemSpacing: Double = 0
    ) -> KsCollectionLayout {
        KsCollectionLayout(
            kind: .list,
            rowSpacing: rowSpacing,
            groupSpacing: groupSpacing,
            headerItemSpacing: headerItemSpacing
        )
    }

    /// グリッドを作成します。
    ///
    /// 間隔はいずれも 0 以上で指定します。省略した間隔は 0 です。負の値は誤りで、デバッグビルドでは
    /// 停止して知らせ、リリースビルドでは警告を記録して 0 として表示します。
    public static func grid(
        columns: KsGridColumns,
        rowSpacing: Double = 0,
        columnSpacing: Double = 0,
        groupSpacing: Double = 0,
        headerItemSpacing: Double = 0
    ) -> KsCollectionLayout {
        KsCollectionLayout(
            kind: .grid(columns),
            rowSpacing: rowSpacing,
            columnSpacing: columnSpacing,
            groupSpacing: groupSpacing,
            headerItemSpacing: headerItemSpacing
        )
    }

    private init(
        kind: Kind,
        rowSpacing: Double = 0,
        columnSpacing: Double = 0,
        groupSpacing: Double = 0,
        headerItemSpacing: Double = 0
    ) {
        // 間隔の負の値は不正入力。検知と縮退 (0 として扱う) は、表示するときにエンジンが
        // `negativeSpacingNames` と `clampingNegativeSpacings()` で行う (core/ADR-0011)。
        switch kind {
        case .list:
            break
        case let .grid(columns):
            switch columns.storage {
            case let .count(count):
                assert(count > 0, "列数は 1 以上で指定してください")
            case let .orientation(portrait, landscape):
                assert(portrait > 0 && landscape > 0, "列数は 1 以上で指定してください")
            case let .adaptive(minItemWidth):
                assert(minItemWidth > 0, "minItemWidth は 0 より大きい値を指定してください")
            }
        }

        self.kind = kind
        self.rowSpacing = rowSpacing
        self.columnSpacing = columnSpacing
        self.groupSpacing = groupSpacing
        self.headerItemSpacing = headerItemSpacing
    }

    /// 負の値が指定された間隔の名前。宣言の順。
    internal var negativeSpacingNames: [String] {
        [
            ("rowSpacing", rowSpacing),
            ("columnSpacing", columnSpacing),
            ("groupSpacing", groupSpacing),
            ("headerItemSpacing", headerItemSpacing),
        ]
        .filter { $0.1 < 0 }
        .map(\.0)
    }

    /// 負の値の間隔を 0 に置き換えた layout 値。
    internal func clampingNegativeSpacings() -> KsCollectionLayout {
        KsCollectionLayout(
            kind: kind,
            rowSpacing: max(0, rowSpacing),
            columnSpacing: max(0, columnSpacing),
            groupSpacing: max(0, groupSpacing),
            headerItemSpacing: max(0, headerItemSpacing)
        )
    }
}
