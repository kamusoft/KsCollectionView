import Nuke
@_spi(KsMeasurement) import KsCollectionView
import SwiftUI
import UIKit

/// ``ImagePrefetchMatchProbeView`` の駆動と集計。1 回の起動で 1 度だけ走らせます。
@MainActor
final class ImagePrefetchMatchProbe {
    private let prefetch: ImagePrefetchChoice
    private let ledger = ImageLoadingLedger.shared

    /// 送る段数。
    private let steps: Int

    /// 段ごとの待ち方。`nil` は `settle`。
    private let fixedWait: Duration?

    /// 連続送りの段の指定。`nil` なら通常の観測 (送り・戻し・メモリのみの消去) を走らせます。
    private let burstPlan: BurstPlan?

    /// 1 段の送り量 (可視範囲の高さに対する割合)。
    private static let stepRatio: CGFloat = 0.5

    /// セルの中身が組み立てられた時刻 (項目ごと、組み立てられた順)。観測を走らせている間だけ溜まります。
    private static var cellBuilds: [Int: [ContinuousClock.Instant]] = [:]

    /// 観測を走らせているか。立っていない間は ``noteCellBuilt(itemID:)`` は何もしません。
    private static var isObserving = false

    /// 「画像グリッド」のセルの中身が組み立てられたことを記録します。
    ///
    /// セルの中身 (`KsImage` を含む) が組み立てられた時刻と、先読みの完了の時刻を比べるために使います。
    /// 表示の要求が先読みの完了より後に出た項目について、要求を出すと決めた組み立てが完了の前か後かを
    /// 見分けます。観測していない実行では何もしません。
    static func noteCellBuilt(itemID: Int) {
        guard isObserving else { return }
        cellBuilds[itemID, default: []].append(.now)
    }

    init(prefetch: ImagePrefetchChoice) {
        self.prefetch = prefetch
        let arguments = ProcessInfo.processInfo.arguments
        steps = Self.value(after: "--probe-steps", in: arguments).flatMap(Int.init) ?? 20
        fixedWait = Self.value(after: "--probe-pace", in: arguments)
            .flatMap(Int.init)
            .map { Duration.milliseconds($0) }
        burstPlan = Self.value(after: "--probe-bursts", in: arguments)
            .flatMap(Int.init)
            .map { bursts in
                BurstPlan(
                    bursts: bursts,
                    steps: Self.value(after: "--probe-burst-steps", in: arguments).flatMap(Int.init) ?? 10,
                    ratio: CGFloat(
                        Self.value(after: "--probe-burst-ratio", in: arguments).flatMap(Double.init) ?? 1.0
                    )
                )
            }
    }

