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
    targets: [
        .target(name: "KsCollectionView"),
        .testTarget(
            name: "KsCollectionViewTests",
            dependencies: ["KsCollectionView"]
        ),
    ]
)
