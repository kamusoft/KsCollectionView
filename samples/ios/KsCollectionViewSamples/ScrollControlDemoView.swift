import KsCollectionView
import SwiftUI

struct ScrollControlDemoView: View {
    @State private var controller = KsScrollController()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("先頭") { controller.scrollToStart() }
                Spacer()
                Button("Item 50") { controller.scrollTo(id: 50, position: .center) }
                Spacer()
                Button("末尾") { controller.scrollToEnd() }
            }
            .padding(.horizontal, SampleTheme.horizontalPadding)
            .padding(.vertical, SampleTheme.controlVerticalPadding)
            .foregroundStyle(SampleTheme.accent)
            .background(SampleTheme.cell)

            KsCollectionView(DemoData.scrollItems) { item in
                DemoListRow(item: item)
            }
            .scrollController(controller)
        }
    }
}
