#if canImport(UIKit)
import SwiftUI
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

/// 次のページの読み込み中の表示が、一覧の見えている範囲の下端に止めて重ねられ、項目がその裏を流れることを
/// 実レイアウトの上で確かめる (list / グリッド、下の内側余白の有無、全画面の一覧で下端の安全領域あり)。
@MainActor
final class KsPagingIndicatorTests: XCTestCase {
    private typealias Support = KsPagingTestSupport
    // 画面いっぱいのウインドウに載せ、下端の安全領域 (ホームインジケータの分) を持たせる。
    private static var size: CGSize { UIScreen.main.bounds.size }
    private static let rowHeight: CGFloat = 80
    private static let layouts: [(String, KsCollectionLayout)] = [
        ("list", .list),
        ("grid", .grid(columns: .fixed(2), columnSpacing: 4)),
    ]

    // MARK: - 置き場

    // 下の内側余白 (contentPadding の下) は中身の周りの余白で、表示の置き場には効かない。どの余白でも、表示の下端は
    // 見えている範囲の下端から「下端の安全領域 + 間隔」だけ上にあり、スクロールしても動かない。
    func test追加読み込み中の表示は下の余白によらず見えている範囲の下端の決まった位置に止まりスクロールしても動かない() async {
        for (name, layout) in Self.layouts {
            var frames: [CGRect] = []
            for bottomPadding in [CGFloat(0), 40, 100] {
                let label = "\(name) / 下の余白 \(bottomPadding)"
                let controller = makeController(rows: makeRows(60), state: .appending, layout: layout, bottomPadding: bottomPadding)
                let window = Support.show(controller, size: Self.size)
                defer { window.isHidden = true }
                let safeBottom = controller.collectionView.safeAreaInsets.bottom
                XCTAssertGreaterThan(safeBottom, 0, "表示先が下端の安全領域を持っていません")
                await Support.waitForItems(60, in: controller)
                await Support.settleLayout(controller)
                await Support.waitUntil("読み込み中の表示 (\(label))", value: { self.indicatorFrame(controller, in: window) }) { $0 != nil }
                guard let frame = indicatorFrame(controller, in: window) else { continue }
                let expectedBottom = Self.size.height - safeBottom
                    - KsCollectionViewController<KsPagingRow>.pagingIndicatorBottomSpacing
                XCTAssertEqual(frame.maxY, expectedBottom, accuracy: 0.5, "下端の位置が違います (\(label))")
                XCTAssertEqual(frame.midX, Self.size.width / 2, accuracy: 0.5, "横方向の中央にありません (\(label))")
                // 既定の表示は下地を持たず、標準の読み込み中の表示の大きさそのもの。
                if let spinner = activityIndicatorFrame(controller, in: window) {
                    XCTAssertEqual(frame.size.width, spinner.size.width, accuracy: 0.5, "下地が付いています (\(label))")
                    XCTAssertEqual(frame.size.height, spinner.size.height, accuracy: 0.5, "下地が付いています (\(label))")
                } else {
                    XCTFail("標準の読み込み中の表示がありません (\(label))")
                }
                frames.append(frame)

                // スクロールしても表示範囲の同じ位置に留まり、項目がその裏を流れる。
                Support.scroll(controller, to: 600)
                XCTAssertEqual(indicatorFrame(controller, in: window) ?? .zero, frame, "スクロールで動いています (\(label))")
                Support.scroll(controller, to: 1_200)
                XCTAssertEqual(indicatorFrame(controller, in: window) ?? .zero, frame, "スクロールで動いています (\(label))")
            }
            XCTAssertEqual(Set(frames.map { $0.maxY }).count, 1, "下の余白で位置が変わっています (\(name)): \(frames)")
        }
    }

    // 下端の安全領域に重ならない置き方では、表示の下端は見えている範囲の下端から間隔の分だけ上にある。
    // 全画面に広げた一覧では、下端の安全領域の分だけさらに上がる。
    func test追加読み込み中の表示は下端の安全領域の分だけ上がる() async {
        let insideSize = CGSize(width: 390, height: 800)
        let inside = makeController(rows: makeRows(60), state: .appending, layout: .list, bottomPadding: 40)
        let insideWindow = Support.show(inside, size: insideSize)
        defer { insideWindow.isHidden = true }
        XCTAssertEqual(inside.collectionView.safeAreaInsets.bottom, 0, "下端の安全領域に重なっています")
        await Support.waitForItems(60, in: inside)
        await Support.waitUntil("読み込み中の表示", value: { self.indicatorFrame(inside, in: insideWindow) }) { $0 != nil }
        let spacing = KsCollectionViewController<KsPagingRow>.pagingIndicatorBottomSpacing
        XCTAssertEqual(indicatorFrame(inside, in: insideWindow)?.maxY ?? 0, insideSize.height - spacing, accuracy: 0.5)
        insideWindow.isHidden = true

        let full = makeController(rows: makeRows(60), state: .appending, layout: .list, bottomPadding: 40)
        let fullWindow = Support.show(full, size: Self.size)
        defer { fullWindow.isHidden = true }
        let safeBottom = full.collectionView.safeAreaInsets.bottom
        XCTAssertGreaterThan(safeBottom, 0)
        await Support.waitForItems(60, in: full)
        await Support.waitUntil("読み込み中の表示", value: { self.indicatorFrame(full, in: fullWindow) }) { $0 != nil }
        XCTAssertEqual(indicatorFrame(full, in: fullWindow)?.maxY ?? 0, Self.size.height - safeBottom - spacing, accuracy: 0.5)
    }

