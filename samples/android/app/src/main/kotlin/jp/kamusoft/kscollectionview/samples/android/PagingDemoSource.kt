package jp.kamusoft.kscollectionview.samples.android

import kotlinx.coroutines.delay

/**
 * 「ページング」画面の偽の取得元。
 *
 * 全 [TotalCount] 件 (「Item 1」〜「Item 10000」、ID は 1 からの整数) を 1 ページ [PageSize] 件で
 * 返す。取得のたびに [delayMilliseconds] の遅延を置く。iOS Sample の同名の定義と同じ規則にし、
 * 同じページの番号には同じ並びを返す。
 *
 * - 「中身を 0 件にする」がオンなら、どのページも 0 件・最後のページとして返す
 * - 「次の読み込みを失敗させる」がオンなら、遅延の後に失敗させる (「中身を 0 件にする」より優先)
 *
 * @property delayMilliseconds 1 回の取得に置く遅延 (ミリ秒)
 */
class PagingDemoSource(val delayMilliseconds: Int = PagingDelay.DefaultMilliseconds) {
    /**
     * 指定したページを取得する。
     *
     * @param page 0 から数えたページの番号
     * @param fails 失敗させるか
     * @param isEmpty 中身を 0 件にするか
     * @return そのページの項目と、最後のページか
     * @throws PagingDemoFailure [fails] が true のとき
     */
    suspend fun fetch(page: Int, fails: Boolean, isEmpty: Boolean): PagingDemoPage {
        if (delayMilliseconds > 0) delay(delayMilliseconds.toLong())
        if (fails) throw PagingDemoFailure()
        return page(page, isEmpty)
    }

    companion object {
        /** 全件数。 */
        const val TotalCount: Int = 10_000

        /** 1 ページの件数。 */
        const val PageSize: Int = 50

        /**
         * 遅延と失敗を除いた、指定したページの中身。
         *
         * @param page 0 から数えたページの番号
         * @param isEmpty 中身を 0 件にするか
         */
        fun page(page: Int, isEmpty: Boolean): PagingDemoPage {
            if (isEmpty) return PagingDemoPage(items = emptyList(), isLast = true)
            val first = page * PageSize + 1
            val last = minOf(first + PageSize - 1, TotalCount)
            if (first > last) return PagingDemoPage(items = emptyList(), isLast = true)
            return PagingDemoPage(
                items = (first..last).map(::item),
                isLast = last == TotalCount,
            )
        }

        /** ID [id] の項目。 */
        fun item(id: Int): DemoItem = DemoItem(id = id, title = "Item $id")
    }
}
