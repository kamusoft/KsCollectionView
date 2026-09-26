package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** 「グループ化」画面の下部バーの文言。iOS Sample の同じ画面と一字一句そろえる。 */
object GroupingDemoText {
    /** グループの並び順を反転する操作。 */
    const val Reverse = "並び順を反転"

    /** 表示中の項目を隣のグループへ移す操作。 */
    const val MoveItem = "項目を別のグループへ"

    /** 件数と列数を含む画面の説明。 */
    const val Description = "10,000 件・縦 2 列 / 横 4 列・見出しは固定"
}

/**
 * 「グループ化」画面。10,000 件を大小のグループに分けたグリッドを、固定される見出しつきで表示する。
 *
 * 下部バーの 2 つの操作は配列をデータ側で組み替えて渡すだけで、触れなければ表示やスクロールの
 * 仕事は増えない。件数・グループ分け・文言は iOS Sample の同名画面とそろえる。
 */
@Composable
fun GroupingDemoScreen(modifier: Modifier = Modifier) {
    // 操作の結果は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞いにそろえる。
    val state = rememberSaveable(saver = GroupingDemoState.Saver) { GroupingDemoState() }
    val probe = remember { VisibleItemProbe() }

    Column(modifier = modifier.fillMaxSize()) {
        GroupingCollection(items = state.items, modifier = Modifier.weight(1f), probe = probe)

        HorizontalDivider(color = SampleTheme.separator)

        SampleControlBar(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SampleBarButton(
                    text = GroupingDemoText.Reverse,
                    onClick = state::reverseGroups,
                    modifier = Modifier.weight(1f),
                )
                SampleBarButton(
                    text = GroupingDemoText.MoveItem,
                    onClick = { state.moveVisibleItem(probe) },
                    modifier = Modifier.weight(1f),
                )
            }
            Text(
                text = GroupingDemoText.Description,
                style = MaterialTheme.typography.bodySmall,
                color = SampleTheme.secondaryText,
            )
        }
    }
}

/**
 * 「グループ化」画面の配列と、そこまでに行った操作の記録。
 *
 * 保存するのは操作の記録だけで、復元では初期の配列から同じ操作をやり直す。操作はどちらも
 * 決定的なため同じ配列に戻り、10,000 件の配列そのものを保存領域に載せずに済む。
 *
 * @param initialEdits 復元する操作の記録。反転は負の値、項目の移動は移した項目の通し番号
 */
class GroupingDemoState(initialEdits: IntArray = IntArray(0)) {
    private var edits: IntArray = initialEdits

    /** 表示する配列。 */
    var items: List<GroupingDemoItem> by mutableStateOf(replay(initialEdits))
        private set

    /** グループの並び順を反転する。 */
    fun reverseGroups() {
        items = GroupingDemoEdits.reversingGroups(items)
        edits += ReverseEdit
    }

    /**
     * 表示中の項目のうち真ん中のものを、隣のグループへ移す。
     *
     * @param probe 表示中の項目を読む登録先
     */
    fun moveVisibleItem(probe: VisibleItemProbe) {
        val visibleIds = probe.visibleItemIds().toSet()
        val offsets = items.indices.filter { items[it].id in visibleIds }
        if (offsets.isEmpty()) return
        moveItem(offsets[offsets.size / 2])
    }

    /**
     * 通し番号 [offset] の項目を隣のグループへ移す。
     *
     * @param offset 移す項目の通し番号 (先頭を 0 とする)
     */
    fun moveItem(offset: Int) {
        items = GroupingDemoEdits.movingItem(offset, items)
        edits += offset
    }

    companion object {
        /** 操作の記録で反転を表す値 (移動の通し番号は 0 以上)。 */
        private const val ReverseEdit = -1

        /** 操作の記録を初期の配列に当て直す。 */
        private fun replay(edits: IntArray): List<GroupingDemoItem> =
            edits.fold(GroupingDemoData.items) { items, edit ->
                if (edit == ReverseEdit) {
                    GroupingDemoEdits.reversingGroups(items)
                } else {
                    GroupingDemoEdits.movingItem(edit, items)
                }
            }

        /** 操作の記録だけを保存し、復元でやり直す。 */
        val Saver: Saver<GroupingDemoState, IntArray> = Saver(
            save = { it.edits },
            restore = { GroupingDemoState(it) },
        )
    }
}
