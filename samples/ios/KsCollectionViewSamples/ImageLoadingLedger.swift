import Foundation
import os

/// 観測した読み込みの節目を、実行中のプロセスの中に溜めておく記録です。
///
/// 観測 (``ImageLoadingObservation``) はログへ 1 行ずつ出しますが、実機のログはプロセスの外から
/// 確実には回収できません。計測用の起動経路が同じプロセスの中で節目を数えられるよう、ログと同じ
/// 節目をここにも残します。記録するのは ``isRecording`` を立てた実行だけです (既定の観測では
/// 溜めないため、長く動かしても大きくなりません)。
///
/// 割り込み処理はローダーのスレッドから呼ばれるため、主アクターに閉じず錠で守ります。
nonisolated final class ImageLoadingLedger: Sendable {
    /// 節目 1 件分の記録。
    struct Entry: Sendable {
        /// 記録した時刻。
        let time: ContinuousClock.Instant

        /// 節目の種類 (`start` / `success` / `cancel` / `error`)。
        let event: String

        /// 要求の種別 (``ImageRequestKind`` の値)。
        let kind: String

        /// 成功したときにどの層から返ったか (`memory` / `disk` / `network`)。成功以外は `nil`。
        let source: String?

        /// 要求の URL の文字列。
        let url: String
    }

    static let shared = ImageLoadingLedger()

    private struct State {
        var isRecording = false
        var entries: [Entry] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// 記録を始めます。これより前の節目は残りません。
    func startRecording() {
        state.withLock {
            $0.isRecording = true
            $0.entries.removeAll()
        }
    }

    /// 節目を 1 件残します。記録を始めていなければ何もしません。
    func append(_ entry: Entry) {
        state.withLock {
            guard $0.isRecording else { return }
            $0.entries.append(entry)
        }
    }

    /// これまでに残した節目を、残した順に返します。
    func snapshot() -> [Entry] {
        state.withLock { $0.entries }
    }
}
