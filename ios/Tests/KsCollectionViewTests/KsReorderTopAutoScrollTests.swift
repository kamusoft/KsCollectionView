import CoreGraphics
import XCTest
@testable import KsCollectionView

/// 並べ替えのドラッグ中に上端で足す自動スクロールの計算を確かめる。
final class KsReorderTopAutoScrollTests: XCTestCase {
    private let frame = 1.0 / 60
    private let ios26 = KsReorderTopAutoScroll.profile(osMajorVersion: 26)
    private let ios18 = KsReorderTopAutoScroll.profile(osMajorVersion: 18)

    /// 1 フレーム進める。既定はバーの裏まで広げた一覧 (安全領域の上 116pt・内側の余白 0)。
    private func next(
        _ scroll: inout KsReorderTopAutoScroll,
        fingerY: CGFloat?,
        safeAreaTop: CGFloat = 116,
        systemBandTop: CGFloat = 0,
        offset: CGFloat = 1000,
        minimum: CGFloat = 0,
        elapsed: TimeInterval = 1.0 / 60
    ) -> CGFloat? {
        scroll.nextOffset(
            fingerY: fingerY,
            safeAreaTop: safeAreaTop,
            systemBandTop: systemBandTop,
            currentOffset: offset,
            minimumOffset: minimum,
            elapsed: elapsed
        )
    }

    /// 待ちの無い iOS 26 の計算で 1 フレーム進める。
    private func next26(
        fingerY: CGFloat?,
        safeAreaTop: CGFloat = 116,
        systemBandTop: CGFloat = 0,
        offset: CGFloat = 1000,
        minimum: CGFloat = 0,
        elapsed: TimeInterval = 1.0 / 60
    ) -> CGFloat? {
        var scroll = KsReorderTopAutoScroll(profile: ios26)
        return next(
            &scroll, fingerY: fingerY, safeAreaTop: safeAreaTop, systemBandTop: systemBandTop,
            offset: offset, minimum: minimum, elapsed: elapsed
        )
    }

    private func speed(depth: CGFloat, _ profile: KsReorderTopAutoScroll.Profile) -> CGFloat? {
        KsReorderTopAutoScroll.speed(fingerY: 116 + depth, safeAreaTop: 116, profile: profile)
    }

    func test帯の幅と速さと待ちはiOS26以降とそれより前で分ける() {
        XCTAssertEqual(KsReorderTopAutoScroll.profile(osMajorVersion: 16), ios18)
        XCTAssertEqual(KsReorderTopAutoScroll.profile(osMajorVersion: 17), ios18)
        XCTAssertEqual(KsReorderTopAutoScroll.profile(osMajorVersion: 27), ios26)
        XCTAssertEqual(ios26.bandHeight, 60)
        XCTAssertEqual(ios18.bandHeight, 50)
        XCTAssertEqual(ios26.startDelay, 0)
        XCTAssertEqual(ios18.startDelay, 0.75)
    }

    // UIKit の上端 (一覧を安全領域の内側に置いたとき) の実測 (evidence/ios-r4-autoscroll-speed.log)。
    // iOS 26.5 は深さ 1・5・12・35・50・55pt で約 1090・920・718・257・60・20 pt/秒。
    func testiOS26の速さは帯の中の深さでUIKitの実測に近い() {
        let measured: [(CGFloat, CGFloat)] = [(1, 1090), (5, 920), (12, 718), (35, 257), (50, 60), (55, 20)]
        for (depth, expected) in measured {
            let actual = speed(depth: depth, ios26) ?? .nan
            XCTAssertEqual(actual, expected, accuracy: max(10, expected * 0.05), "深さ \(depth)pt")
        }
    }

    // iOS 18.6 は深さ 1・25・45pt で約 811・381・122 pt/秒。深い側 (45pt) の差も 1 割未満に収める。
    func testiOS18の速さは帯の中の深さでUIKitの実測に近い() {
        let measured: [(CGFloat, CGFloat)] = [(1, 811), (25, 381), (45, 122)]
        for (depth, expected) in measured {
            let actual = speed(depth: depth, ios18) ?? .nan
            XCTAssertEqual(actual, expected, accuracy: max(10, expected * 0.05), "深さ \(depth)pt")
        }
    }

    func test浅いほど速く帯の内側の端に近いほど遅い() {
        for profile in [ios26, ios18] {
            var previous = CGFloat.infinity
            for depth in stride(from: CGFloat(0), to: profile.bandHeight, by: 5) {
                let current = speed(depth: depth, profile) ?? .nan
                XCTAssertLessThan(current, previous, "深さ \(depth)pt")
                previous = current
            }
            XCTAssertEqual(speed(depth: 0, profile) ?? .nan, profile.maximumSpeed, accuracy: 0.001)
        }
    }

