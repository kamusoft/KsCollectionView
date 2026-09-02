import KsCollectionView
import SwiftUI

struct InteractiveControlVerificationView: View {
    private struct Item: Identifiable, Equatable {
        let id = 1
    }

    @State private var buttonActionCount = 0
    @State private var itemTapCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("セル内 Button 実タッチ検証")
                .font(.headline)
            Text("Button を押し、押下中にも赤いセル全面 feedback が見えないことを確認します。")
                .font(.body)
            Text("Button action count: \(buttonActionCount)")
                .accessibilityIdentifier("verification.buttonActionCount")
            Text("Item tap count: \(itemTapCount)")
                .accessibilityIdentifier("verification.itemTapCount")
            Text("期待値: Button=1 / Item tap=0 / 赤い feedback=非表示")
                .accessibilityIdentifier("verification.expectedResult")

            KsCollectionView([Item()]) { _ in
                HStack {
                    Text("セル本文")
                    Spacer()
                    Button("セル内 Button") {
                        buttonActionCount += 1
                    }
                    .accessibilityIdentifier("verification.cellButton")
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 16)
                .background(Color.white)
            }
            .onItemTap { _ in
                itemTapCount += 1
            }
            .touchFeedback(color: .red)
            .frame(height: 96)

            Spacer()
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
