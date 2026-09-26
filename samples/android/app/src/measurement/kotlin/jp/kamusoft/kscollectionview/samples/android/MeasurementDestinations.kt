package jp.kamusoft.kscollectionview.samples.android

import android.os.Bundle
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsPrefetchDestination
import kotlinx.coroutines.delay

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

    /** ライブラリで描く「グループ化」の土俵。 */
    fun ksGrouping(): String = "${Prefix}grouping"

    /** 素の LazyVerticalGrid で描く「グループ化」の比較対象。 */
    fun baselineGrouping(): String = "${Prefix}baseline-grouping"

    /** メモリの定常判定のための自動往復。 */
    fun memoryRoundTrip(count: Int, maxRoundTrips: Int): String =
        "${Prefix}memory/$count/$maxRoundTrips"

    /** 自動往復が置換の後に離脱する先。離脱後の同時生存をここで読む。 */
    fun memoryResult(): String = "${Prefix}memory-result"

    /** 到達点を渡す引数の名前。 */
    const val DestinationArgument = "destination"

    /** ライブラリで描く画像グリッドの土俵。 */
    fun imageGrid(count: Int, destination: String): String =
        "${Prefix}image/$count/$destination"

    /** 画像グリッドのメモリの定常判定のための自動往復。 */
    fun imageMemoryRoundTrip(count: Int, maxRoundTrips: Int, destination: String): String =
        "${Prefix}image-memory/$count/$maxRoundTrips/$destination"

    /**
     * 画像グリッドのメモリの自動往復のうち、1 段階ごとに読み込みが落ち着くのを待ってから進むもの。
     *
     * 待たない往復は取得より速く進むため、メモリキャッシュがほとんど埋まらない。メモリキャッシュと
     * 索引の中身を定常状態で見るときに使う。
     */
    fun imageMemoryLoadedRoundTrip(count: Int, maxRoundTrips: Int, destination: String): String =
        "${Prefix}image-memory-loaded/$count/$maxRoundTrips/$destination"

    /** 画像の挙動 (共有・読み込み中・失敗) の検証画面。 */
    fun imageBehavior(): String = "${Prefix}image-behavior"

    /** 同一ホストの同時取得数を渡す引数の名前。0 は既定のまま。 */
    const val MaxRequestsPerHostArgument = "maxRequestsPerHost"

    /**
     * 画像グリッドの土俵で、セルの出入り・止まった時点・読み込みの節目をログへ出す観測用の画面。
     *
     * @param maxRequestsPerHost 同一ホストの同時取得数。0 なら取得経路の既定のまま
     */
    fun imageObserve(count: Int, destination: String, maxRequestsPerHost: Int): String =
        "${Prefix}image-observe/$count/$destination/$maxRequestsPerHost"

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
 * @param onLeaveTo 自動走査が画面を離れて別の経路へ移る処理 (離れた画面は残さない)
 */
fun NavGraphBuilder.measurementDestinations(
    onBack: () -> Unit,
    onLeaveTo: (from: String, to: String) -> Unit,
) {
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

    composable(route = MeasurementRoutes.ksGrouping()) {
        SampleScaffold(title = "計測: ライブラリ グループ化", onBack = onBack) {
            GroupingCollection(
                items = GroupingDemoData.items,
                modifier = Modifier.markMeasurementScreen(MeasurementRoutes.ksGrouping()),
            )
        }
    }

    composable(route = MeasurementRoutes.baselineGrouping()) {
        SampleScaffold(title = "計測: 比較対象 グループ化", onBack = onBack) {
            BaselineGroupingGrid(
                items = GroupingDemoData.items,
                modifier = Modifier.markMeasurementScreen(MeasurementRoutes.baselineGrouping()),
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
                replacementItems = { replacementItems(count) },
                onLeave = { onLeaveTo(route, MeasurementRoutes.memoryResult()) },
            )
        }
    }

    composable(route = MeasurementRoutes.memoryResult()) {
        SampleScaffold(title = "計測: 解放の確認") {
            MeasurementResultScreen(
                modifier = Modifier.markMeasurementScreen(MeasurementRoutes.memoryResult()),
            )
        }
    }

    imageMeasurementDestinations(onBack, onLeaveTo)
}

