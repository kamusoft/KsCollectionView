package jp.kamusoft.kscollectionview.samples.android

import androidx.navigation.NavGraphBuilder

/**
 * 計測用の入口の経路。この構成では計測用の画面を持たない。
 */
object MeasurementRoutes {
    /** 開ける計測用の経路はない。 */
    fun isKnown(route: String): Boolean = false
}

/**
 * 計測用の画面を経路に加える。この構成では何も加えない。
 *
 * @param onBack 戻る導線の処理 (使わない)
 */
@Suppress("UNUSED_PARAMETER")
fun NavGraphBuilder.measurementDestinations(onBack: () -> Unit) {
    // 配布する構成に計測用の画面は入れない。
}
