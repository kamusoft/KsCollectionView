import SwiftUI

struct VerificationDestinationView: View {
    let screen: VerificationScreen

    var body: some View {
        Group {
            switch screen {
            case .heightChange:
                HeightChangeVerificationView()
            }
        }
        .navigationTitle(screen.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .background(SampleTheme.background)
    }
}