    func test待機に戻ると消えフッターの枠の高さは追加読み込み中の間も変わらない() async {
        for (name, layout) in Self.layouts {
            let rows = makeRows(60)
            let controller = makeController(rows: rows, state: .idle, layout: layout, bottomPadding: 24)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(60, in: controller)
            await Support.scrollToBottom(controller)
            let footerHeight = Support.rootFooterFrame(in: controller)?.height ?? -1
            let offset = controller.collectionView.contentOffset.y
            XCTAssertFalse(controller.isPagingIndicatorShown)

            controller.update(configuration: makeConfiguration(rows: rows, state: .appending, layout: layout, bottomPadding: 24))
            XCTAssertTrue(controller.isPagingIndicatorShown, "\(name)")
            await Support.settleLayout(controller)
            XCTAssertEqual(Support.rootFooterFrame(in: controller)?.height ?? -1, footerHeight, accuracy: 0.5, "フッターの枠の高さが変わっています (\(name))")
            XCTAssertEqual(controller.collectionView.contentOffset.y, offset, accuracy: 0.5, "表示範囲が動いています (\(name))")

            controller.update(configuration: makeConfiguration(rows: rows, state: .idle, layout: layout, bottomPadding: 24))
            XCTAssertFalse(controller.isPagingIndicatorShown, "\(name)")
            await Support.waitUntil("読み込み中の表示が消える (\(name))", value: {
                controller.pagingIndicatorView?.isHidden ?? true
            }) { $0 }
            XCTAssertEqual(Support.rootFooterFrame(in: controller)?.height ?? -1, footerHeight, accuracy: 0.5, "\(name)")
        }
    }

    func test出るときと消えるときは短くフェードする() async {
        let rows = makeRows(60)
        let controller = makeController(rows: rows, state: .idle, layout: .list, bottomPadding: 0)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(60, in: controller)

        controller.update(configuration: makeConfiguration(rows: rows, state: .appending, layout: .list, bottomPadding: 0))
        guard let indicator = controller.pagingIndicatorView else {
            XCTFail("読み込み中の表示がありません")
            return
        }
        XCTAssertNotNil(indicator.layer.animation(forKey: "opacity"), "出るときにフェードしていません")
        await Support.waitUntil("出るフェードの終わり", value: { indicator.layer.animation(forKey: "opacity") == nil }) { $0 }
        XCTAssertEqual(indicator.alpha, 1)

        controller.update(configuration: makeConfiguration(rows: rows, state: .idle, layout: .list, bottomPadding: 0))
        XCTAssertNotNil(indicator.layer.animation(forKey: "opacity"), "消えるときにフェードしていません")
        XCTAssertFalse(indicator.isHidden, "フェードの前に消えています")
        await Support.waitUntil("消えるフェードの終わり", value: { indicator.isHidden }) { $0 }
    }

    // MARK: - タッチ

    func test既定の表示はタッチを受けず下の項目のタップが届く() async {
        var tapped: [Int] = []
        var configuration = makeConfiguration(rows: makeRows(60), state: .appending, layout: .list, bottomPadding: 0)
        configuration.onItemTap = { tapped.append($0.id) }
        let controller = KsCollectionViewController(configuration: configuration)
        let window = Support.show(controller, size: Self.size)
        defer { window.isHidden = true }
        await Support.waitForItems(60, in: controller)
        await Support.settleLayout(controller)
        await Support.waitUntil("読み込み中の表示", value: { self.indicatorFrame(controller, in: window) }) { $0 != nil }
        guard let frame = indicatorFrame(controller, in: window), let indicator = controller.pagingIndicatorView else { return }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        let hit = window.hitTest(center, with: nil)
        XCTAssertFalse(hit.map { $0.isDescendant(of: indicator) } ?? true, "既定の表示がタッチを受けています")
        let point = controller.collectionView.convert(center, from: window)
        guard let indexPath = controller.collectionView.indexPathForItem(at: point) else {
            XCTFail("表示の下に項目がありません")
            return
        }
        XCTAssertTrue(hit.map { $0.isDescendant(of: controller.collectionView) } ?? false)
        controller.collectionView(controller.collectionView, didSelectItemAt: indexPath)
        XCTAssertEqual(tapped.count, 1, "下の項目のタップが届いていません")
    }

