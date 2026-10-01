import Foundation

/// 「ページング」画面の失敗・終端・空の表示の寸法。
///
/// 値は Android Sample の同名の定義とそろえる。この画面だけの値のため `SampleTheme` には置かない。
enum PagingMessageMetrics {
    /// ページングの表示 (失敗・終端) の上下の余白。
    static let footerVerticalPadding = 16.0

    /// 失敗の表示の文言と「再試行」の間隔。
    static let messageSpacing = 8.0

    /// 「再試行」の文言の上下 / 左右の余白と角丸の半径。
    static let retryVerticalPadding = 6.0
    static let retryHorizontalPadding = 16.0
    static let retryCornerRadius = 10.0
}
