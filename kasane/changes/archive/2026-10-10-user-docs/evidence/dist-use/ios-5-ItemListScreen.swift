import Foundation
import KsCollectionView
import SwiftUI

/// 署名付き URL で配られる画像 1 枚。
///
/// `signedURL` は取得のたびにクエリ文字列 (期限・署名) が変わるので、
/// キャッシュの識別には使わず、変わらない `id` をキーにする。
struct Item: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let signedURL: URL
}

extension Item {
    /// 画像キャッシュのキー。画像 1 枚の内容を指す、空でない文字列。
    private var imageKey: String {
        "item-thumbnail-\(id)"
    }

    /// セルで表示するときの画像の源泉。
    /// 先読みの宣言と同じキーになるよう、キーは `imageKey` の 1 か所から作る。
    var imageSource: KsImageSource {
        .remote(signedURL, key: imageKey)
    }

    /// 先読みの宣言。セルの幅いっぱいに表示するので、幅は列の幅を伝える。
    var prefetchResource: KsResource {
        KsResource(signedURL, width: .column, key: imageKey)
    }
}

extension Item {
    /// ファイル内で完結するサンプルデータ。
    static let samples: [Item] = (1...120).compactMap { index in
        // 署名付き URL の例。クエリ文字列は時間とともに変わる想定。
        let string = "https://example.com/images/thumbnails/\(index).jpg"
            + "?expires=1791590400&signature=sample\(index)"
        guard let url = URL(string: string) else {
            return nil
        }
        return Item(id: String(index), title: "Image \(index)", signedURL: url)
    }
}

/// グリッドの 1 マス。
struct ItemCell: View {
    let item: Item

    var body: some View {
        // KsImage には必ず大きさを与える (ここでは正方形)。
        KsImage(item.imageSource)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityLabel(item.title)
    }
}

/// リモート画像のグリッドを表示する画面。
struct ItemListScreen: View {
    private let items = Item.samples

    init() {}

    var body: some View {
        KsCollectionView(
            items,
            layout: .grid(columns: .fixed(3), rowSpacing: 2, columnSpacing: 2)
        ) { item in
            ItemCell(item: item)
        }
        // もうすぐ表示される項目の画像を先読みする。
        // .memory はデコードしてメモリキャッシュまで運ぶので、
        // ディスクキャッシュを有効にしていないアプリでも表示に使われる。
        .prefetchResources(destination: .memory) { item in
            [item.prefetchResource]
        }
    }
}
