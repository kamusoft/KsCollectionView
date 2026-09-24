import Foundation
import KsCollectionView

/// 「画像グリッド」画面で選べるプリフェッチの形 (到達点と表示幅)。
// 並び順と文言は Android Sample の同名の選択肢とそろえる (cross/ADR-0004)。
enum ImagePrefetchChoice: String, CaseIterable, Identifiable {
    case none = "なし"
    case disk = "ディスクまで"
    /// 表示幅を宣言せず、元の大きさのままメモリへ載せる。
    case memory = "メモリまで"
    /// 列幅を宣言し、列幅に縮小してメモリへ載せる。
    case memoryColumn = "メモリまで (列幅)"

    var id: Self { self }

    /// 起動引数 `--prefetch` (`none` / `disk` / `memory` / `memory-column`) で要求された選択。指定が無ければ `nil` (画面の初期選択に任せる)。
    ///
    /// 計測では到達点ごとに独立した実行を取るため、画面を開いた後に選び直すのではなく
    /// 起動の時点で決められる必要があります (選び直すと、その前の選択で読み込んだ分が
    /// 観測に混じります)。引数の名前と値の解釈はここだけが持ち、計測用の起動経路もデモ画面も
    /// ここを通して読みます。
    static var requested: ImagePrefetchChoice? {
        switch ProcessInfo.processInfo.arguments
            .drop(while: { $0 != "--prefetch" })
            .dropFirst()
            .first {
        case "none": ImagePrefetchChoice.none
        case "disk": ImagePrefetchChoice.disk
        case "memory": ImagePrefetchChoice.memory
        case "memory-column": ImagePrefetchChoice.memoryColumn
        default: nil
        }
    }

    /// 「画像グリッド」画面の初期選択。
    static let initialSelection = ImagePrefetchChoice.disk

    /// 実際に使う選択。起動引数の指定があればそれ、無ければ画面の初期選択。
    ///
    /// 起動引数を読む画面 (デモ画面と計測用の起動経路) はいずれもこれを使います。綴りと既定を
    /// 別々に書くと、片方だけを直したときに誰も落ちないまま到達点が食い違うためです。
    static var resolved: ImagePrefetchChoice { requested ?? initialSelection }

    /// 対応する到達点。`nil` はプリフェッチを宣言しないことを表す。
    var destination: KsPrefetchDestination? {
        switch self {
        case .none: nil
        case .disk: .disk
        case .memory, .memoryColumn: .memory
        }
    }

    /// 先読みの要素に宣言する表示幅。`nil` は元の大きさのまま扱う。
    var width: KsWidth? {
        switch self {
        case .memoryColumn: .column
        case .none, .disk, .memory: nil
        }
    }
}
