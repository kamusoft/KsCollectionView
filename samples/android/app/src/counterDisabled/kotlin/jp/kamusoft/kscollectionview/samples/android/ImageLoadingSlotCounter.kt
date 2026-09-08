package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable

/**
 * 読み込み中の表示が組み立てられた回数の計数。この構成では数えない。
 */
object ImageLoadingSlotCounter {

    /** 数えることが要求されているかどうか。この構成では常に false。 */
    val isEnabled: Boolean get() = false

    /** 観測区間の通し番号。この構成では常に 0。 */
    val session: Int get() = 0

    /**
     * 数えるかどうかを決める。この構成では何もしない。
     *
     * @param enabled 数えるなら true (使わない)
     */
    @Suppress("UNUSED_PARAMETER")
    fun setEnabled(enabled: Boolean) {
        // 配布する構成では数える手段そのものを持たない。
    }

    /**
     * 読み込み中の表示として渡す組み立てを返す。この構成では渡すものが無いため null を返し、
     * 本体の既定の表示に任せる。
     *
     * @param itemId 読み込み中を出している要素の識別子 (使わない)
     */
    @Composable
    @Suppress("UNUSED_PARAMETER")
    fun rememberLoadingSlot(itemId: Any): (@Composable () -> Unit)? = null

    /** 要素ごとの累計。この構成では常に空。 */
    fun snapshot(): Map<Any, ImageLoadingSlotTally> = emptyMap()

    /** 要素ごとの、基準点からの差分。この構成では常に空。 */
    fun deltaSnapshot(): Map<Any, ImageLoadingSlotTally> = emptyMap()

    /**
     * 1 要素の計数 (累計)。この構成では常に 0 件。
     *
     * @param itemId 読み込み中を出している要素の識別子 (使わない)
     */
    @Suppress("UNUSED_PARAMETER")
    fun tally(itemId: Any): ImageLoadingSlotTally = ImageLoadingSlotTally()

    /**
     * 1 要素の、基準点からの差分。この構成では常に 0 件。
     *
     * @param itemId 対象の要素の識別子 (使わない)
     */
    @Suppress("UNUSED_PARAMETER")
    fun delta(itemId: Any): ImageLoadingSlotTally = ImageLoadingSlotTally()

    /** 観測区間を切り直す。この構成では何もしない。 */
    fun beginSession() {
        // 配布する構成には切り直す区間そのものが無い。
    }

    /** 計数・基準点・区間の通し番号を初期状態に戻す。この構成では何もしない。 */
    fun reset() {
        // 配布する構成に計数を残さない。
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
