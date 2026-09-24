import CoreGraphics

// 先読みの幅をピクセルへ解くための、その時点の表示の寸法。
internal struct KsPrefetchMetrics: Equatable {
    // 幅のピクセルの上限。描画できる画像の最大辺 (16384) を超える幅に縮小しても表示には使えず、
    // 元寸より大きい指定は拡大されないので、ここで頭打ちにしても結果は変わらない。有効な固定値でも
    // 大きすぎると整数へ直せず停止するため、直す前にこの値へ丸める (不正入力としては扱わない)。
    static let maximumPixels = 16_384

    // 現在のレイアウトの 1 列分の幅 (ポイント)。0 以下は列の幅がまだ解けないことを表す。
    let columnWidth: Double

    // 表示倍率。
    let displayScale: CGFloat

    // 幅 (ポイント) をピクセルへ直す。四捨五入した上で 1 以上・上限以下にする。表示倍率を掛けて
    // 無限大になる値も上限になる。
    func pixels(forPoints points: Double) -> Int {
        let scaled = (points * Double(displayScale)).rounded()
        guard scaled < Double(Self.maximumPixels) else { return Self.maximumPixels }
        return max(1, Int(scaled))
    }
}
