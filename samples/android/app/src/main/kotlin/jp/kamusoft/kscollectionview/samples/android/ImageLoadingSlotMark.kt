package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/** 読み込み中の計数を外から読むための印。計測側はこの印の付いた表示の文字列を読む。 */
const val ImageLoadingSlotStatusDescription: String = "image-loading-slot-status"

/** 印に並べる要素ごとの内訳の上限。読み取り側が扱える長さに収める。 */
private const val SlotDetailLimit = 20

/** 印を書き換える間隔 (ミリ秒)。 */
private const val SlotMarkRefreshMillis = 250L

/**
 * 読み込み中の計数を画面の印として出す。基準点を切る操作もここが受け持つ。
 *
 * 計数の読み出しが logcat だけだと、**ログが落ちた分はそのまま `sized` の減少に見え、
 * 「読み込み中を経由していない」= 合格の側に倒れる**。画面にも同じ数を出し、証跡ではログと
 * この印を突き合わせて初めて判定に使う。
 *
 * ## 見せる数
 *
 * 主に見せるのは**基準点からの差分**である (`sized` / `unsized` / `lines` と要素ごとの内訳)。
 * 累計は `total=` に併記する。書式は iOS Sample の同じ印とそろえている。
 *
 * 印の数は読み込み中の表示が組み立てられた回数である。画面に出る前に組み立てられ、描かれない
 * まま画像に替わる読み込み中もここに数えられるため、「読み込み中を画面に出したか」の判定
 * (`Δshown` が 0) はログの `shown` の行で読む ([ImageLoadingSlotCounter] の「組み立てと、画面に
 * 出た読み込み中」)。
 *
 * ## 基準点を切る
 *
 * この印を叩くと観測区間が切り替わる ([ImageLoadingSlotCounter.beginSession])。
 * 「初回表示 → 基準点 → 画面外へ送る → 戻す」の手順では、初回表示が落ち着いた時点で 1 度
 * 叩いてから送り出す。区間の通し番号は `session=` に出るので、叩けたかどうかは画面で確かめ
 * られる。iOS Sample の同じ印も同じ操作・同じ書式である。
 *
 * ## 突き合わせ規則
 *
 * 判定に使う前に、次の 3 つがすべて成り立つことを確かめる。成り立たないときはログが落ちて
 * いるので、計測をやり直す (数が小さい側に倒れているため、そのまま合格にしない)。
 *
 * - ログの各行の `session=` が印の `session=` と一致すること (違う番号の行は別の区間の記録な
 *   ので、突き合わせに混ぜない)
 * - その区間の行数が、印の `lines` と一致すること
 * - 要素ごとに、ログの `sized=` の値が 1 から印の内訳の値まで飛びなく現れること
 *   (`unsized=` も同様。計数は 1 回ごとに 1 ずつ増えるため、飛びはそのまま欠落を意味する)
 *
 * 数えることが要求されていない実行では何も出さない。印そのものが出ないことが、
 * 「この実行は数えていない」ことの表明になる。
 */
@Composable
fun ImageLoadingSlotMark(modifier: Modifier = Modifier) {
    if (!ImageLoadingSlotCounter.isEnabled) return

    // 計数は Compose の状態ではないため、書き換えは検知できない。一定間隔で読み直す。
    var summary by remember { mutableStateOf(imageLoadingSlotSummary(0, emptyMap(), emptyMap())) }
    LaunchedEffect(Unit) {
        while (true) {
            summary = imageLoadingSlotSummary(
                session = ImageLoadingSlotCounter.session,
                delta = ImageLoadingSlotCounter.deltaSnapshot(),
                total = ImageLoadingSlotCounter.snapshot(),
            )
            delay(SlotMarkRefreshMillis)
        }
    }

    Text(
        text = summary,
        style = MaterialTheme.typography.bodySmall,
        color = SampleTheme.secondaryText,
        modifier = modifier
            .semantics { contentDescription = ImageLoadingSlotStatusDescription }
            // 計測する人が実機で確実に叩けるよう、文字の周りにも触れる余地を持たせる。
            // 数えない実行ではこの印自体が現れないため、デモの見た目には影響しない。
            .clickable { ImageLoadingSlotCounter.beginSession() }
            .padding(vertical = MarkTapPadding),
    )
}

/** 印を叩きやすくするための上下の余白。 */
private val MarkTapPadding = 4.dp

/**
 * 計数を印の文字列に組み立てる。副作用を持たない写像で、テストから直接確かめられる。
 *
 * 区間の通し番号 (`session`) と、基準点からの差分の総数 (`items` / `sized` / `unsized` /
 * `lines`)、累計 (`total=<sized>/<unsized>/<lines>`) を並べ、その後ろに要素ごとの差分を
 * `<識別子>:<sized>/<unsized>` の形で並べる。内訳は差分の大きい順 (`sized`、同値なら
 * `unsized`) に、同値なら識別子の順に [SlotDetailLimit] 件までとし、収まらなかった件数を
 * `more=` で残す (総数はすべての要素を数えているため、内訳を切ってもログとの突き合わせに
 * 使う数は失われない)。iOS Sample の同じ印と同じ書式・同じ並びにそろえる。
 *
 * @param session 観測区間の通し番号
 * @param delta 要素ごとの、基準点からの差分
 * @param total 要素ごとの累計
 */
fun imageLoadingSlotSummary(
    session: Int,
    delta: Map<Any, ImageLoadingSlotTally>,
    total: Map<Any, ImageLoadingSlotTally>,
): String {
    val sized = delta.values.sumOf { it.sized }
    val unsized = delta.values.sumOf { it.unsized }
    val totalSized = total.values.sumOf { it.sized }
    val totalUnsized = total.values.sumOf { it.unsized }
    // 内訳の枠は限られるので、差分の大きい要素から並べる。判定は差分で行うため、溢れさせたく
    // ないのは差分が出ている側 (差分 0 の要素はログにも行が出ない)。同値の並びは、識別子を
    // 文字列として比べて iOS と同じにそろえる。
    val entries = delta.entries.sortedWith(
        compareByDescending<Map.Entry<Any, ImageLoadingSlotTally>> { it.value.sized }
            .thenByDescending { it.value.unsized }
            .thenBy { it.key.toString() },
    )
    val detail = entries.take(SlotDetailLimit)
        .joinToString(" ") { (id, tally) -> "$id:${tally.sized}/${tally.unsized}" }
    val omitted = (entries.size - SlotDetailLimit).coerceAtLeast(0)
    val head = "slots session=$session items=${delta.size} " +
        "sized=$sized unsized=$unsized lines=${sized + unsized} " +
        "total=$totalSized/$totalUnsized/${totalSized + totalUnsized}"
    return listOf(
        head,
        detail.takeIf { it.isNotEmpty() },
        "more=$omitted".takeIf { omitted > 0 },
    ).filterNotNull().joinToString(" ")
}
