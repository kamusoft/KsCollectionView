import KsCollectionView
import SwiftUI

// MARK: - モデル

/// グループの値。配列の中では、同じ値の項目を必ず隣り合わせに並べる。
enum BoardSection: String, Hashable, Sendable {
    case today
    case later
    case archived

    var title: String {
        switch self {
        case .today: return "Today"
        case .later: return "Later"
        case .archived: return "Archived"
        }
    }
}

/// 一覧の 1 項目。値型で、Equatable と Identifiable を満たす。
struct BoardItem: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var section: BoardSection
    /// true の項目は持ち上げられない (動かせない)。
    var isLocked = false
}

// MARK: - 並べ替えの決まり

/// どの項目を動かせるか、どこに落とせるかの決まり。
/// 画面やモデルの状態を読まない、軽い同期の判定だけにしている。
enum BoardReorderRules {
    /// ロックされた項目は動かせない。
    static func canMove(_ item: BoardItem) -> Bool {
        !item.isLocked
    }

    /// Archived のグループは、ほかのグループからの項目を受け入れない。
    /// (Archived の中での並べ替えと、Archived から外へ出す移動はできる)
    static func canDrop(_ move: KsReorderMove<BoardItem>) -> Bool {
        guard let destination = move.group?.base as? BoardSection else { return true }
        if destination == .archived && move.item.section != .archived {
            return false
        }
        return true
    }
}

// MARK: - 画面のモデル

@MainActor
final class BoardModel: ObservableObject {
    @Published private(set) var items: [BoardItem]
    @Published var isReordering = true

    init() {
        items = [
            BoardItem(id: 1, title: "Write the weekly report", section: .today),
            BoardItem(id: 2, title: "Stand-up meeting (locked)", section: .today, isLocked: true),
            BoardItem(id: 3, title: "Review pull requests", section: .today),
            BoardItem(id: 4, title: "Reply to the customer", section: .today),
            BoardItem(id: 5, title: "Plan the next sprint", section: .later),
            BoardItem(id: 6, title: "Update the dependencies", section: .later),
            BoardItem(id: 7, title: "Release freeze (locked)", section: .later, isLocked: true),
            BoardItem(id: 8, title: "Clean up old branches", section: .later),
            BoardItem(id: 9, title: "Set up the CI", section: .archived),
            BoardItem(id: 10, title: "Design the first screen", section: .archived),
            BoardItem(id: 11, title: "Kick-off meeting", section: .archived),
        ]
    }

    /// 落とされた移動を自分の配列に反映する。受け入れたら true を返す。
    func move(_ move: KsReorderMove<BoardItem>) -> Bool {
        var next = items
        guard let from = next.firstIndex(where: { $0.id == move.item.id }) else { return false }
        var moved = next.remove(at: from)
        let section = move.group?.base as? BoardSection
        switch move.destination {
        case .before(let target):
            guard let index = next.firstIndex(where: { $0.id == target.id }) else { return false }
            // グループをまたいだ移動では、行き先のグループの値を項目に書き込む。
            moved.section = section ?? next[index].section
            next.insert(moved, at: index)
        case .end:
            if let section {
                moved.section = section
                let last = next.lastIndex(where: { $0.section == section })
                next.insert(moved, at: last.map { $0 + 1 } ?? next.count)
            } else {
                moved.section = next.last?.section ?? moved.section
                next.append(moved)
            }
        }
        items = next
        return true
    }
}

// MARK: - 行とグループの見出し

struct BoardRow: View {
    let item: BoardItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.title)
                .foregroundStyle(item.isLocked ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Locked")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct BoardSectionHeader: View {
    let section: BoardSection
    let count: Int

    var body: some View {
        Text("\(section.title) (\(count))")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            // 固定される見出しの後ろを行が流れるので、不透明な背景を付ける。
            .background(.background)
    }
}

// MARK: - 画面

struct ItemListScreen: View {
    @StateObject private var model = BoardModel()

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Reorder", isOn: $model.isReordering)
                .padding()
            KsCollectionView(model.items, layout: .list(groupSpacing: 16)) { item in
                BoardRow(item: item)
            }
            .groups(by: \.section) { section, itemsInSection in
                BoardSectionHeader(section: section, count: itemsInSection.count)
            }
            .reorder(
                isEnabled: model.isReordering,
                canMove: { item in BoardReorderRules.canMove(item) },
                canDrop: { move in BoardReorderRules.canDrop(move) },
                // VoiceOver の利用者に出す移動の操作の名前。ライブラリは文言を持たないので、
                // ローカライズ済みの文字列を渡す。
                accessibilityActions: KsReorderAccessibilityActions(
                    previous: String(localized: "Move up"),
                    next: String(localized: "Move down")
                )
            ) { move in
                model.move(move)
            }
        }
    }
}
