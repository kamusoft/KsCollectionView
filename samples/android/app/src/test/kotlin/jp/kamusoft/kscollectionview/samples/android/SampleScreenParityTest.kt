package jp.kamusoft.kscollectionview.samples.android

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 画面の集合・順序・文言が iOS Sample と一致していることを表で確かめる。
 *
 * 期待値は iOS Sample の `SampleScreen.swift` / `VerificationScreen.swift` の宣言をそのまま
 * 書き写したもの。プラットフォーム間の一致 (cross/ADR-0004) は言語をまたぐためコンパイラでは
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
    )

    @Test
    fun `デモ画面のタイトルと順序が iOS と一致する`() {
        assertEquals(iosDemoTitles, SampleScreen.entries.map { it.title })
    }

    @Test
    fun `デモ画面は 9 つある`() {
        assertEquals(9, SampleScreen.entries.size)
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
}
