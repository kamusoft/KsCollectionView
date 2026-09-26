/// 「グループ化」画面の 2 つの操作で、配列をデータ側で組み替える規則。
///
/// どちらも新しい配列を作って返すだけで、表示側に並べ替えを命じない。同じグループの項目は
/// 操作の後も続いて並ぶ (離れた位置に同じグループが現れる配列は作らない)。
/// Android Sample の同名の定義と同じ規則にする。
enum GroupingDemoEdits {
    /// グループの並び順を反転する。グループの中の項目の順は変えない。
    static func reversingGroups(_ items: [GroupingDemoItem]) -> [GroupingDemoItem] {
        runs(of: items).reversed().flatMap { items[$0] }
    }

    /// 通し番号 `offset` の項目を、隣のグループへ移す。
    ///
    /// 項目がグループの末尾に近ければ (末尾までの件数が先頭までの件数以下なら) 次のグループの先頭へ、
    /// 先頭に近ければ前のグループの末尾へ移す。近い側に隣のグループが無ければ反対側へ移す。
    /// 移した項目のグループの番号は移り先のグループのものに変わる。グループが 1 つしか無いときは
    /// 何もしない。
    ///
    /// - Parameters:
    ///   - offset: 移す項目の通し番号 (先頭を 0 とする)
    ///   - items: 今の配列
    /// - Returns: 組み替えた配列。移せないときは `items` のまま
    static func movingItem(at offset: Int, in items: [GroupingDemoItem]) -> [GroupingDemoItem] {
        guard items.indices.contains(offset),
              let run = runs(of: items).first(where: { $0.contains(offset) })
        else { return items }

        let hasNext = run.upperBound < items.count
        let hasPrevious = run.lowerBound > 0
        let prefersNext = offset - run.lowerBound >= run.upperBound - 1 - offset

        var result = items
        var moved = result.remove(at: offset)
        if hasNext && (prefersNext || !hasPrevious) {
            // 取り除いた分だけ次のグループの先頭が 1 つ前へ詰まる。
            moved.group = items[run.upperBound].group
            result.insert(moved, at: run.upperBound - 1)
        } else if hasPrevious {
            // 前のグループの末尾のすぐ後ろ (= 今のグループの先頭の位置) に入れる。
            moved.group = items[run.lowerBound - 1].group
            result.insert(moved, at: run.lowerBound)
        } else {
            return items
        }
        return result
    }

    /// 同じグループが続く範囲を、配列の順に返す。
    private static func runs(of items: [GroupingDemoItem]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start = 0
        for index in items.indices.dropFirst() where items[index].group != items[index - 1].group {
            runs.append(start..<index)
            start = index
        }
        if !items.isEmpty {
            runs.append(start..<items.count)
        }
        return runs
    }
}
