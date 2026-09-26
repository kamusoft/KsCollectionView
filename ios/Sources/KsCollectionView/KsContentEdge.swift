// コンテンツの端。配列の差し替えで表示範囲を留める端を表す (core/ADR-0018)。
internal enum KsContentEdge {
    // コンテンツの先頭 (ルートのヘッダーがあればその上端)。
    case top
    // コンテンツの末尾 (ルートのフッターがあればその下端)。
    case bottom
}
