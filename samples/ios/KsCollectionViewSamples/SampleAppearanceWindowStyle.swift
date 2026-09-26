import SwiftUI

extension View {
    /// 外観の選択を、この View が載る window の `overrideUserInterfaceStyle` として掛ける。
    ///
    /// SwiftUI の `preferredColorScheme` は、上書きありから上書きなし (nil) へ戻した後に
    /// 表示したまま端末の表示モードが変わると、ナビゲーションバーの題名・戻るボタン・
    /// ステータスバーが前の配色のまま残る。window の上書きなら「システム」を `.unspecified` と
    /// して表せ、以後の端末の表示モードの変化が OS の部品を含む全体へそのまま伝わる。
    func sampleAppearanceWindowStyle(_ appearance: SampleAppearance) -> some View {
        background(SampleWindowAppearanceApplier(style: appearance.userInterfaceStyle))
    }
}
