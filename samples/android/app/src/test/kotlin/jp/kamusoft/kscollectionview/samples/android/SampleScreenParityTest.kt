package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 画面の集合・順序・文言が iOS Sample と一致していることを表で確かめる。
 *
 * 期待値は iOS Sample の `SampleScreen.swift` / `VerificationScreen.swift` の宣言をそのまま
 * 書き写したもの。プラットフォーム間の一致は言語をまたぐためコンパイラでは
 * 守れず、片側を写した表との突き合わせで守る。
 */
class SampleScreenParityTest {

    /** 「再試行」の押せる範囲の高さ (Material の最小の押せる大きさ)。 */
    private val RetryTouchTarget = 48.dp

    /** 失敗の文言 1 行の高さの見込み (bodyMedium の行の高さ)。 */
    private val OneLineOfText = 20.dp

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
        "ページング",
    )

    @Test
    fun `デモ画面のタイトルと順序が iOS と一致する`() {
        assertEquals(iosDemoTitles, SampleScreen.entries.map { it.title })
    }

    @Test
    fun `デモ画面は 13 ある`() {
        assertEquals(13, SampleScreen.entries.size)
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

    /**
     * 「ページング」画面の文言が iOS Sample と一致する。
     *
     * 期待値は iOS Sample の `PagingDemoText.swift` / `PagingLayoutChoice.swift` の文言と、
     * `PagingDemoSource.swift` の項目のタイトルをそのまま書き写したもの。
     */
    @Test
    fun `ページングの文言が iOS と一致する`() {
        assertEquals(
            listOf(
                "表示",
                "次の読み込みを失敗させる",
                "中身を 0 件にする",
                "再読み込み",
                "全 10,000 件・1 ページ 50 件",
                "更新できませんでした",
                "読み込めませんでした",
                "再試行",
                "これ以上ありません",
                "項目がありません",
                "操作を畳む",
                "操作を広げる",
            ),
            with(PagingDemoText) {
                listOf(
                    LayoutPicker, FailsNextLoad, IsEmpty, Reload, Summary, RefreshFailed,
                    LoadFailed, Retry, EndReached, Empty, Fold, Unfold,
                )
            },
        )
        assertEquals(listOf("リスト", "グリッド"), PagingLayoutChoice.entries.map { it.title })
        assertEquals("Item 51", PagingDemoSource.item(51).title)
    }

    /**
     * 「ページング」画面の寸法と透け方が iOS Sample と一致する。
     *
     * 期待値は iOS Sample の `PagingPanelMetrics.swift` の値 (pt) をそのまま dp として書き写したもの。
     * パネルを下端から上げる量 (`bottomMargin`) は、決め方だけをそろえて値は分けるため、ここには含めない
     * (`ページングの操作のパネルを上げる量は 末尾の失敗の表示が丸ごと入る高さ` で確かめる)。
     */
    @Test
    fun `ページングの操作のパネルの寸法が iOS と一致する`() {
        with(PagingPanelMetrics) {
            assertEquals(
                listOf(16f, 18f, 12f, 10f, 6f, 30f, 44f, 8f, 4f, 16f, 8f, 6f, 16f, 10f),
                listOf(
                    horizontalMargin, cornerRadius, horizontalPadding, verticalPadding, rowSpacing,
                    foldButtonSize, handleSize, shadowRadius, shadowOffset, footerVerticalPadding,
                    messageSpacing, retryVerticalPadding, retryHorizontalPadding, retryCornerRadius,
                ).map { it.value },
            )
            assertEquals(listOf(8f, 12f, 10f), listOf(bannerTopMargin, bannerCornerRadius, bannerVerticalPadding).map { it.value })
            assertEquals(3_000L, BannerDurationMillis)
            assertEquals(200, BannerFadeMillis)
            assertEquals(0.72f, SurfaceOpacity)
            assertEquals(0.10f, ShadowOpacity)
        }
    }

    /**
     * パネル (畳んだときは丸いボタン) を画面の下端から上げる量は、両プラットフォームで「末尾の失敗の表示が
     * 丸ごとパネルの下に入る高さ」という同じ決め方にし、値は失敗の表示の背の高さの差で分ける
     * (iOS 100pt / Android 128dp)。Android は「再試行」の押せる範囲が 48dp あるため、その分だけ高い。
     *
     * ここでは Android の値と、失敗の表示のうち文言の 1 行を除いた部分 (上下の余白・文言と「再試行」の
     * 間隔・「再試行」の押せる範囲) より十分に高いことを確かめる。
     */
    @Test
    fun `ページングの操作のパネルを上げる量は 末尾の失敗の表示が丸ごと入る高さ`() {
        with(PagingPanelMetrics) {
            assertEquals(128f, bottomMargin.value)
            val failureWithoutText = footerVerticalPadding * 2 + messageSpacing + RetryTouchTarget
            assertTrue(
                "上げる量 $bottomMargin が失敗の表示の文言以外の高さ $failureWithoutText と文言の 1 行分より低い",
                bottomMargin >= failureWithoutText + OneLineOfText,
            )
        }
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
    fun `グループ化と差分更新とページングは開始ルートで開ける経路を持つ`() {
        // 起動時の追加情報 ks_start_route に渡す経路。計測と検証はこの経路で画面を直接開く。
        assertEquals("demo/Grouping", SampleRoutes.demo(SampleScreen.Grouping))
        assertEquals("demo/DiffUpdate", SampleRoutes.demo(SampleScreen.DiffUpdate))
        assertEquals("demo/Paging", SampleRoutes.demo(SampleScreen.Paging))
    }
}
