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

    /** デモ画面の経路。 */
    fun demo(screen: SampleScreen): String = "demo/${screen.name}"

    /** 検証画面の経路。 */
    fun verification(screen: VerificationScreen): String = "verification/${screen.name}"
}
