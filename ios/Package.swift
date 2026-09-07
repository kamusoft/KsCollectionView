// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KsCollectionView",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "KsCollectionView", targets: ["KsCollectionView"]),
    ],
    dependencies: [
        // 画像の読み込み・キャッシュ・プリフェッチを担うローダー (core/ADR-0012)。
        // メジャー 13 系の範囲で最新に追随する。
        .package(url: "https://github.com/kean/Nuke.git", from: "13.2.0"),
    ],
    targets: [
        .target(
            name: "KsCollectionView",
            dependencies: [
                // ImagePipeline / ImagePrefetcher (プリフェッチとキャッシュ)
                .product(name: "Nuke", package: "Nuke"),
                // LazyImage (KsImage の表示経路)
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
        .testTarget(
            name: "KsCollectionViewTests",
            dependencies: [
                "KsCollectionView",
                // 受け口の要求の組み立てと、キャッシュ契約の統合テストがローダーの型を直接使う。
                .product(name: "Nuke", package: "Nuke"),
            ]
        ),
    ]
)
