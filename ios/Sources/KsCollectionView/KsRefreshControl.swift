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
internal final class KsRefreshControl: UIRefreshControl {
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
