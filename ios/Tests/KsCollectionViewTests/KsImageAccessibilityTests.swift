import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// `KsImage` の既定の表示が読み上げへ何を差し出すかを確かめる。
///
/// 既定の失敗表示に置かれた印は「画像が無いこと」を目で示すための飾りであり、名前を読み上げても
/// 利用者の役に立たない。一方で、利用者が付けた説明は読み込み中・失敗のどちらの状態でも
/// 読み上げに残らなければならない。この 2 つを両方確かめる。
///
/// SwiftUI が読み上げの木を組み立てるのは、その処理系でアクセシビリティが動いているときだけである。
/// 素の xctest では動いていないため木が空になり、名前を数えるアサーションは中身を見ないまま
/// 「0 件」を返す。木を実体化させてから測るために、各テストの前でアクセシビリティを入れる。
@MainActor
final class KsImageAccessibilityTests: XCTestCase {
    private var windows: [UIWindow] = []
    private let frame = CGSize(width: 40, height: 40)
    private var previousAutomationEnabled: Bool?

    override func setUp() async throws {
        try await super.setUp()
        previousAutomationEnabled = try AccessibilityAutomation.isEnabled()
        try AccessibilityAutomation.setEnabled(true)
    }

    override func tearDown() async throws {
        if let previousAutomationEnabled {
            try? AccessibilityAutomation.setEnabled(previousAutomationEnabled)
            self.previousAutomationEnabled = nil
        }
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
        try await super.tearDown()
    }

    // MARK: - 説明が無いとき

    func test失敗の既定表示は読み上げる名前を作らない() throws {
        try assertAccessibilityTreeIsMaterialized()
        let host = show(KsImageDefaultFailureView())

        let labels = Self.accessibilityLabels(in: host)

        XCTAssertEqual(labels, [], "失敗の既定表示が読み上げる名前を作りました: \(labels)")
    }

    func test読み込み中の既定表示は読み上げる名前を作らない() throws {
        try assertAccessibilityTreeIsMaterialized()
        let host = show(KsImageDefaultLoadingView())

        let labels = Self.accessibilityLabels(in: host)

        XCTAssertEqual(labels, [], "読み込み中の既定表示が読み上げる名前を作りました: \(labels)")
    }

    // MARK: - 説明を付けたとき

    func test利用者が付けた説明は失敗の表示でも読み上げられる() throws {
        let host = show(KsImageDefaultFailureView().accessibilityLabel(Self.label))

        let labels = Self.accessibilityLabels(in: host)

        XCTAssertEqual(labels, [Self.label], "失敗の表示で説明が失われました: \(labels)")
    }

    func test利用者が付けた説明は読み込み中の表示でも読み上げられる() throws {
        let host = show(KsImageDefaultLoadingView().accessibilityLabel(Self.label))

        let labels = Self.accessibilityLabels(in: host)

        XCTAssertEqual(labels, [Self.label], "読み込み中の表示で説明が失われました: \(labels)")
    }

    /// 解決できないリソース名は失敗の表示になる。ローダーを通らないので同期で結果が出る。
    func test説明を付けた画像は失敗の状態でもその説明を読み上げる() throws {
        let host = show(KsImage(.asset("ks-nonexistent-asset")).accessibilityLabel(Self.label))

        let labels = Self.accessibilityLabels(in: host)

        XCTAssertEqual(labels, [Self.label], "失敗の状態で説明が失われました: \(labels)")
    }

    // MARK: - 読み上げの性格 (trait)

    /// 成功の表示は画像として読み上げられるため、既定の読み込み中・失敗も同じ性格にする。
    /// 揃えないと、同じ要素が状態によって画像になったりならなかったりする。
    func test既定の表示は状態によらず画像として読み上げられる() throws {
        for (name, host) in [
            ("読み込み中", show(KsImageDefaultLoadingView())),
            ("失敗", show(KsImageDefaultFailureView())),
        ] {
            let traits = Self.accessibilityTraits(in: host)

            XCTAssertFalse(traits.isEmpty, "\(name)の既定表示に読み上げの要素がありません")
            XCTAssertTrue(
                traits.allSatisfy { $0.contains(.image) },
                "\(name)の既定表示が画像として読み上げられません: \(traits)"
            )
        }
    }

    // MARK: - 補助

    private static let label = "この画像の説明"
    private static let probeLabel = "読み上げの木の実体化を確かめる印"