    func test同じ位置に止めている間は速さが変わらない() {
        // 時間で加速しない: 同じ深さなら、何フレーム目でも進む量は同じ。
        var scroll = KsReorderTopAutoScroll(profile: ios26)
        var offset: CGFloat = 5000
        var steps: [CGFloat] = []
        for _ in 0..<120 {
            let moved = next(&scroll, fingerY: 136, offset: offset) ?? .nan
            steps.append(offset - moved)
            offset = moved
        }
        let first = steps[0]
        XCTAssertGreaterThan(first, 0)
        for step in steps {
            XCTAssertEqual(step, first, accuracy: 0.001)
        }
        let expected = (speed(depth: 20, ios26) ?? .nan) * CGFloat(frame)
        XCTAssertEqual(first, expected, accuracy: 0.001)
    }

    // iOS 18.6 の UIKit は、指が帯に入ってから約 0.75 秒待って送り始め、帯を出て入り直すと待ち直す。
    func testiOS26より前は帯に入ってから待って送り始め帯を出ると待ち直す() {
        var scroll = KsReorderTopAutoScroll(profile: ios18)
        let waitFrames = Int((ios18.startDelay / frame).rounded(.up))
        for index in 0..<(waitFrames - 1) {
            XCTAssertNil(next(&scroll, fingerY: 130), "待ちの間に送りました (\(index) フレーム目)")
        }
        XCTAssertNotNil(next(&scroll, fingerY: 136), "待ちの後に送り始めていません")
        // 帯の中で指を動かしても待ち直さない。
        XCTAssertNotNil(next(&scroll, fingerY: 140))

        // 帯を出ると待ちを数え直す。
        XCTAssertNil(next(&scroll, fingerY: 400))
        XCTAssertEqual(scroll.dwell, 0)
        XCTAssertNil(next(&scroll, fingerY: 130))
        // 一覧の外へ出た (指の位置が無い) ときも数え直す。
        for _ in 0..<(waitFrames - 2) {
            _ = next(&scroll, fingerY: 130)
        }
        XCTAssertNil(next(&scroll, fingerY: nil))
        XCTAssertEqual(scroll.dwell, 0)
        XCTAssertNil(next(&scroll, fingerY: 130))
    }

    func testiOS26は帯に入ってすぐ送る() {
        var scroll = KsReorderTopAutoScroll(profile: ios26)
        XCTAssertNotNil(next(&scroll, fingerY: 130))
    }

    func test帯の外では送らない() {
        // 帯の下の端 (安全領域の上 + 帯の幅) から下。
        XCTAssertNil(next26(fingerY: 176))
        XCTAssertNil(next26(fingerY: 400))
        XCTAssertNil(KsReorderTopAutoScroll.speed(fingerY: 166, safeAreaTop: 116, profile: ios18))
        // 安全領域の上の境目より上 (バーの裏)。
        XCTAssertNil(next26(fingerY: 100))
        // 指が一覧の外。
        XCTAssertNil(next26(fingerY: nil))
    }

    // 安全領域の上が UIKit の帯より短い置き方 (例: 一覧の枠が画面の上端から 40pt 下がり、安全領域の上が
    // 22pt)。UIKit の帯 (内側の余白の下から 60pt) と自前の帯 (22〜82pt) が重なる 22〜60pt では、UIKit が
    // 送るので自前では送らない。UIKit の帯より下 (60〜82pt) だけ自前で送る。
    func testUIKitの帯と重なる所では送らない() {
        XCTAssertNil(next26(fingerY: 22, safeAreaTop: 22))
        XCTAssertNil(next26(fingerY: 40, safeAreaTop: 22))
        XCTAssertNil(next26(fingerY: 59.9, safeAreaTop: 22))
        XCTAssertNotNil(next26(fingerY: 60, safeAreaTop: 22))
        XCTAssertNotNil(next26(fingerY: 81, safeAreaTop: 22))
        XCTAssertNil(next26(fingerY: 82, safeAreaTop: 22))
        // 内側の余白で UIKit の帯が下がっている置き方では、その分だけ重なる所も下がる。
        XCTAssertNil(next26(fingerY: 150, safeAreaTop: 116, systemBandTop: 100))
        XCTAssertNotNil(next26(fingerY: 165, safeAreaTop: 116, systemBandTop: 100))
    }

