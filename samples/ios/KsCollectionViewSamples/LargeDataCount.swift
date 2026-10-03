import Foundation

/// 「大量件数」画面の件数です。
///
/// 既定は 10,000 件で、起動引数 `--large-count <件数>` を付けたときだけその件数で開きます。
/// 件数を変えられるのは、対策の効果が件数に比例しないことを件数どうしの比較で確かめるためです。
/// 生成規則は件数によらず同じで、項目の内容は ID から決まります。
enum LargeDataCount {
    /// 指定が無いときの件数。
    static let defaultValue = 10_000

    /// 件数を与える起動引数の名前。
    static let argumentName = "--large-count"

    /// 起動引数の読み取り結果。
    enum Resolution: Equatable {
        /// 指定が無い。
        case unspecified
        /// 正の整数が 1 つだけ指定された。
        case specified(Int)
        /// 指定はあるが受け取れない。理由を伴う。
        case invalid(String)
    }

    /// 起動引数から件数を読み取ります。
    ///
    /// 受け取るのは正の整数 1 つだけです。値の欠落・0・負数・数値でない値・複数指定は、
    /// いずれも既定件数へ戻さずに受け取れないものとして返します。黙って既定へ戻すと、
    /// 測ったつもりの件数と実際に測った件数が食い違ったまま証跡が残るためです。
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
            return .invalid("\(argumentName) に件数が指定されていません")
        }
        let rawValue = arguments[valuePosition]
        guard let count = Int(rawValue), count > 0 else {
            return .invalid("\(argumentName) に正の整数以外が指定されました: \(rawValue)")
        }
        return .specified(count)
    }

    /// この起動での読み取り結果。
    static let resolved = resolve(arguments: ProcessInfo.processInfo.arguments)

    /// この起動で使う件数。
    static var value: Int { value(for: resolved) }

    /// 読み取り結果から決まる件数。指定が無いか受け取れないときは既定の件数。
    static func value(for resolution: Resolution) -> Int {
        switch resolution {
        case .unspecified, .invalid: defaultValue
        case let .specified(count): count
        }
    }

    /// 件数が起動引数で指定されたか。計測のための表示を出すかの判断に使います。
    static var isSpecified: Bool {
        if case .specified = resolved { return true }
        return false
    }

    /// 受け取れない指定なら、起動を止めます。
    static func failIfInvalid() {
        guard case let .invalid(reason) = resolved else { return }
        fatalError(reason)
    }
}
