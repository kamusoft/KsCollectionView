package jp.kamusoft.kscollectionview

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput

/** 並べ替えのテストで一覧の根に付けるタグ。 */
internal const val ReorderListTag = "reorder-list"

/** 長押しが成立するまで進める時間 (ミリ秒)。長押しの判定時間より十分長くする。 */
internal const val ReorderLongPressMillis = 1_000L

/**
 * 一覧の点 [start] を長押しして持ち上げ、[path] の点を順に通って動かす。指はまだ離さない。
 *
 * 点は一覧の根の座標 (左上が原点、ピクセル) で渡す。1 点ごとにフレームを進めて、仮の並びの入れ替えを
 * 反映させる。
 */
internal fun ComposeContentTestRule.reorderDragTo(start: Offset, path: List<Offset>) {
    val list = onNodeWithTag(ReorderListTag)
    list.performTouchInput { down(start) }
    mainClock.advanceTimeBy(ReorderLongPressMillis)
    waitForIdle()
    for (point in path) {
        list.performTouchInput { moveTo(point) }
        waitForIdle()
        mainClock.advanceTimeByFrame()
        waitForIdle()
    }
}

/** 指を離す。 */
internal fun ComposeContentTestRule.reorderRelease() {
    onNodeWithTag(ReorderListTag).performTouchInput { up() }
    waitForIdle()
}

/** 長押しして [path] を通り、指を離す。 */
internal fun ComposeContentTestRule.reorderDragAndDrop(start: Offset, path: List<Offset>) {
    reorderDragTo(start, path)
    reorderRelease()
}

/** 知らせの行き先を、比べやすい文字列にする (「before:ID」か「end」)。 */
internal fun KsReorderMove<TestItem>.describe(): String {
    val destination = when (val d = destination) {
        is KsReorderDestination.Before -> "before:${d.item.id}"
        KsReorderDestination.End -> "end"
    }
    return "${item.id}->$destination@${group ?: "-"}"
}
