import Foundation

// アイテムの先読みの宣言 1 件を、台帳で突き合わせる形にしたもの。
//
// 宣言が変わったかどうかは識別子・URL・幅の種類で判定する。列の幅は種類 (`column`) のまま持ち、
// ピクセルに解いた値は含めない。含めると、回転で列の幅が変わるだけで進行中の取得を取り消して
// 出し直すことになるためである。URL を含めるのは、キーが同じでも URL (署名) が変わった要素を
// 新しい URL で出し直すため (古い URL が失効すると取得が失敗したまま残る)。
internal struct KsPrefetchDeclaration: Hashable {
    let identifier: String
    let url: URL
    // 誤った固定値を取り除いた後の幅。nil は元の大きさのまま扱う。
    let width: KsWidth?

    // 利用者の宣言を台帳の形に直す。空文字のキーと誤った固定値は誤りとして知らせ、
    // それぞれキーなし・幅なしとして扱う (core/ADR-0011)。
    @MainActor
    init(_ resource: KsResource) {
        identifier = KsImageIdentity.identifier(url: resource.url, key: resource.key)
        url = resource.url
        switch resource.width {
        case .fixed(let points) where !(points.isFinite && points > 0):
            KsInvalidInput.report(
                "先読みの固定の幅には 0 より大きい有限の値を指定してください (\(points))。元の大きさで扱います: \(resource.url.absoluteString)"
            )
            width = nil
        default:
            width = resource.width
        }
    }
}
