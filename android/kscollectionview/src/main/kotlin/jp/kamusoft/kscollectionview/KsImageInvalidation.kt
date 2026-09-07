package jp.kamusoft.kscollectionview

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.setValue

/**
 * キャッシュを消したことを表示中の [KsImage] へ伝える世代の台帳。
 *
 * [globalGeneration] は範囲消去の世代で、進むとすべての [KsImage] が読み込みをやり直す。
 * ソース単位の削除では [globalGeneration] は進まず、そのソースの世代だけが進むため、
 * 消したソースの表示だけが読み込み中へ戻る。
 *
 * 値は Compose の状態として持つので、読んでいる [KsImage] だけが組み立て直される。
 */
internal object KsImageInvalidation {
    var globalGeneration: Int by mutableIntStateOf(0)
        private set

    private val sourceGenerations = mutableStateMapOf<String, Int>()

    /** キャッシュ鍵に対応する世代。一度も消していないソースは 0 になる。 */
    fun generation(cacheKey: String): Int = sourceGenerations[cacheKey] ?: 0

    /** 範囲消去の世代を進める。 */
    fun invalidateAll() {
        globalGeneration += 1
    }

    /** ソース 1 つ分の世代を進める。 */
    fun invalidateSource(cacheKey: String) {
        sourceGenerations[cacheKey] = generation(cacheKey) + 1
    }

    /** テストが互いの世代を持ち込まないために使う。 */
    fun reset() {
        globalGeneration = 0
        sourceGenerations.clear()
    }
}
