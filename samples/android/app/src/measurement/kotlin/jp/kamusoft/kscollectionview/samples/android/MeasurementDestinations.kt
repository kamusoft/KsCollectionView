package jp.kamusoft.kscollectionview.samples.android

import android.os.Bundle
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsPrefetchDestination

/**
 * 計測用の入口の経路。
 *
 * 実体を持つのは計測できる構成だけで、配布する構成では空になる。
 */
object MeasurementRoutes {
    /** 経路の共通の頭。起動時の指定を受け付けてよいかの判定に使う。 */
    const val Prefix = "measurement/"

    /** 件数を渡す引数の名前。 */
    const val CountArgument = "count"

    /** 往復の上限を渡す引数の名前。 */
    const val MaxRoundTripsArgument = "maxRoundTrips"

    /** ライブラリで描く土俵。 */
    fun ksLargeData(count: Int): String = "${Prefix}ks/$count"

    /** 素の LazyVerticalGrid で描く比較対象。 */
    fun baselineLargeData(count: Int): String = "${Prefix}baseline/$count"

    /** ライブラリで描く 1 列の土俵。 */
    fun ksLargeList(count: Int): String = "${Prefix}ks-list/$count"

    /** 素の LazyColumn で描く 1 列の比較対象。 */
    fun baselineLargeList(count: Int): String = "${Prefix}baseline-list/$count"

    /** メモリの定常判定のための自動往復。 */
    fun memoryRoundTrip(count: Int, maxRoundTrips: Int): String =
        "${Prefix}memory/$count/$maxRoundTrips"

    /** 到達点を渡す引数の名前。 */
    const val DestinationArgument = "destination"

    /** ライブラリで描く画像グリッドの土俵。 */
    fun imageGrid(count: Int, destination: String): String =
        "${Prefix}image/$count/$destination"

    /** 画像グリッドのメモリの定常判定のための自動往復。 */
    fun imageMemoryRoundTrip(count: Int, maxRoundTrips: Int, destination: String): String =
        "${Prefix}image-memory/$count/$maxRoundTrips/$destination"

    /** 画像の挙動 (共有・読み込み中・失敗) の検証画面。 */
    fun imageBehavior(): String = "${Prefix}image-behavior"

    /**
     * 計測用の画面が載り終えたことを外から読むための印。
     *
     * 計測側は `setupBlock` でこの印の出現を待ってから計測に入る。待たずに始めると、
     * メニューや遷移の途中のフレームが計測に混ざる。経路ごとに別の印にするのは、
     * 目的の画面に着いたことを確かめるため (どれか 1 つの印では区別できない)。
     */
    fun screenDescription(route: String): String = "measurement-screen:$route"

    /** この構成で開ける計測用の経路かどうか。 */
    fun isKnown(route: String): Boolean = route.startsWith(Prefix)
}

/**
 * 計測用の画面を経路に加える。
 *
 * @param onBack 戻る導線の処理
 */
