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
    private let probesImagePrefetchMatch = ProcessInfo.processInfo.arguments.contains(
        "--verify-image-prefetch-match-auto"
    )
    private let verifiesSlotShownClipping = ProcessInfo.processInfo.arguments.contains(
        "--verify-slot-shown-clipping"
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
    private let requestedScreen = SampleScreen.requested(arguments: ProcessInfo.processInfo.arguments)

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
        } else if verifiesSlotShownClipping {
            ImageLoadingSlotShownClippingView()
        } else if probesImagePrefetchMatch {
            ImagePrefetchMatchProbeView()
        } else if automaticallyVerifiesImagePerformance {
            PerformanceVerificationView(
                automaticallyRuns: true,
                fixture: .imageGrid(prefetch: ImagePrefetchChoice.resolved)
            )
        } else if verifiesPerformance || automaticallyVerifiesPerformance {
            PerformanceVerificationView(
                automaticallyRuns: automaticallyVerifiesPerformance,
                fixture: PerformanceFixture.requested
            )
        } else if let requestedScreen {
            NavigationStack {
                SampleDestinationView(screen: requestedScreen)
            }
            .tint(SampleTheme.accent)
        } else {
            RootMenuView()
        }
    }
}
