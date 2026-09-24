package jp.kamusoft.kscollectionview.samples.android

import android.os.Bundle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument

/** 経路の引数として渡す画面名のキー。 */
private const val ScreenArgument = "screen"

/**
 * Sample 全体の画面遷移。
 *
 * @param startRoute 起動直後に開く経路。null ならルートメニューだけを出す
 * @param requestedPrefetch 起動時に指定された「画像グリッド」のプリフェッチの形。null なら画面の
 *   初期選択
 */
@Composable
fun SampleNavHost(startRoute: String? = null, requestedPrefetch: ImagePrefetchChoice? = null) {
    val navController = rememberNavController()
    // 起動時の経路指定は 1 回だけ消費する。構成変更 (回転) で Activity が作り直されても
    // Intent の追加情報は残るため、消費済みを覚えていないと同じ宛先が back stack に積み増し、
    // 戻る操作でメニューへ抜けられなくなる。
    var startRouteConsumed by rememberSaveable { mutableStateOf(false) }

    NavHost(navController = navController, startDestination = SampleRoutes.Menu) {
        composable(SampleRoutes.Menu) {
            SampleScaffold(title = "KsCollectionView Samples") {
                RootMenuScreen(
                    onSelectDemo = { navController.navigate(SampleRoutes.demo(it)) },
                    onSelectVerification = {
                        navController.navigate(SampleRoutes.verification(it))
                    },
                )
            }
        }

        composable(
            route = "demo/{$ScreenArgument}",
            arguments = listOf(navArgument(ScreenArgument) { type = NavType.StringType }),
        ) { entry ->
            val screen = SampleScreen.valueOf(entry.arguments.readScreenName())
            SampleScaffold(title = screen.title, onBack = { navController.popBackStack() }) {
                when (screen) {
                    SampleScreen.List -> ListDemoScreen()
                    SampleScreen.FixedGrid -> FixedGridDemoScreen()
                    SampleScreen.AdaptiveGrid -> AdaptiveGridDemoScreen()
                    SampleScreen.OrientationGrid -> OrientationGridDemoScreen()
                    SampleScreen.Templates -> TemplateSwitchDemoScreen()
                    SampleScreen.HeaderFooter -> HeaderFooterDemoScreen()
                    SampleScreen.Scrolling -> ScrollControlDemoScreen()
                    SampleScreen.Spacing -> SpacingPaddingDemoScreen()
                    SampleScreen.LargeData -> LargeDataDemoScreen()
                    SampleScreen.ImageGrid -> ImageGridDemoScreen(
                        initialChoice = requestedPrefetch ?: ImagePrefetchChoice.InitialSelection,
                    )
                }
            }
        }

        composable(
            route = "verification/{$ScreenArgument}",
            arguments = listOf(navArgument(ScreenArgument) { type = NavType.StringType }),
        ) { entry ->
            val screen = VerificationScreen.valueOf(entry.arguments.readScreenName())
            SampleScaffold(title = screen.title, onBack = { navController.popBackStack() }) {
                when (screen) {
                    VerificationScreen.HeightChange -> HeightChangeVerificationScreen()
                }
            }
        }

        measurementDestinations(
            onBack = { navController.popBackStack() },
            // 離れた画面は積み残さない。残すと、離脱後の保持を読む計測が「戻れる画面の分だけ
            // 生きている」状態を測ることになる。
            onLeaveTo = { from, to ->
                navController.navigate(to) { popUpTo(from) { inclusive = true } }
            },
        )
    }

    LaunchedEffect(startRoute) {
        if (startRouteConsumed) return@LaunchedEffect
        startRouteConsumed = true
        if (startRoute != null && isKnownStartRoute(startRoute)) {
            navController.navigate(startRoute)
        }
    }
}

/** 起動時の指定として受け付ける経路かどうか。未知の経路で遷移しようとすると落ちるため先に絞る。 */
private fun isKnownStartRoute(route: String): Boolean =
    route in SampleScreen.entries.map { SampleRoutes.demo(it) } ||
        route in VerificationScreen.entries.map { SampleRoutes.verification(it) } ||
        MeasurementRoutes.isKnown(route)

/** 経路の引数から画面名を読む。 */
private fun Bundle?.readScreenName(): String =
    this?.getString(ScreenArgument) ?: error("経路の引数に画面名がありません")
