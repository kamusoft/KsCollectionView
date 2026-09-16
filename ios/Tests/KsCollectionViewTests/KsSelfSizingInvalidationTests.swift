import SwiftUI
import UIKit
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// セルが返した高さと、そのセルに渡されていた高さがどれだけ違うとレイアウトの解き直しが
/// 起こるかを確定させます。
///
/// 推定高さを実測へ寄せる仕組みは「多数派のセルが解き直しを起こさないこと」を狙いますが、
/// セルが返す高さと推定高さは浮動小数の最下位桁で食い違うことがあります。その差でも解き直しが
/// 起こるなら寄せる効果はほとんど無く、自己サイズの診断カウンタ (`KsLayoutDiagnostics`) を
/// 解き直しの回数の上界として読むこともできません。
///
/// 観測するのは 3 つです。
///
/// - `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` の呼び出し
///   回数と `invalidateLayout(with:)` の回数。前者は自己サイズ 1 回につき 1 回呼ばれ、後者は
///   解き直しが起きたときに増える。override が効くのはレイアウトを `init(sectionProvider:)` で
///   派生させたときだけで、ファクトリ経由で作った実体では効かない。なお前者の戻り値は
///   解き直しの有無と連動しない (差が大きくても `false` が返る) ため、回数で見る
/// - 解き直しで測り直しが起こることによる「セルを測った回数」
/// - 許容の内側の差がコンテンツ全体の高さにどう出るか (許容の内側では実測ではなく
///   渡した高さのまま行が積まれるため、その差は全行ぶん合計に乗る)
///
/// ここで組むのは本体のレイアウト定義 (区切り線・内側余白・list / grid の分岐) ではなく、
/// 同じ土俵を最小構成で再現したものです。確かめたいのが UIKit 側の境界だからです。
@MainActor
final class KsSelfSizingInvalidationTests: XCTestCase {
    func test最下位桁だけ違う高さは解き直しを起こさない() async {
        let rowHeight = await measuredRowHeight()

        // 渡す高さがセルの返す高さと完全に同じとき (解き直しが起きない下限) と、
        // 最下位桁だけ違うときを比べる。
        let exact = await observe(estimatedHeight: rowHeight)
        let lastDigit = await observe(estimatedHeight: rowHeight.nextUp)

        XCTAssertNotEqual(rowHeight, rowHeight.nextUp, "最下位桁だけ違う値を作れていません")
        XCTAssertGreaterThan(exact.askedCount, 0, "解き直しの判断が 1 度も観測できていません")
        XCTAssertEqual(
            lastDigit.invalidatedCount,
            exact.invalidatedCount,
            "最下位桁だけ違う高さで無効化が増えています "
                + "(完全一致 \(exact.invalidatedCount) 回 / 最下位桁だけ違う \(lastDigit.invalidatedCount) 回)"
        )
        XCTAssertEqual(
            lastDigit.measureCount,
            exact.measureCount,
            "最下位桁だけ違う高さで測り直しが増えています "
                + "(完全一致 \(exact.measureCount) 回 / 最下位桁だけ違う \(lastDigit.measureCount) 回)"
        )
        XCTAssertEqual(
            lastDigit.contentHeight,
            exact.contentHeight,
            accuracy: 0.01,
            "最下位桁だけ違う高さでコンテンツ全体の高さが変わりました "
                + "(完全一致 \(exact.contentHeight) / 最下位桁だけ違う \(lastDigit.contentHeight))"
        )
    }

