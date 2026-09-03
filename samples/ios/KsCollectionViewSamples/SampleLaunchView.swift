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
