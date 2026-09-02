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

    static let largeItems = (1...10_000).map { index in
        DemoItem(
            id: index,
            title: "Item \(index)",
            detail: index.isMultiple(of: 7)
                ? "可変行高を確認するための固定シード長文データ \(index) — KsCollectionView"
                : nil
        )
    }
}
