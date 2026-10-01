// 並べ替えの行き先を、表示から切り離して求める (core/ADR-0028、core/ADR-0029)。
//
// 配列の並び (識別子) とグループの区切りを受け取り、動かした項目を「あるグループの中の、動かした項目を
// 除いた何番目」に置いたときの行き先を求める。行き先は、置いた位置の後ろに同じグループの項目があれば
// その項目の前、無ければそのグループの末尾とする。グループの境目は、前のグループの末尾と次のグループの
// 先頭のどちらに置いたかを、置いた先のグループで区別する。
//
// 読み上げの移動操作の「1 つ前 / 1 つ後ろ」も同じ規則で求める。グループの先頭の項目の 1 つ前は前の
// グループの末尾、グループの最後の項目の 1 つ後ろは次のグループの先頭とする (core/ADR-0032)。
internal struct KsReorderPlanner {
    // 配列の並び (元の並び)。
    let identifiers: [AnyHashable]
    // グループ。配列の順に並び、範囲は配列全体を隙間なく覆う。グループを宣言していない一覧では、
    // 配列全体を値なしの 1 つのグループとして渡す。
    let groups: [KsReorderGroupSpan]

    // 配列の位置の項目が属するグループの並び順。範囲外なら nil。グループは配列の順に並ぶため二分探索で引く。
    func groupIndex(containing index: Int) -> Int? {
        var low = 0
        var high = groups.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let range = groups[middle].itemRange
            if index < range.lowerBound {
                high = middle - 1
            } else if index >= range.upperBound {
                low = middle + 1
            } else {
                return middle
            }
        }
        return nil
    }

    // 動かした項目 (配列の位置 `source`) を、グループ `groupIndex` の中の、動かした項目を除いた
    // `position` 番目に置いたときの行き先。`position` がグループの件数以上なら末尾。
    func placement(moving source: Int, toGroup groupIndex: Int, at position: Int) -> KsReorderPlacement {
        let range = groups[groupIndex].itemRange
        let position = max(0, position)
        // 動かした項目を除いた並びの番号を、配列の位置へ戻す。
        let offset = range.contains(source) && position >= source - range.lowerBound ? 1 : 0
        let index = range.lowerBound + position + offset
        guard index < range.upperBound else {
            return KsReorderPlacement(target: .end, groupIndex: groupIndex)
        }
        return KsReorderPlacement(target: .before(identifiers[index]), groupIndex: groupIndex)
    }

    // 動かす前の位置の行き先。求めた行き先がこれと同じなら、元の位置に置いたことになる。
    func originalPlacement(of source: Int) -> KsReorderPlacement? {
        guard let groupIndex = groupIndex(containing: source) else { return nil }
        let range = groups[groupIndex].itemRange
        return placement(moving: source, toGroup: groupIndex, at: source - range.lowerBound)
    }

    // 1 つ前へ動かすときの行き先。一覧の先頭の項目では nil。
    func previousPlacement(of source: Int) -> KsReorderPlacement? {
        guard let groupIndex = groupIndex(containing: source) else { return nil }
        let offset = source - groups[groupIndex].itemRange.lowerBound
        if offset > 0 {
            return placement(moving: source, toGroup: groupIndex, at: offset - 1)
        }
        guard groupIndex > 0 else { return nil }
        return KsReorderPlacement(target: .end, groupIndex: groupIndex - 1)
    }

    // 1 つ後ろへ動かすときの行き先。一覧の最後の項目では nil。
    func nextPlacement(of source: Int) -> KsReorderPlacement? {
        guard let groupIndex = groupIndex(containing: source) else { return nil }
        let range = groups[groupIndex].itemRange
        let offset = source - range.lowerBound
        if offset < range.count - 1 {
            return placement(moving: source, toGroup: groupIndex, at: offset + 1)
        }
        guard groupIndex < groups.count - 1 else { return nil }
        return placement(moving: source, toGroup: groupIndex + 1, at: 0)
    }

    // 行き先に置いた後の配列の並び。動かした項目を取り除き、行き先の項目の前 (末尾ならグループの
    // 最後の項目の後ろ) へ入れる。
    func reorderedIdentifiers(moving source: Int, to placement: KsReorderPlacement) -> [AnyHashable] {
        let movedID = identifiers[source]
        var result = identifiers
        result.remove(at: source)
        let insertion: Int
        switch placement.target {
        case let .before(id):
            insertion = result.firstIndex(of: id) ?? result.count
        case .end:
            // グループの最後の項目の後ろ。動かした項目を取り除いた分だけ、元の範囲の上端をずらす。
            let upper = groups[placement.groupIndex].itemRange.upperBound
            insertion = upper > source ? upper - 1 : upper
        }
        result.insert(movedID, at: min(max(0, insertion), result.count))
        return result
    }
}
