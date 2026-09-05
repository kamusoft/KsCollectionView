package jp.kamusoft.kscollectionview.samples.android

/**
 * デモ画面が使うデータ。値は iOS Sample の同名定義とそろえる (cross/ADR-0004)。
 */
object DemoData {
    /** 「リスト」「ルートヘッダー/フッター」画面が使う 6 件。 */
    val fruits: List<DemoItem> = listOf(
        DemoItem(id = 1, title = "Apple", detail = "ID: 1"),
        DemoItem(id = 2, title = "Banana", detail = "ID: 2"),
        DemoItem(id = 3, title = "Cherry", detail = "ID: 3"),
        DemoItem(id = 4, title = "Durian", detail = "ID: 4"),
        DemoItem(id = 5, title = "Elderberry", detail = "ID: 5"),
        DemoItem(id = 6, title = "Fig", detail = "ID: 6"),
    )

    /** 「グリッド (固定列)」画面が使う 9 件 (3 列でちょうど 3 行になる件数)。 */
    val fixedGridItems: List<DemoItem> = (1..9).map { DemoItem(id = it, title = "Item $it") }

    /** 列数が変わる画面が使う 18 件。 */
    val gridItems: List<DemoItem> = (1..18).map { DemoItem(id = it, title = "Item $it") }

    /** 「スクロール制御」画面が使う 100 件。 */
    val scrollItems: List<DemoItem> =
        (1..100).map { DemoItem(id = it, title = "Item $it", detail = "ID: $it") }

    /** 「テンプレート切り替え」画面が使う 30 件。5 件ごとに通知の見た目になる。 */
    val templateItems: List<TemplateDemoItem> = (1..30).map { index ->
        val isNotice = index % 5 == 0
        TemplateDemoItem(
            id = index,
            kind = if (isNotice) TemplateDemoKind.Notice else TemplateDemoKind.Message,
            title = if (isNotice) "Notice $index" else "Message $index",
        )
    }

    /** 「大量件数」画面の件数。計測で件数を変えるときも生成規則はこの関数のまま使う。 */
    const val LargeItemCount: Int = 10_000

    /**
     * 「大量件数」画面と性能計測の fixture を、要求された件数だけ作る。
     *
     * 件数・可変行高の混ぜ方 (7 件ごとの長文) ・文言は整数 ID から決定的に作るため、同じ
     * バイナリでは項目ごとの内容が常に一致し、計測結果を回ごとに比較できる。
     *
     * 件数ごとに新しく作るのは、メモリを件数間で比べるときに**その件数分の入力データだけ**が
     * 保持されている必要があるため。最大件数を作り置きして先頭から切り出すと、件数を減らしても
     * 入力データは最大件数分が残り、件数差を測れなくなる。
     *
     * @param count 作る件数
     */
    fun largeItems(count: Int): List<DemoItem> = (1..count).map { index ->
        DemoItem(
            id = index,
            title = "Item $index",
            detail = if (index % 7 == 0) {
                "可変行高を確認するための固定シード長文データ $index — KsCollectionView"
            } else {
                null
            },
        )
    }
}
