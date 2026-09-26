import SwiftUI
import UIKit

/// Sample 共通の配色と寸法。
///
/// 色は ``SamplePalette`` のライト / ダークの 2 組から、描かれる場所の外観 (ルートメニューで
/// 選んだ外観を window に上書きしたもの。「システム」なら端末の表示モード) に応じた組の値を取る。
enum SampleTheme {
    static let accent = adaptive(SamplePalette.light.accent, SamplePalette.dark.accent)
    static let background = adaptive(SamplePalette.light.background, SamplePalette.dark.background)
    static let cell = adaptive(SamplePalette.light.cell, SamplePalette.dark.cell)
    static let text = adaptive(SamplePalette.light.text, SamplePalette.dark.text)
    static let secondaryText = adaptive(SamplePalette.light.secondaryText, SamplePalette.dark.secondaryText)
    static let separator = adaptive(SamplePalette.light.separator, SamplePalette.dark.separator)
    static let onAccent = adaptive(SamplePalette.light.onAccent, SamplePalette.dark.onAccent)

    static let horizontalPadding = 16.0
    static let rowVerticalPadding = 12.0
    static let controlVerticalPadding = 10.0
    static let swatchSize = 44.0
    static let gridMinimumHeight = 106.0

    /// 色見本。項目の内容を表す色のため、ライト / ダークで同じ値を使う (先頭はライトのアクセントと同じ値)。
    static let swatches: [Color] = [
        Color(uiColor: SamplePalette.light.accent),
        Color(red: 232 / 255, green: 96 / 255, blue: 76 / 255),
        Color(red: 59 / 255, green: 165 / 255, blue: 93 / 255),
        Color(red: 229 / 255, green: 165 / 255, blue: 10 / 255),
        Color(red: 142 / 255, green: 91 / 255, blue: 216 / 255),
        Color(red: 42 / 255, green: 161 / 255, blue: 179 / 255),
        Color(red: 211 / 255, green: 85 / 255, blue: 127 / 255),
        Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255),
        Color(red: 180 / 255, green: 86 / 255, blue: 46 / 255),
    ]

    /// 描かれる場所の外観がダークならダークの組、それ以外ならライトの組の値になる色。
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
