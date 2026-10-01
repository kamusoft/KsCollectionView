// 読み上げの移動操作 1 つ (core/ADR-0032)。
internal struct KsReorderAccessibilityAction: Identifiable {
    // 操作の向き。
    enum Direction: Hashable {
        case previous
        case next
    }

    let direction: Direction
    // 読み上げる操作の名前 (利用者が渡した文言)。
    let name: String
    // 操作を実行する。
    let perform: @MainActor () -> Void

    var id: Direction { direction }
}
