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

    /** デモ画面の経路。 */
    fun demo(screen: SampleScreen): String = "demo/${screen.name}"

    /** 検証画面の経路。 */
    fun verification(screen: VerificationScreen): String = "verification/${screen.name}"
}
