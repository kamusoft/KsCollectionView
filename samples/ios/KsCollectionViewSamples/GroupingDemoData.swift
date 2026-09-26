/// 「グループ化」画面の初期データの生成規則。
///
/// Android Sample の同名の定義と同じ規則で、同じ並び・同じグループ分けを作る。規則は次のとおり。
///
/// 1. 項目は ID 1〜10,000 を昇順に並べる。中身は ID から決まる (`DemoData.largeItem(_:)`)
/// 2. グループは配列の先頭から順に、続いた ID の範囲として切る。グループの番号は切った順に 1 から振る
/// 3. 大きいグループ (1,200 件) は ID 1・4,401・8,201 から始まる 3 つ (``largeGroupStarts``)。先頭寄り・中ほど・末尾寄りに置き、どこをスクロールしても塊の境目と
///    固定見出しの入れ替わりを通るようにする
/// 4. 大きいグループの間は小さいグループ (5〜30 件) で埋める。1 つ切るごとに、次の大きいグループの
///    開始 (無ければ 10,001) までの残り件数 r を見て、
///    - r が 30 以下なら r 件をまとめて 1 グループにする (乱数を引かない)
///    - そうでなければ `5 + random.next(below: 26)` 件にする。その結果 r の残りが 5 件未満になるなら、
///      残りをちょうど 5 件にする件数 (r − 5) に置き換える
/// 5. 乱数は ``SampleRandom`` を種 ``seed`` で 1 本だけ作り、手順 4 で引く分だけ順に消費する
enum GroupingDemoData {
    /// 項目の総数。
    static let itemCount = 10_000

    /// 大きいグループの件数。
    static let largeGroupSize = 1_200

    /// 大きいグループの先頭の ID。
    static let largeGroupStarts = [1, 4_401, 8_201]

    /// 小さいグループの件数の下限と上限。
    static let smallGroupSizes = 5...30

    /// 小さいグループの件数を決める乱数の種。
    static let seed: UInt32 = 20_260_924

    /// 初期の配列。
    static let items: [GroupingDemoItem] = makeItems()

    private static func makeItems() -> [GroupingDemoItem] {
        var random = SampleRandom(seed: seed)
        var items: [GroupingDemoItem] = []
        items.reserveCapacity(itemCount)
        var group = 0
        var id = 1
        while id <= itemCount {
            group += 1
            let size: Int
            if largeGroupStarts.contains(id) {
                size = largeGroupSize
            } else {
                let boundary = largeGroupStarts.first { $0 > id } ?? itemCount + 1
                size = smallGroupSize(remaining: boundary - id, random: &random)
            }
            for member in id..<(id + size) {
                items.append(GroupingDemoItem(row: DemoData.largeItem(member), group: group))
            }
            id += size
        }
        return items
    }

    /// 次の大きいグループまでの残り件数から、小さいグループの件数を決める。
    private static func smallGroupSize(remaining: Int, random: inout SampleRandom) -> Int {
        if remaining <= smallGroupSizes.upperBound {
            return remaining
        }
        let span = smallGroupSizes.upperBound - smallGroupSizes.lowerBound + 1
        let size = smallGroupSizes.lowerBound + random.next(below: span)
        if remaining - size < smallGroupSizes.lowerBound {
            return remaining - smallGroupSizes.lowerBound
        }
        return size
    }
}
