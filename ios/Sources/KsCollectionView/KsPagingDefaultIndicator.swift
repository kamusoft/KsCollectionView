import SwiftUI

// 次のページの読み込み中の既定の表示。一覧の見えている範囲の下端に重ねる、標準の円形の読み込み中の表示。
// 下地は付けず、文言・色・大きさはシステムの既定に任せる (core/ADR-0024)。
internal struct KsPagingDefaultIndicator: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }
}