/**
 * 置換の段階で差し替える、同じ件数で識別子の重ならない配列を作る。
 *
 * 識別子が重なると同じ項目として扱われてテンプレートが作り直されず、置換前の項目のための
 * 保持が解放されたかどうかを見られない。
 *
 * @param count 作る件数
 */
private fun replacementItems(count: Int): List<DemoItem> =
    DemoData.largeItems(count).map { item -> item.copy(id = item.id + count) }

/** 1 段階ごとに読み込みが落ち着くのを待つ上限 (ミリ秒)。 */
private const val ImageLoadingSettleDeadlineMillis = 10_000L

/**
 * 進行中の読み込みが無くなるのを、実時間の上限つきで待つ。
 *
 * 位置を送った直後は表示と先読みの要求がまだ出ていないことがあるため、先に少し待ってから数える。
 * 上限を超えたらそのまま進む (取得の遅れで走査全体が止まらないようにする)。
 */
private suspend fun awaitImageLoadingSettled() {
    delay(100)
    val deadline = System.currentTimeMillis() + ImageLoadingSettleDeadlineMillis
    while (ImageLoadingInFlight.current > 0 && System.currentTimeMillis() < deadline) {
        delay(50)
    }
}

/**
 * 画像グリッドの置換の段階で差し替える、同じ件数で識別子の重ならない配列を作る。
 *
 * 識別子を件数分ずらすため、置換後のセルは別の画像 (別の URL) を表示する。
 *
 * @param count 作る件数
 */
private fun imageReplacementItems(count: Int): List<DemoItem> =
    ImageGridFixture.items(count).map { item -> item.copy(id = item.id + count) }

/**
 * 画像グリッドの計測用の画面を経路に加える。
 *
 * 土俵はデモ画面「画像グリッド」と同じ宣言元 ([ImageGridFixture]) から取り、件数と
 * プリフェッチの到達点だけを経路で選べるようにする。操作バーは計測に関係しないため持たない。
 *
 * @param onBack 戻る導線の処理
 * @param onLeaveTo 自動走査が画面を離れて別の経路へ移る処理 (離れた画面は残さない)
 */
