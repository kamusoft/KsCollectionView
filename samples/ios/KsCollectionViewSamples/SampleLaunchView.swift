import KsCollectionView
import SwiftUI

struct SampleLaunchView: View {
    private let verifiesInteractiveControl = ProcessInfo.processInfo.arguments.contains(
        "--verify-interactive-control"
    )
    private let verifiesPerformance = ProcessInfo.processInfo.arguments.contains(
        "--verify-performance"
    )
    private let automaticallyVerifiesPerformance = ProcessInfo.processInfo.arguments.contains(
        "--verify-performance-auto"
    )
    private let verifiesImageBehavior = ProcessInfo.processInfo.arguments.contains(
        "--verify-image-behavior"
    )
    private let automaticallyVerifiesImagePerformance = ProcessInfo.processInfo.arguments.contains(
        "--verify-image-performance-auto"
    )
    /// 画像の土俵で使うプリフェッチの到達点。`none` は宣言しない。
    private let requestedPrefetch = ProcessInfo.processInfo.arguments
        .drop { $0 != "--prefetch" }
        .dropFirst()
        .first
    private let verifiesLongPress = ProcessInfo.processInfo.arguments.contains(
        "--verify-long-press"
    )
    private let verifiesTapOnly = ProcessInfo.processInfo.arguments.contains(
        "--verify-tap-only"
    )
    private let verifiesHeightChange = ProcessInfo.processInfo.arguments.contains(
        "--verify-height-change"
    )
    private let requestedScreen = ProcessInfo.processInfo.arguments
        .drop { $0 != "--screen" }
        .dropFirst()
        .first

    /// 起動引数の到達点を値に読み替える。指定が無ければデモ画面の初期選択に合わせる。
    private var prefetchDestination: KsPrefetchDestination? {
        switch requestedPrefetch {
        case "none": nil
        case "memory": .memory
        default: .disk
        }
    }

    var body: some View {
        if verifiesInteractiveControl {
            InteractiveControlVerificationView()
        } else if verifiesLongPress || verifiesTapOnly {
            LongPressVerificationView(declaresLongTap: verifiesLongPress)
        } else if verifiesHeightChange {
            NavigationStack {
                VerificationDestinationView(screen: .heightChange)
            }
            .tint(SampleTheme.accent)
        } else if verifiesImageBehavior {
            ImageBehaviorVerificationView()
        } else if automaticallyVerifiesImagePerformance {
            PerformanceVerificationView(
                automaticallyRuns: true,
                fixture: .imageGrid(destination: prefetchDestination)
            )
        } else if verifiesPerformance || automaticallyVerifiesPerformance {
            PerformanceVerificationView(automaticallyRuns: automaticallyVerifiesPerformance)
        } else if let requestedScreen,
           let screen = SampleScreen.allCases.first(where: { $0.rawValue == requestedScreen }) {
            NavigationStack {
                SampleDestinationView(screen: screen)
            }
            .tint(SampleTheme.accent)
        } else {
            RootMenuView()
        }
    }
}
