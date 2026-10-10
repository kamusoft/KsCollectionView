import KsCollectionView
import SwiftUI

/// 一覧に表示する 1 件分のデータ。
/// KsCollectionView の要素は Equatable かつ Identifiable な値型にする。
struct Item: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    /// グループ分けのキー。同じ値の要素は配列の中で連続して並べる。
    let category: String
}

/// 画面内で完結するサンプルデータ。
enum ItemSamples {
    private static let categories = ["Fruits", "Vegetables", "Grains", "Dairy", "Seafood"]
    private static let itemsPerCategory = 14

    /// カテゴリごとに連続して並んだ配列 (グループは連続した並びから作られるため)。
    static let all: [Item] = categories.enumerated().flatMap { categoryIndex, category in
        (0..<itemsPerCategory).map { index in
            Item(
                id: categoryIndex * 1000 + index,
                title: "\(category) \(index + 1)",
                category: category
            )
        }
    }
}

/// グリッドの 1 マス。高さは内容から決まるので、全マスを同じ高さにそろえる。
struct ItemCell: View {
    let item: Item

    var body: some View {
        Text(item.title)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.gray.opacity(0.2))
    }
}

/// グループの見出し。固定表示されるので、不透明な背景を付ける。
/// 余白は見出しの縦の padding ではなく groupSpacing / headerItemSpacing で作る。
struct ItemGroupHeader: View {
    let title: String
    let count: Int

    var body: some View {
        Text("\(title) (\(count))")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.background)
    }
}

/// コレクション全体の見出し (最初のグループの上に置かれ、内容と一緒にスクロールする)。
struct ItemCollectionHeader: View {
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Items")
                .font(.largeTitle.bold())
            Text("\(totalCount) items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
    }
}

struct ItemListScreen: View {
    private let items: [Item]

    init() {
        items = ItemSamples.all
    }

    var body: some View {
        KsCollectionView(
            items,
            // 縦長のときは 3 列、横長のときは 5 列。
            layout: .grid(
                columns: .fixed(portrait: 3, landscape: 5),
                rowSpacing: 8,
                columnSpacing: 8,
                groupSpacing: 24,
                headerItemSpacing: 8
            ),
            contentPadding: EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        ) { item in
            ItemCell(item: item)
        }
        // ライブラリの修飾子は SwiftUI の修飾子より前に書く。
        .groups(by: \.category, pinnedHeaders: true) { category, itemsInCategory in
            ItemGroupHeader(title: category, count: itemsInCategory.count)
        }
        .header {
            ItemCollectionHeader(totalCount: items.count)
        }
    }
}
