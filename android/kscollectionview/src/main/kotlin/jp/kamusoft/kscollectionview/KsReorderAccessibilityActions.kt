package jp.kamusoft.kscollectionview

/**
 * 並べ替えを有効にした一覧で、読み上げ (TalkBack) 用に出す移動の操作の文言です。
 *
 * 文言を渡すと、動かせる項目に「1 つ前へ動かす」「1 つ後ろへ動かす」の 2 つの操作が出ます。
 *
 * @property previous 1 つ前へ動かす操作の文言 (例: 「前へ移動」)
 * @property next 1 つ後ろへ動かす操作の文言 (例: 「後ろへ移動」)
 */
public class KsReorderAccessibilityActions(
    public val previous: String,
    public val next: String,
)
