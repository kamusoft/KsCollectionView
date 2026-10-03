import Combine
import KsCollectionView

/// 「並べ替え」画面の項目と操作の切り替え、置いたときの並べ替えの規則。
///
/// Android Sample の同名の定義と同じ規則にし、同じ操作の順で同じ並びになる。
/// Sample の配布先の下限 (iOS 16) では `@Observable` を使えないため、`ObservableObject` で持つ。
///
/// - 初期の配列: ID 1〜10,000 を昇順に。グループは 100 件ずつ 1〜100
/// - 動かせる項目: 10 の倍数の項目は動かせない (``ReorderDemoItem/isMovable``)
/// - 置いたとき (``move(_:)``): 「置いても受け入れない」がオンなら並べ替えず、「並べ替えを受け入れませんでした」を
///   出して受け入れないと返す。オフなら ``applying(_:to:)`` の規則で並べ替えて受け入れたと返す
/// - 置けるか (``canDrop(_:)``): 「グループをまたがせない」がオンの間は、行き先のグループが元のグループと
///   同じときだけ置ける。グループをオフにしている間 (知らせにグループの値が無い) はどこにでも置ける
/// - 長押し (``didLongPress(_:)``): 「長押し: Item n」を出す。一覧は並べ替えのスイッチがオンの間は長押しを
///   知らせないため、スイッチがオフの間だけ出る
/// - 帯: 出してから ``SamplePanelMetrics/bannerDuration`` (3 秒) たったら消す。その間に次の帯を出したら、
///   その時点から 3 秒出す
@MainActor
final class ReorderDemoModel: ObservableObject {
    /// 項目の件数。
    static let itemCount = 10_000

    /// 1 グループの件数 (初期の配列)。
    static let groupSize = 100

    /// 表示している項目。
    @Published private(set) var items: [ReorderDemoItem] = ReorderDemoModel.initialItems

    /// 並べ替えのスイッチ。
    @Published var isReorderEnabled = true

    /// グループの有無。
    @Published var isGrouped = true

    /// 「グループをまたがせない」。
    @Published var keepsGroups = false

    /// 「置いても受け入れない」。
    @Published var rejectsMoves = false

    /// 画面の上の帯に出している知らせ。出していなければ nil。
    @Published private(set) var notice: String?

    /// 帯を出しておく時間 (秒)。
    private let noticeDuration: Double

    /// 帯を決まった時間の後に消す処理。
    private var noticeTask: Task<Void, Never>?

    /// - Parameter noticeDuration: 帯を出しておく時間 (秒)
    init(noticeDuration: Double = SamplePanelMetrics.bannerDuration) {
        self.noticeDuration = noticeDuration
    }

    /// 初期の配列。
    static var initialItems: [ReorderDemoItem] {
        (1...itemCount).map { ReorderDemoItem(id: $0, group: ($0 - 1) / groupSize + 1) }
    }

    /// 置いたときの知らせを受ける。受け入れたら配列を並べ替えて `true` を返す。
    func move(_ move: KsReorderMove<ReorderDemoItem>) -> Bool {
        guard !rejectsMoves else {
            showNotice(ReorderDemoText.rejected)
            return false
        }
        items = Self.applying(move, to: items)
        return true
    }

    /// 行き先に置けるか。
    func canDrop(_ move: KsReorderMove<ReorderDemoItem>) -> Bool {
        guard keepsGroups, let group = move.group?.base as? Int else { return true }
        return group == move.item.group
    }

    /// 項目を長押ししたときの知らせを出す。
    func didLongPress(_ item: ReorderDemoItem) {
        showNotice(ReorderDemoText.longPressed(item))
    }

    /// 置いたときの知らせのとおりに並べ替えた配列を返す。
    ///
    /// 動かした項目を取り除き、行き先 (`before` ならその項目の前、`end` なら知らせのグループの末尾。
    /// グループの値が無ければ配列の末尾) に入れる。項目のグループの値は、知らせのグループの値に書き換える。
    /// 知らせにグループの値が無い (グループをオフにしている) ときは、行き先の隣の項目 (`before` ならその項目、
    /// `end` なら最後の項目) のグループの値に書き換える。オフの間に動かした項目のグループの値を変えないと、
    /// オンに戻したときに同じグループの値が離れた位置に現れ、一覧に渡せない配列になるため。
    static func applying(_ move: KsReorderMove<ReorderDemoItem>, to items: [ReorderDemoItem]) -> [ReorderDemoItem] {
        var result = items
        guard let from = result.firstIndex(where: { $0.id == move.item.id }) else { return items }
        var moved = result.remove(at: from)
        let group = move.group?.base as? Int
        switch move.destination {
        case .before(let next):
            guard let index = result.firstIndex(where: { $0.id == next.id }) else { return items }
            moved.group = group ?? result[index].group
            result.insert(moved, at: index)
        case .end:
            if let group {
                let last = result.lastIndex(where: { $0.group == group })
                moved.group = group
                result.insert(moved, at: last.map { $0 + 1 } ?? result.count)
            } else {
                moved.group = result.last?.group ?? moved.group
                result.append(moved)
            }
        }
        return result
    }

    /// 帯を出し、決まった時間の後に消す。
    private func showNotice(_ text: String) {
        noticeTask?.cancel()
        notice = text
        noticeTask = Task { [weak self, noticeDuration] in
            try? await Task.sleep(nanoseconds: UInt64(noticeDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}