    // iOS 26 より前で、重なる置き方 (安全領域の上 22pt・UIKit の帯 0〜50pt・自前の帯 22〜72pt) の指を
    // UIKit の帯から自前だけの所へ下向きに続けて動かすと、重なる所にいた時間も待ちに数え、待ち直さない。
    func testiOS26より前は重なる所にいた時間も待ちに数え下へまたいでも待ち直さない() {
        let waitFrames = Int((ios18.startDelay / frame).rounded(.up))

        // 待ちを重なる所で終えてから下へまたぐと、またいだフレームから送る。
        var crossed = KsReorderTopAutoScroll(profile: ios18)
        for index in 0..<waitFrames {
            XCTAssertNil(
                next(&crossed, fingerY: 30, safeAreaTop: 22),
                "重なる所で送りました (\(index) フレーム目)"
            )
        }
        XCTAssertEqual(crossed.dwell, ios18.startDelay, accuracy: 0.001)
        XCTAssertNotNil(next(&crossed, fingerY: 55, safeAreaTop: 22), "下へまたいだ後に待ち直しています")

        // 待ちの途中でまたぐと、残りの分だけ待つ。
        var midway = KsReorderTopAutoScroll(profile: ios18)
        for _ in 0..<10 {
            XCTAssertNil(next(&midway, fingerY: 30, safeAreaTop: 22))
        }
        for index in 0..<(waitFrames - 11) {
            XCTAssertNil(next(&midway, fingerY: 55, safeAreaTop: 22), "待ちの間に送りました (\(index) フレーム目)")
        }
        XCTAssertNotNil(next(&midway, fingerY: 55, safeAreaTop: 22), "残りの待ちの後に送り始めていません")

        // 安全領域の境目より上 (UIKit の帯だけの所) で待ちを終えてから下へまたいでも、待ち直さない。
        var fromAbove = KsReorderTopAutoScroll(profile: ios18)
        for index in 0..<waitFrames {
            XCTAssertNil(
                next(&fromAbove, fingerY: 10, safeAreaTop: 22),
                "UIKit の帯だけの所で送りました (\(index) フレーム目)"
            )
        }
        XCTAssertNotNil(next(&fromAbove, fingerY: 55, safeAreaTop: 22), "境目より上から下へまたいだ後に待ち直しています")

        // どちらの帯にも入っていない所 (自前の帯より下) へ出ると数え直す。
        XCTAssertNil(next(&fromAbove, fingerY: 80, safeAreaTop: 22))
        XCTAssertEqual(fromAbove.dwell, 0)
    }

    func test先頭で止まり行き過ぎない() {
        XCTAssertEqual(next26(fingerY: 120, offset: 2, minimum: 0), 0)
        XCTAssertNil(next26(fingerY: 120, offset: 0, minimum: 0))
        XCTAssertEqual(next26(fingerY: 120, offset: -40, minimum: -44) ?? .nan, -44, accuracy: 0.001)
    }

    func test安全領域の上が0なら送らない() {
        XCTAssertNil(next26(fingerY: 10, safeAreaTop: 0))
        XCTAssertNil(next26(fingerY: 30, safeAreaTop: 0))
    }

    // 描画が 30fps を下回っても (例: 約 22fps、フレームの間隔 45ms)、間隔の分だけ進めて速さを保つ。
    func test低いフレームレートでも速さを保つ() {
        let fast = speed(depth: 14, ios26) ?? .nan
        for interval in [1.0 / 60, 1.0 / 30, 0.045, 1.0 / 15] {
            var scroll = KsReorderTopAutoScroll(profile: ios26)
            var offset: CGFloat = 5000
            var elapsed: TimeInterval = 0
            while elapsed < 1 {
                offset = next(&scroll, fingerY: 130, offset: offset, elapsed: interval) ?? offset
                elapsed += interval
            }
            let perSecond = (5000 - offset) / CGFloat(elapsed)
            XCTAssertEqual(perSecond, fast, accuracy: fast * 0.001, "フレームの間隔 \(interval) 秒")
        }
    }

    func testフレームが大きく飛んだときは1回に進む量に上限がある() {
        XCTAssertEqual(KsReorderTopAutoScroll.maximumStep, 0.1)
        let fast = speed(depth: 14, ios26) ?? .nan
        let capped = 1000 - fast * CGFloat(KsReorderTopAutoScroll.maximumStep)
        XCTAssertEqual(next26(fingerY: 130, elapsed: 1.0) ?? .nan, capped, accuracy: 0.001)
    }
}
