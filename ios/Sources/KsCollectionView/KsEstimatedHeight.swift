import CoreGraphics

/// 行の推定高さを実測から決めます。
///
/// compositional layout の `NSCollectionLayoutSize.estimated` は item / group の定義単位であり
/// index path ごとには変えられないため、テンプレートキー別ではなくコレクション全体で 1 つの値を持ちます。
/// 行の幅と画面の倍率ごとに実測値を持ち、どちらかが変われば前の値を捨てます (list / grid の
/// 切り替え・回転・adaptive や向き指定での列数変化はいずれも行の幅を変え、別の画面への移動は
/// 倍率を変えます)。倍率が変わるとピクセル格子の刻みも変わるため、混ざったままでは同じ見た目の
/// 高さが別の格子に散り、最頻値が成立しなくなります。
///
/// 使うのは直近の実測値の**最頻値**です。セルが自己サイズで返した高さ (preferred) が、その
/// セルに渡されていた高さ (original) と同じなら再解決は起きません。UIKit はこの 2 つの差で
/// 判断しており、判断の結果は
/// `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` の戻り値には
/// 現れません (`KsSelfSizingInvalidationTests` で確認)。高さが少数の種類に集中する画面では、
/// 多数派のセルがこの一致に入って再解決を起こさなくなります。標本の単位は行ではなくセルです
/// — 判断がセルの preferred と original の比較で行われるため、一致させる相手はセルの実測です。
///
/// 実測値は画面のピクセル格子に量子化して**数えます**。量子化しないと、同じ見た目の高さが
/// 浮動小数の微小な差で別の値に散り、最頻値が成立しなくなります。返す値は量子化した値ではなく、
/// **その格子に入った実測値そのもの (直近の 1 件)** です。格子へ丸めた値は実測と半画素まで
/// ずれ、その差は**解き直しを起こさないまま渡した高さのまま行が積まれる**ため、全行ぶんが
/// 合計高さの誤差として積み上がります (`KsSelfSizingInvalidationTests` で確認)。実測値を
/// そのまま返せば、同じ高さに測られるセルとの差は浮動小数の最下位桁に収まり、積み上がりません。
internal struct KsEstimatedHeight {
    /// 実測値が 1 件も無いときに使う値。
    internal static let defaultValue: CGFloat = 44

    /// 保持する実測値の上限。可視範囲と再利用プールの規模より十分に大きく、
    /// かつ古い実測値を引きずり続けない大きさにする。
    internal static let sampleCapacity = 32

    /// 実測値と、それを数えるための格子上の値の対。新しいものほど後ろにある。
    private var samples: [(measured: CGFloat, grid: CGFloat)] = []

    /// `samples` を測ったときの行の幅。
    private var sampledWidth: CGFloat?

    /// `samples` を量子化したときの画面の倍率 (正規化後)。平均を格子に載せ直すのと、
    /// 倍率が変わったことの判定に使う。
    private var sampledScale: CGFloat?

    /// 現在の推定高さ。
    ///
    /// 未計測のときは既定値、繰り返し現れた値があればその最頻値 (同数なら直近に現れた方)、
    /// まだどの値も繰り返していないうちは実測値の平均です。平均を挟むのは、標本が 1〜数件の
    /// 段階で「たまたま最初に測れた 1 件」を推定値に固定してしまわないためです。
    /// 繰り返しが現れた後に返すのは、その格子に入った直近の実測値そのものです (丸めません)。
    /// 平均を返す間だけは値が格子の外に落ちうるので、返す前に格子へ載せ直します。
    internal var value: CGFloat {
        guard !samples.isEmpty else { return Self.defaultValue }

        var counts: [CGFloat: Int] = [:]
        samples.forEach { counts[$0.grid, default: 0] += 1 }

        // 新しい方から見て、最も多く現れた格子の値を採る。同数のときは先に見つかった
        // (= 直近に現れた) 値が残るため、「同数なら新しい方」になる。返すのはその格子に
        // 入った直近の実測値そのもの (丸めた値ではない)。
        var mode = samples[samples.count - 1].measured
        var modeCount = 0
        for sample in samples.reversed() {
            let count = counts[sample.grid] ?? 0
            if count > modeCount {
                mode = sample.measured
                modeCount = count
            }
        }

        guard modeCount > 1 else {
            let average = samples.reduce(0) { $0 + $1.measured } / CGFloat(samples.count)
            return Self.quantized(average, scale: sampledScale ?? 1)
        }
        return mode
    }

    /// 実測した行の高さを、それを測ったときの行の幅・画面の倍率とともに記録します。
    /// 有限で正の値だけを採用します。
    ///
    /// 前と違う幅、または前と違う画面の倍率で測った値が来たら、それまでの実測値をこの時点で
    /// 捨てます。別の幅で測った高さは推定の役に立たず、別の倍率で測った高さは格子の刻みが
    /// 違うため同じ土俵で数えられないためです。捨てるのを幅・倍率が変わった瞬間ではなく次の
    /// 実測が来たときまで遅らせるのは、その変化で走る再レイアウトに既定値を読ませないためです
    /// (捨てた直後の再レイアウトは実測を 1 件も持たない状態になり、推定が既定値へ戻る)。
    /// この遅延により、新しい幅・倍率の実測が入るまでは前の推定値が使われます。
    ///
    /// - Parameters:
    ///   - height: 実測した高さ
    ///   - width: それを測ったときの行の幅
    ///   - scale: 画面のピクセル格子の倍率 (量子化の刻みは 1 / scale pt)。
    ///     有限で正でなければ 1 として扱う (`quantized` の丸めと同じ扱い)
    internal mutating func record(height: CGFloat, width: CGFloat, scale: CGFloat) {
        guard height.isFinite, height > 0, width.isFinite, width > 0 else { return }
        // 有効でない倍率はすべて同じ刻み (1 pt) に落ちるため、捨てるかの判定も正規化後で行う。
        let normalizedScale = scale.isFinite && scale > 0 ? scale : 1
        if sampledWidth != nil, sampledWidth != width || sampledScale != normalizedScale {
            samples.removeAll()
        }
        sampledWidth = width
        sampledScale = normalizedScale
        samples.append((measured: height, grid: Self.quantized(height, scale: normalizedScale)))
        if samples.count > Self.sampleCapacity {
            samples.removeFirst(samples.count - Self.sampleCapacity)
        }
    }

    /// 高さを画面のピクセル格子に載せます。
    ///
    /// 同じ見た目の高さが必ず同じ値になることが、最頻値が成立する条件です。
    ///
    /// - Parameters:
    ///   - height: 量子化する高さ
    ///   - scale: 画面のピクセル格子の倍率。有限で正でなければ 1 pt 刻みにする
    /// - Returns: 格子に載せた高さ
    internal static func quantized(_ height: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale.isFinite, scale > 0 else { return height.rounded() }
        return (height * scale).rounded() / scale
    }
}
