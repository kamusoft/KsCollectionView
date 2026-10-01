import CoreGraphics
import Foundation

// UIKit のドラッグ & ドロップが、置く先の隙間を次にどこへ動かすかを求める (ios/ADR-0011)。
//
// UIKit はドラッグ中の行き先の提案 (`dropSessionDidUpdate` に渡す位置) をそのまま隙間の位置にはしない。
// 提案の位置は指の下のセルの、動かす前の配列での位置で、指が隙間の上にあるときは持ち上げた項目の元の位置、
// セルの無い所 (見出し・グループの間の間隔) では nil になる。隙間は次の規則で動く (iOS 18.6・26.5 の
// シミュレータで観測)。
//
// - 隙間が動くのは、指が動いたときだけ。指を止めている間は、隙間が動いて指の下のセルが入れ替わっても動かない
// - 指が動いたとき、指の下のセルがあればその位置へ、無ければ (nil) まだ当たっていない最後の提案の位置へ動く。
//   指が隙間の上にある (提案が元の位置) なら動かず、それまでの提案は捨てる
// - 置けない場所として断った提案は隙間を動かさずに持ち越され、次に置ける提案として受けたとき (指が
//   止まっていても) に当たる
// - 動く先は、指の下のセルが今の隙間と同じセクションにあれば、そのセルと隙間を入れ替えた位置 (隙間が
//   セルより前にあればセルの後ろ、後ろにあればセルの前)。別のセクションにあれば、そのセクションの
//   指の下のセルの前
//
// 位置はいずれも、置いたときの行き先と同じく「持ち上げた項目を元の位置から抜いた並び」での番号で表す。
// 置けるかの判定はこの規則で求めた「次に見える隙間」の位置で行い、見えている隙間と判定を一致させる。
// 実際に隙間が動いた位置はレイアウトから届くので (`gapDidMove(to:)`)、規則が外れても次の判定から合う。
//
// 上の規則は隙間が動く速さ (`reorderingCadence`) が既定の immediate のときの観測。一覧は slow にしているため、
// UIKit は受けた提案の位置へ、指を止めてから隙間を動かす。判定は提案を受けたときに行い、置けない提案は断って
// 隙間を動かさせない (slow でも、断った位置に隙間が空かないことを iOS 18.6・26.5 のシミュレータで確かめた範囲)。
internal struct KsReorderGapTracker {
    // 持ち上げた項目の元の位置。
    let source: IndexPath
    // 今見えている (または断っている間に保っている) 隙間の位置。
    private(set) var gap: IndexPath
    // まだ隙間に当たっていない最後の提案。
    private var pendingProposal: IndexPath?
    // 最後に届いた提案 (nil を除く)。
    private var lastProposal: IndexPath?
    // 最後に届いた指の位置。
    private var lastLocation: CGPoint?
    // 最後に求めた隙間が、控えた提案を当てたものか。
    private var candidateAppliesProposal = false
    // 控えた提案を断ったか。断った提案は UIKit の側に残り、次に受けたときに指が止まっていても当たる。
    private var isPendingProposalRefused = false

    init(source: IndexPath) {
        self.source = source
        gap = source
    }

    /// この提案を受けたときに隙間が空く位置。提案は控えるが、隙間の位置は受けるまで変えない。
    ///
    /// - Parameters:
    ///   - location: 指の位置
    ///   - itemCount: セクションの項目の数 (動かす前の配列での数)
    mutating func candidate(
        for proposal: IndexPath?,
        at location: CGPoint,
        itemCount: (Int) -> Int
    ) -> IndexPath {
        let moved = location != lastLocation
        lastLocation = location
        // 指が止まったまま同じ提案が続くあいだは、新しい提案として扱わない。
        if let proposal, moved || proposal != lastProposal {
            lastProposal = proposal
            if proposal != source {
                pendingProposal = proposal
            } else {
                pendingProposal = nil
                isPendingProposalRefused = false
            }
        }
        guard moved || isPendingProposalRefused, let pending = pendingProposal else {
            candidateAppliesProposal = false
            return gap
        }
        candidateAppliesProposal = true
        return Self.nextGap(proposal: pending, current: gap, source: source, itemCount: itemCount)
    }

    /// 提案を受けた (置ける場所として隙間を空けさせた)。
    mutating func accept(_ candidate: IndexPath) {
        if candidateAppliesProposal {
            pendingProposal = nil
            isPendingProposalRefused = false
            candidateAppliesProposal = false
        }
        gap = candidate
    }

    /// 提案を断った (置けない場所として隙間を空けさせなかった)。
    mutating func refuse() {
        if candidateAppliesProposal {
            isPendingProposalRefused = true
            candidateAppliesProposal = false
        }
    }

    /// UIKit が実際に隙間を動かした。
    mutating func gapDidMove(to target: IndexPath) {
        gap = target
    }

    /// 提案 1 つで隙間が動く先。
    static func nextGap(
        proposal: IndexPath,
        current: IndexPath,
        source: IndexPath,
        itemCount: (Int) -> Int
    ) -> IndexPath {
        guard proposal != source else { return current }
        // 提案の位置を、持ち上げた項目を抜いた並びでの位置へ直す。
        let item = proposal.section == source.section && proposal.item > source.item
            ? proposal.item - 1
            : proposal.item
        // 置ける番号の上限は、持ち上げた項目を抜いたセクションの項目の数。
        let upperBound = itemCount(proposal.section) - (proposal.section == source.section ? 1 : 0)
        let target: Int
        if proposal.section == current.section, current.item <= item {
            target = item + 1
        } else {
            target = item
        }
        return IndexPath(item: min(max(0, target), max(0, upperBound)), section: proposal.section)
    }
}
