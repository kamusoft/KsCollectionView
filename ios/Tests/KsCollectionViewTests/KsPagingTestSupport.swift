#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

// ページングの結合テストが共有する部品。一覧を実際のウインドウに載せ、実レイアウトの上で次ページ要求・
// 表示・位置・Pull to Refresh を確かめる。

// ページングの試験に使う項目。
struct KsPagingRow: Identifiable, Equatable {
    let id: Int
    var group: Int = 0
}

// 処理の終わりを試験の側で決めるための門。`open()` を呼ぶまで待つ処理は戻らない。
@MainActor
final class KsPagingGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private(set) var isOpen = false
    private(set) var cancelledWhileWaiting = false
    private(set) var waitingCount = 0

    func wait() async {
        guard !isOpen else { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waitingCount += 1
                continuations.append(continuation)
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelledWhileWaiting = true
                self.open()
            }
        }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}

// 次ページ要求・取り直しの処理が呼ばれた回数を数え、必要なら門で待たせる。
@MainActor
final class KsPagingProbe {
    private(set) var loadMoreCount = 0
    private(set) var refreshCount = 0
    var loadMoreGate: KsPagingGate?
    var refreshGate: KsPagingGate?
    // 次ページ要求の処理の中で行うこと (配列と状態の書き換えなど)。
    var onLoadMore: (() -> Void)?
    var onRefresh: (() -> Void)?

    var loadMoreAction: @MainActor () async -> Void {
        { [weak self] in
            guard let self else { return }
            loadMoreCount += 1
            onLoadMore?()
            if let gate = loadMoreGate {
                await gate.wait()
            }
        }
    }

    var refreshAction: @MainActor () async -> Void {
        { [weak self] in
            guard let self else { return }
            refreshCount += 1
            onRefresh?()
            if let gate = refreshGate {
                await gate.wait()
            }
        }
    }
}

// 高さを固定した行。
struct KsPagingFixedView: View {
    let text: String
    let height: CGFloat

    var body: some View {
        Text(text).frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
    }
}

// 中身の中に敷く目印のビュー。表示の中身を見分けるために使う。
final class KsPagingProbeView: UIView {
    var label = ""
}

struct KsPagingProbeRepresentable: UIViewRepresentable {
    let label: String

    func makeUIView(context: Context) -> KsPagingProbeView {
        let view = KsPagingProbeView()
        view.label = label
        return view
    }

    func updateUIView(_ uiView: KsPagingProbeView, context: Context) {
        uiView.label = label
    }
}

// 目印のついた表示。高さを固定し、目印を背景に敷く。
struct KsPagingLabeledView: View {
    let label: String
    var height: CGFloat = 40

    var body: some View {
        Text(label)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(KsPagingProbeRepresentable(label: label))
    }
}

@MainActor
enum KsPagingTestSupport {
    static func show(_ controller: UIViewController, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    // 目印のラベルの一覧。
    static func probeLabels(in view: UIView?) -> [String] {
        guard let view else { return [] }
        var labels: [String] = []
        if let probe = view as? KsPagingProbeView {
            labels.append(probe.label)
        }
        for subview in view.subviews where !subview.isHidden {
            labels.append(contentsOf: probeLabels(in: subview))
        }
        return labels
    }

    // 標準の読み込み中の表示 (円形の読み込み中の表示) があるか。
    static func containsActivityIndicator(in view: UIView?) -> Bool {
        guard let view, !view.isHidden else { return false }
        if view is UIActivityIndicatorView {
            return true
        }
        return view.subviews.contains { containsActivityIndicator(in: $0) }
    }

    static func rootFooterView<Item>(in controller: KsCollectionViewController<Item>) -> KsHostingSupplementaryView? {
        controller.collectionView.visibleSupplementaryViews(ofKind: KsSupplementaryKind.rootFooter)
            .compactMap { $0 as? KsHostingSupplementaryView }
            .first
    }

    // ルートのフッターの枠のレイアウト上の位置。レイアウト全体の補助ビューは 1 要素の位置で指す。
    static func rootFooterFrame<Item>(in controller: KsCollectionViewController<Item>) -> CGRect? {
        controller.collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(
            ofKind: KsSupplementaryKind.rootFooter,
            at: IndexPath(index: 0)
        )?.frame
    }

    static func itemFrame<Item>(offset: Int, in controller: KsCollectionViewController<Item>) -> CGRect? {
        guard let indexPath = ksIndexPathIfPresent(forItemOffset: offset, in: controller.collectionView) else {
            return nil
        }
        return controller.collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
    }

    static func bottomOffset<Item>(in controller: KsCollectionViewController<Item>) -> CGFloat {
        let collectionView = controller.collectionView!
        let insets = collectionView.adjustedContentInset
        let contentHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
        return max(-insets.top, contentHeight + insets.bottom - collectionView.bounds.height)
    }

    // 位置を動かしてレイアウトを確定させる (次ページ要求の判定はレイアウトの確定時に行われる)。
    static func scroll<Item>(_ controller: KsCollectionViewController<Item>, to offset: CGFloat) {
        controller.collectionView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        controller.collectionView.layoutIfNeeded()
    }

    // 末尾まで送り、自己サイズの解き直しで末尾が動かなくなるまで送り直す。
    static func scrollToBottom<Item>(_ controller: KsCollectionViewController<Item>) async {
        for _ in 0..<6 {
            await settleLayout(controller)
            let bottom = bottomOffset(in: controller)
            if abs(controller.collectionView.contentOffset.y - bottom) < 0.5 {
                return
            }
            scroll(controller, to: bottom)
        }
        XCTFail("末尾まで送れませんでした")
    }

    static func waitForItems<Item>(_ count: Int, in controller: KsCollectionViewController<Item>) async {
        await waitUntil("\(count) 件の snapshot の適用", value: { controller.appliedItemIdentifiers.count }) {
            $0 == count
        }
        controller.collectionView.layoutIfNeeded()
    }

    // 差分のアニメーションと自己サイズの解き直しが止まり、内容の高さと表示位置が動かなくなるまで待つ。
    static func settleLayout<Item>(_ controller: KsCollectionViewController<Item>) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        var last = (controller.collectionView.contentSize.height, controller.collectionView.contentOffset.y)
        var quietSince = clock.now
        while clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            controller.collectionView.layoutIfNeeded()
            let current = (controller.collectionView.contentSize.height, controller.collectionView.contentOffset.y)
            if current != last {
                last = current
                quietSince = clock.now
            } else if clock.now - quietSince >= .milliseconds(300) {
                return
            }
        }
        XCTFail("内容の高さと表示位置が期限内に静止しませんでした。実測値: \(last)")
    }

    static func waitUntil<Value>(
        _ label: String,
        timeout: Duration = .seconds(3),
        value: () -> Value,
        file: StaticString = #filePath,
        line: UInt = #line,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if predicate(value()) {
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))", file: file, line: line)
    }

    // 待ちたい変化が起きないことを確かめるために、実行機会を一定時間譲る。
    static func yield(for duration: Duration = .milliseconds(150)) async {
        try? await Task.sleep(for: duration)
    }
}
#endif
