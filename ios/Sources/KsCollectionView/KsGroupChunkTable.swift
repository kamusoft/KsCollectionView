/// 配列を利用者のグループと内部の塊へ区切った結果の表 (ios/ADR-0010)。
///
/// 配列を先頭から走査し、グループの値が等しい項目が続く範囲を 1 つのグループにする。各グループは
/// その先頭から塊の件数ごとに区切るため、1 つの塊が 2 つのグループにまたがることはなく、列数に
/// 満たない行は各グループの最終行にだけ現れる。グループを宣言しないときは配列全体を値なしの
/// 1 つのグループとして同じ規則で区切る。
///
/// snapshot と同時に作り、セクションの番号からグループの中での位置を引くために使う。
internal struct KsGroupChunkTable: Equatable {
    /// セクションの識別子。snapshot に載せる順。
    let sectionIDs: [KsSectionID]
    /// セクションごとの、グループの中での位置と件数。`sectionIDs` と同じ順。
    let chunks: [KsChunkInfo]
    /// セクションごとの、載せる項目の配列全体での位置の範囲。`sectionIDs` と同じ順。
    let sectionItemRanges: [Range<Int>]
    /// グループ。配列の順。
    let groups: [KsGroupInfo]
    /// 配列の離れた位置に再び現れたグループの値。最初に再び現れた順に 1 度ずつ並ぶ。
    let reappearingValues: [AnyHashable]

    /// まだ snapshot を組んでいない間に使う、項目の無い 1 つの塊だけの表。
    static var empty: KsGroupChunkTable {
        make(groupValues: nil, itemCount: 0, chunkSize: 1)
    }

    /// 表を作る。
    ///
    /// - Parameters:
    ///   - groupValues: 項目ごとのグループの値 (配列の順)。グループを宣言しないときは nil
    ///   - itemCount: 項目の数。`groupValues` があるときはその件数と一致させる
    ///   - chunkSize: 1 つの塊に載せる件数
    static func make(
        groupValues: [AnyHashable]?,
        itemCount: Int,
        chunkSize: Int
    ) -> KsGroupChunkTable {
        let size = max(1, chunkSize)
        let runs = makeRuns(groupValues: groupValues, itemCount: itemCount)

        var sectionIDs: [KsSectionID] = []
        var chunks: [KsChunkInfo] = []
        var sectionItemRanges: [Range<Int>] = []
        var groups: [KsGroupInfo] = []

        for (groupIndex, run) in runs.runs.enumerated() {
            let count = run.range.count
            // 項目が空のときも塊を 1 つ作る (ルートのヘッダー / フッターを載せるため)。
            let chunkCount = count > 0 ? (count + size - 1) / size : 1
            let firstSection = sectionIDs.count
            for chunkInGroup in 0..<chunkCount {
                let start = run.range.lowerBound + chunkInGroup * size
                let end = min(start + size, run.range.upperBound)
                sectionIDs.append(
                    KsSectionID(group: run.value, occurrence: run.occurrence, chunkInGroup: chunkInGroup)
                )
                chunks.append(
                    KsChunkInfo(
                        groupIndex: groupIndex,
                        chunkInGroup: chunkInGroup,
                        chunkCountInGroup: chunkCount,
                        itemCount: max(0, end - start),
                        isFirstGroup: groupIndex == 0,
                        isLastGroup: groupIndex == runs.runs.count - 1
                    )
                )
                sectionItemRanges.append(start..<max(start, end))
            }
            groups.append(
                KsGroupInfo(
                    value: run.value,
                    occurrence: run.occurrence,
                    sectionRange: firstSection..<sectionIDs.count,
                    itemRange: run.range
                )
            )
        }

        return KsGroupChunkTable(
            sectionIDs: sectionIDs,
            chunks: chunks,
            sectionItemRanges: sectionItemRanges,
            groups: groups,
            reappearingValues: runs.reappearingValues
        )
    }

    /// セクションの番号に対応する塊。範囲外なら nil。
    func chunk(at section: Int) -> KsChunkInfo? {
        chunks.indices.contains(section) ? chunks[section] : nil
    }

    /// セクションの番号の塊が属するグループ。範囲外なら nil。
    func group(containingSection section: Int) -> KsGroupInfo? {
        guard let chunk = chunk(at: section) else { return nil }
        return groups[chunk.groupIndex]
    }

    // 同じグループの値が続く範囲。
    private struct Run {
        let value: AnyHashable?
        let occurrence: Int
        let range: Range<Int>
    }

    private static func makeRuns(
        groupValues: [AnyHashable]?,
        itemCount: Int
    ) -> (runs: [Run], reappearingValues: [AnyHashable]) {
        guard let groupValues, !groupValues.isEmpty else {
            return ([Run(value: nil, occurrence: 0, range: 0..<max(0, itemCount))], [])
        }

        var runs: [Run] = []
        var occurrences: [AnyHashable: Int] = [:]
        var reappearingValues: [AnyHashable] = []
        var start = 0
        for index in 1...groupValues.count {
            // 末尾に達したか、値が変わったところで 1 つのグループを閉じる。
            guard index == groupValues.count || groupValues[index] != groupValues[start] else { continue }
            let value = groupValues[start]
            let occurrence = occurrences[value, default: 0]
            if occurrence == 1 {
                reappearingValues.append(value)
            }
            occurrences[value] = occurrence + 1
            runs.append(Run(value: value, occurrence: occurrence, range: start..<index))
            start = index
        }
        return (runs, reappearingValues)
    }
}
