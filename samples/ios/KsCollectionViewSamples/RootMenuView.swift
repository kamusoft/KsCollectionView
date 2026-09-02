import SwiftUI

struct RootMenuView: View {
    var body: some View {
        NavigationStack {
            List(SampleScreen.allCases) { screen in
                NavigationLink(screen.rawValue, value: screen)
                    .listRowBackground(SampleTheme.cell)
                    .foregroundStyle(SampleTheme.text)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SampleTheme.background)
            .navigationTitle("KsCollectionView Samples")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SampleScreen.self) { screen in
                SampleDestinationView(screen: screen)
            }
        }
        .tint(SampleTheme.accent)
    }
}
