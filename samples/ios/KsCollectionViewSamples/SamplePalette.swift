import UIKit

// 2 組の同じ名前の色は Android Sample の `SamplePalette.kt` と同じ RGBA にそろえる (cross/ADR-0007)。

/// Sample の配色の 1 組。ライトとダークの 2 組を持ち、画面側は ``SampleTheme`` の同じ名前の色から、
/// 選んだ外観に応じた組の値を受け取る。
///
/// OS の semantic color は実値がプラットフォーム間でずれるため使わない。
struct SamplePalette: Sendable {
    /// 選択の印・戻る・操作の文言など、強調に使う色。
    let accent: UIColor
    /// 画面の下地。
    let background: UIColor
    /// 行・セル・操作の帯の面。
    let cell: UIColor
    /// 主な文字。
    let text: UIColor
    /// 補助の文字。
    let secondaryText: UIColor
    /// 区切りの線。
    let separator: UIColor
    /// アクセントで塗った面の上に載せる文字・印・つまみ。
    let onAccent: UIColor

    /// ライトの組。
    static let light = SamplePalette(
        accent: rgb(47, 111, 237),         // #2F6FED
        background: rgb(242, 242, 247),    // #F2F2F7
        cell: rgb(255, 255, 255),          // #FFFFFF
        text: rgb(17, 18, 20),             // #111214
        secondaryText: rgb(110, 112, 118), // #6E7076
        separator: rgb(217, 217, 222),     // #D9D9DE
        onAccent: rgb(255, 255, 255)       // #FFFFFF
    )

    /// ダークの組。下地と行をアクセントの青の色相に寄せた紺にし、OS のダークの灰色で描かれる
    /// ライブラリの既定の色と見分けられるようにする。アクセントの上の色は、明るめの青のアクセントの
    /// 上で白では読みにくいため、下地の紺にする。
    static let dark = SamplePalette(
        accent: rgb(91, 141, 246),         // #5B8DF6
        background: rgb(13, 19, 33),       // #0D1321
        cell: rgb(24, 34, 54),             // #182236
        text: rgb(230, 235, 245),          // #E6EBF5
        secondaryText: rgb(142, 154, 179), // #8E9AB3
        separator: rgb(42, 55, 82),        // #2A3752
        onAccent: rgb(13, 19, 33)          // #0D1321
    )

    /// 0〜255 の成分から不透明の色を作る。
    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
        UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}
