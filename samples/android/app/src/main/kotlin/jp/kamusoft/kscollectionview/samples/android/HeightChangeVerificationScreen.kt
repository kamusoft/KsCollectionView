package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout

/**
 * 検証で並べる行数。
 *
 * この画面の目的の 1 つは、テンプレートの中で持った状態が、行を可視範囲外へ送って戻したときに
 * 初期値へ戻ること (Compose の Lazy 系が範囲外の項目の Composition を捨てること) を確かめる
 * ことにある。数行しかないと全行が同時に画面へ載り、行を範囲外へ出す操作自体ができない。
 * そこで可視範囲 (端末で 5〜10 行) と先読み分を大きく上回る行数にしている。
 *
 * この画面は Android 固有の検証画面であり、iOS Sample と行数をそろえる必要はない。
 */
private const val HeightChangeRowCount = 60

/**
 * 行の高さが変わる 2 経路を実タッチで確かめる検証用画面。
 *
 * タップで行を展開・折りたたみ、展開の瞬間と再利用後に本文が行の上端より上へはみ出さないか、
 * 初回表示で本文が上下にずれないかを目視で確認する。
 */
@Composable
fun HeightChangeVerificationScreen(modifier: Modifier = Modifier) {
    // 経路・レイアウト・展開状態は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞い。
    // 展開状態は Bundle へ保存できる形にするため Set ではなく List で持つ。
    var path by rememberSaveable { mutableStateOf(HeightChangeExpansionPath.ParentState) }
    var layoutChoice by rememberSaveable { mutableStateOf(HeightChangeLayoutChoice.List) }
    var expandedIds by rememberSaveable { mutableStateOf(emptyList<Int>()) }

    val items = remember { (1..HeightChangeRowCount).map(::HeightChangeItem) }
    val layout = when (layoutChoice) {
        HeightChangeLayoutChoice.List -> KsLayout.List
        HeightChangeLayoutChoice.Grid -> KsLayout.Grid(
            columns = KsColumns.Fixed(2),
            rowSpacing = 8.dp,
            columnSpacing = 8.dp,
        )
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SampleTheme.background),
    ) {
        SampleControlBar(
            verticalArrangement = Arrangement.spacedBy(SampleTheme.controlVerticalPadding),
        ) {
            Text(
                text = "行の高さ変化検証",
                style = MaterialTheme.typography.titleMedium,
                color = SampleTheme.text,
                modifier = Modifier.fillMaxWidth().testTag("heightChange.title"),
            )
            SampleSegmentedControl(
                options = HeightChangeExpansionPath.entries.map { it.title },
                selectedIndex = path.ordinal,
                onSelect = { path = HeightChangeExpansionPath.entries[it] },
                modifier = Modifier.fillMaxWidth().testTag("heightChange.pathPicker"),
            )
            SampleSegmentedControl(
                options = HeightChangeLayoutChoice.entries.map { it.title },
                selectedIndex = layoutChoice.ordinal,
                onSelect = { layoutChoice = HeightChangeLayoutChoice.entries[it] },
                modifier = Modifier.fillMaxWidth().testTag("heightChange.layoutPicker"),
            )
            Text(
                text = "展開中: ${expandedIds.size} 行",
                style = MaterialTheme.typography.bodySmall,
                color = SampleTheme.secondaryText,
                modifier = Modifier.fillMaxWidth().testTag("heightChange.expandedCount"),
            )
            Text(
                text = "行をタップして展開・折りたたみ、本文が行の上端より上へ出ないことを確認します。",
                style = MaterialTheme.typography.bodySmall,
                color = SampleTheme.secondaryText,
                modifier = Modifier.fillMaxWidth().testTag("heightChange.instruction"),
            )
        }

        when (path) {
            // 配列は同値のまま、親の展開状態でテンプレート内容だけが変わる経路。
            HeightChangeExpansionPath.ParentState -> KsCollectionView(
                items = items,
                key = { it.id },
                layout = layout,
                onItemTap = { item ->
                    expandedIds = if (item.id in expandedIds) {
                        expandedIds - item.id
                    } else {
                        expandedIds + item.id
                    }
                },
            ) {
                template { item ->
                    HeightChangeRowBody(item = item, isExpanded = item.id in expandedIds)
                }
            }

            // 親はタップを知らず、テンプレート内の内容が自分の状態で展開する経路。
            HeightChangeExpansionPath.TemplateState -> KsCollectionView(
                items = items,
                key = { it.id },
                layout = layout,
            ) {
                template { item -> HeightChangeSelfStateCell(item) }
            }
        }
    }
}

/**
 * テンプレートの中で自分の状態を持ち、親に知らせずに展開するセル。
 *
 * @param item 表示する項目
 */
@Composable
private fun HeightChangeSelfStateCell(item: HeightChangeItem, modifier: Modifier = Modifier) {
    var isExpanded by remember { mutableStateOf(false) }
    // 行の高さの補間中に本体へ高さの制約を渡す。渡さないと透明な箱と本体の間が空き、
    // 折りたたみの途中でページ背景の帯が見える。
    Box(
        modifier = modifier
            .clickable { isExpanded = !isExpanded }
            .testTag("heightChange.selfStateCell.${item.id}"),
        propagateMinConstraints = true,
    ) {
        HeightChangeRowBody(item = item, isExpanded = isExpanded)
    }
}
