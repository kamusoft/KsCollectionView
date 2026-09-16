package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.geometry.Rect
import java.util.concurrent.atomic.AtomicLong

/**
 * 計測用の入口で、テンプレートの呼び出しと破棄を数えてライブラリが項目単位で持つ保持の寿命を見る。
 *
 * 数はプロセスに属し、画面を離れた後も読める。画面の中に数を持つと、離脱後に「いくつ残って
 * いるか」を読む相手そのものが消えてしまい、解放されたのか観測できなくなっただけなのかを
 * 区別できない。
 *
 * 計数は [TemplateInvocationCounter] とは別に持つ。あちらはデモ画面の確認用で呼び出しごとに
 * ログを出し、また配布しない構成でだけ実体を持つ。こちらは計測用の入口と同じ構成に置き、
 * フリックの計測を乱さないようログを出さない。
 */
object MeasurementLifetime {
    private val invoked = AtomicLong()
    private val disposed = AtomicLong()
    private val peak = AtomicLong()

    /** いま生きているテンプレートの数 (累計 − 破棄)。 */
    val alive: Long
        get() = invoked.get() - disposed.get()

    /** 観測した中での最大の同時生存数。可視範囲 + 先読み分の実測にあたる。 */
    val peakAlive: Long
        get() = peak.get()

    /** 数を 0 に戻す。走査を始める前に呼ぶ。 */
    fun reset() {
        invoked.set(0)
        disposed.set(0)
        peak.set(0)
    }

    /** テンプレートが 1 つ生き始めたことを数える。 */
    fun enter() {
        invoked.incrementAndGet()
        val current = alive
        peak.updateAndGet { previous -> maxOf(previous, current) }
    }

    /** テンプレートが 1 つ破棄されたことを数える。 */
    fun leave() {
        disposed.incrementAndGet()
    }
}

/**
 * いま画面の見える範囲に載っている項目の数を数える。
 *
 * 同時生存の上限は、同じ走査で観測した同時生存そのものを基準にすると「走査中からすでに多すぎた」
 * 場合を素通りさせる。見える範囲の件数はそれとは別の観測 (配置された矩形の重なり) なので、
 * 同時生存の上限をここから独立に決められる。
 */
class VisibleItemTracker {
    private var viewport: Rect = Rect.Zero
    private val bounds = mutableMapOf<Int, Rect>()

    /** 観測した中での最大の可視件数。 */
    var peakVisible: Int = 0
        private set

    /**
     * 見える範囲を更新する。
     *
     * @param rect 画面上での見える範囲
     */
    fun setViewport(rect: Rect) {
        viewport = rect
        refresh()
    }

    /**
     * 項目の位置を更新する。
     *
     * @param id 項目の識別子
     * @param rect 画面上での項目の位置
     */
    fun setItem(id: Int, rect: Rect) {
        bounds[id] = rect
        refresh()
    }

    /**
     * 項目を数える対象から外す。
     *
     * @param id 項目の識別子
     */
    fun removeItem(id: Int) {
        bounds.remove(id)
        refresh()
    }

    /** 数え直す。 */
    fun reset() {
        viewport = Rect.Zero
        bounds.clear()
        peakVisible = 0
    }

    private fun refresh() {
        if (viewport.isEmpty) return
        val visible = bounds.count { (_, rect) -> !rect.isEmpty && rect.overlaps(viewport) }
        if (visible > peakVisible) peakVisible = visible
    }
}

/**
 * 走査が画面を離れる直前までに得た結果。
 *
 * 離脱後の同時生存は、離脱先の結果画面が [MeasurementLifetime] から読む。離脱前の値をここに
 * 預けておくことで、結果画面が「置換後」と「離脱後」を 1 つの進捗の印にまとめて出せる。
 */
object MeasurementScanResult {
    /** 定常に達した往復の回数。 */
    var settledRoundTrips: Long = 0
        private set

    /** 走査中に観測した最大の同時生存数。 */
    var peakAlive: Long = 0
        private set

    /** 走査中に観測した最大の可視件数。同時生存の上限はこれを基に決める。 */
    var peakVisible: Long = 0
        private set

    /** 配列を置換した後の同時生存数。 */
    var aliveAfterReplacement: Long = 0
        private set

    /**
     * 離脱前までの結果を預ける。
     *
     * @param settledRoundTrips 定常に達した往復の回数
     * @param peakAlive 走査中に観測した最大の同時生存数
     * @param peakVisible 走査中に観測した最大の可視件数
     * @param aliveAfterReplacement 配列を置換した後の同時生存数
     */
    fun record(
        settledRoundTrips: Int,
        peakAlive: Long,
        peakVisible: Int,
        aliveAfterReplacement: Long,
    ) {
        this.settledRoundTrips = settledRoundTrips.toLong()
        this.peakAlive = peakAlive
        this.peakVisible = peakVisible.toLong()
        this.aliveAfterReplacement = aliveAfterReplacement
    }
}
