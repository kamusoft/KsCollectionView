import UIKit

// ライブラリが自前の値を持つ既定の色。利用者が色や表示を指定しないときにだけ使う。
//
// どの色もライト用とダーク用の 2 つの固定値 (sRGB の 0xRRGGBB) を持ち、Android 版と同じ値にする
// (core/ADR-0036)。OS の色を借りないのは、両プラットフォームで同じ値であることを値で比べられるように
// するためである。そのため OS の「コントラストを上げる」設定には追随しない。
//
// 色は、置かれた場所の外観 (アプリが上書きした外観を含む) で OS が解決する `UIColor` として 1 つずつ持つ。
// 表示中に外観が切り替わると、この色で描いているビューは OS がその場で描き直す。
internal enum KsDefaultColors {
    // list の区切り線。
    static let separatorLight: UInt32 = 0xD9D9DE
    static let separatorDark: UInt32 = 0x38383A

    // 画像の読み込み中の表示の無地。
    static let imageLoadingLight: UInt32 = 0xE5E5EA
    static let imageLoadingDark: UInt32 = 0x2C2C2E

    // 画像の失敗の表示の下地。
    static let imageFailureBackgroundLight: UInt32 = 0xD1D1D6
    static let imageFailureBackgroundDark: UInt32 = 0x3A3A3C

    // 画像の失敗の表示の印。ライトとダークで同じ値である。
    static let imageFailureMarkLight: UInt32 = 0x8E8E93
    static let imageFailureMarkDark: UInt32 = 0x8E8E93

    // 参照のたびに同じオブジェクトを返す。区切り線の色の書き込みは、同じオブジェクトなら省かれる
    // (`KsHostingCell.configureSeparators`)。
    static let separator = adaptive(light: separatorLight, dark: separatorDark)
    static let imageLoading = adaptive(light: imageLoadingLight, dark: imageLoadingDark)
    static let imageFailureBackground = adaptive(
        light: imageFailureBackgroundLight,
        dark: imageFailureBackgroundDark
    )
    static let imageFailureMark = adaptive(light: imageFailureMarkLight, dark: imageFailureMarkDark)

    private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        let lightColor = opaque(light)
        let darkColor = opaque(dark)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }

    private static func opaque(_ rgb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