    func run() async {
        ledger.startRecording()
        Self.isObserving = true
        guard let collectionView = await Self.awaitCollectionView() else {
            print("KS_PROBE_ERROR=コレクションを取得できませんでした")
            return
        }
        let scale = collectionView.traitCollection.displayScale
        let columnPixels = Self.columnWidthPixels(of: collectionView, scale: scale)
        print(
            "KS_PROBE_CONFIG prefetch=\(prefetch) steps=\(steps) "
                + "pace=\(fixedWait.map { "\($0)" } ?? "settle") scale=\(scale) "
                + "columnWidthPx=\(columnPixels)"
        )

        // 初回表示が落ち着くまで待ってから基準点を切る。
        await waitUntilQuiet(quiet: .seconds(3), timeout: .seconds(60))
        let initiallyVisible = Self.visibleItemIDs(in: collectionView)

        // 連続送りの段を要求されたときは、通常の観測の代わりにそれだけを走らせる。
        if let burstPlan {
            await runBursts(collectionView, plan: burstPlan)
            print("KS_PROBE_DONE")
            return
        }

        // 1. 送り
        ImageLoadingSlotCounter.beginSession()
        let forwardStart = ContinuousClock.now
        var shown = initiallyVisible
        var appeared: [Int] = []
        var appearedStep: [Int: Int] = [:]
        var scrollTimes: [ContinuousClock.Instant] = []
        for step in 0..<steps {
            await pace()
            scrollTimes.append(.now)
            await scroll(collectionView, by: Self.stepRatio)
            for id in Self.visibleItemIDs(in: collectionView).sorted() where !shown.contains(id) {
                shown.insert(id)
                appeared.append(id)
                appearedStep[id] = step
            }
        }
        await waitUntilQuiet(quiet: .seconds(2), timeout: .seconds(60))
        reportForward(appeared: appeared, since: forwardStart, columnPixels: columnPixels)
        reportTimeline(appeared: appeared, appearedStep: appearedStep, scrollTimes: scrollTimes)

        // 2. 戻し
        ImageLoadingSlotCounter.beginSession()
        let returnStart = ContinuousClock.now
        var returned: Set<Int> = []
        for _ in 0..<steps {
            await pace()
            await scroll(collectionView, by: -Self.stepRatio)
            returned.formUnion(Self.visibleItemIDs(in: collectionView))
        }
        await waitUntilQuiet(quiet: .seconds(2), timeout: .seconds(60))
        reportPhase("return", items: returned, since: returnStart)

        // 3. メモリのみの消去の後、表示し続けるセルが読み込み中へ戻らないか
        ImageLoadingSlotCounter.beginSession()
        let clearStart = ContinuousClock.now
        let beforeClear = Self.visibleItemIDs(in: collectionView)
        KsImageCache.clear(.memory)
        await scroll(collectionView, by: Self.stepRatio)
        let middle = Self.visibleItemIDs(in: collectionView)
        await scroll(collectionView, by: -Self.stepRatio)
        await waitUntilQuiet(quiet: .seconds(2), timeout: .seconds(60))
        let afterClear = Self.visibleItemIDs(in: collectionView)
        let keptVisible = beforeClear.intersection(middle).intersection(afterClear)
        reportPhase("memory-clear-kept-visible", items: keptVisible, since: clearStart)
        reportPhase(
            "memory-clear-reappeared",
            items: afterClear.subtracting(keptVisible),
            since: clearStart
        )
        print("KS_PROBE_DONE")
    }

    // MARK: - 連続送り

    /// 連続送りの段の指定。起動引数 `--probe-bursts <回数>` で有効になり、
    /// `--probe-burst-steps <段数>` (既定 10) と `--probe-burst-ratio <割合>` (既定 1.0) で形を変えます。
    private struct BurstPlan {
        /// 連続送りを繰り返す回数。
        let bursts: Int

        /// 1 回の連続送りで続けて送る段数。
        let steps: Int

        /// 1 段の送り量 (可視範囲の高さに対する割合)。
        let ratio: CGFloat
    }

    /// 連続送りの後に止め、見える範囲に掛かる読み込み中の表示が無くなるまでの時間を測ります。
    ///
    /// 1 回ごとに、止めた時点で取得中の要求 (始まって、成功・取り消し・失敗のどれにもなっていないもの)
    /// を種別ごとに数え、送りの間と止めた後の要求の内訳とあわせて `KS_BURST` / `KS_BURST_TALLY` の行に
    /// 出します。回と回の間は 15 秒静止します。
    private func runBursts(_ collectionView: UICollectionView, plan: BurstPlan) async {
        // 止めた時点の取得中は観測の記録から、読み込み中は画面に出た読み込み中の印から数える。
        // どちらかが無いと待ちが 0 として出てしまうため、測らずに止める。
        guard ImageLoadingObservation.isRequested, ImageLoadingSlotCounter.isEnabled else {
            print("KS_PROBE_ERROR=連続送りには --observe-image-loading と --count-image-loading-slots が必要です")
            return
        }
        guard plan.bursts > 0 else { return }
        for burst in 1...plan.bursts {
            let burstStart = ContinuousClock.now
            for _ in 0..<plan.steps {
                await scroll(collectionView, by: plan.ratio)
            }
            let stop = ContinuousClock.now
            var openURLs: [String: Set<String>] = [:]
            for entry in ledger.snapshot() {
                switch entry.event {
                case "start":
                    openURLs[entry.kind, default: []].insert(entry.url)
                default:
                    openURLs[entry.kind, default: []].remove(entry.url)
                }
            }
            let visible = Self.visibleItemIDs(in: collectionView)
            let visibleURLs = Set(visible.map { DemoData.imageURL(for: $0).absoluteString })
            let openVisibleDisplay = openURLs[ImageRequestKind.display, default: []]
                .intersection(visibleURLs).count
            let placeholdersAtStop = Self.placeholdersOnScreen(in: collectionView)
            // 見える範囲の読み込み中が消えるまで、画面の更新の間隔ほどで確かめる (上限 30 秒)。
            let deadline = stop + .seconds(30)
            var settled: ContinuousClock.Instant?
            while ContinuousClock.now < deadline {
                if Self.placeholdersOnScreen(in: collectionView) == 0 {
                    settled = .now
                    break
                }
                try? await Task.sleep(for: .milliseconds(8))
            }
            let waitMs = settled.map { Int(($0 - stop) / .milliseconds(1)) } ?? -1
            // 区間の要求の内訳。送りの開始から止めた時点まで (during) と、止めた後 (after) に分ける。
            var tally: [String: Int] = [:]
            for entry in ledger.snapshot() where entry.time >= burstStart {
                let phase = entry.time < stop ? "during" : "after"
                tally["\(phase)/\(entry.kind)/\(entry.event)/\(entry.source ?? "-")", default: 0] += 1
            }
            print(
                "KS_BURST b=\(burst) steps=\(plan.steps) ratio=\(plan.ratio) "
                    + "burstMs=\(Int((stop - burstStart) / .milliseconds(1))) waitMs=\(waitMs) "
                    + "visible=\(visible.count) placeholdersAtStop=\(placeholdersAtStop) "
                    + "openAtStop=\(openURLs.mapValues(\.count).filter { $0.value > 0 }.sorted { $0.key < $1.key }) "
                    + "openVisibleDisplay=\(openVisibleDisplay)"
            )
            print("KS_BURST_TALLY b=\(burst) \(tally.sorted { $0.key < $1.key })")
            try? await Task.sleep(for: .seconds(15))
        }
    }

