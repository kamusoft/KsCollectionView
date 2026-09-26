import Foundation
import KsCollectionView

/// メモリ計測が走査する土俵です。
enum PerformanceFixture {
    /// 固定高と可変行高が混在する 2 列グリッド。
    case largeData

    /// リモート画像の 3 列グリッド。プリフェッチの形 (到達点と表示幅) を選べます。
    case imageGrid(prefetch: ImagePrefetchChoice)

    /// 大小のグループに分けた、固定される見出しつきのグリッド (「グループ化」画面と同じ土俵)。
    case grouping

    /// この土俵の件数です。走査が全件を通過したかの判定に使います。
    var itemCount: Int {
        switch self {
        case .largeData: DemoData.largeItems.count
        case .imageGrid: ImageGridFixture.items.count
        case .grouping: GroupingDemoData.items.count
        }
    }

    /// 土俵を選ぶ起動引数の名前。`--verify-performance` / `--verify-performance-auto` と一緒に使います。
    static let argumentName = "--performance-fixture"

    /// 起動引数 `--performance-fixture <画面名>` で選んだ土俵です。
    ///
    /// 指定が無ければ「大量件数」です。受け取れるのは「グループ化」だけで、それ以外の値や値の欠落は
    /// 既定へ戻さずに起動を止めます (測ったつもりの土俵と実際の土俵が食い違わないようにするため)。
    static let requested: PerformanceFixture = resolve(arguments: ProcessInfo.processInfo.arguments)

    private static func resolve(arguments: [String]) -> PerformanceFixture {
        guard let position = arguments.firstIndex(of: argumentName) else { return .largeData }
        let valuePosition = arguments.index(after: position)
        guard valuePosition < arguments.endIndex else {
            fatalError("\(argumentName) に土俵の画面名が指定されていません")
        }
        switch arguments[valuePosition] {
        case SampleScreen.grouping.rawValue:
            return .grouping
        case let value:
            fatalError("\(argumentName) に受け取れない土俵が指定されました: \(value)")
        }
    }
}
