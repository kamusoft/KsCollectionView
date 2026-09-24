import CoreGraphics
import Foundation

// メモリにある画像を表示枠へそのまま使えるかの判定 (core/ADR-0013)。
//
// 画像を当てはめ方で枠へ合わせるのに必要な拡大率 s を求め、s が [1/上限, 1/下限] の内側なら使う。
// 言い換えると、画像の寸法が「枠に必要な寸法」の下限倍以上・上限倍以下なら使う。下限は拡大による
// ぼやけ、上限は描画時の縮小によるざらつきと描画できる寸法の上限を避けるための値である。
// 値は実機の見た目で決めるため、この 1 か所にだけ置く。
internal enum KsImageMatching {
    // 画像の寸法が必要な寸法の何倍以上なら使うか。
    static let lowerBound = 0.5

    // 画像の寸法が必要な寸法の何倍以下なら使うか。
    static let upperBound = 4.0

    // 画像 (ピクセル) を枠 (ピクセル) へ当てはめるのに必要な拡大率。`fill` は枠を覆う最小、
    // `fit` は枠に収まる最大の拡大率になる。大きさが 0 の画像には nil を返す。
    static func requiredScale(
        imagePixels: CGSize,
        framePixels: CGSize,
        contentMode: KsImageContentMode
    ) -> Double? {
        guard imagePixels.width > 0, imagePixels.height > 0 else { return nil }
        let horizontal = Double(framePixels.width / imagePixels.width)
        let vertical = Double(framePixels.height / imagePixels.height)
        switch contentMode {
        case .fill: return max(horizontal, vertical)
        case .fit: return min(horizontal, vertical)
        }
    }

    // 拡大率が許容範囲の内側か。
    static func isAcceptable(scale: Double) -> Bool {
        scale <= 1 / lowerBound && scale >= 1 / upperBound
    }

    // 候補のうち、許容範囲の内側で必要な寸法に最も近い (拡大率が 1 に最も近い) ものの位置。
    // 近さは比で測る (2 倍大きいことと 2 倍小さいことを同じ遠さとみなす)。
    static func bestMatch(
        among imagePixels: [CGSize],
        framePixels: CGSize,
        contentMode: KsImageContentMode
    ) -> Int? {
        var best: (index: Int, distance: Double)?
        for (index, pixels) in imagePixels.enumerated() {
            guard let scale = requiredScale(
                imagePixels: pixels, framePixels: framePixels, contentMode: contentMode
            ), isAcceptable(scale: scale) else { continue }
            let distance = abs(log(scale))
            if let current = best, current.distance <= distance { continue }
            best = (index, distance)
        }
        return best?.index
    }
}
