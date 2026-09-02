import SwiftUI

struct SampleDestinationView: View {
    let screen: SampleScreen

    var body: some View {
        Group {
            switch screen {
            case .list:
                ListDemoView()
            case .fixedGrid:
                FixedGridDemoView()
            case .adaptiveGrid:
                AdaptiveGridDemoView()
            case .orientationGrid:
                OrientationGridDemoView()
            case .templates:
                TemplateSwitchDemoView()
            case .headerFooter:
                HeaderFooterDemoView()
            case .scrolling:
                ScrollControlDemoView()
            case .spacing:
                SpacingPaddingDemoView()
            case .largeData:
                LargeDataDemoView()
            }
        }
        .navigationTitle(screen.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .background(SampleTheme.background)
    }
}
