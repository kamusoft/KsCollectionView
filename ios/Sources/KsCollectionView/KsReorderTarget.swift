// 並べ替えの行き先を、項目の識別子で表したもの。利用者へ渡す知らせ (`KsReorderDestination`) に
// 読み替える前の、UI から切り離した形。
internal enum KsReorderTarget: Hashable {
    // この識別子の項目の前。
    case before(AnyHashable)
    // グループの末尾 (グループを宣言していなければ一覧の末尾)。
    case end
}
