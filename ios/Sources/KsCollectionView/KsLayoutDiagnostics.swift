#if DEBUG
import Foundation

/// 自己サイズと、そのセルに渡されていた高さの一致を数える計数です。
///
/// 行の高さがコンテンツで決まるレイアウトでは、セルが返した高さと渡されていた高さの差が
/// 画面のピクセル格子への丸めの境界 (半画素) を超えると、レイアウトの解き直しが起こります。
/// この計数は、その境界より十分に小さい許容幅を除いた差を数えるので、**解き直しの回数の上界**
/// になります。表示件数や操作量に依らない値として読めます (境界と、許容幅の内側では解き直しが
/// 起きないことを `KsSelfSizingInvalidationTests` で確かめています)。
///
/// 計数はプロセス全体で 1 か所に持ちます。区間を区切って読むときは `reset()` で数え直します。
///
/// - Important: 計測のための入口であり、通常の利用者向けの API ではありません。
///   デバッグ構成でだけ存在し、使うには専用の指定を付けて読み込む必要があります。
@_spi(KsMeasurement)
@MainActor
public enum KsLayoutDiagnostics {
    /// 自己サイズを返したセルの数。
    @_spi(KsMeasurement)
    public private(set) static var selfSizedCellCount = 0

    /// 自己サイズが、そのセルに渡されていた高さと違った回数。
    @_spi(KsMeasurement)
    public private(set) static var estimateMismatchCount = 0

    /// 自己サイズを返したセルのうち、渡されていた高さと違った割合。まだ 1 件も無いときは 0 です。
    @_spi(KsMeasurement)
    public static var estimateMismatchRate: Double {
        guard selfSizedCellCount > 0 else { return 0 }
        return Double(estimateMismatchCount) / Double(selfSizedCellCount)
    }

    /// 計数を数え直します。
    @_spi(KsMeasurement)
    public static func reset() {
        selfSizedCellCount = 0
        estimateMismatchCount = 0
    }

    /// 同じ高さと見なす幅。浮動小数の丸め誤差だけを吸収する大きさにする。
    ///
    /// 解き直しの境界は画面のピクセル格子への丸めにある (倍率 3 では、半画素に届かない
    /// 0.1 pt の差では起きず、半画素を超える 0.2 pt で起きる)。境界そのものを幅にすると、
    /// 解き直しは起きないまま渡した高さのまま行が積まれ、その差が全行ぶん合計高さに乗る。
    /// そこで境界の十分内側、丸め誤差だけを吸収する大きさに置く。
    nonisolated internal static let matchTolerance: CGFloat = 1e-9

    /// 測った高さが、そのセルに渡されていた高さと同じと見なせるかを返します。
    ///
    /// 同じと見なすのは浮動小数の最下位桁の丸め誤差までです。同じ高さを別々の経路で計算すると
    /// 最下位桁が食い違うことがあり、その差では解き直しが起きないためです。解き直しの境界
    /// そのもの (ピクセル格子の半画素) より内側に置く理由は `matchTolerance` にあります。
    ///
    /// - Parameters:
    ///   - measured: セルが測って返した高さ
    ///   - original: そのセルに渡されていた高さ
    /// - Returns: 同じと見なせるなら `true`
    nonisolated internal static func matchesLayout(measured: CGFloat, original: CGFloat) -> Bool {
        abs(measured - original) < matchTolerance
    }

    /// 自己サイズを 1 件数えます。
    ///
    /// - Parameter matchesEstimate: そのセルに渡されていた高さと (最下位桁の丸め誤差を除いて)
    ///   同じ高さに測られたなら `true`
    internal static func recordSelfSizedCell(matchesEstimate: Bool) {
        selfSizedCellCount += 1
        if !matchesEstimate {
            estimateMismatchCount += 1
        }
    }
}
#endif