fun NavGraphBuilder.measurementDestinations(onBack: () -> Unit) {
    val countArguments = listOf(
        navArgument(MeasurementRoutes.CountArgument) { type = NavType.IntType },
    )

    composable(
        route = "${MeasurementRoutes.Prefix}ks/{${MeasurementRoutes.CountArgument}}",
        arguments = countArguments,
    ) { entry ->
        val count = entry.arguments.readCount()
        val route = MeasurementRoutes.ksLargeData(count)
        val items = remember(count) { DemoData.largeItems(count) }
        SampleScaffold(title = "計測: ライブラリ $count 件", onBack = onBack) {
            KsLargeDataGrid(items = items, modifier = Modifier.markMeasurementScreen(route))
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}baseline/{${MeasurementRoutes.CountArgument}}",
        arguments = countArguments,
    ) { entry ->
        val count = entry.arguments.readCount()
        val route = MeasurementRoutes.baselineLargeData(count)
        val items = remember(count) { DemoData.largeItems(count) }
        SampleScaffold(title = "計測: 比較対象 $count 件", onBack = onBack) {
            BaselineLargeDataGrid(
                items = items,
                modifier = Modifier.markMeasurementScreen(route),
            )
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}ks-list/{${MeasurementRoutes.CountArgument}}",
        arguments = countArguments,
    ) { entry ->
        val count = entry.arguments.readCount()
        val route = MeasurementRoutes.ksLargeList(count)
        val items = remember(count) { DemoData.largeItems(count) }
        SampleScaffold(title = "計測: ライブラリ 1 列 $count 件", onBack = onBack) {
            KsLargeDataList(items = items, modifier = Modifier.markMeasurementScreen(route))
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}baseline-list/{${MeasurementRoutes.CountArgument}}",
        arguments = countArguments,
    ) { entry ->
        val count = entry.arguments.readCount()
        val route = MeasurementRoutes.baselineLargeList(count)
        val items = remember(count) { DemoData.largeItems(count) }
        SampleScaffold(title = "計測: 比較対象 1 列 $count 件", onBack = onBack) {
            BaselineLargeDataList(
                items = items,
                modifier = Modifier.markMeasurementScreen(route),
            )
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}memory/{${MeasurementRoutes.CountArgument}}" +
            "/{${MeasurementRoutes.MaxRoundTripsArgument}}",
        arguments = countArguments + listOf(
            navArgument(MeasurementRoutes.MaxRoundTripsArgument) { type = NavType.IntType },
        ),
    ) { entry ->
        val count = entry.arguments.readCount()
        val maxRoundTrips = entry.arguments
            ?.getInt(MeasurementRoutes.MaxRoundTripsArgument)
            ?: error("経路の引数に往復の上限がありません")
        val route = MeasurementRoutes.memoryRoundTrip(count, maxRoundTrips)
        val items = remember(count) { DemoData.largeItems(count) }
        SampleScaffold(title = "計測: メモリ $count 件", onBack = onBack) {
            MemoryRoundTripScreen(
                items = items,
                maxRoundTrips = maxRoundTrips,
                modifier = Modifier.markMeasurementScreen(route),
            )
        }
    }

    imageMeasurementDestinations(onBack)
}

/**
 * 画像グリッドの計測用の画面を経路に加える。
 *
 * 土俵はデモ画面「画像グリッド」と同じ宣言元 ([ImageGridFixture]) から取り、件数と
 * プリフェッチの到達点だけを経路で選べるようにする。操作バーは計測に関係しないため持たない。
 *
 * @param onBack 戻る導線の処理
 */
private fun NavGraphBuilder.imageMeasurementDestinations(onBack: () -> Unit) {
    composable(route = MeasurementRoutes.imageBehavior()) {
        SampleScaffold(title = "検証: 画像の挙動", onBack = onBack) {
            ImageBehaviorVerificationScreen(
                modifier = Modifier.markMeasurementScreen(MeasurementRoutes.imageBehavior()),
            )
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}image/{${MeasurementRoutes.CountArgument}}" +
            "/{${MeasurementRoutes.DestinationArgument}}",
        arguments = listOf(
            navArgument(MeasurementRoutes.CountArgument) { type = NavType.IntType },
            navArgument(MeasurementRoutes.DestinationArgument) { type = NavType.StringType },
        ),
    ) { entry ->
        val count = entry.arguments.readCount()
        val choice = entry.arguments.readPrefetchChoice()
        val route = MeasurementRoutes.imageGrid(count, choice.routeSegment)
        SampleScaffold(title = "計測: 画像 $count 件 ${choice.title}", onBack = onBack) {
            ImageGridMeasurementScreen(
                count = count,
                choice = choice,
                modifier = Modifier.markMeasurementScreen(route),
            )
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}image-memory/{${MeasurementRoutes.CountArgument}}" +
            "/{${MeasurementRoutes.MaxRoundTripsArgument}}" +
            "/{${MeasurementRoutes.DestinationArgument}}",
        arguments = listOf(
            navArgument(MeasurementRoutes.CountArgument) { type = NavType.IntType },
            navArgument(MeasurementRoutes.MaxRoundTripsArgument) { type = NavType.IntType },
            navArgument(MeasurementRoutes.DestinationArgument) { type = NavType.StringType },
        ),
    ) { entry ->
        val count = entry.arguments.readCount()
        val maxRoundTrips = entry.arguments.readMaxRoundTrips()
        val choice = entry.arguments.readPrefetchChoice()
        val route = MeasurementRoutes.imageMemoryRoundTrip(
            count,
            maxRoundTrips,
            choice.routeSegment,
        )
        val items = remember(count) { ImageGridFixture.items(count) }
        SampleScaffold(
            title = "計測: 画像メモリ $count 件 ${choice.title}",
            onBack = onBack,
        ) {
            MemoryRoundTripScreen(
                items = items,
                maxRoundTrips = maxRoundTrips,
                modifier = Modifier.markMeasurementScreen(route),
                layout = ImageGridFixture.layout,
                contentPadding = ImageGridFixture.contentPadding,
                prefetchResources = ImageGridFixture.resources(choice.destination),
                prefetchDestination = choice.destination ?: KsPrefetchDestination.Disk,
                row = { item -> ImageGridCell(item) },
            )
        }
    }
}

