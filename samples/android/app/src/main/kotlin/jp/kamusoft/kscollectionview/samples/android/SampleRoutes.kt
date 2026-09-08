package jp.kamusoft.kscollectionview.samples.android

/**
 * 画面遷移の経路名。
 *
 * 計測用の入口は起動時の指定 (Intent の追加情報) でも使うため、文字列の組み立てを 1 か所に置く。
 */
object SampleRoutes {
    /** ルートメニュー。 */
    const val Menu = "menu"

    /** 起動時に開く経路を指定する Intent の追加情報のキー。 */
    const val StartRouteExtra = "ks_start_route"

    /**
     * 起動時に画像キャッシュを空にするかを指定する Intent の追加情報のキー。
     *
     * 計測は試行ごとに同じキャッシュ状態から始めなければ独立した試行にならないため、
     * 計測側が試行の前処理でこれを立てる。配布する構成では読み捨てられる。
     */
    const val ResetImageCacheExtra = "ks_reset_image_cache"

    /**
     * 読み込み中の表示を経由した回数を数えるかを指定する Intent の追加情報のキー。
     *
     * 数える構成では読み込み中の表示が Sample 側の複製に置き換わるため、常時数えると
     * 「読み込み中の既定の表示」を観測点に持つ検証画面が本体の既定を通らなくなる。数えることを
     * 明示的に要求した実行にだけ置き換わるよう、実行時の指定にする (iOS の起動引数
     * `--count-image-loading-slots` と対称)。配布する構成では読み捨てられる。
     */
    const val CountImageLoadingSlotsExtra = "ks_count_image_loading_slots"

    /** デモ画面の経路。 */
    fun demo(screen: SampleScreen): String = "demo/${screen.name}"

    /** 検証画面の経路。 */
    fun verification(screen: VerificationScreen): String = "verification/${screen.name}"
}
