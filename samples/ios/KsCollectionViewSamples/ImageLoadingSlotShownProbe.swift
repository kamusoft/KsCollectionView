import SwiftUI
import UIKit

/// 読み込み中の表示が画面に出たことを知らせる、見た目を持たない下敷きです。
///
/// 読み込み中の表示は、画面に出る前に組み立てられても、画面に出る時点で先読みの画像に替わって
/// 1 度も画面に出ないまま消えることがあります。組み立ての回数ではこの 2 つを見分けられないため、
/// 画面の更新の周期ごとに、この下敷きが見える位置にあるかを確かめます
/// (``ImageLoadingSlotShownMonitor``)。
///
/// 描かれたかどうかでは判定しません。コレクションは画面に出す前のセルを隠したまま窓の中で
/// 描かせることがあり、描画の回数は画面に出たかどうかと一致しないためです。
///
/// 数えることが要求された構成 (``ImageLoadingSlotCounter/isEnabled``) でだけ使います。
struct ImageLoadingSlotShownProbe: UIViewRepresentable {
    /// 初めて画面に出たときに 1 度だけ呼ばれます。
    let onFirstShown: @MainActor () -> Void

    func makeUIView(context: Context) -> ImageLoadingSlotShownProbeView {
        ImageLoadingSlotShownProbeView(onFirstShown: onFirstShown)
    }

    func updateUIView(_ uiView: ImageLoadingSlotShownProbeView, context: Context) {}
}
