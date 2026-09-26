package jp.kamusoft.kscollectionview.samples.android

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 画面の集合・順序・文言が iOS Sample と一致していることを表で確かめる。
 *
 * 期待値は iOS Sample の `SampleScreen.swift` / `VerificationScreen.swift` の宣言をそのまま
 * 書き写したもの。プラットフォーム間の一致は言語をまたぐためコンパイラでは
 * 守れず、片側を写した表との突き合わせで守る。
 */
class SampleScreenParityTest {

    /** iOS Sample の SampleScreen の宣言順と表示文言。 */
    private val iosDemoTitles = listOf(
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
    )

    @Test
    fun `デモ画面のタイトルと順序が iOS と一致する`() {
        assertEquals(iosDemoTitles, SampleScreen.entries.map { it.title })
    }

    @Test
    fun `デモ画面は 12 ある`() {
        assertEquals(12, SampleScreen.entries.size)
    }

    /**
     * 「グループ化」「差分更新」画面の操作と説明の文言が iOS Sample と一致する。
     *
     * 期待値は iOS Sample の `GroupingDemoView.swift` / `DiffUpdateDemoView.swift` /
     * `DiffUpdateLayoutChoice.swift` / `DiffUpdatePosition.swift` / `GroupHeaderBand.swift` の文言を
     * そのまま書き写したもの。
     */
    @Test
    fun `グループ化と差分更新の文言が iOS と一致する`() {
        assertEquals(
            listOf("並び順を反転", "項目を別のグループへ", "10,000 件・縦 2 列 / 横 4 列・見出しは固定"),
            listOf(GroupingDemoText.Reverse, GroupingDemoText.MoveItem, GroupingDemoText.Description),
        )
        assertEquals(listOf("リスト", "グリッド"), DiffUpdateLayoutChoice.entries.map { it.title })
        assertEquals(listOf("先頭", "中ほど", "末尾"), DiffUpdatePosition.entries.map { it.title })
        assertEquals(
            listOf("グループ", "挿入", "削除", "更新", "移動", "反転", "シャッフル", "元に戻す"),
            with(DiffUpdateDemoText) {
                listOf(Grouped, Insert, Delete, Update, Move, Reverse, Shuffle, Reset)
            },
        )
        // 見出しのグループ名と件数、更新した項目の印。
        assertEquals("グループ 1", GroupingFixture.groupName(1))
        assertEquals("グループ A", DiffUpdateModel.groupName(0))
        assertEquals("1,200 件", groupItemCountText(1_200))
        assertEquals("5 件", groupItemCountText(5))
        assertEquals("Item 3 ★", DiffUpdateItem(id = 3, group = 0, revision = 1).row.title)
        assertEquals("Item 3", DiffUpdateItem(id = 3, group = 0).row.title)
    }

    @Test
    fun `検証画面はデモ画面と別区分の 1 画面である`() {
        assertEquals(
            listOf("検証: 行の高さ変化 (Android 固有)"),
            VerificationScreen.entries.map { it.title },
        )
    }

    @Test
    fun `メニューの文言と画面タイトルは同じ宣言元から引く`() {
        // 経路は画面名から作り、表示文言はタイトルから引く。両者が別々の文字列表を持って
        // いないことを、経路の作りが名前だけに依存することで確かめる。
        SampleScreen.entries.forEach { screen ->
            assertEquals("demo/${screen.name}", SampleRoutes.demo(screen))
        }
    }

    @Test
    fun `グループ化と差分更新は開始ルートで開ける経路を持つ`() {
        // 起動時の追加情報 ks_start_route に渡す経路。計測と検証はこの経路で画面を直接開く。
        assertEquals("demo/Grouping", SampleRoutes.demo(SampleScreen.Grouping))
        assertEquals("demo/DiffUpdate", SampleRoutes.demo(SampleScreen.DiffUpdate))
    }
}
