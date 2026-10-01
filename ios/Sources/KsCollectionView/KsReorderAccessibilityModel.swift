import Combine

// セルの中身に出す読み上げの移動操作。セルの再利用をまたいでセルが持ち、表示する項目・並び・スイッチ・
// 判定が変わるたびに一覧が操作を付け直す。中身の SwiftUI の要素に付けるため、観測できる形で持つ。
@MainActor
internal final class KsReorderAccessibilityModel: ObservableObject {
    @Published private(set) var actions: [KsReorderAccessibilityAction] = [] {
        didSet {
            #if DEBUG
            actionsChangeCount += 1
            #endif
        }
    }
    #if DEBUG
    // 操作を入れ替えた回数。中身を作った後に操作が変わっていないこと (作ったばかりの中身が描き直されないこと) を
    // 観測するために読む。計測のための仕組みが計測対象に混ざらないよう、debug ビルドにだけ載せる。
    private(set) var actionsChangeCount = 0
    #endif
    // 最後に操作を求めたときの世代と項目。同じなら求め直さない。
    private var key: (generation: Int, identifier: AnyHashable)?

    // 世代と項目が前と同じなら false を返し、何もしない。
    func needsUpdate(generation: Int, identifier: AnyHashable) -> Bool {
        guard let key, key.generation == generation, key.identifier == identifier else { return true }
        return false
    }

    func update(_ actions: [KsReorderAccessibilityAction], generation: Int, identifier: AnyHashable) {
        key = (generation, identifier)
        // 実行する処理は項目の識別子と向きだけで決まり、実行するときに行き先を求め直す。向きと名前が
        // 同じなら出ている操作は変わらないため、中身を描き直させない。
        let names = { (list: [KsReorderAccessibilityAction]) in list.map { "\($0.direction):\($0.name)" } }
        if names(actions) != names(self.actions) {
            self.actions = actions
        }
    }

    // 操作を外す (再利用に入るセル・操作を出さない構成)。
    func clear() {
        key = nil
        if !actions.isEmpty {
            actions = []
        }
    }
}
