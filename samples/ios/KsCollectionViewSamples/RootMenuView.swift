import SwiftUI

struct RootMenuView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(SampleScreen.allCases) { screen in
                    NavigationLink(screen.rawValue, value: screen)
                        .listRowBackground(SampleTheme.cell)
                        .foregroundStyle(SampleTheme.text)
                }
                ForEach(VerificationScreen.allCases) { screen in
                    NavigationLink(screen.rawValue, value: screen)
                        .listRowBackground(SampleTheme.cell)
                        .foregroundStyle(SampleTheme.text)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SampleTheme.background)
            .navigationTitle("KsCollectionView Samples")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SampleScreen.self) { screen in
                SampleDestinationView(screen: screen)
            }
            .navigationDestination(for: VerificationScreen.self) { screen in
                VerificationDestinationView(screen: screen)
            }
        }
        .tint(SampleTheme.accent)
    }
}
