import UIKit

// 一覧の Pull to Refresh の部品。標準の引っ張りの部品を、上端の安全領域の境目 (バーのすぐ下) より
// 下に出す (core/ADR-0025)。
//
// 一覧は行をバーの裏に流すため、安全領域の分の余白を自動では空けない (core/ADR-0017)。そのままでは
// 標準の部品が表示範囲の上端、つまりバーの裏に出る。部品の位置は一覧が決めるため、ここでは描く位置
// だけを bounds の原点で下げる。下げる量は、表示範囲の上端から安全領域の分だけ下の位置までとし、
// コンテンツの先頭の空白 (上の内側余白) より下へは下げない。上の内側余白に安全領域の分を入れた一覧
// では、引っ張り始めてバーの下に隙間が空けば部品がバーのすぐ下に見える。余白の無い一覧では、引っ張った
// 量が安全領域に満たない間は部品がバーの裏に留まり、バーの下に空いた隙間に上から現れる。
// 取り直し中にコンテンツを部品の下で止める余白 (安全領域のうち上の内側余白で覆えない分) は一覧が足す。
//
// 部品の色は、一覧に指定した読み込み中の表示の色に合わせる。指定が無いときは標準の色のままにする
// (core/ADR-0035)。
//
// 標準の部品は、渡した色 (tintColor) をそのままの色では描かない。引っ張って取り直し中になると、線 1 本の
// 下地に渡した色を塗り、それを 8 本に複製するレイヤーが同じ色をもう一度掛けるため、RGB の成分ごとに
// 2 乗した色になる (iOS 18.6・27.0 で、描いた画素とレイヤーの値の両方から確認)。線の不透明度は複製ごとに
// 決まり、いちばん濃い線で約 57%。これは色を指定しない標準の色でも同じで、公開の手段では変えられない。
// このため部品には、成分ごとの平方根にした色を渡して 2 乗を打ち消す。色みは指定した色になり、濃さは
// 標準の Pull to Refresh と同じ (読み込み中の表示より薄い) になる。
internal final class KsRefreshControl: UIRefreshControl {
    // 部品の色。nil は標準の色。
    var indicatorColor: UIColor? {
        didSet {
            guard indicatorColor != oldValue else { return }
            tintColor = indicatorColor.map(Self.tintColor(drawing:))
        }
    }

    // 標準の部品が `color` の色みで描くように、部品に渡す色。RGB の成分ごとの平方根にする。
    //
    // - 表示モードで値が変わる色は、描くときの表示の特性で解決してから補正する。解決の前に補正すると、
    //   どの外観の値を補正したのか決まらず、外観の切り替えにも追随しない。
    // - 不透明度は変えずに渡す。部品が 2 回掛けるのは RGB だけで、不透明度は線の下地に 1 回だけ効く
    //   (標準の色の不透明度 0.6 が、線の下地にそのまま入っている)。
    // - 成分は sRGB の 0〜1 に収めてから平方根にする。sRGB の外の色は成分が負や 1 超になり、負の数の
    //   平方根は求められず、1 超の成分は部品が掛け合わせた結果を画面の色に収められないため、sRGB の
    //   範囲でいちばん近い色として扱う。
    // - RGB の成分に直せない色 (模様の色など) は、補正せずそのまま渡す。
    static func tintColor(drawing color: UIColor) -> UIColor {
        UIColor { traits in
            let resolved = color.resolvedColor(with: traits)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                return resolved
            }
            return UIColor(
                red: min(max(red, 0), 1).squareRoot(),
                green: min(max(green, 0), 1).squareRoot(),
                blue: min(max(blue, 0), 1).squareRoot(),
                alpha: alpha
            )
        }
    }

    // コンテンツの先頭にある空白の高さ (一覧の上の内側余白)。部品はこの空白の中までは下げてよい。
    var emptyTopSpace: CGFloat = 0 {
        didSet {
            guard emptyTopSpace != oldValue else { return }
            updateDrawingOffset()
        }
    }

    override var frame: CGRect {
        didSet { updateDrawingOffset() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawingOffset()
    }

    // 部品を描く位置を、一覧の表示範囲と安全領域から求め直す。一覧のスクロールのたびに呼ぶ。
    func updateDrawingOffset() {
        guard let scrollView = superview as? UIScrollView else { return }
        let shift = Self.drawingOffset(
            controlTop: frame.minY,
            controlHeight: frame.height,
            contentOffset: scrollView.contentOffset.y,
            topSafeArea: scrollView.safeAreaInsets.top,
            emptyTopSpace: emptyTopSpace
        )
        guard abs(bounds.origin.y + shift) >= 0.01 else { return }
        bounds.origin.y = -shift
    }

    // 部品を下げる量。表示範囲の上端 + 安全領域の位置まで下げ、部品の下端がコンテンツの先頭の空白の
    // 下端 (内容の座標の emptyTopSpace) を越えない範囲に留める。安全領域に重ならない置き方では 0。
    static func drawingOffset(
        controlTop: CGFloat,
        controlHeight: CGFloat,
        contentOffset: CGFloat,
        topSafeArea: CGFloat,
        emptyTopSpace: CGFloat
    ) -> CGFloat {
        let towardSafeArea = contentOffset + topSafeArea - controlTop
        let untilContentTop = emptyTopSpace - controlHeight - controlTop
        return max(0, min(towardSafeArea, untilContentTop))
    }
}
