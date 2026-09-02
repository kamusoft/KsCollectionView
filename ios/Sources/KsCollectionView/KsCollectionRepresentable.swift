import SwiftUI

internal struct KsCollectionRepresentable<Item: Equatable>: UIViewControllerRepresentable {
    let configuration: KsCollectionConfiguration<Item>

    func makeUIViewController(context: Context) -> KsCollectionViewController<Item> {
        KsCollectionViewController(configuration: configuration)
    }

    func updateUIViewController(
        _ uiViewController: KsCollectionViewController<Item>,
        context: Context
    ) {
        uiViewController.update(configuration: configuration)
    }

    static func dismantleUIViewController(
        _ uiViewController: KsCollectionViewController<Item>,
        coordinator: Void
    ) {
        uiViewController.disconnect()
    }
}
