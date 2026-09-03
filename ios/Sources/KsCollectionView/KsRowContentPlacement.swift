import SwiftUI

/// 行の中で content の位置を決めるレイアウトです。縦は content の自然高を基準に上端へ揃え、
/// 行が content より高い間も content の上端を動かしません。横は余白があれば等分して中央に置き、
/// 素の `UIHostingConfiguration` と同じ見え方を保ちます。
///
/// # なぜ独自 Layout が要るか
///
/// `UIHostingConfiguration` のホスト View は、まず行の高さを提案して content を測り、返ってきた
/// 高さが行より大きいと**その高さで組み直して行の中央に置きます**。行の高さは content の
/// サイズ変化より 1 レイアウトパス遅れて追いつくため、content が行に収まらない間は上下へ均等に
/// はみ出し、展開操作が「本文が一度上へ飛び出してから降りてくる」動きに見えます。
///
/// `frame(maxHeight: .infinity)` では防げません。`frame` の高さは子の高さより小さくならないため、
/// 提案された行の高さへ切り詰められず、ホスト View から見た content の高さが変わらないからです。
/// 提案された高さをそのまま自分の高さとして返せるのは `Layout` だけなので、ここだけ独自 Layout を
/// 置きます。KsSettingsView の `CustomCellRowPlacement` と同じ役割を、行高の概念を持たない
/// (基準は content の自然高だけの) 形で担います。
///
/// # 水平位置を変えない理由
///
/// 縦のはみ出しを抑えるために置く Layout であって、水平の見え方まで変えるものではありません。
/// 幅は行の幅をそのまま提案するので、幅いっぱいに広がる content は従来どおり広がります。
/// 幅を明示しない content (短い `Text` 等) は自然幅より広い余白を等分して中央に置き、
/// この Layout が無かったときと同じ位置に来るようにします。
internal struct KsRowContentPlacement: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return CGSize(
                width: Self.finite(proposal.width) ?? 0,
                height: Self.finite(proposal.height) ?? 0
            )
        }
        let natural = subview.sizeThatFits(Self.contentProposal(for: proposal))
        return Self.resolvedSize(proposal: proposal, natural: natural)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        let contentProposal = ProposedViewSize(width: bounds.width, height: nil)
        let natural = subview.sizeThatFits(contentProposal)
        subview.place(
            at: Self.contentOrigin(in: bounds, naturalWidth: natural.width),
            anchor: .topLeading,
            proposal: contentProposal
        )
    }

    /// 提案された高さをそのまま自分の高さとして返す (= 行の高さを超えて自己申告しない)。
    /// 提案がない (intrinsic size の問い合わせ) ときだけ content の自然高を返し、
    /// 行の self-sizing に使わせる。
    internal static func resolvedSize(proposal: ProposedViewSize, natural: CGSize) -> CGSize {
        CGSize(
            width: finite(proposal.width) ?? natural.width,
            height: finite(proposal.height) ?? natural.height
        )
    }

    /// content を置く原点。
    ///
    /// 縦は行が content より低い間も上端に固定し、はみ出しを下方向だけにする。
    /// 横は余白 (行の幅 - content の自然幅) を等分して中央に置く。余白が無い、または
    /// 自然幅が有限でない (幅いっぱいに広がる content) ときは行の先頭に置く。
    internal static func contentOrigin(in bounds: CGRect, naturalWidth: CGFloat) -> CGPoint {
        let contentWidth = finite(naturalWidth) ?? bounds.width
        return CGPoint(
            x: bounds.minX + max(0, (bounds.width - contentWidth) / 2),
            y: bounds.minY
        )
    }

    /// content には幅だけを提案し、高さは自然高に任せる。
    private static func contentProposal(for proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: Self.finite(proposal.width), height: nil)
    }

    /// 有限値の提案だけを採用する (`nil` / 無限大は「提案なし」として扱う)。
    private static func finite(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return value
    }
}
