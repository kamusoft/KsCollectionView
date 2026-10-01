import CoreGraphics
import Foundation

// 並べ替えのドラッグ中に、一覧の上端で自前で足す自動スクロールの計算 (表示から切り離した部品)。
//
// 一覧を画面の上端のバーの裏まで広げた置き方 (core/ADR-0017) では、UIKit のドラッグ & ドロップの上端の
// 自動スクロールが反応する帯 (一覧の上端の内側の余白の下から一定の幅) がバーの裏に入り、指を置けないため
// 上へ送れない。このため安全領域の上の境目 (バーのすぐ下) から下へ UIKit と同じ幅の帯を取り、指がその中に
// ある間は上へ送る。UIKit の帯と重なる所では UIKit が送るので、自前では送らない (両方が送ると速さが足し
// 合わさる)。安全領域の上が 0 の置き方では自前の帯がすべて UIKit の帯に入るので、自前では送らない。
// 下端は UIKit に任せる。
//
// 速さは UIKit の上端 (一覧を安全領域の内側に置いたとき) と同じ形にする。帯の中の指の深さだけで決まり
// (浅いほど速い)、止めている間に時間で加速はしない。iOS 26 より前は、指が帯に入ってから一定の時間待って
// 送り始め、自前の帯と UIKit の帯のどちらにも入っていないときに待ちを数え直す。
// 帯の幅・待ち・速さの曲がり方は、iOS 18.6・26.5 のシミュレータで観測した UIKit の上端の反応に合わせた値。
internal struct KsReorderTopAutoScroll {
    /// 帯の幅と速さの出し方。
    struct Profile: Equatable {
        /// 反応する帯の幅 (pt)。
        let bandHeight: CGFloat
        /// 速さの曲がり方の基準の長さ (pt)。深さがこの長さのときに速さが 0 になる形で、帯の幅以上。
        let curveLength: CGFloat
        /// 帯の一番上 (安全領域の境目) に指があるときの速さ (pt/秒)。
        let maximumSpeed: CGFloat
        /// `1 - 深さ / curveLength` に掛ける指数。1 なら深さに比例して遅くなる。
        let exponent: CGFloat
        /// 指が帯に入ってから送り始めるまでの待ち (秒)。
        let startDelay: TimeInterval
    }

    /// 1 回に進める時間の上限 (秒)。アプリが裏から戻った直後のような、明らかに飛んだフレームだけを切る。
    /// 描画が 30fps を下回る程度のフレームの間隔では、間隔の分だけ進めて速さを保つ。
    static let maximumStep: TimeInterval = 0.1

    /// OS ごとの帯の幅と速さ。iOS 16・17 は 18 と同じとみなす。
    static func profile(osMajorVersion: Int) -> Profile {
        if osMajorVersion >= 26 {
            return Profile(bandHeight: 60, curveLength: 60, maximumSpeed: 1100, exponent: 1.7, startDelay: 0)
        }
        return Profile(bandHeight: 50, curveLength: 65, maximumSpeed: 830, exponent: 1.6, startDelay: 0.75)
    }

    /// 自前の帯の中の指の速さ (pt/秒)。自前の帯の外では nil。UIKit の帯との重なりは見ない。
    ///
    /// - Parameters:
    ///   - fingerY: 指の位置 (一覧の枠の上端から、画面に対しての縦の距離)
    ///   - safeAreaTop: 一覧の上端の安全領域の高さ
    ///   - profile: 帯の幅と速さの出し方
    static func speed(fingerY: CGFloat, safeAreaTop: CGFloat, profile: Profile) -> CGFloat? {
        let depth = fingerY - safeAreaTop
        guard safeAreaTop > 0, depth >= 0, depth < profile.bandHeight else { return nil }
        let rest = max(0, 1 - depth / profile.curveLength)
        return profile.maximumSpeed * pow(rest, profile.exponent)
    }

    let profile: Profile
    /// 指が自前か UIKit の帯に入ってからの時間 (秒)。どちらの帯にも入っていないときは 0 に戻す。
    private(set) var dwell: TimeInterval = 0

    init(profile: Profile) {
        self.profile = profile
    }

    /// 1 フレーム分進めた後の contentOffset の縦の値。送らないときは nil。
    ///
    /// - Parameters:
    ///   - fingerY: 指の位置 (一覧の枠の上端から、画面に対しての縦の距離)。指が一覧の外なら nil
    ///   - safeAreaTop: 一覧の上端の安全領域の高さ
    ///   - systemBandTop: UIKit の帯の上端 (一覧の上端の内側の余白。adjustedContentInset.top)。UIKit の帯は
    ///     ここから帯の幅だけ下まで
    ///   - currentOffset: 今の contentOffset の縦の値
    ///   - minimumOffset: 先頭 (-adjustedContentInset.top)
    ///   - elapsed: 前のフレームからの時間 (秒)
    mutating func nextOffset(
        fingerY: CGFloat?,
        safeAreaTop: CGFloat,
        systemBandTop: CGFloat,
        currentOffset: CGFloat,
        minimumOffset: CGFloat,
        elapsed: TimeInterval
    ) -> CGFloat? {
        guard let fingerY else {
            dwell = 0
            return nil
        }
        let ownSpeed = Self.speed(fingerY: fingerY, safeAreaTop: safeAreaTop, profile: profile)
        // UIKit が反応する所 (内側の余白の部分と、その下の帯)。
        let inSystemBand = fingerY < systemBandTop + profile.bandHeight
        // 自前と UIKit のどちらかの帯に入っている時間は数え続ける (UIKit の帯から自前の帯へ下へまたいだときに
        // 待ち直さない)。どちらの帯にも入っていないときだけ数え直す。
        guard ownSpeed != nil || inSystemBand else {
            dwell = 0
            return nil
        }
        let step = min(max(elapsed, 0), Self.maximumStep)
        dwell += step
        // UIKit が反応する所では UIKit が送るので、自前では送らない。
        guard let speed = ownSpeed, !inSystemBand else { return nil }
        // 足し合わせの誤差で待ちの終わりのフレームを取りこぼさないよう、わずかな幅を持たせて比べる。
        guard dwell + 1e-9 >= profile.startDelay, speed > 0, currentOffset > minimumOffset, step > 0 else {
            return nil
        }
        return max(minimumOffset, currentOffset - speed * CGFloat(step))
    }
}
