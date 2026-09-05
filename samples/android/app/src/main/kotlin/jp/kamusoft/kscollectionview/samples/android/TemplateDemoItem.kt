package jp.kamusoft.kscollectionview.samples.android

/**
 * 「テンプレート切り替え」画面が表示する要素。`kind` がテンプレートのキー値になる。
 */
data class TemplateDemoItem(
    val id: Int,
    val kind: TemplateDemoKind,
    val title: String,
)
