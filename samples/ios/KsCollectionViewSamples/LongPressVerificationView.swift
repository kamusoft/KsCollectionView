import KsCollectionView
import SwiftUI

/// 長押しと通常タップの排他を実タッチで確かめる検証用画面です。
struct LongPressVerificationView: View {
    /// 長押しハンドラを宣言するかどうかです。未宣言時に通常タップが失われないことの確認に使います。
    let declaresLongTap: Bool

    private struct Item: Identifiable, Equatable {
        let id = 1
    }

    @State private var itemTapCount = 0
    @State private var itemLongTapCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("長押しと通常タップの排他検証")
                .font(.headline)
            Text("セルを 1 秒保持して離し、下のカウントを確認します。")
                .font(.body)
            Text("Long tap declared: \(declaresLongTap ? "yes" : "no")")
                .accessibilityIdentifier("longPress.declaresLongTap")
            Text("Item tap count: \(itemTapCount)")
                .accessibilityIdentifier("longPress.itemTapCount")
            Text("Item long tap count: \(itemLongTapCount)")
                .accessibilityIdentifier("longPress.itemLongTapCount")

            collection
                .frame(height: 96)

            Spacer()
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var collection: KsCollectionView<Item> {
        let base = KsCollectionView([Item()]) { _ in
            Text("保持対象のセル")
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 16)
                .background(Color.white)
                .accessibilityIdentifier("longPress.cell")
        }
        .onItemTap { _ in
            itemTapCount += 1
        }

        guard declaresLongTap else { return base }
        return base.onItemLongTap { _ in
            itemLongTapCount += 1
        }
    }
}
