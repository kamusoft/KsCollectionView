/// 「画像グリッド」画面だけが使う寸法。
///
/// 値は Android Sample の同名定義とそろえる (cross/ADR-0004)。Sample 全体で使い回す値では
/// ないため `SampleTheme` には置かない。
enum ImageGridMetrics {
    /// グリッドの列数。
    static let columnCount = 3

    /// セルとセルの間隔と、グリッドの内側余白。
    static let spacing = 8.0

    /// セルの角丸の半径。
    static let cellCornerRadius = 8.0

    /// ID の文言の左右の余白。
    static let captionHorizontalPadding = 8.0

    /// ID の文言の上下の余白。
    static let captionVerticalPadding = 6.0
}
