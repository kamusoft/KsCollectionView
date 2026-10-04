import SwiftUI

// 既定の読み込み中の表示。次のページの読み込み中 (一覧の見えている範囲の下端に重ねる) と、項目が 0 件の
// ときの最初の読み込み中 (一覧の真ん中) の両方に使う。標準の円形の読み込み中の表示をそのまま使い、
// 下地は付けず、文言・大きさはシステムの既定に任せる (core/ADR-0024)。
//
// 色は、一覧に指定した読み込み中の表示の色で描く。指定が無い (nil) ときは色を付けず、親の View に付けた
// tint に従うシステムの既定のままにする (core/ADR-0035)。
internal struct KsPagingDefaultProgress: View {
    let color: UIColor?

    var body: some View {
        if let color {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(color))
        } else {
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}
