import SwiftUI

struct RootMenuView: View {
    /// 外観の選択。`UserDefaults` に保存され、起動し直しても残る。window への反映は
    /// ``KsCollectionViewSamplesApp`` が同じキーを読んで起動の分岐より上で行う。
    @AppStorage(SampleAppearance.storageKey) private var appearance = SampleAppearance.initial

    var body: some View {
        NavigationStack {
            List {
                // 見出しと隙間は行として置く (plain の List の見出しは上端に固定され、スクロールしても
                // 「外観」がデモ画面の項目の上に残るため)。
                SampleMenuHeadingRow(title: SampleAppearance.sectionTitle)
                ForEach(SampleAppearance.allCases) { entry in
                    SampleAppearanceRow(appearance: entry, selection: $appearance)
                        .listRowBackground(SampleTheme.cell)
                }
                SampleMenuGapRow()
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
            .environment(\.defaultMinListRowHeight, 0)
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
