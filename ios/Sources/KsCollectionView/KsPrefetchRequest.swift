import Foundation
import Nuke

// 先読みの取得 1 件分の要求。取得を始めたときに作り、取り消しにも同じ値を使う。
//
// 取り消しの時点で作り直すと、その間に列の幅や世代が変わっていれば始めたときと違う要求を
// 止めることになるため、始めたときの値をそのまま持ち回る。
internal struct KsPrefetchRequest: Hashable {
    // 取得に使う URL。
    let url: URL

    // キャッシュの項目を見分ける `imageID`。キーなしで世代が進んでいない画像では nil
    // (ローダーは URL で見分ける)。
    let imageID: String?

    // 縮小してメモリへ載せるときの幅 (ピクセル)。幅の正方形を覆う最小の大きさに縮小する。
    // nil は縮小しない (元の大きさのまま、または到達点がディスクまで) ことを表す。
    let widthPixels: Int?

    // ローダーへ渡す要求。同じ値からは同じ要求 (同じ鍵) ができる。
    var imageRequest: ImageRequest {
        var request = ImageRequest(url: url)
        if let widthPixels {
            // 元の画像が指定より小さいときは拡大されない (デコード時の縮小は縮める方向にだけ働く)。
            request.thumbnail = ImageRequest.ThumbnailOptions(
                size: CGSize(width: widthPixels, height: widthPixels),
                unit: .pixels,
                contentMode: .aspectFill
            )
        }
        request.imageID = imageID
        return request
    }
}
