import Foundation

/// 画像の取得元を表します。
public enum KsImageSource: Hashable, Sendable {
    /// ネットワーク上の画像を URL で指定します。
    case remote(URL)

    /// 端末内のファイルを URL で指定します。
    case file(URL)

    /// アプリに同梱したアセットカタログの画像を名前で指定します。
    case asset(String)
}