    func test差し替えた表示は同じ置き場に下地なしで出てその範囲だけタッチを受ける() async {
        for (name, layout) in Self.layouts {
            let controller = KsCollectionViewController(
                configuration: makeConfiguration(rows: makeRows(60), state: .appending, layout: layout, bottomPadding: 40, replaces: true)
            )
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            let safeBottom = controller.collectionView.safeAreaInsets.bottom
            await Support.waitForItems(60, in: controller)
            await Support.settleLayout(controller)
            await Support.waitUntil("差し替えた表示 (\(name))", value: {
                Support.probeLabels(in: controller.pagingIndicatorView)
            }) { $0 == ["読み込み中"] }
            guard let indicator = controller.pagingIndicatorView, let content = indicator.hostedContentView else { continue }
            indicator.layoutIfNeeded()
            let frame = content.convert(content.bounds, to: window)
            let expectedBottom = Self.size.height - safeBottom
                - KsCollectionViewController<KsPagingRow>.pagingIndicatorBottomSpacing
            XCTAssertEqual(frame.maxY, expectedBottom, accuracy: 0.5, "下端の位置が違います (\(name))")
            XCTAssertEqual(frame.midX, Self.size.width / 2, accuracy: 0.5, "\(name)")
            XCTAssertEqual(frame.size.width, KsPagingIndicatorTests.customSize.width, accuracy: 0.5, "下地が付いています (\(name))")
            XCTAssertEqual(frame.size.height, KsPagingIndicatorTests.customSize.height, accuracy: 0.5, "下地が付いています (\(name))")
            XCTAssertFalse(Support.containsActivityIndicator(in: indicator), "既定の読み込み中の表示が出ています (\(name))")

            // 表示の範囲はタッチを受け、外は下の一覧へ通す。
            let inside = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
            XCTAssertTrue(inside.map { $0.isDescendant(of: indicator) } ?? false, "差し替えた表示がタッチを受けていません (\(name))")
            let outside = window.hitTest(CGPoint(x: 20, y: frame.midY), with: nil)
            XCTAssertFalse(outside.map { $0.isDescendant(of: indicator) } ?? true, "表示の外のタッチを受けています (\(name))")
        }
    }

