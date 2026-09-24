package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * アイテムの先読みの宣言 1 件を、台帳で突き合わせる形にしたもの。
 *
 * 宣言が変わったかどうかは識別子・URL・幅の種類で判定する。列の幅は種類 ([KsWidth.Column]) の
 * まま持ち、ピクセルに解いた値は含めない。含めると、回転で列の幅が変わるだけで進行中の取得を
 * 取り消して出し直すことになるためである。URL を含めるのは、キーが同じでも URL (署名) が変わった
 * 要素を新しい URL で出し直すため (古い URL が失効すると取得が失敗したまま残る)。
 *
 * @property key 空文字を取り除いた後のキー。null はキーなし
 * @property width 誤った固定値を取り除いた後の幅。null は元の大きさのまま扱う
 */
internal data class KsPrefetchDeclaration(
    val url: String,
    val key: String?,
    val width: KsWidth?,
) {
    /** 画像の識別子。 */
    val identifier: String get() = KsImageIdentity.identifier(url, key)

    companion object {
        /**
         * 利用者の宣言を台帳の形に直す。空文字のキーと誤った固定値は誤りとして [report] で知らせ、
         * それぞれキーなし・幅なしとして扱う (core/ADR-0011)。
         */
        fun of(resource: KsResource, report: (String) -> Unit): KsPrefetchDeclaration {
            val key = resource.key
            val validKey = if (key != null && key.isEmpty()) {
                report(KsImageIdentity.emptyKeyMessage(resource.url))
                null
            } else {
                key
            }
            val width = resource.width
            val validWidth = if (width is KsWidth.Fixed && !width.width.isValidPrefetchWidth()) {
                report(
                    "先読みの固定の幅には 0 より大きい有限の値を指定してください (${width.width})。" +
                        "元の大きさで扱います: ${resource.url}",
                )
                null
            } else {
                width
            }
            return KsPrefetchDeclaration(resource.url, validKey, validWidth)
        }
    }
}

/** 先読みの固定の幅として有効な値か。`Dp.Unspecified` は NaN なので無効になる。 */
private fun Dp.isValidPrefetchWidth(): Boolean = value.isFinite() && value > 0f

/**
 * 先読みの取得の単位。同じ単位を必要とするアイテムの数を数え、最後の 1 つが外れたときに取り消す。
 *
 * 到達点がディスクまでのときは幅を使わないので識別子だけで決まり、幅違いの宣言も 1 つの取得に
 * まとまる。メモリまでのときは識別子と幅 (ピクセル) で決まり、幅違いは別の取得として数える。
 */
internal data class KsPrefetchUnit(val identifier: String, val widthPixels: Int?)

/**
 * 先読みの幅をピクセルへ解くための、その時点の表示の寸法。
 *
 * @property columnWidthPx 現在のレイアウトの 1 列分の幅 (ピクセル)。0 以下は列の幅がまだ解けない
 *   ことを表す
 * @property density 表示倍率
 */
internal data class KsPrefetchMetrics(val columnWidthPx: Int, val density: Float) {

    /**
     * 幅をピクセルへ直す。四捨五入した上で 1 以上・[MaximumPixels] 以下にする。表示倍率を掛けて
     * 無限大になる値も上限になる (`roundToInt` は範囲外を整数の上限に飽和させるので停止しない)。
     */
    fun pixels(width: Dp): Int = (width.value * density).roundToInt().coerceIn(1, MaximumPixels)

    /** 列の幅 (ピクセル)。列の幅が解けない間は null、上限を超える幅は [MaximumPixels] にする。 */
    val columnWidthPixels: Int? get() = columnWidthPx.takeIf { it > 0 }?.coerceAtMost(MaximumPixels)

    companion object {
        /**
         * 幅のピクセルの上限。描画できる画像の最大辺 (16384) を超える幅に縮小しても表示には使えず、
         * 元寸より大きい指定は拡大されないので、ここで頭打ちにしても結果は変わらない。有効な固定値でも
         * 丸めるだけで、不正入力としては扱わない。iOS と同じ値にしてメモリの鍵の幅をそろえる。
         */
        const val MaximumPixels: Int = 16_384

        /** 列の幅がまだ解けない寸法。 */
        val Unresolved: KsPrefetchMetrics = KsPrefetchMetrics(columnWidthPx = 0, density = 1f)
    }
}

/**
 * コレクションの 1 列分の幅 (ピクセル) を、`LazyVerticalGrid` がセルの幅を決めるのと同じ規則で
 * 求める。列の幅が正にならない (余白と列間隔がコンテナ幅を超える、コンテナ幅が未確定) ときは 0 を
 * 返す。
 *
 * 列数は list なら 1、`KsColumns.Fixed` はコンテナの向きで、`KsColumns.Adaptive` は
 * `floor((利用可能幅 + 列間隔) / (最小幅 + 列間隔))` (1 以上) で決まる。
 *
 * @param containerWidthPx コンテナの幅 (ピクセル)。未確定なら 0
 * @param isPortrait コンテナの高さが幅より大きいなら true
 */
internal fun resolveColumnWidthPx(
    layout: KsLayout,
    containerWidthPx: Int,
    isPortrait: Boolean,
    contentPadding: PaddingValues,
    layoutDirection: LayoutDirection,
    density: Density,
): Int = with(density) {
    val horizontalPadding = contentPadding.calculateLeftPadding(layoutDirection).roundToPx() +
        contentPadding.calculateRightPadding(layoutDirection).roundToPx()
    val available = containerWidthPx - horizontalPadding
    val spacing = layout.effectiveColumnSpacing.roundToPx()
    val count = when (layout) {
        is KsLayout.List -> 1
        is KsLayout.Grid -> when (val columns = layout.columns) {
            is KsColumns.Fixed -> columns.resolveCount(isPortrait)
            is KsColumns.Adaptive -> {
                val minWidth = columns.minItemWidth.coerceAtLeast(1.dp).roundToPx()
                max((available + spacing) / (minWidth + spacing), 1)
            }
        }
    }
    val withoutSpacing = available - spacing * (count - 1)
    if (withoutSpacing <= 0) 0 else withoutSpacing / count
}
