import CoreGraphics
import XCTest
@_spi(KsMeasurement) @testable import KsCollectionView

final class KsEstimatedHeightTests: XCTestCase {
    func test未計測のときは既定値を返す() {
        let estimate = KsEstimatedHeight()

        XCTAssertEqual(estimate.value, KsEstimatedHeight.defaultValue)
    }

    func test計測後はその実測値を使う() {
        var estimate = KsEstimatedHeight()

        estimate.record(height: 120, width: 402, scale: 2)

        XCTAssertEqual(estimate.value, 120)
    }

    func test繰り返し現れた値があればその値を使う() {
        var estimate = KsEstimatedHeight()

        // 多数派のセルが推定値と一致すれば、そのセルの自己サイズはレイアウトの再解決を起こさない。
        [44, 44, 44, 140].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        XCTAssertEqual(estimate.value, 44)
    }

    func test少数派の高い行が混ざっても推定値は多数派のまま変わらない() {
        var estimate = KsEstimatedHeight()

        // 6 : 1 で混ざる配列。1 件の長文が推定値を動かすと、多数派の全セルが再解決を起こす。
        (0 ..< 6).forEach { _ in estimate.record(height: 44, width: 402, scale: 2) }
        estimate.record(height: 140, width: 402, scale: 2)

        XCTAssertEqual(estimate.value, 44)
    }

    func test出現回数が同じなら新しい方の値を使う() {
        var estimate = KsEstimatedHeight()

        [44, 140, 44, 140].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        XCTAssertEqual(estimate.value, 140)
    }

    func test実測値がまだ繰り返していないうちは平均を使う() {
        var estimate = KsEstimatedHeight()

        // 標本が数件の段階では、たまたま最初に測れた 1 件に推定値を固定しない。
        [40, 50, 60].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        XCTAssertEqual(estimate.value, 50)
    }

    func test繰り返しが現れた時点で平均から最頻値へ切り替わる() {
        var estimate = KsEstimatedHeight()
        [40, 50, 60].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        estimate.record(height: 40, width: 402, scale: 2)

        XCTAssertEqual(estimate.value, 40)
    }

    func testピクセル格子未満の差は同じ高さとして数える() {
        var estimate = KsEstimatedHeight()

        // 同じ見た目の高さが浮動小数の微小な差で別の値に散ると、最頻値が成立しなくなる。
        estimate.record(height: 44.0, width: 402, scale: 2)
        estimate.record(height: 44.01, width: 402, scale: 2)
        estimate.record(height: 43.99, width: 402, scale: 2)
        estimate.record(height: 140, width: 402, scale: 2)

        // 数えるのは格子の上だが、返すのはその格子に入った直近の実測値そのもの。
        // 丸めた値を返すと、セルが実際に返す高さと最下位桁で食い違う。
        XCTAssertEqual(estimate.value, 43.99)
    }

    func test格子をまたぐ差は別の高さとして数える() {
        var estimate = KsEstimatedHeight()

        // 倍率 2 の格子は 0.5 pt 刻み。44.0 と 44.6 は別の格子に入るため、多い方が最頻値になる。
        [44.0, 44.0].forEach { estimate.record(height: $0, width: 402, scale: 2) }
        [44.6, 44.6, 44.6].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        XCTAssertEqual(estimate.value, 44.6)
    }

    func test量子化はピクセル格子の刻みに丸める() {
        XCTAssertEqual(KsEstimatedHeight.quantized(44.4, scale: 3), 133.0 / 3.0)
        XCTAssertEqual(KsEstimatedHeight.quantized(44.4, scale: 2), 44.5)
    }

    func test繰り返しが無いときの平均も格子に載せて返す() {
        var estimate = KsEstimatedHeight()

        // 倍率 2 の格子に載る 2 値でも、その平均は格子の外に落ちる (44.0 と 44.5 の平均は 44.25)。
        estimate.record(height: 44.0, width: 402, scale: 2)
        estimate.record(height: 44.5, width: 402, scale: 2)

        XCTAssertEqual(estimate.value, 44.5)
        XCTAssertEqual(estimate.value, KsEstimatedHeight.quantized(estimate.value, scale: 2))
    }

