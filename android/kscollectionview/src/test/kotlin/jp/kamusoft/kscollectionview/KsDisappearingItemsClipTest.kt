package jp.kamusoft.kscollectionview

import android.app.Activity
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PixelMap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowLooper

/**
 * 配列の差し替えで消えていく項目が、一覧の枠の上下へはみ出して描かれないことを確かめる。
 *
 * 一覧の上と下に別の部品を並べ、端の行が一部隠れるまでスクロールしてから、全項目のキーが
 * 入れ替わる差し替えをする。時計を止めて消えるフェードの途中のフレームを読み、上下の部品の
 * 画素が差し替え前と同じであることを見る。
 *
 * 消えていく項目は描画の層 (GraphicsLayer) として描かれ、View をソフトウェアの Canvas へ
 * 描く読み方では層の中身が出ない。ここでは Robolectric のハードウェア描画で画面を読む
 * (`PixelCopy` と `robolectric.pixelCopyRenderMode=hardware`)。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w1000dp-h1000dp")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
internal class KsDisappearingItemsClipTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var previousRenderMode: String? = null

    @Before
    fun setUp() {
        previousRenderMode = System.getProperty(PixelCopyRenderModeKey)
        System.setProperty(PixelCopyRenderModeKey, "hardware")
    }

    @After
    fun tearDown() {
        val previous = previousRenderMode
        if (previous == null) {
            System.clearProperty(PixelCopyRenderModeKey)
        } else {
            System.setProperty(PixelCopyRenderModeKey, previous)
        }
    }

    /** 全項目のキーが入れ替わる差し替えで、消えていく端の行が上の部品に重ならない。 */
    @Test
    fun disappearingItemsDoNotDrawOverViewAbove() {
        assertNeighborUnchangedDuringReplace(AboveTag)
    }

    /** 全項目のキーが入れ替わる差し替えで、消えていく端の行が下の部品に重ならない。 */
    @Test
    fun disappearingItemsDoNotDrawOverViewBelow() {
        assertNeighborUnchangedDuringReplace(BelowTag)
    }

    private fun assertNeighborUnchangedDuringReplace(neighborTag: String) {
        var items by mutableStateOf(testItems(60, prefix = OldPrefix))
        composeTestRule.setContent {
            Column(Modifier.size(300.dp, 600.dp)) {
                Box(Modifier.fillMaxWidth().height(NeighborHeight).background(NeighborColor).testTag(AboveTag))
                Box(Modifier.fillMaxWidth().height(CollectionHeight).testTag(CollectionTag)) {
                    KsCollectionView(
                        items = items,
                        key = { it.id },
                        layout = KsLayout.Grid(columns = KsColumns.Fixed(3)),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        template { item ->
                            val color = if (item.id.startsWith(OldPrefix)) OldItemColor else NewItemColor
                            Box(Modifier.fillMaxWidth().height(ItemHeight).background(color))
                        }
                    }
                }
                // 後に並べた部品は一覧より後に描かれ、はみ出しを覆い隠してしまう。一覧より先に描かせて、
                // 下へのはみ出しが画素に出るようにする。
                Box(
                    Modifier
                        .zIndex(-1f)
                        .fillMaxWidth()
                        .height(NeighborHeight)
                        .background(NeighborColor)
                        .testTag(BelowTag),
                )
            }
        }

        // 先頭の行が上端で半分隠れ、最後の行が下端で半分はみ出す位置まで送る
        // (一覧の高さ 300dp は行の高さ 70dp の倍数でないため、半行ずらすと上下とも端の行が欠ける)。
        val list = composeTestRule.onNode(hasScrollAction())
        list.performScrollToIndex(30)
        val halfRowPx = with(composeTestRule.density) { (ItemHeight / 2).toPx() }
        list.performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, halfRowPx) }
        composeTestRule.waitForIdle()

        assertEquals(
            "差し替え前は部品の色だけが描かれている",
            0,
            composeTestRule.onNodeWithTag(neighborTag).readScreenPixels().countNotMatching(NeighborColor),
        )

        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { items = testItems(60, prefix = NewPrefix) }

        val neighborDiffering = mutableListOf<Int>()
        val notNewInList = mutableListOf<Int>()
        repeat(FramesToObserve) {
            composeTestRule.mainClock.advanceTimeByFrame()
            composeTestRule.waitForIdle()
            neighborDiffering +=
                composeTestRule.onNodeWithTag(neighborTag).readScreenPixels().countNotMatching(NeighborColor)
            notNewInList +=
                composeTestRule.onNodeWithTag(CollectionTag).readScreenPixels().countNotMatching(NewItemColor)
        }
        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()

        // 消える項目が描かれているフレームを観測できていないと、上下の部品の判定が空振りする。
        assertTrue(
            "消えるフェードの途中のフレームが観測できている (一覧の中の新しい項目の色でない画素の数 $notNewInList)",
            notNewInList.count { it > 0 } >= 3,
        )
        assertTrue(
            "消えるフェードの途中も部品の画素は差し替え前と同じ (フレームごとの違う画素の数 $neighborDiffering)",
            neighborDiffering.all { it == 0 },
        )
    }

    /** [color] と違う画素の数。 */
    private fun PixelMap.countNotMatching(color: Color): Int {
        var count = 0
        for (y in 0 until height) {
            for (x in 0 until width) {
                if (this[x, y] != color) count++
            }
        }
        return count
    }

    private companion object {
        const val PixelCopyRenderModeKey = "robolectric.pixelCopyRenderMode"

        const val AboveTag = "above"
        const val BelowTag = "below"
        const val CollectionTag = "collection"

        const val OldPrefix = "old"
        const val NewPrefix = "new"

        /** 消えるフェードの全体を覆うフレーム数。 */
        const val FramesToObserve = 30

        val NeighborHeight = 100.dp
        val CollectionHeight = 300.dp
        val ItemHeight = 70.dp

        val NeighborColor = Color(0xFF0B1F3A)
        val OldItemColor = Color(0xFFE23A2E)
        val NewItemColor = Color(0xFF2EB85C)
    }
}

/**
 * 画面に描かれた結果のうち、指定した節点の矩形の画素を読む。
 *
 * `PixelCopy` でウィンドウを読むため、描画の層 (GraphicsLayer) を含めて実際の描画と同じ結果になる。
 * Robolectric では `PixelCopy` の完了がメインの Looper に積まれるので、積まれた処理を流して待つ。
 */
@OptIn(androidx.compose.ui.InternalComposeUiApi::class)
private fun SemanticsNodeInteraction.readScreenPixels(): PixelMap {
    val node = fetchSemanticsNode()
    val view = (node.root as ViewRootForTest).view
    var context = view.context
    while (context !is Activity) context = (context as ContextWrapper).baseContext
    val location = IntArray(2)
    view.getLocationInWindow(location)
    val whole = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
    var result: Int? = null
    PixelCopy.request(
        context.window,
        Rect(location[0], location[1], location[0] + view.width, location[1] + view.height),
        whole,
        { result = it },
        Handler(Looper.getMainLooper()),
    )
    ShadowLooper.idleMainLooper()
    check(result == PixelCopy.SUCCESS) { "画面を読めなかった (PixelCopy の結果 $result)" }

    val bounds = node.boundsInRoot
    val left = bounds.left.toInt()
    val top = bounds.top.toInt()
    val width = bounds.width.toInt().coerceAtMost(view.width - left)
    val height = bounds.height.toInt().coerceAtMost(view.height - top)
    return Bitmap.createBitmap(whole, left, top, width, height).asImageBitmap().toPixelMap()
}
