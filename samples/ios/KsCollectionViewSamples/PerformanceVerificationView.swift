import Darwin
@_spi(KsMeasurement) import KsCollectionView
import SwiftUI
import UIKit

/// メモリ計測用の検証画面です。起動引数で指定したときだけ表示します。
struct PerformanceVerificationView: View {
    let automaticallyRuns: Bool
    var fixture: PerformanceFixture = .largeData

    @State private var completedRoundTrips = 0
    @State private var memoryAfterLastRoundTrip = "未計測"
    @State private var judgement = Judgement.undetermined
    @State private var visitedItemsInLastRoundTrip: Set<Int> = []
    @State private var footprints: [UInt64] = []
    @State private var isRunning = false

    /// 往復を重ねた結果の判定です。
    enum Judgement: String {
        /// 連続する 2 往復の増分が許容差に収まった。
        case steady = "定常"
        /// まだ増分が収まっていない (上限まで重ねた後なら、これが最終の判定になる)。
        case undetermined = "未判定"
        /// 走査そのものが成立しなかった往復があり、定常化を判定できない。
        case invalid = "無効"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("1 往復する") {
                    runRoundTrip()
                }
                .disabled(isRunning || completedRoundTrips >= Self.maximumRoundTrips)
                .accessibilityIdentifier("performance.roundTrip")

                Text("完了: \(completedRoundTrips)")
                    .accessibilityIdentifier("performance.completedRoundTrips")
            }

            // 往復ごとに読めればよいので、直近 1 往復の値だけを出す。定常判定はこの値の列から
            // app 側が決め、駆動側 (UI テスト) はその判定を読んで往復を止める。
            Text(verbatim: "直近往復のメモリ: \(memoryAfterLastRoundTrip)")
                .accessibilityIdentifier("performance.memory.last")
            Text(verbatim: "判定: \(judgement.rawValue)")
                .accessibilityIdentifier("performance.judgement")
            // 通過件数は往復ごとに数え直すため、直近 1 往復の結果であることを表示に明示する。
            // 桁区切りが入ると読み取り側の期待値がロケール依存になるため、そのままの数字で表示する。
            Text(verbatim: "直近往復の通過: \(visitedItemsInLastRoundTrip.count) / \(fixture.itemCount)")
                .accessibilityIdentifier("performance.visitedItems")

