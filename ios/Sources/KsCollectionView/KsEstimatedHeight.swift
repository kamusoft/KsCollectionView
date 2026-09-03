import CoreGraphics

/// 行の推定高さを実測から決めます。
///
/// compositional layout の `NSCollectionLayoutSize.estimated` は item / group の定義単位であり
/// index path ごとには変えられないため、テンプレートキー別ではなくコレクション全体で 1 つの値を持ちます。
/// 行の幅ごとに実測値を持ち、幅が変われば前の幅の値を捨てます (list / grid の切り替え・回転・
/// adaptive や向き指定での列数変化はいずれも行の幅を変えます)。
/// 直近の実測値の平均を使います。推定高さは行位置の積み上げ (= コンテンツ全体の高さ) の見積もりに
/// 使われるため、行高が混在するときに合計を最もよく言い当てるのは平均です。1 件の極端な行に
/// 引きずられ続けないよう、参照するのは直近の一定件数だけに限ります。
internal struct KsEstimatedHeight {
    /// 実測値が 1 件も無いときに使う値。
    internal static let defaultValue: CGFloat = 44

    /// 保持する実測値の上限。可視範囲と再利用プールの規模より十分に大きく、
    /// かつ古い実測値を引きずり続けない大きさにする。
    internal static let sampleCapacity = 32

    private var samples: [CGFloat] = []

    /// `samples` を測ったときの行の幅。
    private var sampledWidth: CGFloat?

    /// 現在の推定高さ。未計測のときは既定値、計測後は直近の実測値の平均。
    internal var value: CGFloat {
        guard !samples.isEmpty else { return Self.defaultValue }
        return samples.reduce(0, +) / CGFloat(samples.count)
    }

    /// 実測した行の高さを、それを測ったときの行の幅とともに記録します。
    /// 有限で正の値だけを採用します。
    ///
    /// 前と違う幅で測った値が来たら、それまでの実測値をこの時点で捨てます。別の幅で測った
    /// 高さは推定の役に立たないためです。捨てるのを幅が変わった瞬間ではなく次の実測が来た
    /// ときまで遅らせるのは、幅の変化で走る再レイアウトに既定値を読ませないためです
    /// (捨てた直後の再レイアウトは実測を 1 件も持たない状態になり、推定が既定値へ戻る)。
    /// この遅延により、新しい幅の実測が入るまでは前の幅の平均が使われます。
    internal mutating func record(height: CGFloat, width: CGFloat) {
        guard height.isFinite, height > 0, width.isFinite, width > 0 else { return }
        if let sampledWidth, sampledWidth != width {
            samples.removeAll()
        }
        sampledWidth = width
        samples.append(height)
        if samples.count > Self.sampleCapacity {
            samples.removeFirst(samples.count - Self.sampleCapacity)
        }
    }
}
