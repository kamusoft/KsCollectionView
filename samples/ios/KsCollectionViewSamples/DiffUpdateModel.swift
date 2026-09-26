/// 「差分更新」画面の配列と、操作ごとの組み替えの規則。
///
/// 操作は新しい配列を作って置き換えるだけで、表示側に並べ替えを命じない。Android Sample の同名の
/// 定義と同じ規則にし、同じ初期状態から同じ順で同じ操作をすれば同じ並びになる。
///
/// - 初期の配列: ID 1〜20 を昇順に。グループは 5 件ずつ 0〜3 (見出しは A〜D)
/// - 挿入: 新しい ID (21 から 1 ずつ増える) の項目を ``DiffUpdatePosition/insertionIndex(count:)`` に
///   入れる。グループはその位置の項目 (末尾なら最後の項目、空なら 0) と同じ
/// - 削除: ``DiffUpdatePosition/targetIndex(count:)`` の項目を取り除く
/// - 更新: 同じ位置の項目の「更新」の回数を 1 増やす (ID は変えない)
/// - 移動: 同じ位置の項目を取り除き、グループありなら次のグループ (グループの並びで次。最後の
///   グループなら最初のグループ) の先頭へ、そのグループの番号に変えて入れる。グループが 1 つしか
///   無ければ何もしない。グループなしなら、元の位置 i と元の件数 n から (i + n / 2) % n の位置
///   (取り除いた後の件数を超えるなら末尾) へ入れる
/// - 反転: 配列全体を逆順にする (グループありなら、グループの順とグループ内の順の両方が逆になる)
/// - シャッフル: グループありなら、グループの並び (初めて現れた順) を混ぜ、次にそのグループの順で
///   各グループの項目を混ぜて並べる。グループなしなら配列全体を混ぜる。混ぜ方は
///   ``SampleRandom/shuffle(_:)`` で、乱数は種 ``shuffleSeed`` から作った 1 本を、元に戻すまで
///   シャッフルのたびに続けて消費する
/// - 元に戻す: 初期の配列・次の ID・乱数を初期の状態に戻す (表示の形とグループの有無は変えない)
/// - グループありへの切り替え: 同じグループの項目が続くよう、グループが初めて現れた順に集め直す
///   (グループ内の順は保つ)。並べ直しと切り替えは ``setGrouped(_:)`` の 1 回の変更で行い、並べ直す前の
///   配列がグループありで表示側へ渡らないようにする
struct DiffUpdateModel {
    /// 初期の件数。
    static let initialCount = 20

    /// 1 グループの件数 (初期の配列)。
    static let groupSize = 5

    /// シャッフルの乱数の種。
    static let shuffleSeed: UInt32 = 20_260_925

    private(set) var items = Self.initialItems
    /// グループありで表示するか。
    private(set) var grouped = true
    private var nextID = Self.initialCount + 1
    private var random = SampleRandom(seed: Self.shuffleSeed)

    private static let initialItems = (1...initialCount).map {
        DiffUpdateItem(id: $0, group: ($0 - 1) / groupSize)
    }

    /// グループの見出しの名前。
    static func groupName(_ group: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return "グループ \(letters[group % letters.count])"
    }

    mutating func insert(at position: DiffUpdatePosition) {
        let index = position.insertionIndex(count: items.count)
        let neighbor = index < items.count ? items[index] : items.last
        items.insert(DiffUpdateItem(id: nextID, group: neighbor?.group ?? 0), at: index)
        nextID += 1
    }

    mutating func delete(at position: DiffUpdatePosition) {
        guard let index = position.targetIndex(count: items.count) else { return }
        items.remove(at: index)
    }

    mutating func update(at position: DiffUpdatePosition) {
        guard let index = position.targetIndex(count: items.count) else { return }
        items[index].revision += 1
    }

    mutating func move(at position: DiffUpdatePosition) {
        guard let index = position.targetIndex(count: items.count) else { return }
        if grouped {
            let order = groupOrder
            guard order.count > 1, let current = order.firstIndex(of: items[index].group) else { return }
            let target = order[(current + 1) % order.count]
            var moved = items.remove(at: index)
            moved.group = target
            // 移り先のグループは空にならない (移すのは別のグループの項目) ため、先頭が必ず見つかる。
            let head = items.firstIndex { $0.group == target } ?? items.count
            items.insert(moved, at: head)
        } else {
            let count = items.count
            let moved = items.remove(at: index)
            items.insert(moved, at: min((index + count / 2) % count, items.count))
        }
    }

    mutating func reverse() {
        items.reverse()
    }

    mutating func shuffle() {
        guard grouped else {
            random.shuffle(&items)
            return
        }
        var order = groupOrder
        random.shuffle(&order)
        var result: [DiffUpdateItem] = []
        for group in order {
            var members = items.filter { $0.group == group }
            random.shuffle(&members)
            result += members
        }
        items = result
    }

    mutating func reset() {
        items = Self.initialItems
        nextID = Self.initialCount + 1
        random = SampleRandom(seed: Self.shuffleSeed)
    }

    /// グループの有無を切り替える。グループありにするときは、同じ変更の中で先に並べ直す。
    mutating func setGrouped(_ isGrouped: Bool) {
        if isGrouped {
            regroup()
        }
        grouped = isGrouped
    }

    /// 同じグループの項目が続くよう、グループが初めて現れた順に集め直す。
    private mutating func regroup() {
        let order = groupOrder
        items = order.flatMap { group in items.filter { $0.group == group } }
    }

    /// グループが初めて現れた順のグループの番号。
    private var groupOrder: [Int] {
        var seen = Set<Int>()
        return items.map(\.group).filter { seen.insert($0).inserted }
    }
}