            fixtureCollection
        }
        .task {
            guard automaticallyRuns else { return }
            let isSteady = await runUntilSteady()
            // 定常化しないまま終わった走行を成功として終わらせない (未判定が緑にならない)。
            exit(isSteady ? EXIT_SUCCESS : EXIT_FAILURE)
        }
    }

    /// 走査する土俵です。件数と配置とセルの中身がここで決まります。
    @ViewBuilder
    private var fixtureCollection: some View {
        switch fixture {
        case .largeData:
            KsCollectionView(
                DemoData.largeItems,
                layout: .grid(columns: .fixed(2), rowSpacing: 1, columnSpacing: 1)
            ) { item in
                DemoListRow(item: item)
            }
        case .imageGrid(let destination):
            // 件数・列数・間隔・外周の余白・セルはデモ画面と同じ宣言元 (ImageGridFixture) から
            // 取り、プリフェッチの到達点だけを外から選ぶ。
            ImageGridFixture.collection(destination: destination)
        }
    }

    private func runRoundTrip() {
        Task { @MainActor in
            await performRoundTrip()
        }
    }

    /// 1 段階の送り量を可視範囲の高さに対する割合で決めます。
    /// 前後の可視範囲が十分に重ならない刻みでは、UIKit は再利用ではなくセルの作り直しを行うため、
    /// 通過した項目のセルが実際に作られる刻みにする必要があります。
    private static let traversalStepRatio: CGFloat = 0.5

    /// 送り 1 段階あたり、目的の位置に到達してレイアウトが確定するまでの待ち上限です。
    private static let settleTimeout = Duration.seconds(5)

    /// 走査が終わらないまま回り続けるのを防ぐ、片道あたりの段数の上限です。
    private static let maximumStepsPerDirection = 20_000

    /// 往復を重ねる回数の上限です。
    private static let maximumRoundTrips = 10

    /// 定常化とみなす許容差。連続する 2 往復の増分がいずれも 1 往復後の値のこの割合以内なら、
    /// メモリの増加が止まったと判定します。
    private static let steadyStateTolerance = 0.02

    /// 増加が止まるまで往復を重ねます。上限まで重ねても止まらなければ、未判定として記録します。
    /// 走査が成立しなかった往復に出会った時点で打ち切り、定常化を主張せずに終了します。
    ///
    /// - Returns: 定常化したなら `true`
    @MainActor
    @discardableResult
    private func runUntilSteady() async -> Bool {
        for _ in 0..<Self.maximumRoundTrips {
            guard await performRoundTrip() else { break }
            if judgement == .steady { break }
        }
        print(
            "KS_PERF_VISITED_ITEMS_LAST_ROUND="
                + "\(visitedItemsInLastRoundTrip.count)/\(fixture.itemCount)"
        )
        print("KS_PERF_ROUND_TRIPS=\(completedRoundTrips)")
        print("KS_PERF_JUDGEMENT=\(judgement.rawValue)")
        return judgement == .steady
    }

    /// 先頭から末尾まで、そして末尾から先頭までを可視範囲の半分ずつ送り、通過した項目を記録します。
    /// 端への到達・各段階の位置確定・全項目の通過がすべて揃ったときだけ、この往復を成立とみなして
    /// `true` を返し、そのメモリ実測値を定常化の判定材料に加えます。
    @MainActor
    @discardableResult
    private func performRoundTrip() async -> Bool {
        isRunning = true
        defer { isRunning = false }

        guard let collectionView = await Self.awaitCollectionView() else {
            print("KS_PERF_ERROR=コレクションを取得できませんでした")
            judgement = .invalid
            return false
        }

        // 通過項目は往復ごとに数え直す。累積すると、一度でも全件に届いた後は
        // 後続の往復が不完全でも全件通過として見えてしまう。
        var visited: Set<Int> = []
        let forward = await traverse(collectionView, direction: 1, visited: &visited)
        let backward = await traverse(collectionView, direction: -1, visited: &visited)
        visitedItemsInLastRoundTrip = visited

        completedRoundTrips += 1

        guard let footprint = Self.physicalFootprint() else {
            print("KS_PERF_ERROR=phys_footprint を取得できませんでした")
            judgement = .invalid
            return false
        }
        let text = "\(footprint) bytes"
        memoryAfterLastRoundTrip = text
        print(
            "KS_PERF_MEMORY_ROUND_\(completedRoundTrips)=\(text) "
                + "visited=\(visited.count)/\(fixture.itemCount)"
        )

        let reachedBothEnds = forward.reachedEnd && backward.reachedEnd
        let settledEveryStep = forward.settled && backward.settled
        let coveredEveryItem = visited.count == fixture.itemCount
        guard reachedBothEnds, settledEveryStep, coveredEveryItem else {
            print(
                "KS_PERF_ROUND_TRIP_INVALID=\(completedRoundTrips) "
                    + "reachedBothEnds=\(reachedBothEnds) settledEveryStep=\(settledEveryStep) "
                    + "visited=\(visited.count)/\(fixture.itemCount)"
            )
            judgement = .invalid
            return false
        }
        footprints.append(footprint)
        judgement = Self.hasSteadied(footprints) ? .steady : .undetermined
        return true
    }

    /// 指定方向へ端まで送ります。1 段階ごとに到達を待ち、その時点の可視項目を記録します。
    /// 端まで送り切れたか (`reachedEnd`)、全段階で位置の確定を待てたか (`settled`) を返します。
    /// 段数の上限で打ち切った場合は端へ到達していないため `reachedEnd` は `false` になります。
    @MainActor
    private func traverse(
        _ collectionView: UICollectionView,
        direction: CGFloat,
        visited: inout Set<Int>
    ) async -> (reachedEnd: Bool, settled: Bool) {
        let step = max(1, collectionView.bounds.height * Self.traversalStepRatio) * direction
        var steps = 0
        var settledEveryStep = true
        while steps < Self.maximumStepsPerDirection {
            Self.record(collectionView, into: &visited)

            let limits = Self.offsetLimits(of: collectionView)
            let current = collectionView.contentOffset.y
            let target = min(max(current + step, limits.lowerBound), limits.upperBound)
            // 端に着いたら送る先が無くなる。
            if abs(target - current) < 1 {
                Self.record(collectionView, into: &visited)
                return (reachedEnd: true, settled: settledEveryStep)
            }

            collectionView.setContentOffset(
                CGPoint(x: collectionView.contentOffset.x, y: target),
                animated: false
            )
            if await settle(collectionView, target: target) == false {
                settledEveryStep = false
            }

            steps += 1
            // 数段階ごとに実行機会を譲る。譲らないと UIKit がセルを手放す機会を持てず、
            // 走査した件数に比例してセルが生き残ってしまう。
            if steps.isMultiple(of: 8) {
                try? await Task.sleep(for: .milliseconds(1))
            }
        }
        Self.record(collectionView, into: &visited)
        return (reachedEnd: false, settled: settledEveryStep)
    }

    /// 目的の位置に到達し、その位置のセルが載るまで待ちます。固定時間ではなく到達そのものを条件にします。
    @MainActor
    private func settle(_ collectionView: UICollectionView, target: CGFloat) async -> Bool {
        let deadline = ContinuousClock.now + Self.settleTimeout
        while ContinuousClock.now < deadline {
            collectionView.layoutIfNeeded()
            let reachedTarget = abs(collectionView.contentOffset.y - target) < 1
            if reachedTarget, !collectionView.indexPathsForVisibleItems.isEmpty {
                return true
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return false
    }

    /// 可視項目を「全体の順番」(先頭の項目を 0 とする通し番号) で記録します。
    /// コレクションは内部で項目を複数のセクションに分けて載せることがあり、`indexPath.item` は
    /// セクションごとに 0 から始まります。item だけで数えると別のセクションの項目と重なり、
    /// 全件を通過しても件数が足りないまま (かつ重複して) 数えられます。
    /// 変換は本体の `KsItemOffsetLookup` を使い、通過記録とエンジン側の数え方を 1 つの実装に揃えます。
    @MainActor
    private static func record(_ collectionView: UICollectionView, into visited: inout Set<Int>) {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let offset = KsItemOffsetLookup.itemOffset(of: indexPath, in: collectionView) else {
                continue
            }
            visited.insert(offset)
        }
    }

    /// 送れる範囲です。自己サイズによりコンテンツの高さは走査中に確定していくため、段階ごとに取り直します。
    @MainActor
    private static func offsetLimits(of collectionView: UICollectionView) -> ClosedRange<CGFloat> {
        let inset = collectionView.adjustedContentInset
        let lowerBound = -inset.top
        let upperBound = max(
            lowerBound,
            collectionView.contentSize.height - collectionView.bounds.height + inset.bottom
        )
        return lowerBound...upperBound
    }

    @MainActor
    private static func awaitCollectionView() async -> UICollectionView? {
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if let candidate = collectionView(),
               candidate.bounds.height > 0,
               !candidate.indexPathsForVisibleItems.isEmpty {
                return candidate
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }

    /// 画面に載っているコレクションを探します。走査の刻みは可視範囲の高さから決め、通過は可視セルで数えるため、
    /// SwiftUI 側からは読めない `contentOffset` と可視セルを UIKit のビュー階層から取ります。
    @MainActor
    private static func collectionView() -> UICollectionView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let found = firstCollectionView(in: window) {
                    return found
                }
            }
        }
        return nil
    }

    @MainActor
    private static func firstCollectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView {
            return collectionView
        }
        for subview in view.subviews {
            if let found = firstCollectionView(in: subview) {
                return found
            }
        }
        return nil
    }

    /// 直近 2 往復の増分がいずれも 1 往復後の値の許容差以内なら、増加が止まったとみなします。
    private static func hasSteadied(_ footprints: [UInt64]) -> Bool {
        guard footprints.count >= 3, let base = footprints.first else { return false }
        let allowance = Double(base) * steadyStateTolerance
        let recent = Array(footprints.suffix(3))
        let increments = zip(recent.dropFirst(), recent).map { Double($0.0) - Double($0.1) }
        return increments.allSatisfy { $0 <= allowance }
    }

    private static func physicalFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }
}