    func test半画素を超える差は解き直しを起こす() async {
        let (rowHeight, pixel, scale) = await baseline()

        // 解き直しの境界は画面のピクセル格子への丸めにあり、境界の大きさは画素に対して相対
        // (倍率 3 なら半画素 = 1/6 pt、倍率 2 なら 1/4 pt)。対照はその画素から振る。
        // この対照は、上のテストが「そもそも解き直しを観測できていない」形で緑になっていない
        // ことも示す。
        let within = pixel * 0.3
        let over = pixel * 0.6
        let condition = "(倍率 \(scale) / 1 画素 \(pixel) pt / 半画素未満 \(within) pt / 半画素超 \(over) pt)"
        let exact = await observe(estimatedHeight: rowHeight)
        let withinHalfPixel = await observe(estimatedHeight: rowHeight + within)
        let overHalfPixel = await observe(estimatedHeight: rowHeight + over)

        XCTAssertEqual(
            withinHalfPixel.invalidatedCount,
            exact.invalidatedCount,
            "半画素に届かない差で無効化が増えています "
                + "(完全一致 \(exact.invalidatedCount) 回 / 半画素未満 \(withinHalfPixel.invalidatedCount) 回) "
                + condition
        )
        XCTAssertEqual(
            withinHalfPixel.measureCount,
            exact.measureCount,
            "半画素に届かない差で測り直しが増えています "
                + "(完全一致 \(exact.measureCount) 回 / 半画素未満 \(withinHalfPixel.measureCount) 回) "
                + condition
        )
        XCTAssertGreaterThan(
            overHalfPixel.invalidatedCount,
            exact.invalidatedCount,
            "半画素を超える差で無効化が増えませんでした "
                + "(完全一致 \(exact.invalidatedCount) 回 / 半画素超 \(overHalfPixel.invalidatedCount) 回) "
                + condition
        )
        XCTAssertGreaterThan(
            overHalfPixel.measureCount,
            exact.measureCount,
            "半画素を超える差で測り直しが増えませんでした "
                + "(完全一致 \(exact.measureCount) 回 / 半画素超 \(overHalfPixel.measureCount) 回) "
                + condition
        )
    }

    #if DEBUG
    func test許容幅の内側の差は解き直しも合計高さの積み上がりも起こさない() async {
        let rowHeight = await measuredRowHeight()
        let tolerance = KsLayoutDiagnostics.matchTolerance

        // 許容の内側の差は解き直しを起こさないが、そのぶん UIKit は実測ではなく渡した高さのまま
        // 行を積む。つまり許容幅は「行ごとの誤差」としてそのまま合計高さに乗る。許容幅は、
        // 全行ぶん積み上げても合計高さが動かない大きさでなければならない。
        let exact = await observe(estimatedHeight: rowHeight)
        let inside = await observe(estimatedHeight: rowHeight + tolerance * 0.9)

        XCTAssertTrue(
            KsLayoutDiagnostics.matchesLayout(measured: rowHeight, original: rowHeight + tolerance * 0.9),
            "許容幅の内側が一致と数えられていません"
        )
        XCTAssertFalse(
            KsLayoutDiagnostics.matchesLayout(measured: rowHeight, original: rowHeight + tolerance * 1.1),
            "許容幅の外側が不一致と数えられていません"
        )
        XCTAssertEqual(
            inside.invalidatedCount,
            exact.invalidatedCount,
            "許容幅の内側の差で無効化が増えています "
                + "(完全一致 \(exact.invalidatedCount) 回 / 許容幅の内側 \(inside.invalidatedCount) 回)"
        )
        XCTAssertEqual(
            inside.measureCount,
            exact.measureCount,
            "許容幅の内側の差で測り直しが増えています "
                + "(完全一致 \(exact.measureCount) 回 / 許容幅の内側 \(inside.measureCount) 回)"
        )
        XCTAssertEqual(
            inside.contentHeight,
            exact.contentHeight,
            accuracy: 0.01,
            "許容幅の内側の差が合計高さに積み上がっています "
                + "(完全一致 \(exact.contentHeight) / 許容幅の内側 \(inside.contentHeight) / "
                + "行数 \(Self.itemCount) / 許容幅 \(tolerance))"
        )
    }
    #endif

    // MARK: - 観測

    /// 1 回の観測結果。
    private final class Observation {
        /// 数え始めてからセルが自己サイズを測った回数。
        var measureCount = 0
        /// 自己サイズの判断が求められた回数 (自己サイズ 1 回につき 1 回)。
        var askedCount = 0
        /// レイアウトが無効化された回数。
        var invalidatedCount = 0
        /// 観測の終わりのコンテンツ全体の高さ。
        var contentHeight: CGFloat = 0
        /// 最後に測られた高さ。
        var lastMeasuredHeight: CGFloat = 0
        /// 観測に使った画面の倍率。
        var displayScale: CGFloat = 1
    }

    private static let itemCount = 60
    private static let windowSize = CGSize(width: 390, height: 844)

