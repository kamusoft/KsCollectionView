package jp.kamusoft.kscollectionview.samples.android

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import java.util.concurrent.ConcurrentHashMap

/** 読み込み中の計数を logcat に出すときのタグ。計測側はこのタグの行を数える。 */
const val ImageLoadingSlotTag: String = "KsImageLoadingSlot"

/**
 * 読み込み中の表示が組み立てられた回数の計数。
 *
 * 「読み込み中を経由したか」は、要求の件数や取得元では代用できない。メモリにある画像を同期で
 * 引き当てて読み込み中を挟まない経路があるため、**要求が起きないこと**と
 * **読み込み中を出さないこと**は別の事実である。ここでは読み込み中の表示そのものが
 * 組み立てられた回数を、要素の識別子つきで 1 件ずつ数える。
 *
 * 数は 2 種類に分ける。表示枠の大きさが決まる前の読み込み中 (`unsized`) と、枠は決まっていて
 * 取得を待っている読み込み中 (`sized`) である。[jp.kamusoft.kscollectionview.KsImage] は枠の
 * 大きさが決まるまで取得を始めず読み込み中を出すため、前者は取得の状況と無関係に現れることが
 * ある。混ぜて数えると「読み込み中を経由していない」を判定できなくなるので、記録の時点で分ける。
 *
 * ## 観測区間 (基準点) と判定規則
 *
 * 判定に使うのは `sized` の側だが、**累計では判定できない**。「戻ってきたときの再表示」を見る
 * 手順は「初回表示 → 画面外へ送る → 戻す」であり、初回表示の時点で対象の `sized` は通常
 * 1 以上になる。累計の `sized == 0` を規則にすると、正しく即時再表示された場合まで不合格に
 * なる。
 *
 * そこで**基準点** ([beginSession]) を設ける。初回表示が終わった時点・画面外へ送る直前に
 * 基準点を切ると、そこから先の増分だけを数えた観測区間が始まる。判定規則は
 * **対象の要素ごとに「基準点からの差分 `Δsized` が 0」** である。
 *
 * 基準点は画面の印 ([ImageLoadingSlotMark]) を叩くと切れる (iOS Sample も同じ操作)。区間には
 * 1 から始まる通し番号 ([session]) が付き、印とログの両方に載る。番号が違う記録は別の区間の
 * ものなので、突き合わせに混ぜてはいけない。
 *
 * 計数は Activity より長く生きるため、入口 ([MainActivity]) は起動のたびに [reset] を呼んで
 * 前の Activity の値が混ざらないようにする。
 *
 * 数えるかどうかは実行時の指定 ([SampleRoutes.CountImageLoadingSlotsExtra]) で決める。
 * 指定が無い限り読み込み中の表示を差し込まず、本体の既定の表示をそのまま通す。この構成の
 * セルはデモ画面・計測用の画面・検証画面が共有しており、常時差し込むと「読み込み中の既定の
 * 表示」を観測点に持つ検証画面が本体の既定を通らなくなる。
 *
 * 配布する構成では何もしない実装に差し替わる。
 */
object ImageLoadingSlotCounter {

    private val tallies = ConcurrentHashMap<Any, ImageLoadingSlotTally>()

    /** 基準点を切った時点の累計。差分はここからの増分になる。 */
    private val baseline = ConcurrentHashMap<Any, ImageLoadingSlotTally>()

    // 入口 (Activity) が書き、Compose の各所が読む。スレッドをまたぐため可視性を明示する。
    @Volatile
    private var enabled = false

    // 印が読み、基準点を切る操作が書く。同上。
    @Volatile
    private var sessionNumber = 0

    /** 観測区間の通し番号。0 は基準点をまだ切っていない状態 (差分 = 累計) を表す。 */
    val session: Int get() = sessionNumber

    /** 数えることが要求されているかどうか。 */
    val isEnabled: Boolean get() = enabled

    /**
     * 数えるかどうかを決める。入口が起動時の指定を読んで 1 度だけ呼ぶ。
     *
     * @param enabled 数えるなら true
     */
    fun setEnabled(enabled: Boolean) {
        this.enabled = enabled
    }

    /**
     * 読み込み中の表示として渡す組み立てを返す。数えることが要求されているときだけ、
     * 数える表示を返す。要求されていなければ null を返し、本体の既定の表示に任せる。
     *
     * 呼び出しごとに新しい組み立てを作ると、渡された側が毎回作り直しになる。要素ごとに
     * 覚えておいて同じものを返す。
     *
     * @param itemId 読み込み中を出している要素の識別子
     */
    @Composable
    fun rememberLoadingSlot(itemId: Any): (@Composable () -> Unit)? {
        val enabled = isEnabled
        return remember(itemId, enabled) {
            if (enabled) {
                { CountedLoadingSlot(itemId) }
            } else {
                null
            }
        }
    }

    /** 要素ごとの累計。画面の印が総数の併記に使う。 */
    fun snapshot(): Map<Any, ImageLoadingSlotTally> = tallies.toMap()

