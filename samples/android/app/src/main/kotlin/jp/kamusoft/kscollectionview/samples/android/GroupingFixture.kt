package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsGroups
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 「グループ化」の土俵の宣言元。
 *
 * デモ画面 ([GroupingDemoScreen]) と計測用の画面は、配置・セル・見出しの宣言をここから取る。
 * 計測はデモ画面と同じ土俵を測って初めて意味を持つため、組み立てを 1 箇所に集める。
 * 値は iOS Sample の同名定義とそろえる。
 */
object GroupingFixture {
    /** 縦長 2 列・横長 4 列のグリッド。見出しと先頭行の間は行の間と同じ細い間隔にする。 */
    val layout: KsLayout = KsLayout.Grid(
        columns = KsColumns.Fixed(portrait = 2, landscape = 4),
        rowSpacing = GroupHeaderMetrics.gridSpacing,
        columnSpacing = GroupHeaderMetrics.gridSpacing,
        groupSpacing = GroupHeaderMetrics.groupSpacing,
        headerItemSpacing = GroupHeaderMetrics.gridSpacing,
    )

    /** グループ分けと見出し。見出しは固定する (既定)。 */
    val groups: KsGroups<GroupingDemoItem, Int> = KsGroups(by = { it.group }) { group, itemsInGroup ->
        GroupHeaderBand(name = groupName(group), itemCount = itemsInGroup.size)
    }

    /**
     * 見出しのグループ名。
     *
     * @param group グループの番号 (1 から)
     */
    fun groupName(group: Int): String = "グループ $group"
}

/**
 * 「グループ化」の土俵をライブラリで描く。
 *
 * @param items 表示する配列。操作で組み替えた配列もそのまま渡す
 * @param probe 表示中の項目を読むための登録先。計測では渡さない (行に何も足さない)
 */
@Composable
fun GroupingCollection(
    items: List<GroupingDemoItem>,
    modifier: Modifier = Modifier,
    probe: VisibleItemProbe? = null,
) {
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier,
        layout = GroupingFixture.layout,
        groups = GroupingFixture.groups,
    ) {
        template { item ->
            DemoListRow(
                item = item.row,
                modifier = if (probe != null) Modifier.visibleItemProbe(probe, item.id) else Modifier,
            )
        }
    }
}
