import KsCollectionView
import SwiftUI

/// 「画像グリッド」の 1 セル。正方形の画像とその下に ID の文言を置く。
struct ImageGridCell: View {
    let item: DemoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
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

    /// 読み込み中の表示を差し込むのは、数えることが要求された構成だけにする。
    ///
    /// このセルはデモ画面・計測用の画面・検証画面が共有しており、差し込みを常時にすると
    /// 配布する構成のセルまで計測の都合で変わる。数えない構成では本体の既定の表示に任せる。
    @ViewBuilder
    private var image: some View {
        if ImageLoadingSlotCounter.isEnabled {
            KsImage(
                DemoData.imageURL(for: item.id),
                contentMode: .fill,
                loading: { CountedImageLoadingPlaceholder(itemID: item.id) }
            )
        } else {
            KsImage(DemoData.imageURL(for: item.id), contentMode: .fill)
        }
    }
}