    #if DEBUG
    func test一致と数えるのは最下位桁の丸め誤差までとする() {
        // 解き直しの境界は画面のピクセル格子への丸めにあり、半画素を超える差 (倍率 3 で 0.2 pt)
        // で起こる。境界そのものを幅にすると差が合計高さに積み上がるため、吸収するのは
        // 浮動小数の丸め誤差だけにする (境界と積み上がりは `KsSelfSizingInvalidationTests`)。
        let height: CGFloat = 36.333333333333336
        XCTAssertTrue(KsLayoutDiagnostics.matchesLayout(measured: height, original: height.nextUp))
        XCTAssertTrue(KsLayoutDiagnostics.matchesLayout(measured: height, original: height))
        XCTAssertFalse(KsLayoutDiagnostics.matchesLayout(measured: height, original: height + 0.2))
        XCTAssertFalse(KsLayoutDiagnostics.matchesLayout(measured: height, original: height + 1.0 / 3))
        XCTAssertFalse(KsLayoutDiagnostics.matchesLayout(measured: height, original: 80))
    }
    #endif

    func test倍率が有限でなければ1pt刻みに丸める() {
        XCTAssertEqual(KsEstimatedHeight.quantized(44.4, scale: 0), 44)
        XCTAssertEqual(KsEstimatedHeight.quantized(44.6, scale: .nan), 45)
    }

    func test有限でない値と0以下の値は採用しない() {
        var estimate = KsEstimatedHeight()

        estimate.record(height: .nan, width: 402, scale: 2)
        estimate.record(height: .infinity, width: 402, scale: 2)
        estimate.record(height: 0, width: 402, scale: 2)
        estimate.record(height: -10, width: 402, scale: 2)

        XCTAssertEqual(estimate.value, KsEstimatedHeight.defaultValue)
    }

    func test保持上限を超えた分は古い実測値から捨てる() {
        var estimate = KsEstimatedHeight()

        // 上限いっぱいの古い値を入れてから、上限より少ない件数の新しい値を入れる。
        // 上限が効いていれば古い値は押し出されて少数派になり、効いていなければ古い値が
        // 多数派のまま残る — 新しい値が最頻値になることが上限の効きを表す。
        let newSampleCount = KsEstimatedHeight.sampleCapacity * 5 / 8
        (0 ..< KsEstimatedHeight.sampleCapacity).forEach { _ in
            estimate.record(height: 10, width: 402, scale: 2)
        }
        (0 ..< newSampleCount).forEach { _ in
            estimate.record(height: 200, width: 402, scale: 2)
        }

        XCTAssertLessThan(
            newSampleCount,
            KsEstimatedHeight.sampleCapacity,
            "新しい値だけで上限が埋まると、上限を外しても同じ結果になり効きを検出できません"
        )
        XCTAssertGreaterThan(
            newSampleCount,
            KsEstimatedHeight.sampleCapacity - newSampleCount,
            "押し出した後に新しい値が多数派にならなければ、上限が効いていても最頻値は古い値のままです"
        )
        XCTAssertEqual(estimate.value, 200)
    }

    func test同じ幅で測り続ける限り実測値は捨てられない() {
        var estimate = KsEstimatedHeight()

        // 初回レイアウトでも実測値が残ることを固定する。捨てられると直後の再レイアウトが
        // 既定値を読み、初回表示の見積もりが実測を一度も使えなくなる。
        [120, 120, 120].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        XCTAssertEqual(estimate.value, 120)
    }

    func test幅が変わると前の幅の実測値を捨てる() {
        var estimate = KsEstimatedHeight()
        [120, 120].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        estimate.record(height: 60, width: 197, scale: 2)

        XCTAssertEqual(estimate.value, 60)
    }

    func test幅が変わっても新しい幅の実測が入るまでは前の幅の推定値を使う() {
        var estimate = KsEstimatedHeight()
        [120, 120].forEach { estimate.record(height: $0, width: 402, scale: 2) }

        // 幅の変化で走る再レイアウトに既定値を読ませないための遅延破棄。
        XCTAssertEqual(estimate.value, 120)
    }

    func test幅が有限でない計測は採用しない() {
        var estimate = KsEstimatedHeight()

        estimate.record(height: 120, width: .nan, scale: 2)
        estimate.record(height: 120, width: 0, scale: 2)

        XCTAssertEqual(estimate.value, KsEstimatedHeight.defaultValue)
    }
}