    /// 見える範囲に掛かっている読み込み中の表示の数。
    ///
    /// 判定は画面に出た読み込み中の計数と同じもの (``ImageLoadingSlotShownProbeView/isOnScreen``) を使います。
    static func placeholdersOnScreen(in view: UIView) -> Int {
        var count = 0
        if let probe = view as? ImageLoadingSlotShownProbeView, probe.isOnScreen {
            count += 1
        }
        for subview in view.subviews {
            count += placeholdersOnScreen(in: subview)
        }
        return count
    }

    // MARK: - 集計

    /// 送りで新しく現れた項目を、先読みの完了と表示の要求の前後で分けて数えます。
    private func reportForward(appeared: [Int], since start: ContinuousClock.Instant, columnPixels: Int) {
        let entries = ledger.snapshot().filter { $0.time >= start }
        let prefetchKinds: Set<String> = [
            ImageRequestKind.widthPrefetch, ImageRequestKind.prefetchOrLoaderDisplay,
        ]
        var firstPrefetchSuccess: [String: ContinuousClock.Instant] = [:]
        var firstDisplayStart: [String: ContinuousClock.Instant] = [:]
        // 基準点より前に先読みが終わっていた項目も「先読み済み」として扱うため、全期間から探す。
        for entry in ledger.snapshot() {
            if entry.event == "success", prefetchKinds.contains(entry.kind),
               firstPrefetchSuccess[entry.url] == nil {
                firstPrefetchSuccess[entry.url] = entry.time
            }
        }
        for entry in entries where entry.event == "start" && entry.kind == ImageRequestKind.display {
            if firstDisplayStart[entry.url] == nil {
                firstDisplayStart[entry.url] = entry.time
            }
        }

        // matched: 先読みが終わっていて表示の要求が無い (引き当てた)
        // late: 表示の要求が先読みの完了より前 (先読みが間に合わなかった)
        // builtBefore: 先読みの完了より後に表示の要求が出たが、要求を出すと決めたセルの組み立ては
        //   完了より前 (組み立ての時点ではメモリに無かった)
        // violation: 先読みの完了より後に組み立てられたのに表示の要求が出た (引き当てに失敗した)
        // unprefetched: 先読みの完了が無いまま表示の要求が出た (ディスクまで・なしを含む)
        var matched: [Int] = []
        var late = 0
        var builtBefore = 0
        var violations: [Int] = []
        var unprefetched = 0
        var noEvent = 0
        for id in appeared {
            let url = DemoData.imageURL(for: id).absoluteString
            let prefetched = firstPrefetchSuccess[url]
            let display = firstDisplayStart[url]
            switch (prefetched, display) {
            case let (.some(done), .some(requested)):
                let lastBuild = Self.cellBuilds[id, default: []].last { $0 <= requested }
                if requested < done {
                    late += 1
                } else if let lastBuild, lastBuild < done {
                    builtBefore += 1
                } else {
                    violations.append(id)
                }
            case (.some, .none):
                matched.append(id)
            case (.none, .some):
                unprefetched += 1
            case (.none, .none):
                noEvent += 1
            }
        }
        // 読み込み中の数は 2 種類ある。`matchedSized` / `matchedUnsized` は組み立ての回数で、画面に出る前に
        // 組み立てられ、画面に出ないまま画像に替わった読み込み中も含む。「読み込み中を経由したか」の判定は
        // 実際に画面に出た回数 `matchedShown` で行う。
        let matchedSized = matched.reduce(0) { $0 + ImageLoadingSlotCounter.delta(itemID: $1).sized }
        let matchedUnsized = matched.reduce(0) {
            $0 + ImageLoadingSlotCounter.delta(itemID: $1).unsized
        }
        let matchedShown = matched.reduce(0) { $0 + ImageLoadingSlotCounter.delta(itemID: $1).shown }
        print(
            "KS_PROBE_FORWARD appeared=\(appeared.count) matched=\(matched.count) "
                + "late=\(late) builtBefore=\(builtBefore) violation=\(violations.count) "
                + "unprefetched=\(unprefetched) "
                + "noEvent=\(noEvent) matchedSized=\(matchedSized) matchedUnsized=\(matchedUnsized) "
                + "matchedShown=\(matchedShown)"
        )
        var tally: [String: Int] = [:]
        for entry in ledger.snapshot() {
            tally["\(entry.kind)/\(entry.event)/\(entry.source ?? "-")", default: 0] += 1
        }
        print("KS_PROBE_LEDGER \(tally.sorted { $0.key < $1.key })")
        if !violations.isEmpty {
            print("KS_PROBE_VIOLATION items=\(violations.prefix(20))")
        }
        reportPixels(of: matched, columnPixels: columnPixels)
        reportPhase("forward", items: Set(appeared), since: start)
    }