    // 差し替えた表示 (押せる部品を持たない表示と、ボタンを持つ表示) の範囲から始めた縦のドラッグで一覧が
    // スクロールできる。表示は一覧 (スクロールビュー) の子に重ねてあるため、タッチは一覧のパンのジェスチャーにも
    // 届き、一覧は中身のタッチを取り消してスクロールを始められる。表示の中身 (SwiftUI のホスティング) に当たる
    // 点で確かめるため、目印のビューは敷かない。単体テストではドラッグを合成できないため、実際にはドラッグせず、
    // タッチが一覧のパンに届き、パンが取り消しと開始を妨げられない構造になっていることだけを確かめる。
    func test差し替えた表示の範囲から始めた縦のドラッグで一覧がスクロールできる() async {
        let variants: [(String, () -> AnyView)] = [
            ("押せる部品なし", {
                AnyView(
                    Text("読み込み中")
                        .frame(width: Self.customSize.width, height: Self.customSize.height)
                )
            }),
            ("ボタンあり", {
                AnyView(
                    Button("止める") {}
                        .frame(width: Self.customSize.width, height: Self.customSize.height)
                )
            }),
        ]
        for (name, content) in variants {
            var configuration = makeConfiguration(rows: makeRows(60), state: .appending, layout: .list, bottomPadding: 0)
            configuration.pagingDisplays.appendingIndicator = content
            let controller = KsCollectionViewController(configuration: configuration)
            let window = Support.show(controller, size: Self.size)
            defer { window.isHidden = true }
            await Support.waitForItems(60, in: controller)
            await Support.settleLayout(controller)
            await Support.waitUntil("差し替えた表示 (\(name))", value: {
                controller.isPagingIndicatorShown && controller.pagingIndicatorView?.hostedContentView != nil
            }) { $0 }
            guard let indicator = controller.pagingIndicatorView, let hosted = indicator.hostedContentView else { continue }
            indicator.layoutIfNeeded()
            let frame = hosted.convert(hosted.bounds, to: window)
            XCTAssertEqual(frame.size.width, Self.customSize.width, accuracy: 0.5, "\(name)")
            let collectionView = controller.collectionView!
            // ボタンの上 (表示の真ん中) の点。
            guard let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil) else {
                XCTFail("表示の範囲に当たる部品がありません (\(name))")
                continue
            }
            // タッチは差し替えた表示の中身 (SwiftUI のホスティング) が受け、その祖先に一覧がある。
            XCTAssertTrue(hit === hosted || hit.isDescendant(of: hosted), "表示の中身に当たっていません (\(name)): \(type(of: hit))")
            XCTAssertFalse(hit is KsPagingProbeView)
            XCTAssertTrue(hit.isDescendant(of: collectionView), "タッチが一覧に届きません (\(name))")
            let pan = collectionView.panGestureRecognizer
            XCTAssertTrue(pan.isEnabled && collectionView.isScrollEnabled, "\(name)")
            XCTAssertTrue(pan.view === collectionView)
            // 一覧は、表示の中のタッチを取り消してスクロールを始められる。
            XCTAssertTrue(collectionView.touchesShouldCancel(in: hit), "表示の中のタッチを取り消せません (\(name))")
            // 表示から一覧までの間に、一覧のパンに自分の失敗を待たせる (パンより先にタッチを取る) 認識器が無い。
            var current: UIView? = hit
            while let view = current {
                for recognizer in view.gestureRecognizers ?? [] where recognizer !== pan && recognizer.isEnabled {
                    XCTAssertFalse(
                        Self.panWaitsForFailure(of: recognizer, pan: pan),
                        "\(type(of: recognizer)) が一覧のパンを待たせます (\(name))"
                    )
                }
                if view === collectionView { break }
                current = view.superview
            }
        }
    }

    // 一覧のパンが、その認識器の失敗を待たされるか (パンの側から見た向き)。認識器の側が「パンに失敗を待たせる」
    // と答えるか、パンの側が「その認識器の失敗を待つ」と答えるか、どちらかの代理がそう答えるとき。
    private static func panWaitsForFailure(of recognizer: UIGestureRecognizer, pan: UIGestureRecognizer) -> Bool {
        recognizer.shouldBeRequiredToFail(by: pan)
            || pan.shouldRequireFailure(of: recognizer)
            || (recognizer.delegate?.gestureRecognizer?(recognizer, shouldBeRequiredToFailBy: pan) ?? false)
            || (pan.delegate?.gestureRecognizer?(pan, shouldRequireFailureOf: recognizer) ?? false)
    }

    // MARK: - 部品

    private static let customSize = CGSize(width: 120, height: 30)

    private func makeRows(_ count: Int) -> [KsPagingRow] {
        (0..<count).map { KsPagingRow(id: $0) }
    }

    private func makeConfiguration(
        rows: [KsPagingRow],
        state: KsPagingState,
        layout: KsCollectionLayout,
        bottomPadding: CGFloat,
        replaces: Bool = false
    ) -> KsCollectionConfiguration<KsPagingRow> {
        var view = KsCollectionView(
            rows,
            layout: layout,
            contentPadding: EdgeInsets(top: 0, leading: 0, bottom: bottomPadding, trailing: 0)
        ) { row in
            KsPagingFixedView(text: "\(row.id)", height: Self.rowHeight)
        }
        .paging(state) {}
        if replaces {
            view = view.pagingAppendingIndicator {
                Text("読み込み中")
                    .frame(width: Self.customSize.width, height: Self.customSize.height)
                    .background(KsPagingProbeRepresentable(label: "読み込み中"))
            }
        }
        var configuration = view.configuration
        configuration.showsSeparators = false
        return configuration
    }

    private func makeController(
        rows: [KsPagingRow],
        state: KsPagingState,
        layout: KsCollectionLayout,
        bottomPadding: CGFloat
    ) -> KsCollectionViewController<KsPagingRow> {
        KsCollectionViewController(
            configuration: makeConfiguration(rows: rows, state: state, layout: layout, bottomPadding: bottomPadding)
        )
    }

    // 表示の中の標準の読み込み中の部品のウインドウ上の位置。
    private func activityIndicatorFrame(_ controller: KsCollectionViewController<KsPagingRow>, in window: UIWindow) -> CGRect? {
        func find(_ view: UIView) -> UIActivityIndicatorView? {
            if let indicator = view as? UIActivityIndicatorView { return indicator }
            for subview in view.subviews {
                if let found = find(subview) { return found }
            }
            return nil
        }
        guard let indicator = controller.pagingIndicatorView.flatMap(find) else { return nil }
        return indicator.convert(indicator.bounds, to: window)
    }

    // 既定の読み込み中の表示のウインドウ上の位置。出ていなければ nil。
    private func indicatorFrame(_ controller: KsCollectionViewController<KsPagingRow>, in window: UIWindow) -> CGRect? {
        guard
            controller.isPagingIndicatorShown,
            let indicator = controller.pagingIndicatorView,
            let content = indicator.hostedContentView,
            Support.containsActivityIndicator(in: indicator)
        else {
            return nil
        }
        indicator.layoutIfNeeded()
        return content.convert(content.bounds, to: window)
    }
}
#endif
