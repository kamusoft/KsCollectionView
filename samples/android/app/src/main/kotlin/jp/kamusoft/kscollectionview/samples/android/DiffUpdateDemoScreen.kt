package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsGroups
import jp.kamusoft.kscollectionview.KsLayout

/** 「差分更新」画面の文言。iOS Sample の同じ画面と一字一句そろえる。 */
object DiffUpdateDemoText {
    /** グループの有無の切り替え。 */
    const val Grouped = "グループ"

    /** 位置ごとの操作。 */
    const val Insert = "挿入"
    const val Delete = "削除"
    const val Update = "更新"
    const val Move = "移動"

    /** 位置によらない操作。 */
    const val Reverse = "反転"
    const val Shuffle = "シャッフル"
    const val Reset = "元に戻す"
}

/**
 * 「差分更新」画面。20 件の配列を操作で組み替え、挿入・削除・更新・移動がアニメーションで
 * 反映されるのを目で追う。
 *
 * 件数・グループ分け・操作の規則・文言は iOS Sample の同名画面とそろえる。
 */
@Composable
fun DiffUpdateDemoScreen(modifier: Modifier = Modifier) {
    // 配列と選択は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞いにそろえる。
    var model by rememberSaveable(stateSaver = DiffUpdateModel.Saver) { mutableStateOf(DiffUpdateModel()) }
    var layoutChoice by rememberSaveable { mutableStateOf(DiffUpdateLayoutChoice.List) }
    var grouped by rememberSaveable { mutableStateOf(true) }
    var position by rememberSaveable { mutableStateOf(DiffUpdatePosition.Head) }

    Column(modifier = modifier.fillMaxSize()) {
        // 表示の切り替え (リスト / グリッド と グループの有無)。
        SampleControlBar {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SampleSegmentedControl(
                    modifier = Modifier.weight(1f),
                    options = DiffUpdateLayoutChoice.entries.map { it.title },
                    selectedIndex = layoutChoice.ordinal,
                    onSelect = { layoutChoice = DiffUpdateLayoutChoice.entries[it] },
                )
                GroupedToggle(
                    checked = grouped,
                    onCheckedChange = { isGrouped ->
                        // グループありでは、同じグループの項目が続いていないと不正な入力になる。
                        // 切り替えと同じ変更で並べ直し、並べ直す前の配列をグループありで渡さない。
                        if (isGrouped) model = model.regrouped()
                        grouped = isGrouped
                    },
                )
            }
        }

        HorizontalDivider(color = SampleTheme.separator)

        KsCollectionView(
            items = model.items,
            key = { it.id },
            modifier = Modifier.weight(1f),
            layout = when (layoutChoice) {
                DiffUpdateLayoutChoice.List -> DiffUpdateListLayout
                DiffUpdateLayoutChoice.Grid -> DiffUpdateGridLayout
            },
            groups = if (grouped) DiffUpdateGroups else null,
        ) {
            template { item -> DemoListRow(item.row) }
        }

        HorizontalDivider(color = SampleTheme.separator)

        // 操作の位置の切り替えと、位置ごとの操作・位置によらない操作。
        SampleControlBar(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SampleSegmentedControl(
                modifier = Modifier.fillMaxWidth(),
                options = DiffUpdatePosition.entries.map { it.title },
                selectedIndex = position.ordinal,
                onSelect = { position = DiffUpdatePosition.entries[it] },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OperationButton(DiffUpdateDemoText.Insert) { model = model.inserting(position) }
                OperationButton(DiffUpdateDemoText.Delete) { model = model.deleting(position) }
                OperationButton(DiffUpdateDemoText.Update) { model = model.updating(position) }
                OperationButton(DiffUpdateDemoText.Move) { model = model.moving(position, grouped) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OperationButton(DiffUpdateDemoText.Reverse) { model = model.reversed() }
                OperationButton(DiffUpdateDemoText.Shuffle) { model = model.shuffled(grouped) }
                OperationButton(DiffUpdateDemoText.Reset) { model = model.reset() }
            }
        }
    }
}

/** 行の中で等幅に並べる操作ボタン。 */
@Composable
private fun RowScope.OperationButton(
    text: String,
    onClick: () -> Unit,
) {
    SampleBarButton(text = text, onClick = onClick, modifier = Modifier.weight(1f))
}

/**
 * グループの有無の切り替え。文言とスイッチをまとめて 1 つの切り替えとして扱う。
 *
 * @param checked グループありか
 * @param onCheckedChange 切り替えたときの処理
 */
@Composable
private fun GroupedToggle(checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.toggleable(
            value = checked,
            role = Role.Switch,
            onValueChange = onCheckedChange,
        ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = DiffUpdateDemoText.Grouped,
            style = MaterialTheme.typography.bodySmall,
            color = SampleTheme.text,
        )
        Switch(
            checked = checked,
            // 切り替えは行全体で受ける (文言を押しても切り替わる)。
            onCheckedChange = null,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = SampleTheme.accent,
                checkedBorderColor = SampleTheme.accent,
            ),
        )
    }
}

/** リストの形。区切り線は既定のまま表示する。 */
private val DiffUpdateListLayout: KsLayout = KsLayout.List(groupSpacing = GroupHeaderMetrics.groupSpacing)

/** 2 列のグリッドの形。 */
private val DiffUpdateGridLayout: KsLayout = KsLayout.Grid(
    columns = KsColumns.Fixed(2),
    rowSpacing = GroupHeaderMetrics.gridSpacing,
    columnSpacing = GroupHeaderMetrics.gridSpacing,
    groupSpacing = GroupHeaderMetrics.groupSpacing,
    headerItemSpacing = GroupHeaderMetrics.gridSpacing,
)

/** グループありのときのグループ分けと見出し。見出しは固定する (既定)。 */
private val DiffUpdateGroups: KsGroups<DiffUpdateItem, Int> = KsGroups(by = { it.group }) { group, itemsInGroup ->
    GroupHeaderBand(name = DiffUpdateModel.groupName(group), itemCount = itemsInGroup.size)
}