    /**
     * 要素ごとの、基準点からの差分。画面の印が主に見せる側。
     *
     * 基準点より前から数えられている要素も差分 0 として残す (`items=` の件数に含まれ、ログ側で
     * 対象 ID の `sized` が増えた行が無いことと突き合わせる材料になる)。ただし印の内訳は差分の
     * 大きい順に並ぶため、差分 0 の要素は最後尾に回り、要素数が上限を超えると内訳には現れない —
     * 判定対象の `Δsized == 0` はログ側で読む。
     */
    fun deltaSnapshot(): Map<Any, ImageLoadingSlotTally> =
        tallies.entries.associate { (id, tally) -> id to tally.subtracting(baselineOf(id)) }

    /**
     * 1 要素の計数 (累計)。まだ 1 回も出していない要素には 0 件の計数を返す。
     *
     * @param itemId 読み込み中を出している要素の識別子
     */
    fun tally(itemId: Any): ImageLoadingSlotTally = tallies[itemId] ?: ImageLoadingSlotTally()

    /**
     * 1 要素の、基準点からの差分。判定はこの `sized` が 0 かどうかで行う。
     *
     * @param itemId 対象の要素の識別子
     */
    fun delta(itemId: Any): ImageLoadingSlotTally = tally(itemId).subtracting(baselineOf(itemId))

    /**
     * 観測区間を切り直す。この時点の累計を基準点として覚え、通し番号を 1 つ進める。
     *
     * 累計は消さない。消すと「初回表示で何回経由したか」が失われ、基準点の前後を突き合わせ
     * られなくなる。
     */
    fun beginSession() {
        baseline.clear()
        baseline.putAll(tallies)
        sessionNumber += 1
    }

    /** 計数・基準点・区間の通し番号をすべて初期状態に戻す。 */
    fun reset() {
        tallies.clear()
        baseline.clear()
        sessionNumber = 0
    }

    private fun baselineOf(itemId: Any): ImageLoadingSlotTally =
        baseline[itemId] ?: ImageLoadingSlotTally()

    /**
     * 読み込み中の表示が 1 回組み立てられたことを数える。
     *
     * @param itemId 読み込み中を出している要素の識別子
     * @param width そのときの表示枠の幅 (画素)。決まっていなければ 0
     * @param height そのときの表示枠の高さ (画素)。決まっていなければ 0
     */
    internal fun record(itemId: Any, width: Int, height: Int) {
        val isSized = width > 0 && height > 0
        val next = tallies.compute(itemId) { _, previous ->
            val base = previous ?: ImageLoadingSlotTally()
            if (isSized) base.copy(sized = base.sized + 1) else base.copy(unsized = base.unsized + 1)
        } ?: ImageLoadingSlotTally()
        val delta = next.subtracting(baselineOf(itemId))
        // 1 回ごとに出す。数の正確さがそのまま判定の根拠になるため間引かない。
        // `sized` / `unsized` は基準点からの差分 (印と同じ側)、`total=` が累計。
        Log.i(
            ImageLoadingSlotTag,
            "loading session=$sessionNumber item=$itemId size=${width}x$height " +
                "sized=${delta.sized} unsized=${delta.unsized} " +
                "total=${next.sized}/${next.unsized}",
        )
    }
}

/**
 * 1 つの要素が読み込み中を出した回数。
 *
 * @property sized 表示枠が決まった状態で出した回数 (判定に使う側)
 * @property unsized 表示枠が決まる前に出した回数
 */
data class ImageLoadingSlotTally(val sized: Long = 0, val unsized: Long = 0) {

    /**
     * 基準点の計数を差し引いた差分を返す。
     *
     * @param other 差し引く計数 (基準点の値)
     */
    fun subtracting(other: ImageLoadingSlotTally): ImageLoadingSlotTally =
        ImageLoadingSlotTally(sized = sized - other.sized, unsized = unsized - other.unsized)
}

/**
 * 読み込み中の既定の表示に、組み立てられたことを数える働きだけを足したもの。
 *
 * 見た目は本体の既定の表示 (無地) と同じにする。計測する土俵をデモ画面と同じに保つため、
 * 数えること以外は何も変えない。
 *
 * @param itemId 読み込み中を出している要素の識別子
 */
@Composable
private fun CountedLoadingSlot(itemId: Any) {
    // 表示枠が決まる前かどうかを、この表示自身に与えられた制約で見分ける。
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val width = if (constraints.hasBoundedWidth) constraints.maxWidth else 0
        val height = if (constraints.hasBoundedHeight) constraints.maxHeight else 0
        ImageLoadingSlotCounter.record(itemId, width, height)
        Box(modifier = Modifier.fillMaxSize().background(LoadingSlotColor))
    }
}

// 本体の既定の読み込み中表示と同じ無彩色。テーマには依存しない固定値。
private val LoadingSlotColor = Color(0xFFE0E0E0)
