package jp.kamusoft.kscollectionview

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

/**
 * メモリにある画像を表示枠へそのまま使えるかの判定 (core/ADR-0013)。
 *
 * 画像を当てはめ方で枠へ合わせるのに必要な拡大率 s を求め、s が [1/上限, 1/下限] の内側なら使う。
 * 言い換えると、画像の寸法が「枠に必要な寸法」の下限倍以上・上限倍以下なら使う。下限は拡大による
 * ぼやけ、上限は描画時の縮小によるざらつきと描画できる寸法の上限を避けるための値である。
 * 値は実機の見た目で決めるため、この 1 か所にだけ置く (iOS と同じ値)。
 */
internal object KsImageMatching {
    /** 画像の寸法が必要な寸法の何倍以上なら使うか。 */
    const val LowerBound: Double = 0.5

    /** 画像の寸法が必要な寸法の何倍以下なら使うか。 */
    const val UpperBound: Double = 4.0

    /**
     * 画像 (ピクセル) を枠 (ピクセル) へ当てはめるのに必要な拡大率。fill は枠を覆う最小、
     * fit は枠に収まる最大の拡大率になる。大きさが 0 以下の画像には null を返す。
     */
    fun requiredScale(
        imageWidth: Int,
        imageHeight: Int,
        frameWidth: Int,
        frameHeight: Int,
        contentMode: KsImageContentMode,
    ): Double? {
        if (imageWidth <= 0 || imageHeight <= 0) return null
        val horizontal = frameWidth.toDouble() / imageWidth
        val vertical = frameHeight.toDouble() / imageHeight
        return when (contentMode) {
            KsImageContentMode.Fill -> max(horizontal, vertical)
            KsImageContentMode.Fit -> min(horizontal, vertical)
        }
    }

    /** 拡大率が許容範囲の内側か。 */
    fun isAcceptable(scale: Double): Boolean = scale <= 1 / LowerBound && scale >= 1 / UpperBound

    /**
     * 候補のうち、許容範囲の内側で必要な寸法に最も近い (拡大率が 1 に最も近い) ものの位置。
     * 近さは比で測る (2 倍大きいことと 2 倍小さいことを同じ遠さとみなす)。
     *
     * @param imageSizes 候補の画像の (幅, 高さ) ピクセル
     */
    fun bestMatch(
        imageSizes: List<Pair<Int, Int>>,
        frameWidth: Int,
        frameHeight: Int,
        contentMode: KsImageContentMode,
    ): Int? {
        var bestIndex: Int? = null
        var bestDistance = Double.MAX_VALUE
        for ((index, size) in imageSizes.withIndex()) {
            val scale = requiredScale(size.first, size.second, frameWidth, frameHeight, contentMode)
                ?: continue
            if (!isAcceptable(scale)) continue
            val distance = abs(ln(scale))
            if (distance < bestDistance) {
                bestIndex = index
                bestDistance = distance
            }
        }
        return bestIndex
    }
}
