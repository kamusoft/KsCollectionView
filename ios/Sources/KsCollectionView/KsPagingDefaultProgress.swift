import SwiftUI

// 項目が 0 件のときの既定の読み込み中の表示。標準の円形の読み込み中の表示をそのまま使い、文言・色・大きさは
// システムの既定に任せる (core/ADR-0024)。
internal struct KsPagingDefaultProgress: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }
}
