import KsCollectionView
import SwiftUI

struct Item: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

struct ItemListScreen: View {
    private static let itemCount = 100

    private let items = (0..<itemCount).map { index in
        Item(id: index, title: "Item \(index)")
    }

    var body: some View {
        KsCollectionView(items) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}
