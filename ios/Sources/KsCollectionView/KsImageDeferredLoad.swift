import Nuke
import NukeUI
import SwiftUI
import UIKit

// 組み立ての時点でメモリから引き当てられず、かつ同じ画像の先読みが取得中の可能性がある `KsImage` の表示。
// ローダーへの要求は画面に出る時点まで始めず、画面に出る時点でもう一度メモリを照会する。
//
// コレクションのセルは画面に出る前に前もって組み立てられることがあり、組み立ての時点で未完了の
// 先読みが、画面に出る時点では完了していることが多い。組み立ての時点の照会だけで要求を出す形にすると、
// 先読みで載った項目があるのに読み込み中を経由して、ディスクからデコードし直してしまう。
//
// 画面に出る時点の処理を軽くするため、中身の種類は入れ替えない。ローダーの読み込み状態 (`FetchImage`)
// を最初から持ち、画面に出るまでは要求を出さずに読み込み中の表示を置く。画面に出る時点の照会で使える
// 項目があれば、要求を出さずにその項目で表示する。無ければ、その場で同じ読み込み状態に要求を渡す
// (ローダー付属の `LazyImage` が画面に出る時点で要求を始めるのと同じ動き)。画面から出たときは要求を
// 取り消し (表示済みの画像は残る)、戻ってきたときはもう一度照会してから要求を出し直す。
//
// 状態は引き当ての条件 (枠の大きさ・表示倍率・当てはめ方・世代) ごとに持つ。呼び出し側が条件を識別子として
// 付け、条件が変われば状態を捨てて画面に出る時点の引き当てからやり直させる。
internal struct KsImageDeferredLoad<Placeholder: View, Matched: View, Loaded: View, Failure: View>: View {
    // 引き当てに外れたときに出す要求。
    let request: ImageRequest
    // 画面に出る時点の照会。使える画像があれば返す。
    let rematch: @MainActor () -> UIImage?
    @ViewBuilder let placeholder: @MainActor () -> Placeholder
    @ViewBuilder let matched: @MainActor (UIImage) -> Matched
    @ViewBuilder let loaded: @MainActor (Image) -> Loaded
    @ViewBuilder let failure: @MainActor () -> Failure

    @StateObject private var fetch = FetchImage()
    // 画面に出る時点の照会で引き当てた画像。あればローダーを通さずにこれで表示する。
    @State private var matchedImage: UIImage?

    var body: some View {
        ZStack {
            if let matchedImage {
                matched(matchedImage)
            } else if let image = fetch.image {
                loaded(image)
            } else if case .failure = fetch.result {
                failure()
            } else {
                placeholder()
            }
        }
        .onAppear(perform: appeared)
        .onDisappear(perform: disappeared)
    }

    private func appeared() {
        guard matchedImage == nil else { return }
        if let image = rematch() {
            matchedImage = image
            return
        }
        fetch.load(request)
    }

    private func disappeared() {
        fetch.cancel()
    }
}
