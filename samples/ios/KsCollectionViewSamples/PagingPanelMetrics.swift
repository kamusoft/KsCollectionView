import Foundation

/// 「ページング」画面の操作のパネルまわりの寸法と透け方。
///
/// 値は Android Sample の同名の定義とそろえる。この画面だけの値のため `SampleTheme` には置かない。
enum PagingPanelMetrics {
    /// パネル (畳んだときは丸いボタン) と画面の左右の端との間の余白。
    static let horizontalMargin = 16.0

    /// パネル (畳んだときは丸いボタン) の下端と、画面の下の安全領域の境目との間隔。
    ///
    /// 一覧の下の余白は変えずに、パネルを画面の下端から上げて浮かせる。広げたままでも、パネルの下に
    /// 一覧の底の帯が見え、末尾までスクロールしたときの次のページの読み込み中の表示・失敗の表示
    /// (「読み込めませんでした」と「再試行」)・終端の表示がパネルに重ならずに丸ごと見える高さにする。
    static let bottomMargin = 100.0

    /// パネルの面の上の色 (セル背景) の不透明度。一覧が透けて見える。
    static let surfaceOpacity = 0.72

    /// パネルの角丸の半径。
    static let cornerRadius = 18.0

    /// パネルの中身の左右の余白。
    static let horizontalPadding = 12.0

    /// パネルの中身の上下の余白。
    static let verticalPadding = 10.0

    /// パネルの中身の行と行の間隔。
    static let rowSpacing = 6.0

    /// パネル左上の畳むボタンの直径。
    static let foldButtonSize = 30.0

    /// 畳んだときに残る丸いボタンの直径。
    static let handleSize = 44.0

    /// パネルの影のぼかしの半径と下へのずれ。
    static let shadowRadius = 8.0
    static let shadowOffset = 4.0

    /// パネルの影の不透明度。
    static let shadowOpacity = 0.10

    /// ページングの表示 (失敗・終端) の上下の余白。
    static let footerVerticalPadding = 16.0

    /// 失敗の表示の文言と「再試行」の間隔。
    static let messageSpacing = 8.0

    /// 「再試行」の文言の上下 / 左右の余白と角丸の半径。
    static let retryVerticalPadding = 6.0
    static let retryHorizontalPadding = 16.0
    static let retryCornerRadius = 10.0

    /// 「更新できませんでした」の帯と上端の安全領域の境目 (バーの下端) との間の余白。左右は
    /// ``horizontalMargin`` と同じ。
    static let bannerTopMargin = 8.0

    /// 帯の角丸の半径。
    static let bannerCornerRadius = 12.0

    /// 帯の文言の上下の余白。
    static let bannerVerticalPadding = 10.0

    /// 帯を出しておく時間 (秒)。
    static let bannerDuration = 3.0

    /// 帯が出る・消えるときのフェードの時間 (秒)。
    static let bannerFadeDuration = 0.2
}
