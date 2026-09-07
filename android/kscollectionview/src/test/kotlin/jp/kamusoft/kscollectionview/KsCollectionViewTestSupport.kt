package jp.kamusoft.kscollectionview

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.SemanticsNodeInteractionsProvider
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.startup.AppInitializer

/** テストで使う要素型。テンプレートキーは [kind] が持つ。 */
internal data class TestItem(
    val id: String,
    val text: String,
    val kind: TestKind = TestKind.Message,
)

/** テンプレートキーの値。 */
internal enum class TestKind { Message, Ad, System }

/** 決まった大きさのコンテナ。列数の解決と位置の検証で基準になる。 */
@Composable
internal fun TestContainer(
    width: Dp = 300.dp,
    height: Dp = 600.dp,
    content: @Composable () -> Unit,
) {
    Box(Modifier.size(width, height)) { content() }
}

/** 連番の要素を作る。 */
internal fun testItems(count: Int, prefix: String = "item"): List<TestItem> =
    (0 until count).map { TestItem(id = "$prefix-$it", text = "$prefix $it") }

/** 指定タグでコンポジションされている節点の数。 */
internal fun SemanticsNodeInteractionsProvider.countNodesWithTag(tag: String): Int =
    onAllNodesWithTag(tag).fetchSemanticsNodes().size

/** 指定テキストでコンポジションされている節点の数。 */
internal fun SemanticsNodeInteractionsProvider.countNodesWithText(text: String): Int =
    onAllNodesWithText(text).fetchSemanticsNodes().size

/**
 * アプリケーションのコンテキストを [KsAppContext] へ入れる。
 *
 * Robolectric は宣言された ContentProvider を作らないため、実機・実端末では起動時に走る
 * 初期化がテストでは走らない。同じ [KsAppContextInitializer] をテストから明示的に動かす。
 */
internal fun installKsAppContext(context: Context) {
    AppInitializer.getInstance(context)
        .initializeComponent(KsAppContextInitializer::class.java)
}
