import CoreGraphics
import Foundation
import Nuke
import UIKit

// `KsImageSource` を描画経路へ振り分けた結果。
internal enum KsImageRoute: Equatable {
    // ローダーを通す経路。リモートと端末内のファイルが該当する。
    case loader(URL)

    // アセットカタログを SwiftUI が直接読む経路。ローダーは通さない。
    case asset(String)
}

// 表示に使う要求と、メモリから引き当てた画像の組。
internal struct KsPreparedImageRequest {
    // 引き当てに失敗したときにローダーへ出す、枠の実サイズへ縮小してデコードする要求。
    let request: ImageRequest

    // メモリから引き当てた、枠にそのまま使える画像。あれば表示はこれで完了し、ローダーへは
    // 要求を出さない。無ければ nil で、`request` を出して読み込み中の表示から始まる。
    let matchedImage: UIImage?

    // 引き当てに失敗したときに、同じ識別子について取得中の可能性がある先読み (表示の要求と別の鍵のもの)
    // があるか。あれば、表示の要求は画面に出る時点の引き当ての後まで待つ価値がある。無ければ待っても
    // 引き当てられる見込みが無いので、すぐにローダーへ任せてよい。引き当てたときは常に false。
    let mayBeLoadingPrefetch: Bool
}

// 表示側の要求を組み立てる。表示枠の実サイズが確定してから、まずライブラリが把握しているメモリの
// 項目を引き当て、使えるものが無いときだけ枠の実サイズへ縮小してデコードする要求を作る。
// 縮小はデコード時に行うため、元寸の画像はメモリに展開されない。
@MainActor
internal enum KsImageRequestFactory {
    static func route(for source: KsImageSource) -> KsImageRoute {
        switch source {
        case .remote(let url, _), .file(let url): .loader(url)
        case .asset(let name): .asset(name)
        }
    }

    // 表示に使う要求を組み立て、あわせてメモリから枠にそのまま使える画像を引き当てる。
    // ローダーを通さないソースと、大きさが未確定 (0 を含む) の間は nil を返す。
    //
    // 引き当ては、索引が覚えている同じ識別子の鍵をローダーのキャッシュへ問い合わせ、返った画像の
    // 実物の寸法が枠に対して許容範囲の内側にあるものを選ぶ (`KsImageMatching`)。画素を読んで
    // 縮小し直すことはしないので、画素の置き場に関わらず成立する。
    //
    // 引き当てに失敗したときは、返す要求の鍵を索引に覚えさせる (呼び出し側がその要求を出す前提)。
    // 要求の完了は待たない。完了前の鍵は問い合わせで空になるだけで候補にならない。
    static func prepare(
        source: KsImageSource,
        size: CGSize,
        contentMode: KsImageContentMode,
        displayScale: CGFloat,
        pipeline: ImagePipeline = .shared,
        index: KsImageMemoryIndex = .shared
    ) -> KsPreparedImageRequest? {
        guard let resolved = KsImageIdentity.resolve(source) else { return nil }
        guard size.width > 0, size.height > 0, displayScale > 0 else { return nil }

        let framePixels = CGSize(width: size.width * displayScale, height: size.height * displayScale)
        let imageID = KsImageIdentity.imageID(forIdentifier: resolved.identifier)
        let effectiveID = KsImageIdentity.effectiveID(forIdentifier: resolved.identifier)
        let display = displayRequest(
            url: resolved.url, imageID: imageID, framePixels: framePixels, contentMode: contentMode
        )

        let entries = index.cachedEntries(forEffectiveID: effectiveID, in: pipeline.cache)
        if let best = KsImageMatching.bestMatch(
            among: entries.map { pixelSize(of: $0.container.image) },
            framePixels: framePixels,
            contentMode: contentMode
        ) {
            index.markUsed(entries[best].request)
            return KsPreparedImageRequest(
                request: display,
                matchedImage: entries[best].container.image,
                mayBeLoadingPrefetch: false
            )
        }

        let mayBeLoadingPrefetch = index.mayBeLoadingPrefetch(
            forEffectiveID: effectiveID, excluding: display, in: pipeline.cache
        )
        index.register(display)
        return KsPreparedImageRequest(request: display, matchedImage: nil, mayBeLoadingPrefetch: mayBeLoadingPrefetch)
    }

    // 画像のピクセル寸法。向きの情報を反映した見た目の寸法で測る。
    static func pixelSize(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    // 表示に使う要求。元データからいきなり縮小してデコードする指定を持つため、この要求で取得しても
    // 元寸はメモリに展開されない。縮小指定は鍵の一部でもあるので、同じソースでも表示サイズと
    // 当てはめ方ごとに別のキャッシュ項目になる。
    private static func displayRequest(
        url: URL,
        imageID: String?,
        framePixels: CGSize,
        contentMode: KsImageContentMode
    ) -> ImageRequest {
        var request = ImageRequest(url: url)
        request.thumbnail = ImageRequest.ThumbnailOptions(
            size: framePixels,
            unit: .pixels,
            contentMode: contentMode.thumbnailContentMode
        )
        request.imageID = imageID
        return request
    }
}

extension KsImageContentMode {
    // 縮小の目標を当てはめ方に対応させる。
    var thumbnailContentMode: ImageProcessingOptions.ContentMode {
        switch self {
        case .fit: .aspectFit
        case .fill: .aspectFill
        }
    }
}
