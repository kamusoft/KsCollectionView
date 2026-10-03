import XCTest
@testable import KsCollectionViewSamples

/// ルートメニューの行の並びを確かめます。
///
/// メニューの画面 (`RootMenuView`) は `RootMenuRow.all` を上から順に 1 行ずつ描くため、並びはこの配列で決まります。
final class RootMenuRowTests: XCTestCase {
    /// 見出し「外観」の下に「システム」「ライト」「ダーク」が並び、隙間を挟んでデモ画面の先頭「リスト」が続きます。
    @MainActor
    func test外観の見出しと3項目がデモ画面の項目より上に並ぶ() {
        XCTAssertEqual(
            Array(RootMenuRow.all.prefix(6)),
            [
                .heading("外観"),
                .appearance(.system),
                .appearance(.light),
                .appearance(.dark),
                .gap,
                .screen(.list),
            ]
        )
        XCTAssertEqual(SampleAppearance.allCases.map(\.title), ["システム", "ライト", "ダーク"])
    }

    /// デモ画面の項目は決まった順に並び、その後ろに技術検証画面が続きます (Android Sample と同じ並び)。
    @MainActor
    func testデモ画面の項目が決まった順に並び技術検証画面が後ろに続く() {
        XCTAssertEqual(
            Self.linkTitles,
            [
                "リスト",
                "グリッド (固定列)",
                "グリッド (adaptive)",
                "向きで列数変更",
                "テンプレート切り替え",
                "ルートヘッダー/フッター",
                "スクロール制御",
                "スペーシングと余白",
                "大量件数",
                "画像グリッド",
                "グループ化",
                "差分更新",
                "ページング",
                "並べ替え",
                "検証: 行の高さ変化 (iOS 固有)",
            ]
        )
    }

    /// 「画像グリッド」のすぐ下に「グループ化」、その下に「差分更新」が並びます。
    @MainActor
    func test画像グリッドの次にグループ化と差分更新が並ぶ() throws {
        let imageGrid = try XCTUnwrap(Self.linkTitles.firstIndex(of: "画像グリッド"))
        XCTAssertEqual(
            Array(Self.linkTitles[imageGrid...].prefix(3)),
            ["画像グリッド", "グループ化", "差分更新"]
        )
    }

    /// 「ページング」は「差分更新」のすぐ下にあります。
    @MainActor
    func testページングが差分更新の次にある() throws {
        let diffUpdate = try XCTUnwrap(Self.linkTitles.firstIndex(of: "差分更新"))
        XCTAssertEqual(Self.linkTitles[diffUpdate + 1], "ページング")
    }

    /// 「並べ替え」は「ページング」のすぐ下にあります。
    @MainActor
    func test並べ替えがページングの次にある() throws {
        let paging = try XCTUnwrap(Self.linkTitles.firstIndex(of: "ページング"))
        XCTAssertEqual(Self.linkTitles[paging + 1], "並べ替え")
    }

    /// 画面を開く行の文言を、メニューに並ぶ順に取り出したもの。
    @MainActor
    private static var linkTitles: [String] {
        RootMenuRow.all.compactMap { row in
            switch row {
            case .screen(let screen): screen.rawValue
            case .verification(let screen): screen.rawValue
            case .heading, .appearance, .gap: nil
            }
        }
    }
}
