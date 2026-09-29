package jp.kamusoft.kscollectionview

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 状態だけが変わってフッターの枠の中身の高さが変わったとき、枠が新しい中身の高さまで伸び、中の操作が
 * 押せることを確かめる (読み込み中から失敗への変化・待機から失敗への変化)。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsPagingFooterResizeTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val width = 300.dp
    private val height = 600.dp
    private val tolerance = 1.dp

    /** 末尾で読み込み中から失敗に変わると、失敗の表示が文言と再試行の高さのまま出て、再試行を押せる。 */
    @Test
    fun appendingToFailedGrowsFooterToNewContent() {
        assertFailedFooterGrows(layout = KsLayout.List, startsAppending = true)
    }

    /** グリッドでも同じ。 */
    @Test
    fun appendingToFailedGrowsFooterToNewContentInGrid() {
        assertFailedFooterGrows(layout = KsLayout.Grid(KsColumns.Fixed(2)), startsAppending = true)
    }

    /** 静止中に待機から失敗に変わっても、失敗の表示が文言と再試行の高さのまま出る。 */
    @Test
    fun idleToFailedGrowsFooterToNewContent() {
        assertFailedFooterGrows(layout = KsLayout.List, startsAppending = false)
    }

    private fun assertFailedFooterGrows(layout: KsLayout, startsAppending: Boolean) {
        val vm = KsPagingProbeVm(testItems(30), state = KsPagingState.EndReached)
        val gate = CompletableDeferred<Unit>()
        composeTestRule.setContent {
            TestContainer(width, height) {
                KsCollectionView(
                    items = vm.items,
                    key = { it.id },
                    layout = layout,
                    contentPadding = PaddingValues(bottom = 200.dp),
                    listSeparators = false,
                    paging = KsPaging(
                        state = vm.state,
                        onLoadMore = vm.loadMore,
                        failedFooter = { retry -> FailedMessage(retry) },
                    ),
                ) { template { item -> Text(item.text, Modifier.fillMaxWidth().height(60.dp).testTag(item.id)) } }
            }
        }
        composeTestRule.scrollListToIndex(30)
        if (startsAppending) {
            // VM が次ページ要求の処理の中で追加読み込み中にし、取得を待ってから失敗にする。
            vm.onLoadMore = { state = KsPagingState.Appending }
            vm.loadMoreGate = gate
            composeTestRule.runOnUiThread { vm.state = KsPagingState.Idle }
            composeTestRule.awaitCondition("読み込み中の表示") { composeTestRule.countIndeterminateProgress() == 1 }
            composeTestRule.runOnUiThread {
                vm.state = KsPagingState.Failed
                gate.complete(Unit)
            }
        } else {
            composeTestRule.runOnUiThread { vm.state = KsPagingState.Failed }
        }
        composeTestRule.waitForIdle()

        val message = composeTestRule.onNodeWithTag("message").getUnclippedBoundsInRoot()
        val retry = composeTestRule.onNodeWithTag("retry").getUnclippedBoundsInRoot()
        assertTrue("再試行が文言の下に描かれる (文言 ${message.bottom} / 再試行 ${retry.top})", retry.top >= message.bottom)
        assertTrue("再試行が高さを持つ (実測 ${retry.bottom - retry.top})", retry.bottom - retry.top >= 30.dp - tolerance)
        val loadsBefore = vm.loadMoreCount
        composeTestRule.onNodeWithTag("retry").performClick()
        composeTestRule.awaitCondition("再試行の次ページ要求", observed = { vm.loadMoreCount }) {
            vm.loadMoreCount == loadsBefore + 1
        }
    }

    @Composable
    private fun FailedMessage(retry: () -> Unit) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("読み込めませんでした", Modifier.testTag("message"))
            Text("再試行", Modifier.clickable(onClick = retry).height(36.dp).testTag("retry"))
        }
    }
}
