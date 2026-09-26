/// 「差分更新」画面の操作の対象の位置。配列全体での位置を指す。
enum DiffUpdatePosition: String, CaseIterable, Identifiable {
    case head = "先頭"
    case middle = "中ほど"
    case tail = "末尾"

    var id: Self { self }

    /// 挿入の位置。先頭は 0、中ほどは件数の半分 (切り捨て)、末尾は件数 (最後の項目の後ろ)。
    func insertionIndex(count: Int) -> Int {
        switch self {
        case .head: 0
        case .middle: count / 2
        case .tail: count
        }
    }

    /// 削除・更新・移動の対象の位置。先頭は 0、中ほどは件数の半分 (切り捨て)、末尾は件数 − 1。
    /// 空の配列では `nil`。
    func targetIndex(count: Int) -> Int? {
        guard count > 0 else { return nil }
        switch self {
        case .head: return 0
        case .middle: return count / 2
        case .tail: return count - 1
        }
    }
}
