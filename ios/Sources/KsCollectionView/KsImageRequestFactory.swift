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

// 表示に使う要求と、組み立ての時点でメモリから同期で取り出せた画像の組。
internal struct KsPreparedImageRequest {
    // ローダーへ出す要求。
    let request: ImageRequest

    // 枠の大きさへ縮小済みで、ローダーの応答を待たずにそのまま描ける画像。
    // メモリに何も無ければ nil で、その場合だけ読み込み中の表示から始まる。
    let cachedImage: UIImage?
}

// 表示側の要求を組み立てる。表示枠の実サイズが確定してから、その大きさに縮小してデコードする
// 要求を作る。縮小はデコード時に行うため、元寸の画像はメモリに展開されない。
@MainActor
internal enum KsImageRequestFactory {
    static func route(for source: KsImageSource) -> KsImageRoute {
        switch source {
        case .remote(let url), .file(let url): .loader(url)
        case .asset(let name): .asset(name)
        }
    }

    // 表示に使う要求を組み立て、あわせて初回の描画に使える画像を同期で用意する。
    // ローダーを通さないソースと、大きさが未確定 (0 を含む) の間は nil を返す。
    //
    // 要求はどの経路でも同じ形 (同じ鍵) にする。ローダーは要求そのものの鍵でメモリを引き、
    // 取得の結果も同じ鍵へ書くため、鍵が経路ごとに変わると自分で書いた項目を次の表示が
    // 引き当てられず、セルの再利用や画面への再入場のたびに読み込み中を経由してしまう。
    //
    // 先読みが載せる元寸の項目は鍵に寸法を含まないため、この鍵とは一致しない。元寸が
    // メモリにあるときはその場で枠の大きさへ縮小し、表示の鍵へ載せ直す。取得もデコードも
    // やり直さない。
    //
    // 呼び出し側の注意: メモリに元寸だけがある場合、この関数は共有ローダーのメモリキャッシュ
    // へ縮小結果を書き込む (同じ入力に対して同じ結果を書くだけなので、何度呼んでも増えない)。
    static func prepare(
        source: KsImageSource,
        size: CGSize,
        contentMode: KsImageContentMode,
        displayScale: CGFloat,
        pipeline: ImagePipeline = .shared
    ) -> KsPreparedImageRequest? {
        guard let context = makeContext(source: source, size: size, displayScale: displayScale) else {
            return nil
        }

        let cache = pipeline.cache
        let display = displayRequest(context: context, contentMode: contentMode)
        // この大きさの画像が既にあるなら、それをそのまま初回の描画に使う。
        if let container = cache[display] {
            return KsPreparedImageRequest(request: display, cachedImage: container.image)
        }

        // 元寸がメモリにあるなら、その場で縮小して初回の描画に使う。デコードのやり直しを
        // 避けるため、元データからではなく元寸のメモリ項目から作る。
        if let original = cache[originalRequest(context: context)],
           let downscaled = downscaleProcessor(context: context, contentMode: contentMode)
               .process(original.image) {
            cache[display] = ImageContainer(image: downscaled)
            return KsPreparedImageRequest(request: display, cachedImage: downscaled)
        }

        // メモリに何も無い場合だけ、初回の描画に使える画像が無い。要求の縮小指定により、
        // 元データからいきなり縮小してデコードされる (元寸はメモリに展開されない)。
        return KsPreparedImageRequest(request: display, cachedImage: nil)
    }

    // 要求の組み立てに要る、ソースごとに一度だけ決まる値。
    private struct RequestContext {
        let url: URL
        // 削除済みのソースには世代付きの識別子が付き、削除前のキャッシュ項目に当たらなくなる。
        let imageID: String?
        // 縮小の目標。ピクセルで指定する。
        let target: CGSize
    }

    private static func makeContext(
        source: KsImageSource,
        size: CGSize,
        displayScale: CGFloat
    ) -> RequestContext? {
        guard case .loader(let url) = route(for: source) else { return nil }
        guard size.width > 0, size.height > 0, displayScale > 0 else { return nil }

        return RequestContext(
            url: url,
            imageID: KsImageIdentity.imageID(forKey: url.absoluteString),
            target: CGSize(width: size.width * displayScale, height: size.height * displayScale)
        )
    }

    // 先読みが載せる、縮小指定の無い元寸の項目を指す要求。
    private static func originalRequest(context: RequestContext) -> ImageRequest {
        var request = ImageRequest(url: context.url)
        request.imageID = context.imageID
        return request
    }

    // 表示に使う唯一の要求。元データからいきなり縮小してデコードする指定を持つため、
    // この要求で取得しても元寸はメモリに展開されない。縮小指定は鍵の一部でもあるので、
    // 同じソースでも表示サイズと当てはめ方ごとに別のキャッシュ項目になる。
    private static func displayRequest(
        context: RequestContext,
        contentMode: KsImageContentMode
    ) -> ImageRequest {
        var request = ImageRequest(url: context.url)
        request.thumbnail = ImageRequest.ThumbnailOptions(
            size: context.target,
            unit: .pixels,
            contentMode: contentMode.thumbnailContentMode
        )
        request.imageID = context.imageID
        return request
    }

    // 元寸のメモリ項目を、表示に使う要求と同じ寸法へ縮小する手段。元寸より大きくはしない。
    private static func downscaleProcessor(
        context: RequestContext,
        contentMode: KsImageContentMode
    ) -> ImageProcessors.Resize {
        ImageProcessors.Resize(
            size: context.target,
            unit: .pixels,
            contentMode: contentMode.processingContentMode,
            crop: false,
            upscale: false
        )
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

    // デコード後の縮小でも同じ目標を使う。
    var processingContentMode: ImageProcessingOptions.ContentMode { thumbnailContentMode }
}
