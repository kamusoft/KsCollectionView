import CoreGraphics
import XCTest
@testable import KsCollectionView

/// 置く先の隙間の動き方を求める部品が、UIKit のドラッグ & ドロップの隙間の動きと一致することを確かめる。
/// 置けるかの判定はこの部品が求めた位置で行うため、一致していれば判定と見えている隙間が一致する。
final class KsReorderGapTrackerTests: XCTestCase {
    private func path(_ section: Int, _ item: Int) -> IndexPath {
        IndexPath(item: item, section: section)
    }

    func test同じセクションの項目の上では隙間と項目が入れ替わる() {
        // 元の位置 (1,0) の項目を持ち上げ、同じセクションの 2 番目 (動かす前の番号 1) の上へ。
        XCTAssertEqual(
            KsReorderGapTracker.nextGap(proposal: path(1, 1), current: path(1, 0), source: path(1, 0), itemCount: { _ in 5 }),
            path(1, 1)
        )
        // 隙間が項目より後ろにあれば、項目の前へ動く。
        XCTAssertEqual(
            KsReorderGapTracker.nextGap(proposal: path(1, 3), current: path(1, 3), source: path(1, 0), itemCount: { _ in 5 }),
            path(1, 2)
        )
    }

    func test別のセクションの項目の上では隙間がその項目の前に入る() {
        XCTAssertEqual(
            KsReorderGapTracker.nextGap(proposal: path(1, 4), current: path(2, 0), source: path(2, 1), itemCount: { _ in 5 }),
            path(1, 4)
        )
        // 前のセクションの最後の項目の前にある隙間は、もう一度その項目の上に来ると後ろ (末尾) へ動く。
        XCTAssertEqual(
            KsReorderGapTracker.nextGap(proposal: path(1, 4), current: path(1, 4), source: path(2, 1), itemCount: { _ in 5 }),
            path(1, 5)
        )
    }

    func test指を止めている間と項目の無い所では隙間が動かない() {
        var tracker = KsReorderGapTracker(source: path(2, 1))
        let first = tracker.candidate(for: path(2, 0), at: CGPoint(x: 10, y: 600), itemCount: { _ in 5 })
        XCTAssertEqual(first, path(2, 0))
        tracker.accept(first)
        // 指を止めたまま、隙間が動いて指の下のセルが変わっても動かない。
        XCTAssertEqual(tracker.candidate(for: path(2, 0), at: CGPoint(x: 10, y: 600), itemCount: { _ in 5 }), path(2, 0))
        // 見出し・グループの間の間隔 (提案が nil) では、当たっていない提案が無ければ動かない。
        XCTAssertEqual(tracker.candidate(for: nil, at: CGPoint(x: 10, y: 540), itemCount: { _ in 5 }), path(2, 0))
    }

    func test断った提案は持ち越されて次に受けたときに当たる() {
        var tracker = KsReorderGapTracker(source: path(2, 1))
        tracker.accept(tracker.candidate(for: path(2, 0), at: CGPoint(x: 10, y: 600), itemCount: { _ in 5 }))
        // 前のグループの最後の項目の上: 置けないとして断る。
        let refused = tracker.candidate(for: path(1, 4), at: CGPoint(x: 10, y: 505), itemCount: { _ in 5 })
        XCTAssertEqual(refused, path(1, 4))
        tracker.refuse()
        XCTAssertEqual(tracker.gap, path(2, 0))
        // 指が止まっていても、断った提案は次に受けたときに当たる位置として求まる。
        XCTAssertEqual(tracker.candidate(for: path(1, 4), at: CGPoint(x: 10, y: 505), itemCount: { _ in 5 }), path(1, 4))
        tracker.refuse()
        // 項目の無い所へ動いても、断った提案が当たる位置として求まる。
        XCTAssertEqual(tracker.candidate(for: nil, at: CGPoint(x: 10, y: 560), itemCount: { _ in 5 }), path(1, 4))
    }

    // シミュレータで記録した提案の列を流し、隙間が動く位置の列が記録と一致すること。
    func test記録した提案の列で求めた隙間の動きが実際の隙間の動きと一致する() {
        for recording in KsReorderGapRecording.all {
            var tracker = KsReorderGapTracker(source: recording.source)
            var moves: [IndexPath] = []
            for update in recording.updates {
                let candidate = tracker.candidate(for: update.proposal, at: update.location, itemCount: { _ in 5 })
                let allowed = !recording.sameSectionOnly || candidate.section == recording.source.section
                if allowed {
                    if candidate != tracker.gap {
                        moves.append(candidate)
                    }
                    tracker.accept(candidate)
                } else {
                    tracker.refuse()
                }
            }
            XCTAssertEqual(moves, recording.gaps, "記録 \(recording.name) で隙間の動きが一致しません")
            XCTAssertFalse(recording.gaps.isEmpty, "記録 \(recording.name) に隙間の動きがありません")
        }
    }
}
