package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable

/**
 * テンプレートが呼ばれた回数と同時生存数の計数。この構成では数えない。
 */
object TemplateInvocationCounter {
    /**
     * 呼び出しを 1 回数える。この構成では何もしない。
     *
     * @param screen 数える対象の画面名 (使わない)
     */
    @Suppress("UNUSED_PARAMETER")
    fun record(screen: String) {
        // 配布する構成に計数を残さない。
    }

    /**
     * 同時生存数を数える。この構成では何もしない。
     *
     * @param screen 数える対象の画面名 (使わない)
     * @param itemId 項目の識別子 (使わない)
     */
    @Composable
    @Suppress("UNUSED_PARAMETER")
    fun TrackLifetime(screen: String, itemId: Any) {
        // 配布する構成に計数を残さない。
    }

    /** 画面ごとの現在の計数。この構成では常に空。 */
    fun snapshot(): Map<String, Long> = emptyMap()

    /** 画面ごとの同時生存数。この構成では常に空。 */
    fun lifetimeSnapshot(): Map<String, TemplateLifetime> = emptyMap()

    /** 計数を 0 に戻す。この構成では何もしない。 */
    fun reset() {
        // 何もしない。
    }
}

/**
 * 同時に生きているテンプレートの数。
 *
 * @property alive いま生きている数
 * @property maxAlive 観測した中での最大の同時生存数
 * @property disposed これまでに破棄された数
 */
data class TemplateLifetime(val alive: Long, val maxAlive: Long, val disposed: Long)
