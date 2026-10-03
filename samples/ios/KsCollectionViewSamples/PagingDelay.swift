import Foundation

/// 「ページング」画面の偽の取得元が 1 回の取得に置く遅延です。
///
/// 既定は 1 秒で、起動引数 `--paging-delay-ms <ミリ秒>` を付けたときだけその長さにします。
/// 遅延を変えるのは、UI テストと性能の体感で読み込みの待ち時間を縮めるため (0 で遅延なし) と、
/// 読み込み中の様子を長く見せるためです。
enum PagingDelay {
    /// 指定が無いときの遅延 (ミリ秒)。
    static let defaultMilliseconds = 1_000

    /// 遅延を与える起動引数の名前。
    static let argumentName = "--paging-delay-ms"

    /// 起動引数の読み取り結果。
    enum Resolution: Equatable {
        /// 指定が無い。
        case unspecified
        /// 0 以上の整数が 1 つだけ指定された。
        case specified(Int)
        /// 指定はあるが受け取れない。理由を伴う。
        case invalid(String)
    }

    /// 起動引数から遅延を読み取ります。
    ///
    /// 受け取るのは 0 以上の整数 1 つだけです。値の欠落・負数・数値でない値・複数指定は、
    /// 既定の遅延へ戻さずに受け取れないものとして返します。黙って既定へ戻すと、縮めたつもりの
    /// 待ち時間で測った結果が実際には既定の遅延のまま残るためです。
    ///
    /// - Parameter arguments: 起動引数の並び
    /// - Returns: 読み取り結果
    static func resolve(arguments: [String]) -> Resolution {
        let positions = arguments.indices.filter { arguments[$0] == argumentName }
        guard let position = positions.first else { return .unspecified }
        guard positions.count == 1 else {
            return .invalid("\(argumentName) は 1 回だけ指定してください (\(positions.count) 回指定されています)")
        }
        let valuePosition = arguments.index(after: position)
        guard valuePosition < arguments.endIndex else {
            return .invalid("\(argumentName) にミリ秒が指定されていません")
        }
        let rawValue = arguments[valuePosition]
        guard let milliseconds = Int(rawValue), milliseconds >= 0 else {
            return .invalid("\(argumentName) に 0 以上の整数以外が指定されました: \(rawValue)")
        }
        return .specified(milliseconds)
    }

    /// この起動での読み取り結果。
    static let resolved = resolve(arguments: ProcessInfo.processInfo.arguments)

    /// この起動で使う遅延 (ミリ秒)。
    static var milliseconds: Int { milliseconds(for: resolved) }

    /// 読み取り結果から決まる遅延 (ミリ秒)。指定が無いか受け取れないときは既定の遅延。
    static func milliseconds(for resolution: Resolution) -> Int {
        switch resolution {
        case .unspecified, .invalid: defaultMilliseconds
        case let .specified(value): value
        }
    }

    /// 受け取れない指定なら、起動を止めます。
    static func failIfInvalid() {
        guard case let .invalid(reason) = resolved else { return }
        fatalError(reason)
    }
}
