import KsCollectionView
import NukeUI
import SwiftUI

/// 画像の挙動を確かめる検証画面です。起動引数で指定したときだけ表示します。
///
/// 確かめるのは 3 点です。
/// - プリフェッチで取り込んだ画像が、ローダー付属のビュー (`LazyImage`) を直接使った表示にも効くこと
/// - 読み込み中の既定の表示 (大きな画像を出して読み込み中を見えるようにする)
/// - 失敗の既定の表示 (到達できない取得元を出す)
struct ImageBehaviorVerificationView: View {
    /// 先読みの土俵に使う件数。可視範囲の先に十分な余地を残す。
    private static let itemCount = 200

    /// ローダー付属のビューで表示する ID の範囲。初期表示の可視範囲より後ろで、
    /// 先読みの窓に入る位置を選ぶ。
    private static let sharedIDs = Array(13...36)

    /// 到達できない取得元。失敗の既定の表示を出すために使う。
    private static let unreachableURL = URL(string: "https://ks-unreachable.invalid/image.jpg")!

    /// 読み込みに時間の掛かる取得元。読み込み中の既定の表示を見えるようにするために使う。
    private static let slowURL = URL(string: "https://picsum.photos/seed/ks-slow/4000/4000")!

    @State private var showsLoaderAttachedView = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    KsImage(Self.slowURL)
                        .frame(width: 100, height: 100)
                        .accessibilityIdentifier("imageBehavior.slow")
                    Text("読み込み中")
                        .font(.caption2)
                }
                VStack(spacing: 2) {
                    KsImage(Self.unreachableURL)
                        .frame(width: 100, height: 100)
                        .accessibilityIdentifier("imageBehavior.failure")
                    Text("失敗")
                        .font(.caption2)
                }
                Spacer()
                Button(showsLoaderAttachedView ? "先読みへ戻す" : "ローダー付属ビュー") {
                    showsLoaderAttachedView.toggle()
                }
                .accessibilityIdentifier("imageBehavior.toggle")
            }
            .padding(.horizontal, SampleTheme.horizontalPadding)

            if showsLoaderAttachedView {
                loaderAttachedGrid
            } else {
                prefetchingCollection
            }
        }
    }

    /// 先読みを起こす土俵です。到達点はメモリまでにして、元寸の画像をメモリに載せます。
    private var prefetchingCollection: some View {
        KsCollectionView(
            Array(DemoData.imageGridItems.prefix(Self.itemCount)),
            layout: .grid(
                columns: .fixed(ImageGridMetrics.columnCount),
                rowSpacing: ImageGridMetrics.spacing,
                columnSpacing: ImageGridMetrics.spacing
            ),
            contentPadding: EdgeInsets(
                top: ImageGridMetrics.spacing,
                leading: ImageGridMetrics.spacing,
                bottom: ImageGridMetrics.spacing,
                trailing: ImageGridMetrics.spacing
            )
        ) { item in
            ImageGridCell(item: item)
        }
        .prefetchResources(destination: .memory) {
            [DemoData.imageURL(for: $0.id)]
        }
    }

    /// ローダー付属のビューだけで組んだ表示です。同じ取得元を、ライブラリを通さずに表示します。
    private var loaderAttachedGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: ImageGridMetrics.spacing),
                    count: ImageGridMetrics.columnCount
                ),
                spacing: ImageGridMetrics.spacing
            ) {
                ForEach(Self.sharedIDs, id: \.self) { id in
                    LazyImage(url: DemoData.imageURL(for: id)) { state in
                        if let image = state.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                }
            }
            .padding(ImageGridMetrics.spacing)
        }
        .accessibilityIdentifier("imageBehavior.loaderAttached")
    }
}
