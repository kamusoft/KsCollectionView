import CoreGraphics
import XCTest
@testable import KsCollectionView

final class KsEstimatedHeightTests: XCTestCase {
    func test未計測のときは既定値を返す() {
        let estimate = KsEstimatedHeight()

        XCTAssertEqual(estimate.value, KsEstimatedHeight.defaultValue)
    }

    func test計測後はその実測値を使う() {
        var estimate = KsEstimatedHeight()

        estimate.record(height: 120, width: 402)

        XCTAssertEqual(estimate.value, 120)
    }

    func test複数の実測値では平均を使う() {
        var estimate = KsEstimatedHeight()

        // 行の積み上げ (= コンテンツ全体の高さ) を言い当てるのは平均であり、
        // 高い行を含む分だけ推定値も上がる。
        [40, 50, 60].forEach { estimate.record(height: $0, width: 402) }

        XCTAssertEqual(estimate.value, 50)
    }

    func test高い行が混ざると推定値もその分だけ上がる() {
        var estimate = KsEstimatedHeight()

        [44, 44, 44, 140].forEach { estimate.record(height: $0, width: 402) }

        XCTAssertEqual(estimate.value, 68)
    }

    func test有限でない値と0以下の値は採用しない() {
        var estimate = KsEstimatedHeight()

        estimate.record(height: .nan, width: 402)
        estimate.record(height: .infinity, width: 402)
        estimate.record(height: 0, width: 402)
        estimate.record(height: -10, width: 402)

        XCTAssertEqual(estimate.value, KsEstimatedHeight.defaultValue)
    }

    func test保持上限を超えた分は古い実測値から捨てる() {
        var estimate = KsEstimatedHeight()

        // 上限いっぱいの古い値を入れてから、同数の新しい値で置き換える。
        (0 ..< KsEstimatedHeight.sampleCapacity).forEach { _ in estimate.record(height: 10, width: 402) }
        (0 ..< KsEstimatedHeight.sampleCapacity).forEach { _ in estimate.record(height: 200, width: 402) }

        XCTAssertEqual(estimate.value, 200)
    }

    func test同じ幅で測り続ける限り実測値は捨てられない() {
        var estimate = KsEstimatedHeight()

        // 初回レイアウトでも実測値が残ることを固定する。捨てられると直後の再レイアウトが
        // 既定値を読み、初回表示の見積もりが実測を一度も使えなくなる。
        [120, 120, 120].forEach { estimate.record(height: $0, width: 402) }

        XCTAssertEqual(estimate.value, 120)
    }

    func test幅が変わると前の幅の実測値を捨てる() {
        var estimate = KsEstimatedHeight()
        [120, 120].forEach { estimate.record(height: $0, width: 402) }

        estimate.record(height: 60, width: 197)

        XCTAssertEqual(estimate.value, 60)
    }

    func test幅が変わっても新しい幅の実測が入るまでは前の幅の平均を使う() {
        var estimate = KsEstimatedHeight()
        [120, 120].forEach { estimate.record(height: $0, width: 402) }

        // 幅の変化で走る再レイアウトに既定値を読ませないための遅延破棄。
        XCTAssertEqual(estimate.value, 120)
    }

    func test幅が有限でない計測は採用しない() {
        var estimate = KsEstimatedHeight()

        estimate.record(height: 120, width: .nan)
        estimate.record(height: 120, width: 0)

        XCTAssertEqual(estimate.value, KsEstimatedHeight.defaultValue)
    }
}