/**
 * 「画像グリッド」の土俵を、操作バーを持たずに描く計測用の画面。
 *
 * 要素・配置・外周の余白・プリフェッチの宣言はデモ画面と同じ [ImageGridFixture] から取る。
 * 計測でデモ画面と違う土俵を測ってしまわないよう、件数と到達点以外はここで宣言しない。
 *
 * @param count 土俵の件数
 * @param choice プリフェッチの到達点の選択
 */
@Composable
fun ImageGridMeasurementScreen(
    count: Int,
    choice: ImagePrefetchChoice,
    modifier: Modifier = Modifier,
) {
    val items = remember(count) { ImageGridFixture.items(count) }
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = ImageGridFixture.layout,
        contentPadding = ImageGridFixture.contentPadding,
        prefetchResources = ImageGridFixture.resources(choice.destination),
        prefetchDestination = choice.destination ?: KsPrefetchDestination.Disk,
    ) {
        template { item -> ImageGridCell(item) }
    }
}

/** 経路の文字列に使う到達点の名前。 */
val ImagePrefetchChoice.routeSegment: String
    get() = name.lowercase()

/**
 * 目的の画面が載ったことを外から読めるようにする印を付ける。
 *
 * @param route この画面を開いた経路
 */
private fun Modifier.markMeasurementScreen(route: String): Modifier =
    semantics { contentDescription = MeasurementRoutes.screenDescription(route) }

/** 経路の引数から件数を読む。 */
private fun Bundle?.readCount(): Int =
    this?.getInt(MeasurementRoutes.CountArgument) ?: error("経路の引数に件数がありません")

/** 経路の引数から往復の上限を読む。 */
private fun Bundle?.readMaxRoundTrips(): Int =
    this?.getInt(MeasurementRoutes.MaxRoundTripsArgument)
        ?: error("経路の引数に往復の上限がありません")

/** 経路の引数からプリフェッチの選択を読む。 */
private fun Bundle?.readPrefetchChoice(): ImagePrefetchChoice {
    val name = this?.getString(MeasurementRoutes.DestinationArgument)
        ?: error("経路の引数に到達点がありません")
    return ImagePrefetchChoice.entries.firstOrNull { it.routeSegment == name }
        ?: error("経路の引数の到達点を解釈できません: $name")
}

/**
 * 「大量件数」の土俵を、ライブラリを通さず素の LazyVerticalGrid で描く。
 *
 * ラッパーが薄いこと (android/ADR-0001) を、同じ土俵の測定値の差として確かめるための比較対象。
 * 件数・列数・行間 / 列間・行の見た目はライブラリ側と同一にする。
 *
 * @param items 表示する要素
 */
@Composable
fun BaselineLargeDataGrid(items: List<DemoItem>, modifier: Modifier = Modifier) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = modifier.fillMaxSize().background(SampleTheme.background),
        verticalArrangement = Arrangement.spacedBy(1.dp),
        horizontalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        items(items = items, key = { it.id }) { item ->
            // ライブラリは項目の content を包む Box で高さの変化をアニメーションする。
            // 比較対象にも同じ修飾を同じ位置に置き、既定機能の有無で条件がずれないようにする。
            Box(Modifier.fillMaxWidth().animateContentSize()) {
                DemoListRow(item)
            }
        }
    }
}

/**
 * 「大量件数」の土俵を、ライブラリを通さず素の LazyColumn で 1 列に描く。
 *
 * ライブラリは 1 列も多列と同じ経路 (1 列のグリッド) で描くため、その選択が Compose の
 * 1 列専用の経路に対してどれだけ違うかをここで見る (android/ADR-0001)。
 *
 * @param items 表示する要素
 */
@Composable
fun BaselineLargeDataList(items: List<DemoItem>, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier.fillMaxSize().background(SampleTheme.background),
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        items(items = items, key = { it.id }) { item ->
            // 多列の比較対象と同じく、ライブラリの既定機能に条件をそろえる。
            Box(Modifier.fillMaxWidth().animateContentSize()) {
                DemoListRow(item)
            }
        }
    }
}
