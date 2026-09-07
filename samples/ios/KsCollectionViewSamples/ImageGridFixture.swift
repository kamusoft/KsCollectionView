import KsCollectionView
import SwiftUI

/// 「画像グリッド」の土俵の宣言元。
///
/// デモ画面 (``ImageGridDemoView``) と計測用の画面 (``PerformanceVerificationView``) は、
/// 要素・配置・外周の余白・セル・プリフェッチの宣言をすべてここから取る。計測はデモ画面と
/// 同じ土俵を測って初めて意味を持つため、両者が別々の宣言を持てないよう、コレクションの
/// 組み立てそのものを 1 箇所に集めている (別々に書けば土俵が食い違ってもどちらの画面も
/// 正常に動いてしまい、食い違いに気づけない)。
///
/// 寸法は ``ImageGridMetrics``、要素の作り方は ``DemoData`` が持つ。
enum ImageGridFixture {
    /// 土俵の配置。3 列・セル間の間隔はデモ画面と計測で同じ。
    static let layout = KsCollectionLayout.grid(
        columns: .fixed(ImageGridMetrics.columnCount),
        rowSpacing: ImageGridMetrics.spacing,
        columnSpacing: ImageGridMetrics.spacing
    )

    /// グリッドの外周の余白。
    static let contentPadding = EdgeInsets(
        top: ImageGridMetrics.spacing,
        leading: ImageGridMetrics.spacing,
        bottom: ImageGridMetrics.spacing,
        trailing: ImageGridMetrics.spacing
    )

    /// 土俵の要素。
    static var items: [DemoItem] { DemoData.imageGridItems }

    /// 土俵のコレクションを組み立てます。
    ///
    /// - Parameter destination: プリフェッチの到達点。宣言しないときは `nil` を渡します。
    static func collection(destination: KsPrefetchDestination?) -> KsCollectionView<DemoItem> {
        let view = KsCollectionView(
            items,
            layout: layout,
            contentPadding: contentPadding
        ) { item in
            ImageGridCell(item: item)
        }

        // 到達点を選ばないときは宣言そのものを行わない。宣言が無いことと「空の宣言がある」ことは
        // 本体の動きが変わるため、nil で区別する。
        guard let destination else { return view }
        return view.prefetchResources(destination: destination) {
            [DemoData.imageURL(for: $0.id)]
        }
    }
}
