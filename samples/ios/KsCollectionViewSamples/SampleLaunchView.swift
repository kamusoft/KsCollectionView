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

    /// 画像の土俵で使うプリフェッチの到達点。`nil` は宣言しないことを表す。
    private var prefetchDestination: KsPrefetchDestination? {
        ImagePrefetchChoice.resolved.destination
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
