package jp.kamusoft.kscollectionview.samples.android

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * テンプレートが呼ばれた回数と、同時に生きているテンプレートの数の計数。
 *
 * 大量件数でもテンプレートの呼び出しが可視範囲 + 先読み分に留まることを、実機で数として
 * 確かめるために使う。配布する構成では何もしない実装に差し替わる。
 *
 * 累計の呼び出し回数だけでは「作り直されていないこと」しか言えないため、同時生存数
 * (現在値・最大値・破棄回数) も併せて数える。範囲外へ出た項目が実際に破棄されているか
 * どうかは、破棄回数と最大値でしか見えない。
 */
object TemplateInvocationCounter {
    /** ログの絞り込みに使う印。 */
    private const val Tag = "KsTemplateCounter"

    private val counters = ConcurrentHashMap<String, AtomicLong>()
    private val alive = ConcurrentHashMap<String, AtomicLong>()
    private val aliveMax = ConcurrentHashMap<String, AtomicLong>()
    private val disposed = ConcurrentHashMap<String, AtomicLong>()

    /**
     * 呼び出しを 1 回数える。
     *
     * @param screen 数える対象の画面名
     */
    fun record(screen: String) {
        val count = counters.computeIfAbsent(screen) { AtomicLong() }.incrementAndGet()
        // 呼び出しごとに数を出す。数の正確さがそのまま確認の根拠になるため間引かない。
        // 性能を測る構成では実装ごと空になるので、この出力が計測を乱すことはない。
        Log.i(Tag, "$screen=$count")
    }

    /**
     * 1 項目のテンプレートが生きている間だけ同時生存数を 1 増やす。
     *
     * テンプレートの中で呼ぶ。項目が可視範囲外へ出て Composition が捨てられると
     * `DisposableEffect` の後始末が走り、現在値が減って破棄回数が増える。
     *
     * @param screen 数える対象の画面名
     * @param itemId 項目の識別子 (同じ項目の再利用と別項目の生成を分けるための効果のキー)
     */
    @Composable
    fun TrackLifetime(screen: String, itemId: Any) {
        DisposableEffect(itemId) {
            val current = alive.computeIfAbsent(screen) { AtomicLong() }.incrementAndGet()
            val max = aliveMax.computeIfAbsent(screen) { AtomicLong() }
            max.updateAndGet { previous -> maxOf(previous, current) }
            Log.i(Tag, "$screen alive=$current max=${max.get()}")
            onDispose {
                val left = alive.getValue(screen).decrementAndGet()
                val gone = disposed.computeIfAbsent(screen) { AtomicLong() }.incrementAndGet()
                Log.i(Tag, "$screen alive=$left disposed=$gone")
            }
        }
    }

    /** 画面ごとの現在の計数。 */
    fun snapshot(): Map<String, Long> = counters.mapValues { it.value.get() }

    /** 画面ごとの同時生存数 (現在値・最大値・破棄回数)。 */
    fun lifetimeSnapshot(): Map<String, TemplateLifetime> =
        aliveMax.keys.associateWith { screen ->
            TemplateLifetime(
                alive = alive[screen]?.get() ?: 0L,
                maxAlive = aliveMax[screen]?.get() ?: 0L,
                disposed = disposed[screen]?.get() ?: 0L,
            )
        }

    /** 計数を 0 に戻す。 */
    fun reset() {
        counters.clear()
        alive.clear()
        aliveMax.clear()
        disposed.clear()
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