    /// 読み上げの木が実体化していることを確かめる。
    ///
    /// 名前が 0 件であることを期待する検査は、木が空でもそのまま通る。「名前を付ければ確かに
    /// 1 件拾える」ことを先に置いて、0 件が「作っていない」であって「測れていない」ではない
    /// ことを担保する。
    private func assertAccessibilityTreeIsMaterialized(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let host = show(
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.probeLabel)
        )

        let labels = Self.accessibilityLabels(in: host)

        XCTAssertEqual(
            labels,
            [Self.probeLabel],
            "読み上げの木が実体化していないため、名前を数える検査が空振りします: \(labels)",
            file: file,
            line: line
        )
    }

    private func show(_ view: some View) -> UIView {
        let host = UIHostingController(
            rootView: view.frame(width: frame.width, height: frame.height)
        )
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        windows.append(window)
        return host.view
    }

    /// 表示の中で読み上げの対象になっている要素の名前を集める。
    private static func accessibilityLabels(in view: UIView) -> [String] {
        var labels: [String] = []
        if view.isAccessibilityElement, let label = view.accessibilityLabel, !label.isEmpty {
            labels.append(label)
        }
        for element in view.accessibilityElements ?? [] {
            switch element {
            case let child as UIView:
                labels += accessibilityLabels(in: child)
            case let child as NSObject:
                if let label = child.accessibilityLabel, !label.isEmpty {
                    labels.append(label)
                }
            default:
                break
            }
        }
        for subview in view.subviews {
            labels += accessibilityLabels(in: subview)
        }
        return labels
    }

    /// 表示の中で読み上げの対象になっている要素の性格 (trait) を集める。
    /// 名前を持たない要素も読み上げの単位としては存在するため、名前の有無で絞らない。
    private static func accessibilityTraits(in view: UIView) -> [UIAccessibilityTraits] {
        var traits: [UIAccessibilityTraits] = []
        if view.isAccessibilityElement {
            traits.append(view.accessibilityTraits)
        }
        for element in view.accessibilityElements ?? [] {
            switch element {
            case let child as UIView:
                traits += accessibilityTraits(in: child)
            case let child as NSObject:
                traits.append(child.accessibilityTraits)
            default:
                break
            }
        }
        for subview in view.subviews {
            traits += accessibilityTraits(in: subview)
        }
        return traits
    }
}

/// テスト処理系のアクセシビリティを入れる / 切る。
///
/// SwiftUI が読み上げの木を組み立てるのは、その処理系でアクセシビリティが動いているときだけである。
/// 素の `xctest` では動いていないため木は空になり、木の中の名前や性格 (trait) を数える検査は
/// **中身を見ないまま 0 件**を返す。実体化の可否は Simulator 個体の設定
/// (`com.apple.Accessibility` の `AccessibilityEnabled` / `AutomationEnabled`) で決まるため、
/// 何もしないと「たまたま入っている個体でだけ緑」という状態になる。
///
/// UI テスト処理系が使うのと同じ入り口 (`libAccessibility` の automation スイッチ) を
/// `dlsym` で引いて明示的に入れることで、個体の設定に依らず木を実体化させる。
/// **テストコード専用**であり、製品コードからは呼ばない。
private enum AccessibilityAutomation {
    private typealias GetEnabled = @convention(c) () -> Bool
    private typealias SetEnabled = @convention(c) (Bool) -> Void

    // 一度開いたら処理系が終わるまで開いたままにする。書き換えないので共有しても競合しない。
    nonisolated(unsafe) private static let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW)

    /// スイッチが引けなかったときの失敗。黙って素通りさせると、木が空のまま
    /// 「0 件」を期待する検査だけが緑になるため、テストの失敗として表に出す。
    struct Unavailable: Error, CustomStringConvertible {
        let symbol: String
        var description: String {
            "アクセシビリティを入れる入り口 (\(symbol)) が見つからないため、"
                + "読み上げの木を実体化できません"
        }
    }

    static func isEnabled() throws -> Bool {
        let name = "_AXSAutomationEnabled"
        guard let handle, let symbol = dlsym(handle, name) else { throw Unavailable(symbol: name) }
        return unsafeBitCast(symbol, to: GetEnabled.self)()
    }

    static func setEnabled(_ enabled: Bool) throws {
        let name = "_AXSSetAutomationEnabled"
        guard let handle, let symbol = dlsym(handle, name) else { throw Unavailable(symbol: name) }
        unsafeBitCast(symbol, to: SetEnabled.self)(enabled)
    }
}