private fun NavGraphBuilder.imageMeasurementDestinations(
    onBack: () -> Unit,
    onLeaveTo: (from: String, to: String) -> Unit,
) {
    composable(route = MeasurementRoutes.imageBehavior()) {
        SampleScaffold(title = "検証: 画像の挙動", onBack = onBack) {
            ImageBehaviorVerificationScreen(
                modifier = Modifier.markMeasurementScreen(MeasurementRoutes.imageBehavior()),
            )
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}image-observe/{${MeasurementRoutes.CountArgument}}" +
            "/{${MeasurementRoutes.DestinationArgument}}" +
            "/{${MeasurementRoutes.MaxRequestsPerHostArgument}}",
        arguments = listOf(
            navArgument(MeasurementRoutes.CountArgument) { type = NavType.IntType },
            navArgument(MeasurementRoutes.DestinationArgument) { type = NavType.StringType },
            navArgument(MeasurementRoutes.MaxRequestsPerHostArgument) { type = NavType.IntType },
        ),
    ) { entry ->
        val count = entry.arguments.readCount()
        val choice = entry.arguments.readPrefetchChoice()
        val maxRequestsPerHost = entry.arguments
            ?.getInt(MeasurementRoutes.MaxRequestsPerHostArgument)
            ?: error("経路の引数に同時取得数がありません")
        // 共有インスタンスは最初の読み込みで作られる。土俵を組む前に指定しておく
        // (起動時にキャッシュを消す指定があると、その時点で既定の構成で作られてしまうため、
        // この画面はキャッシュの消去をアプリのデータの消去で行う前提で使う)。
        if (maxRequestsPerHost > 0) ImageLoadingNetworkOverride.maxRequestsPerHost = maxRequestsPerHost
        val route = MeasurementRoutes.imageObserve(count, choice.routeSegment, maxRequestsPerHost)
        SampleScaffold(title = "観測: 画像 $count 件 ${choice.title}", onBack = onBack) {
            ImageObserveScreen(
                count = count,
                choice = choice,
                modifier = Modifier.markMeasurementScreen(route),
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
        val context = LocalContext.current
        // 往復ごとと離脱後に、メモリキャッシュと索引の中身を記録する。
        MemoryIndexProbe.enabled = true
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
                prefetchResources = ImageGridFixture.resources(choice),
                prefetchDestination = choice.destination ?: KsPrefetchDestination.Disk,
                replacementItems = { imageReplacementItems(count) },
                onLeave = { onLeaveTo(route, MeasurementRoutes.memoryResult()) },
                roundTripProbe = { MemoryIndexProbe.describe(context) },
                row = { item -> ImageGridCell(item) },
            )
        }
    }

    composable(
        route = "${MeasurementRoutes.Prefix}image-memory-loaded/{${MeasurementRoutes.CountArgument}}" +
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
        val route = MeasurementRoutes.imageMemoryLoadedRoundTrip(
            count,
            maxRoundTrips,
            choice.routeSegment,
        )
        val items = remember(count) { ImageGridFixture.items(count) }
        val context = LocalContext.current
        // 往復ごとと離脱後に、メモリキャッシュと索引の中身を記録する。
        MemoryIndexProbe.enabled = true
        SampleScaffold(
            title = "計測: 画像メモリ (読み込み待ち) $count 件 ${choice.title}",
            onBack = onBack,
        ) {
            MemoryRoundTripScreen(
                items = items,
                maxRoundTrips = maxRoundTrips,
                modifier = Modifier.markMeasurementScreen(route),
                layout = ImageGridFixture.layout,
                contentPadding = ImageGridFixture.contentPadding,
                prefetchResources = ImageGridFixture.resources(choice),
                prefetchDestination = choice.destination ?: KsPrefetchDestination.Disk,
                replacementItems = { imageReplacementItems(count) },
                onLeave = { onLeaveTo(route, MeasurementRoutes.memoryResult()) },
                roundTripProbe = { MemoryIndexProbe.describe(context) },
                afterStep = { awaitImageLoadingSettled() },
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
    Column(modifier = modifier.fillMaxSize()) {
        // 数えることを要求した実行でだけ現れる印。frameOverrun を測る実行 (数えない) では
        // 出ないため、土俵の高さは要求しない限りデモ画面と同じままになる。
        ImageLoadingSlotMark()

        KsCollectionView(
            items = items,
            key = { it.id },
            modifier = Modifier.weight(1f),
            layout = ImageGridFixture.layout,
            contentPadding = ImageGridFixture.contentPadding,
            prefetchResources = ImageGridFixture.resources(choice),
            prefetchDestination = choice.destination ?: KsPrefetchDestination.Disk,
        ) {
            template { item -> ImageGridCell(item) }
        }
    }
}

/** 経路の文字列に使うプリフェッチの形の名前。起動時の指定と同じ綴りにする。 */
val ImagePrefetchChoice.routeSegment: String
    get() = argument

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
 * ライブラリの上乗せ分が小さいことを、同じ土俵の測定値の差として確かめるための比較対象。
 * 件数・列数・行間 / 列間・行の見た目はライブラリ側と同一にし、ライブラリの既定機能 (高さ変化の
 * アニメーション・配置のアニメーション・縦スクロールインジケータ) を同じ位置に付ける。
 *
 * @param items 表示する要素
 */
@Composable
fun BaselineLargeDataGrid(items: List<DemoItem>, modifier: Modifier = Modifier) {
    val state = rememberLazyGridState()
    val indicator = rememberBaselineScrollIndicatorVisibility(state, state.interactionSource)
    val columns = 2
    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        state = state,
        modifier = modifier
            .fillMaxSize()
            .background(SampleTheme.background)
            .baselineGroupedScrollIndicator(
                state = state,
                visibility = indicator,
                totalRows = (items.size + columns - 1) / columns,
                rowOfLazy = { it / columns },
                isHeader = { false },
            ),
        verticalArrangement = Arrangement.spacedBy(1.dp),
        horizontalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        items(items = items, key = { it.id }) { item ->
            // ライブラリは項目の入れ物のいちばん外側で配置の変化を、その内側で高さの変化を
            // アニメーションする。比較対象にも同じ修飾を同じ順に置き、既定機能の有無で条件が
            // ずれないようにする。
            Box(Modifier.animateItem().fillMaxWidth().animateContentSize()) {
                DemoListRow(item)
            }
        }
    }
}

/**
 * 「大量件数」の土俵を、ライブラリを通さず素の LazyColumn で 1 列に描く。
 *
 * ライブラリは 1 列も多列と同じ経路 (1 列のグリッド) で描くため、その選択が Compose の
 * 1 列専用の経路に対してどれだけ違うかをここで見る。
 *
 * @param items 表示する要素
 */
@Composable
fun BaselineLargeDataList(items: List<DemoItem>, modifier: Modifier = Modifier) {
    val state = rememberLazyListState()
    val indicator = rememberBaselineScrollIndicatorVisibility(state, state.interactionSource)
    LazyColumn(
        state = state,
        modifier = modifier
            .fillMaxSize()
            .background(SampleTheme.background)
            .baselineScrollIndicator(state, indicator),
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        items(items = items, key = { it.id }) { item ->
            // 多列の比較対象と同じく、ライブラリの既定機能に条件をそろえる。
            Box(Modifier.animateItem().fillMaxWidth().animateContentSize()) {
                DemoListRow(item)
            }
        }
    }
}

/** 比較対象の見出しの再利用種別。 */
private object BaselineHeaderContentType

/** 比較対象の項目の再利用種別。 */
private object BaselineItemContentType

/**
 * 「グループ化」の土俵を、ライブラリを通さず素の LazyVerticalGrid で描く。
 *
 * 件数・グループ分け・列数 (縦長 2 列 / 横長 4 列)・間隔・行と見出しの見た目・固定される見出しは
 * ライブラリ側 ([GroupingCollection]) と同一にし、ライブラリの既定機能 (高さ変化のアニメーション・
 * 配置のアニメーション・縦スクロールインジケータ) を同じ位置に付ける。行間・見出しの下の間隔・
 * グループ間の間隔は、ライブラリと同じく項目の上下の余白として置く。
 *
 * @param items 表示する要素 (同じグループの項目が続いて並ぶ配列)
 */
@Composable
fun BaselineGroupingGrid(items: List<GroupingDemoItem>, modifier: Modifier = Modifier) {
    // 同じグループが続く範囲。並べ方と行の数え方の両方に使う。
    val runs = remember(items) {
        buildList {
            var start = 0
            for (index in 1..items.size) {
                if (index == items.size || items[index].group != items[start].group) {
                    add(start until index)
                    start = index
                }
            }
        }
    }
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val columns = if (maxHeight > maxWidth) 2 else 4
        val state = rememberLazyGridState()
        val indicator = rememberBaselineScrollIndicatorVisibility(state, state.interactionSource)
        // 見出しを 1 行と数えたときの、lazy の index から行の番号への対応。
        val rowOfLazy = remember(runs, columns) {
            val rows = IntArray(items.size + runs.size)
            var lazy = 0
            var row = 0
            for (run in runs) {
                rows[lazy++] = row++
                for (position in 0 until run.count()) {
                    rows[lazy++] = row + position / columns
                }
                row += (run.count() + columns - 1) / columns
            }
            rows to row
        }
        val spacing = GroupHeaderMetrics.gridSpacing
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            state = state,
            modifier = Modifier
                .fillMaxSize()
                .background(SampleTheme.background)
                .baselineGroupedScrollIndicator(
                    state = state,
                    visibility = indicator,
                    totalRows = rowOfLazy.second,
                    rowOfLazy = { rowOfLazy.first.getOrElse(it) { 0 } },
                    isHeader = { it === BaselineHeaderContentType },
                ),
            horizontalArrangement = Arrangement.spacedBy(spacing),
        ) {
            runs.forEachIndexed { runIndex, run ->
                val group = items[run.first].group
                val count = run.count()
                stickyHeader(key = "header-$group", contentType = BaselineHeaderContentType) {
                    Box(Modifier.animateItem().fillMaxWidth().animateContentSize()) {
                        GroupHeaderBand(name = GroupingFixture.groupName(group), itemCount = count)
                    }
                }
                val lastRow = (count - 1) / columns
                val isLastGroup = runIndex == runs.lastIndex
                items(
                    count = count,
                    key = { local -> items[run.first + local].id },
                    contentType = { BaselineItemContentType },
                ) { local ->
                    val row = local / columns
                    Box(
                        Modifier
                            .animateItem()
                            .fillMaxWidth()
                            .padding(
                                top = spacing,
                                bottom = if (row == lastRow && !isLastGroup) {
                                    GroupHeaderMetrics.groupSpacing
                                } else {
                                    0.dp
                                },
                            )
                            .animateContentSize(),
                    ) {
                        DemoListRow(items[run.first + local].row)
                    }
                }
            }
        }
    }
}
