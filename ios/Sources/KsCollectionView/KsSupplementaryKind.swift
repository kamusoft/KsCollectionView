// コレクションに載せる補助ビューの種類。
// ルートのヘッダー / フッターはレイアウト全体に 1 つずつ、グループの見出しは塊ごとに付く。
// レイアウトの属性を種類で見分けられるよう、それぞれ別の種類にする。
internal enum KsSupplementaryKind {
    // コンテンツ全体の先頭に置くルートのヘッダー。上の内側余白もこの中に含める。
    static let rootHeader = "jp.kamusoft.kscollectionview.root-header"
    // コンテンツ全体の末尾に置くルートのフッター。下の内側余白もこの中に含める。
    static let rootFooter = "jp.kamusoft.kscollectionview.root-footer"
    // グループの見出し。
    static let groupHeader = "jp.kamusoft.kscollectionview.group-header"
}
