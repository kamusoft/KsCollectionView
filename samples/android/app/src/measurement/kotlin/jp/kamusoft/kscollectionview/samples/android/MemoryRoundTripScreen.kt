package jp.kamusoft.kscollectionview.samples.android

import android.os.Debug
import android.util.Log
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsScrollPosition
import jp.kamusoft.kscollectionview.rememberKsScrollController
import kotlinx.coroutines.delay

/** 走査の進捗を外から読むための印。計測側はこの印の付いた表示の文字列を読む。 */
const val MeasurementStatusDescription: String = "measurement-status"

/** 1 段階で送る要素数。可視範囲の半分ほどに収め、間の要素を飛ばさないようにする。 */
private const val ScanStepItems = 16

/** 定常とみなす増分の割合。 */
private const val SteadyRatio = 0.02

/** 1 段階の到達を待つ上限 (ミリ秒)。 */
private const val StepDeadlineMillis = 10_000L

/**
 * メモリの定常判定のために、全要素を通過する往復を自動で重ねる画面。
 *
 * 走査・記録・停止まで画面自身が行う。人の操作に依存しないため、同じ手順を何度でも再現できる。
 * 往復ごとに使用メモリ (PSS 合計) を記録し、連続する 2 往復の増分がいずれも 2% 以内になった
 * 時点で定常とみなして止める。
 *
 * 走査の各段階は、命令を出した後にフレームを数えるのではなく、**対象の項目が実際に載った**
 * ことを条件に次へ進む。フレーム数で進めると、実行機が混んでいるときに命令が追い越されて
 * 間の項目が作られず、「メモリが増えない = 合格」という向きに誤る。到達しないまま上限時間を
 * 過ぎたときと、往復の上限まで定常にならなかったときは、進捗の印を失敗として残して止める
 * (計測側はその印を読んでテストを失敗させる)。
 *
 * @param items 表示する要素
 * @param maxRoundTrips 重ねる往復の上限
 */
@Composable
fun MemoryRoundTripScreen(
    items: List<DemoItem>,
    maxRoundTrips: Int,
    modifier: Modifier = Modifier,
) {
    val controller = rememberKsScrollController()
    var status by remember { mutableStateOf("running") }
    // いま載っている項目の識別子。1 段階の到達判定はこの集合に対象が入ったことで行う。
    val composed = remember(items) { mutableSetOf<Int>() }
    // 走査中に載った項目の識別子 (往復ごとに数え直す)。全項目を通過したことをこの大きさで確かめる。
    val visited = remember(items) { mutableSetOf<Int>() }

    LaunchedEffect(items, maxRoundTrips) {
        val readings = mutableListOf<Long>()
        var settledAt = 0
        var failure: String? = null

        for (trip in 1..maxRoundTrips) {
            // 往復の開始時点で載っている項目は、この往復で通過済みとして数え始める
            // (すでに載っている項目は改めて載り直さないため)。
            visited.clear()
            visited += composed
            failure = scan(items, composed) { id ->
                controller.scrollTo(id, KsScrollPosition.Start, false)
            }
            if (failure != null) break

            // 両端に到達し、間の項目もすべて通過したことを往復ごとに確かめる。
            if (visited.size < items.size) {
                failure = "missedItems:${items.size - visited.size}/${items.size}"
                break
            }

            // 回収されうる分を先に落としてから読む。読み取り自体は往復の終了時点で行う。
            System.gc()
            delay(300)
            val info = Debug.MemoryInfo()
            Debug.getMemoryInfo(info)
            val pss = info.totalPss.toLong()
            readings += pss
            Log.i(
                "KsMemoryRoundTrip",
                "items=${items.size} roundTrip=$trip totalPssKb=$pss visited=${visited.size}",
            )

            if (isSteady(readings)) {
                settledAt = trip
                break
            }
        }

        status = when {
            failure != null -> failure
            settledAt > 0 -> "steady:$settledAt"
            else -> "notSteady:${readings.size}:${readings.joinToString("/")}"
        }
        Log.i("KsMemoryRoundTrip", "items=${items.size} result=$status series=$readings")
    }

    Column(modifier = modifier.fillMaxSize()) {
        Text(
            text = status,
            color = SampleTheme.secondaryText,
            modifier = Modifier.semantics { contentDescription = MeasurementStatusDescription },
        )
        // 土俵の配置はデモ画面と同じ宣言元 (LargeDataLayout) から取る。走査の到達確認のために
        // 項目が載ったことを記録する点だけがデモ画面との違い。
        KsCollectionView(
            items = items,
            key = { it.id },
            scrollController = controller,
            layout = LargeDataLayout,
        ) {
            template { item ->
                DisposableEffect(item.id) {
                    composed += item.id
                    visited += item.id
                    onDispose { composed -= item.id }
                }
                DemoListRow(item)
            }
        }
    }
}

/**
 * 先頭から末尾へ、そして末尾から先頭へ、可視範囲の半分ずつ送る 1 往復。
 *
 * @param items 走査する要素
 * @param composed いま載っている項目を持つ集合
 * @param scrollTo 指定した識別子の項目まで送る処理
 * @return 到達できなかった場合の失敗の印。すべて到達できたら null
 */
private suspend fun scan(
    items: List<DemoItem>,
    composed: Set<Int>,
    scrollTo: (Any) -> Unit,
): String? {
    var index = 0
    while (index < items.size) {
        awaitArrival(items[index].id, composed, scrollTo)?.let { return it }
        index += ScanStepItems
    }
    // 末尾は刻みの都合で飛ばされうるため、最後に明示して両端到達を保証する。
    awaitArrival(items.last().id, composed, scrollTo)?.let { return it }

    index = items.lastIndex
    while (index >= 0) {
        awaitArrival(items[index].id, composed, scrollTo)?.let { return it }
        index -= ScanStepItems
    }
    awaitArrival(items.first().id, composed, scrollTo)?.let { return it }
    return null
}

/**
 * 対象の項目まで送り、その項目が実際に載るまで待つ。
 *
 * 待ちの上限は実時間で区切る。反復回数で区切ると、対象がバックグラウンドにある間にループが
 * 燃え尽きて「待ったつもり」になる。
 *
 * @param id 送り先の項目の識別子
 * @param composed いま載っている項目を持つ集合
 * @param scrollTo 指定した識別子の項目まで送る処理
 * @return 上限時間内に載らなかった場合の失敗の印。載ったら null
 */
private suspend fun awaitArrival(id: Int, composed: Set<Int>, scrollTo: (Any) -> Unit): String? {
    scrollTo(id)
    val deadline = System.currentTimeMillis() + StepDeadlineMillis
    while (System.currentTimeMillis() < deadline) {
        if (id in composed) return null
        // 待機対象 (コンポジションと配置) へ実行機会を譲る。
        delay(4)
    }
    return "unreached:$id"
}

/** 連続する 2 往復の増分がいずれも 2% 以内なら定常とみなす。 */
private fun isSteady(readings: List<Long>): Boolean {
    if (readings.size < 3) return false
    val last3 = readings.takeLast(3)
    val first = (last3[1] - last3[0]).toDouble() / last3[0]
    val second = (last3[2] - last3[1]).toDouble() / last3[1]
    // 減少も「増え続けていない」として定常に含める。判定の意図は増加が止まったことの確認で
    // あり、実行ごとの揺れによる減少を未定常とは扱わない (証跡にもこの読みを明記する)。
    return first <= SteadyRatio && second <= SteadyRatio
}
