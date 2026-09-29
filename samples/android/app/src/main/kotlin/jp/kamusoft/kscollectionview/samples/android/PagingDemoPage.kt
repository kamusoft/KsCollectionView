package jp.kamusoft.kscollectionview.samples.android

/**
 * 「ページング」画面の偽の取得元が 1 回の取得で返す 1 ページ。
 *
 * @property items このページの項目
 * @property isLast このページが最後のページか (続きが無いか)
 */
data class PagingDemoPage(
    val items: List<DemoItem>,
    val isLast: Boolean,
)
