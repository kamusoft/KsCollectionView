import XCTest
@testable import KsCollectionViewSamples

/// 起動引数 `--screen` の解釈を確かめます。
final class SampleScreenTests: XCTestCase {
    /// 画面の名前を指定すると、その画面を直接開きます。
    @MainActor
    func test画面の名前を指定するとその画面を返す() {
        for screen in SampleScreen.allCases {
            XCTAssertEqual(
                SampleScreen.requested(arguments: ["app", "--screen", screen.rawValue]),
                screen
            )
        }
    }

    /// 画面の指定の後ろに別の起動引数が続いても、画面の指定を読み取ります。
    @MainActor
    func testほかの起動引数と一緒でも画面の指定を読み取る() {
        XCTAssertEqual(
            SampleScreen.requested(arguments: ["app", "--screen", "ページング", "--paging-delay-ms", "0"]),
            .paging
        )
        XCTAssertEqual(
            SampleScreen.requested(arguments: ["app", "--screen", "大量件数", "--large-count", "2000"]),
            .largeData
        )
        XCTAssertEqual(SampleScreen.requested(arguments: ["app", "--screen", "並べ替え"]), .reorder)
    }

    /// 指定が無い・値が無い・どの画面の名前でもないときは、直接開く画面はありません (ルートメニューを開く)。
    @MainActor
    func test指定が無いか受け取れないときは画面を返さない() {
        XCTAssertNil(SampleScreen.requested(arguments: ["app"]))
        XCTAssertNil(SampleScreen.requested(arguments: ["app", "--screen"]))
        XCTAssertNil(SampleScreen.requested(arguments: ["app", "--screen", "無い画面"]))
    }
}