    /// 送りで新しく現れた項目ごとに、先読みの開始・完了と表示の要求の開始が何段目の送りの間に
    /// 起きたかを出します。段の番号は、その段の送りを始めた時刻から次の段の送りを始めるまでを指し、
    /// `-1` は最初の送りより前、`-` は起きていないことを表します。
    private func reportTimeline(
        appeared: [Int],
        appearedStep: [Int: Int],
        scrollTimes: [ContinuousClock.Instant]
    ) {
        func step(of time: ContinuousClock.Instant?) -> String {
            guard let time else { return "-" }
            return "\((scrollTimes.lastIndex { $0 <= time }) ?? -1)"
        }
        let entries = ledger.snapshot()
        let prefetchKinds: Set<String> = [
            ImageRequestKind.widthPrefetch, ImageRequestKind.prefetchOrLoaderDisplay,
        ]
        for id in appeared {
            let url = DemoData.imageURL(for: id).absoluteString
            let own = entries.filter { $0.url == url }
            let prefetchStart = own.first { prefetchKinds.contains($0.kind) && $0.event == "start" }
            let prefetchDone = own.first { prefetchKinds.contains($0.kind) && $0.event == "success" }
            let displayStart = own.first { $0.kind == ImageRequestKind.display && $0.event == "start" }
            let displayDone = own.first { $0.kind == ImageRequestKind.display && $0.event == "success" }
            // 表示の要求より前の最後の組み立てが、先読みの完了より前かどうか。
            let lastBuild = Self.cellBuilds[id, default: []].last { build in
                displayStart.map { build <= $0.time } ?? true
            }
            let builtBeforePrefetchDone: String
            if let lastBuild, let done = prefetchDone?.time {
                builtBeforePrefetchDone = lastBuild < done ? "yes" : "no"
            } else {
                builtBeforePrefetchDone = "-"
            }
            print(
                "KS_PROBE_ITEM id=\(id) appear=\(appearedStep[id].map(String.init) ?? "-") "
                    + "prefetchStart=\(step(of: prefetchStart?.time)) "
                    + "prefetchDone=\(step(of: prefetchDone?.time))/\(prefetchDone?.source ?? "-") "
                    + "displayStart=\(step(of: displayStart?.time)) "
                    + "displayDone=\(step(of: displayDone?.time))/\(displayDone?.source ?? "-") "
                    + "builds=\(Self.cellBuilds[id, default: []].count) "
                    + "lastBuild=\(step(of: lastBuild)) builtBeforePrefetchDone=\(builtBeforePrefetchDone) "
                    + "sized=\(ImageLoadingSlotCounter.delta(itemID: id).sized) "
                    + "shown=\(ImageLoadingSlotCounter.delta(itemID: id).shown)"
            )
        }
    }