    /// 指定した推定高さで 1 列のコレクションを組み、レイアウトを一定回数回して観測します。
    ///
    /// - Parameter estimatedHeight: item / group に渡す推定高さ
    /// - Returns: 観測結果
    private func observe(estimatedHeight: CGFloat) async -> Observation {
        let observation = Observation()
        let layout = Self.makeLayout(estimatedHeight: estimatedHeight)
        layout.onAsked = { observation.askedCount += 1 }
        layout.onInvalidated = { observation.invalidatedCount += 1 }
        let collectionView = UICollectionView(
            frame: CGRect(origin: .zero, size: Self.windowSize),
            collectionViewLayout: layout
        )
        let window = UIWindow(frame: collectionView.frame)
        window.addSubview(collectionView)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // セルの構成は本体と同じ経路にそろえる (ホスト View の測り方が観測の対象そのもののため)。
        let registration = UICollectionView.CellRegistration<KsHostingCell, Int> { cell, _, item in
            cell.onMeasuredSize = { measured, _ in
                observation.measureCount += 1
                observation.lastMeasuredHeight = measured.height
            }
            cell.contentConfiguration = UIHostingConfiguration {
                KsRowContentPlacement {
                    Text(verbatim: "項目 \(item)")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .margins(.all, 0)
        }
        let dataSource = UICollectionViewDiffableDataSource<Int, Int>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0..<Self.itemCount))
        await dataSource.apply(snapshot, animatingDifferences: false)

        // 初回の表示が落ち着くまでを数える。解き直しが起きると、その区間のセルが測り直され、
        // 落ち着くまでの測定回数が増える。
        for _ in 0..<20 {
            collectionView.setNeedsLayout()
            collectionView.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(10))
        }
        observation.contentHeight = collectionView.contentSize.height
        observation.displayScale = collectionView.traitCollection.displayScale
        withExtendedLifetime(dataSource) {}
        return observation
    }

    /// このセルが実際に返す行の高さと、画面の 1 画素の大きさ。
    ///
    /// 解き直しの境界は画素の大きさに対して相対なので、対照に振る差は画素から導く。
    private func baseline() async -> (rowHeight: CGFloat, pixel: CGFloat, scale: CGFloat) {
        let observation = await observe(estimatedHeight: KsEstimatedHeight.defaultValue)
        XCTAssertGreaterThan(observation.lastMeasuredHeight, 0, "行の高さを実測できませんでした")
        let scale = observation.displayScale
        XCTAssertGreaterThan(scale, 0, "画面の倍率を取得できませんでした")
        return (observation.lastMeasuredHeight, 1 / scale, scale)
    }

    /// このセルが実際に返す行の高さ。
    private func measuredRowHeight() async -> CGFloat {
        await baseline().rowHeight
    }

    /// 指定した推定高さの 1 列レイアウト。
    ///
    /// - Parameter estimatedHeight: item / group に渡す推定高さ
    /// - Returns: 組み立てたレイアウト
    private static func makeLayout(estimatedHeight: CGFloat) -> KsInvalidationProbeLayout {
        KsInvalidationProbeLayout { _, _ in
            let size = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(estimatedHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: size)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, repeatingSubitem: item, count: 1)
            return NSCollectionLayoutSection(group: group)
        }
    }
}


/// 解き直しの判断を数えるための compositional layout。
///
/// `UICollectionViewCompositionalLayout` の override が効くのは `init(sectionProvider:)` で
/// 派生させたときだけです (ファクトリ経由で作った実体は別のクラスになり、override が効きません)。
@MainActor
private final class KsInvalidationProbeLayout: UICollectionViewCompositionalLayout {
    /// 自己サイズの判断が求められるたびに呼ばれるハンドラ。
    var onAsked: (() -> Void)?

    /// レイアウトが実際に無効化されるたびに呼ばれるハンドラ。
    var onInvalidated: (() -> Void)?

    override func shouldInvalidateLayout(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> Bool {
        onAsked?()
        return super.shouldInvalidateLayout(
            forPreferredLayoutAttributes: preferredAttributes,
            withOriginalAttributes: originalAttributes
        )
    }

    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        onInvalidated?()
        super.invalidateLayout(with: context)
    }
}
