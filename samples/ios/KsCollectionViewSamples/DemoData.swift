import Foundation

enum DemoData {
    static let fruits = [
        DemoItem(id: 1, title: "Apple", detail: "ID: 1"),
        DemoItem(id: 2, title: "Banana", detail: "ID: 2"),
        DemoItem(id: 3, title: "Cherry", detail: "ID: 3"),
        DemoItem(id: 4, title: "Durian", detail: "ID: 4"),
        DemoItem(id: 5, title: "Elderberry", detail: "ID: 5"),
        DemoItem(id: 6, title: "Fig", detail: "ID: 6"),
    ]

    static let fixedGridItems = (1...9).map { DemoItem(id: $0, title: "Item \($0)") }
    static let gridItems = (1...18).map { DemoItem(id: $0, title: "Item \($0)") }
    static let scrollItems = (1...100).map { DemoItem(id: $0, title: "Item \($0)", detail: "ID: \($0)") }

    static let templateItems = (1...30).map {
        TemplateDemoItem(
            id: $0,
            kind: $0.isMultiple(of: 5) ? .notice : .message,
            title: $0.isMultiple(of: 5) ? "Notice \($0)" : "Message \($0)"
        )
    }

    /// 「大量件数」画面の項目。件数は起動引数で変えられ、内容は ID から決まるため件数に依らない。
    static let largeItems = (1...LargeDataCount.value).map { index in
        DemoItem(
            id: index,
            title: "Item \(index)",
            detail: index.isMultiple(of: 7)
                ? "可変行高を確認するための固定シード長文データ \(index) — KsCollectionView"
                : nil
        )
    }

    /// 「画像グリッド」画面の件数。
    static let imageGridItemCount = 10_000

    /// 「画像グリッド」画面が使う 10,000 件。セルの文言は ID から作る。
    static let imageGridItems = (1...imageGridItemCount).map {
        DemoItem(id: $0, title: "#\($0)")
    }

    /// 「画像グリッド」画面のデモ画像の URL。
    ///
    /// アイテム ID から決定的に組み立てるため、同じセルには常に同じ絵が出る。スクロールで
    /// 戻ってきたときに絵が変われば、キャッシュではなく別画像を引いたと分かる。
    static func imageURL(for id: Int) -> URL {
        // 組み立てに使うのは固定の文字列と整数だけなので、URL の生成は必ず成功する。
        URL(string: "https://picsum.photos/seed/ks-\(id)/400/400")!
    }
}