    /// 引き当てた項目について、メモリにある先読みの項目の寸法を数えます。
    private func reportPixels(of items: [Int], columnPixels: Int) {
        let cache = ImagePipeline.shared.cache
        var original: [String: Int] = [:]
        var thumbnail: [String: Int] = [:]
        var originalAbsent = 0
        for id in items {
            let url = DemoData.imageURL(for: id)
            if let container = cache[ImageRequest(url: url)] {
                original[Self.pixelText(container.image), default: 0] += 1
            } else {
                originalAbsent += 1
            }
            var request = ImageRequest(url: url)
            request.thumbnail = ImageRequest.ThumbnailOptions(
                size: CGSize(width: columnPixels, height: columnPixels),
                unit: .pixels,
                contentMode: .aspectFill
            )
            if let container = cache[request] {
                thumbnail[Self.pixelText(container.image), default: 0] += 1
            }
        }
        print(
            "KS_PROBE_PIXELS items=\(items.count) original=\(original.sorted { $0.key < $1.key }) "
                + "originalAbsent=\(originalAbsent) "
                + "column\(columnPixels)=\(thumbnail.sorted { $0.key < $1.key })"
        )
    }

    /// 段の中で出た表示の要求と読み込み中の表示を、取得元ごとの待ち時間とともに数えます。
    private func reportPhase(_ phase: String, items: Set<Int>, since start: ContinuousClock.Instant) {
        let urls = Set(items.map { DemoData.imageURL(for: $0).absoluteString })
        let entries = ledger.snapshot().filter {
            $0.time >= start && $0.kind == ImageRequestKind.display && urls.contains($0.url)
        }
        var starts: [String: ContinuousClock.Instant] = [:]
        var waits: [String: [Double]] = [:]
        var cancels = 0
        for entry in entries {
            switch entry.event {
            case "start":
                if starts[entry.url] == nil { starts[entry.url] = entry.time }
            case "success":
                guard let begun = starts[entry.url] else { continue }
                let seconds = (entry.time - begun) / .milliseconds(1)
                waits[entry.source ?? "unknown", default: []].append(seconds)
            case "cancel":
                cancels += 1
            default:
                break
            }
        }
        let sized = items.reduce(0) { $0 + ImageLoadingSlotCounter.delta(itemID: $1).sized }
        let unsized = items.reduce(0) { $0 + ImageLoadingSlotCounter.delta(itemID: $1).unsized }
        let shown = items.reduce(0) { $0 + ImageLoadingSlotCounter.delta(itemID: $1).shown }
        let displayStarts = entries.filter { $0.event == "start" }.count
        let waitText = waits.keys.sorted().map { source in
            let values = waits[source, default: []].sorted()
            return "\(source):n=\(values.count),p50=\(Self.percentile(values, 0.5)),"
                + "p90=\(Self.percentile(values, 0.9)),max=\(Int(values.last ?? 0))"
        }.joined(separator: " ")
        print(
            "KS_PROBE_PHASE phase=\(phase) items=\(items.count) displayStarts=\(displayStarts) "
                + "displayCancels=\(cancels) sized=\(sized) unsized=\(unsized) shown=\(shown) "
                + "waitMs=[\(waitText)]"
        )
    }

    // MARK: - 駆動

    /// 段ごとの待ち。
    private func pace() async {
        if let fixedWait {
            try? await Task.sleep(for: fixedWait)
            return
        }
        switch prefetch.destination {
        case .memory:
            await waitUntilPrefetchSettles(timeout: .seconds(20))
        case .disk, .none:
            // ディスクまでの先読みは割り込み処理へ通知が来ないため、終わりを観測できない。
            try? await Task.sleep(for: .seconds(3))
        }
    }

