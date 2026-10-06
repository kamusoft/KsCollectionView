import UIKit
import XCTest
@testable import KsCollectionView

/// 既定の色のテストが共有する部品。色は sRGB の 0〜255 の 3 成分 (赤・緑・青) で比べる。
@MainActor
enum KsDefaultColorTestSupport {
    /// ライブラリの既定の色の、期待する値。ライブラリの定数を読まずに、ここに直接書く
    /// (定数を書き換えたときにテストが落ちるようにするため)。Android 版のテストも同じ値を持つ。
    enum Expected {
        static let separatorLight: UInt32 = 0xD9D9DE
        static let separatorDark: UInt32 = 0x38383A
        static let imageLoadingLight: UInt32 = 0xE5E5EA
        static let imageLoadingDark: UInt32 = 0x2C2C2E
        static let imageFailureBackgroundLight: UInt32 = 0xD1D1D6
        static let imageFailureBackgroundDark: UInt32 = 0x3A3A3C
        static let imageFailureMarkLight: UInt32 = 0x8E8E93
        static let imageFailureMarkDark: UInt32 = 0x8E8E93

        static func separator(_ style: UIUserInterfaceStyle) -> UInt32 {
            style == .dark ? separatorDark : separatorLight
        }

        static func imageLoading(_ style: UIUserInterfaceStyle) -> UInt32 {
            style == .dark ? imageLoadingDark : imageLoadingLight
        }

        static func imageFailureBackground(_ style: UIUserInterfaceStyle) -> UInt32 {
            style == .dark ? imageFailureBackgroundDark : imageFailureBackgroundLight
        }

        static func imageFailureMark(_ style: UIUserInterfaceStyle) -> UInt32 {
            style == .dark ? imageFailureMarkDark : imageFailureMarkLight
        }
    }

    static func name(_ style: UIUserInterfaceStyle) -> String {
        style == .dark ? "ダーク" : "ライト"
    }

    static func opposite(of style: UIUserInterfaceStyle) -> UIUserInterfaceStyle {
        style == .dark ? .light : .dark
    }

    /// 0xRRGGBB を 3 成分に分ける。
    static func components(_ rgb: UInt32) -> [Int] {
        [Int((rgb >> 16) & 0xFF), Int((rgb >> 8) & 0xFF), Int(rgb & 0xFF)]
    }

    /// 色を指定した外観で解決した 3 成分。
    static func resolved(_ color: UIColor, _ style: UIUserInterfaceStyle) -> [Int] {
        components(of: color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style)))
    }

    /// 色をビューの外観で解決した 3 成分。
    static func resolved(_ color: UIColor?, in view: UIView) -> [Int]? {
        color.map { components(of: $0.resolvedColor(with: view.traitCollection)) }
    }

    static func components(of color: UIColor) -> [Int] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].map { Int(($0 * 255).rounded()) }
    }

    /// 描いた結果の比較。色空間の変換の丸めの分だけ、成分ごとに 1 の差を許す。
    static func isClose(_ measured: [Int]?, _ expected: [Int]) -> Bool {
        guard let measured, measured.count == expected.count else { return false }
        return zip(measured, expected).allSatisfy { abs($0 - $1) <= 1 }
    }

    /// ビューを描いた結果の、1 点の色。`point` はビューの座標 (ポイント)。
    static func pixel(of view: UIView, at point: CGPoint) -> [Int]? {
        guard let bitmap = render(view, scale: 1) else { return nil }
        let x = min(max(Int(point.x), 0), bitmap.width - 1)
        let y = min(max(Int(point.y), 0), bitmap.height - 1)
        return bitmap.pixel(x: x, y: y)
    }

    /// ビューを描いた結果のどこかに、その色の画素があるか。細い図形の色を確かめるために、表示倍率 3 で描く。
    static func containsPixel(of view: UIView, matching expected: [Int]) -> Bool {
        guard let bitmap = render(view, scale: 3) else { return false }
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where isClose(bitmap.pixel(x: x, y: y), expected) {
                return true
            }
        }
        return false
    }

    /// 実行ループを回しながら収束を待つ。SwiftUI の表示の更新はレイアウトの機会が来ないと進まないため、
    /// 窓のレイアウトをこちらから促す。期限を過ぎたら、その時点の実測値を載せて失敗させる。
    static func waitPumping<Value>(
        _ label: String,
        windows: [UIWindow],
        value: () -> Value,
        file: StaticString = #filePath,
        line: UInt = #line,
        until predicate: (Value) -> Bool
    ) {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if predicate(value()) {
                return
            }
            pump(windows: windows, turns: 1)
        }
        XCTFail(
            "\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))",
            file: file,
            line: line
        )
    }

    /// 実行ループを決まった回数だけ回す。起きないことを確かめる検査で、起き得る処理に機会を与えるために使う。
    static func pump(windows: [UIWindow], turns: Int) {
        for _ in 0..<turns {
            for window in windows {
                window.rootViewController?.view.setNeedsLayout()
                window.rootViewController?.view.layoutIfNeeded()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func pixel(x: Int, y: Int) -> [Int] {
            let offset = (y * width + x) * 4
            return [Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2])]
        }
    }

    // ビューのレイヤーの木を sRGB のビットマップへ描く。テストの処理系には画面を合成する側の絵を
    // 取る経路 (`drawHierarchy`) が無いため、レイヤーを直接描く。
    private static func render(_ view: UIView, scale: CGFloat) -> Bitmap? {
        let width = Int((view.bounds.width * scale).rounded())
        let height = Int((view.bounds.height * scale).rounded())
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            view.layer.render(in: context.cgContext)
        }
        guard let cgImage = image.cgImage else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Bitmap(width: width, height: height, bytes: bytes) : nil
    }
}
