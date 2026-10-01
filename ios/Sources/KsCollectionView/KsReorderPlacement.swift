// 並べ替えで項目を置く先。行き先と、行き先のグループの配列の中での並び順の組。
// 行き先のグループの値は、並び順から `KsReorderPlanner` が引く。
internal struct KsReorderPlacement: Hashable {
    let target: KsReorderTarget
    // 行き先のグループの、配列の先頭からの並び順。グループを宣言していない一覧では常に 0。
    let groupIndex: Int
}