    /// 取得中の先読み (始まって、成功・取り消し・失敗のどれにもなっていないもの) が無くなるまで待ちます。
    private func waitUntilPrefetchSettles(timeout: Duration) async {
        let deadline = ContinuousClock.now + timeout
        let kinds: Set<String> = [ImageRequestKind.widthPrefetch, ImageRequestKind.prefetchOrLoaderDisplay]
        while ContinuousClock.now < deadline {
            var open = 0
            for entry in ledger.snapshot() where kinds.contains(entry.kind) {
                open += entry.event == "start" ? 1 : -1
            }
            if open <= 0 {
                try? await Task.sleep(for: .milliseconds(300))
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        print("KS_PROBE_WARNING=先読みが \(timeout) 以内に終わりませんでした")
    }

    /// 節目の記録が一定時間増えなくなるまで待ちます。
    private func waitUntilQuiet(quiet: Duration, timeout: Duration) async {
        let deadline = ContinuousClock.now + timeout
        var lastCount = ledger.snapshot().count
        var lastChange = ContinuousClock.now
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            let count = ledger.snapshot().count
            if count != lastCount {
                lastCount = count
                lastChange = .now
            } else if ContinuousClock.now - lastChange >= quiet {
                return
            }
        }
        print("KS_PROBE_WARNING=節目の記録が \(timeout) 以内に静まりませんでした")
    }

    /// 可視範囲の高さに対する割合だけ送り、目的の位置に着いてセルが載るまで待ちます。
    private func scroll(_ collectionView: UICollectionView, by ratio: CGFloat) async {
        let inset = collectionView.adjustedContentInset
        let lower = -inset.top
        let upper = max(lower, collectionView.contentSize.height - collectionView.bounds.height + inset.bottom)
        let target = min(max(collectionView.contentOffset.y + collectionView.bounds.height * ratio, lower), upper)
        // UIKit はアニメーションの無い位置の書き換えでは先読みの通知を出さないため、アニメーションで送る。
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: target), animated: true)
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            collectionView.layoutIfNeeded()
            if abs(collectionView.contentOffset.y - target) < 1,
               !collectionView.indexPathsForVisibleItems.isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    // MARK: - 補助

    private static func visibleItemIDs(in collectionView: UICollectionView) -> Set<Int> {
        let bounds = collectionView.bounds
        return Set(collectionView.indexPathsForVisibleItems.compactMap { indexPath in
            // 端がわずかに掛かっただけのセルは数えない (画面に出たとは言えないため)。
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame,
                  frame.intersection(bounds).height >= frame.height / 2,
                  let offset = KsItemOffsetLookup.itemOffset(of: indexPath, in: collectionView)
            else { return nil }
            return ImageGridFixture.items[offset].id
        })
    }

    /// 列幅の先読みが使う幅 (ピクセル)。本体と同じ式 (外周の余白と列間隔を除いて列数で割る) で求めます。
    private static func columnWidthPixels(of collectionView: UICollectionView, scale: CGFloat) -> Int {
        let columns = Double(ImageGridMetrics.columnCount)
        let usable = Double(collectionView.bounds.width) - ImageGridMetrics.spacing * 2
            - ImageGridMetrics.spacing * (columns - 1)
        return Int((usable / columns * Double(scale)).rounded())
    }

    private static func pixelText(_ image: UIImage) -> String {
        "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
    }

    private static func percentile(_ sorted: [Double], _ ratio: Double) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * ratio).rounded()))
        return Int(sorted[index])
    }

    private static func value(after name: String, in arguments: [String]) -> String? {
        arguments.drop { $0 != name }.dropFirst().first
    }

    private static func awaitCollectionView() async -> UICollectionView? {
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if let candidate = firstCollectionView(),
               candidate.bounds.height > 0,
               !candidate.indexPathsForVisibleItems.isEmpty {
                return candidate
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }

    private static func firstCollectionView() -> UICollectionView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let found = firstCollectionView(in: window) { return found }
            }
        }
        return nil
    }

    private static func firstCollectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView { return collectionView }
        for subview in view.subviews {
            if let found = firstCollectionView(in: subview) { return found }
        }
        return nil
    }
}
