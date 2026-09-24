package jp.kamusoft.kscollectionview.samples.android

import jp.kamusoft.kscollectionview.KsPrefetchDestination
import jp.kamusoft.kscollectionview.KsWidth

/**
 * 「画像グリッド」画面で選べるプリフェッチの形 (到達点と表示幅)。
 *
 * 並び順と文言は iOS Sample の同名 enum と一字一句そろえる。
 *
 * @param title 選択肢の表示文言
 * @param argument 起動時の指定 ([SampleRoutes.PrefetchExtra]) と計測用の経路で使う名前。
 *   iOS の起動引数 `--prefetch` の値と同じ綴りにする
 * @param destination 対応する到達点。null はプリフェッチを宣言しないことを表す
 * @param width 先読みの要素に宣言する表示幅。null は元の大きさのまま扱う
 */
enum class ImagePrefetchChoice(
    val title: String,
    val argument: String,
    val destination: KsPrefetchDestination?,
    val width: KsWidth?,
) {
    /** プリフェッチを宣言しない。 */
    None("なし", "none", null, null),

    /** 元データをディスクのキャッシュに置くところまで先読みする。 */
    Disk("ディスクまで", "disk", KsPrefetchDestination.Disk, null),

    /** 表示幅を宣言せず、元の大きさのままメモリへ載せる。 */
    Memory("メモリまで", "memory", KsPrefetchDestination.Memory, null),

    /** 列幅を宣言し、列幅に縮小してメモリへ載せる。 */
    MemoryColumn("メモリまで (列幅)", "memory-column", KsPrefetchDestination.Memory, KsWidth.Column),
    ;

    companion object {
        /** 「画像グリッド」画面の初期選択。 */
        val InitialSelection: ImagePrefetchChoice = Disk

        /**
         * 起動時の指定の値から選択を引く。指定が無い・解釈できないときは null (画面の初期選択に任せる)。
         *
         * 計測では到達点ごとに独立した実行を取るため、画面を開いた後に選び直すのではなく起動の時点で
         * 決められる必要がある (選び直すと、その前の選択で読み込んだ分が観測に混じる)。
         *
         * @param argument 起動時の指定の値
         */
        fun fromArgument(argument: String?): ImagePrefetchChoice? =
            entries.firstOrNull { it.argument == argument }
    }
}
