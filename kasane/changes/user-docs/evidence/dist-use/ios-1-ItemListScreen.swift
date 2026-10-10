import KsCollectionView
import SwiftUI

/// 項目の種類。テンプレートの切り替えのキーに使う。
enum ItemKind: Hashable, Sendable {
    case message
    case notice
}

/// 一覧に表示する 1 件の項目。
struct Item: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: ItemKind
    let title: String
    let detail: String
}

/// 通常のメッセージの行。
struct MessageRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.body)
            Text(item.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// お知らせの行。
struct NoticeRow: View {
    let item: Item

    var body: some View {
        Label(item.title, systemImage: "exclamationmark.circle.fill")
            .font(.headline)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
    }
}

/// 種類ごとにテンプレートを切り替える一覧の画面。
struct ItemListScreen: View {
    private static let itemCount = 100

    /// 画面の中だけで完結するデータ。10 件に 1 件をお知らせにする。
    private let items: [Item] = (0..<itemCount).map { index in
        if index % 10 == 0 {
            Item(id: index, kind: .notice, title: "Notice \(index)", detail: "")
        } else {
            Item(id: index, kind: .message, title: "Message \(index)", detail: "Detail of message \(index)")
        }
    }

    /// 最後にタップされた項目。
    @State private var tappedItem: Item?
    /// コードから一覧をスクロールさせるためのコントローラー。
    @State private var controller = KsScrollController()

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tappedItem.map { "Tapped: \($0.title) (id \($0.id))" } ?? "Tapped: none")
                    .lineLimit(1)
                Spacer()
                Button("Top") {
                    controller.scrollToStart()
                }
            }
            .padding()

            Divider()

            // ライブラリの修飾子は KsCollectionView の式の直後に書く。
            KsCollectionView(items, template: \.kind) {
                KsTemplate(.message) { item in
                    MessageRow(item: item)
                }
                KsTemplate(.notice) { item in
                    NoticeRow(item: item)
                }
            }
            .onItemTap { item in
                tappedItem = item
            }
            .touchFeedback(color: .accentColor.opacity(0.1))
            .scrollController(controller)
        }
    }
}
