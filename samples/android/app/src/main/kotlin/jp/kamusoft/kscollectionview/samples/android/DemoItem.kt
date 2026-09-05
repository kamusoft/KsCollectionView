package jp.kamusoft.kscollectionview.samples.android

/**
 * デモ画面が表示する要素。`id` が安定 ID になる。
 */
data class DemoItem(
    val id: Int,
    val title: String,
    val detail: String? = null,
)
