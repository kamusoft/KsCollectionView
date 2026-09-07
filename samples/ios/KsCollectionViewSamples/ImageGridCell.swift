import KsCollectionView
import SwiftUI

/// 「画像グリッド」の 1 セル。正方形の画像とその下に ID の文言を置く。
struct ImageGridCell: View {
    let item: DemoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KsImage(DemoData.imageURL(for: item.id), contentMode: .fill)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityHidden(true)
            Text(item.title)
                .font(.caption)
                .foregroundStyle(SampleTheme.secondaryText)
                .padding(.horizontal, ImageGridMetrics.captionHorizontalPadding)
                .padding(.vertical, ImageGridMetrics.captionVerticalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SampleTheme.cell)
        .clipShape(RoundedRectangle(cornerRadius: ImageGridMetrics.cellCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
