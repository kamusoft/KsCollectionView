package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/** 畳むボタンと表示の形の切り替えの間隔。 */
private val FoldButtonSpacing = 8.dp

/**
 * 「ページング」画面の操作のパネル。畳むボタンと表示の形の切り替え、2 つの切り替え、
 * 「再読み込み」、説明の一行を縦に並べる。並びと文言は iOS Sample の `PagingControlPanel` とそろえる。
 *
 * @param layoutChoice 選択中の表示の形
 * @param onSelectLayout 表示の形が選ばれたときの処理
 * @param failsNextLoad 「次の読み込みを失敗させる」の値
 * @param onFailsNextLoadChange 「次の読み込みを失敗させる」を切り替えたときの処理
 * @param isEmpty 「中身を 0 件にする」の値
 * @param onIsEmptyChange 「中身を 0 件にする」を切り替えたときの処理
 * @param onReload 「再読み込み」を押したときの処理
 * @param onFold 畳むボタンを押したときの処理
 * @param modifier パネルに付ける修飾
 */
@Composable
fun PagingControlPanel(
    layoutChoice: PagingLayoutChoice,
    onSelectLayout: (PagingLayoutChoice) -> Unit,
    failsNextLoad: Boolean,
    onFailsNextLoadChange: (Boolean) -> Unit,
    isEmpty: Boolean,
    onIsEmptyChange: (Boolean) -> Unit,
    onReload: () -> Unit,
    onFold: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .pagingPanelSurface(RoundedCornerShape(PagingPanelMetrics.cornerRadius))
            .padding(
                horizontal = PagingPanelMetrics.horizontalPadding,
                vertical = PagingPanelMetrics.verticalPadding,
            ),
        verticalArrangement = Arrangement.spacedBy(PagingPanelMetrics.rowSpacing),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FoldButtonSpacing),
        ) {
            FoldButton(onFold = onFold)
            SampleSegmentedControl(
                modifier = Modifier
                    .weight(1f)
                    .semantics { contentDescription = PagingDemoText.LayoutPicker },
                options = PagingLayoutChoice.entries.map { it.title },
                selectedIndex = layoutChoice.ordinal,
                onSelect = { onSelectLayout(PagingLayoutChoice.entries[it]) },
            )
        }

        PagingToggle(text = PagingDemoText.FailsNextLoad, checked = failsNextLoad, onCheckedChange = onFailsNextLoadChange)
        PagingToggle(text = PagingDemoText.IsEmpty, checked = isEmpty, onCheckedChange = onIsEmptyChange)

        SampleBarButton(text = PagingDemoText.Reload, onClick = onReload, modifier = Modifier.fillMaxWidth())

        // 説明の一行。取り直しの失敗は画面の上の帯で知らせるため、ここは常に通常の文言。
        Text(
            text = PagingDemoText.Summary,
            style = MaterialTheme.typography.bodySmall,
            color = SampleTheme.secondaryText,
        )
    }
}

/** パネル左上の畳むボタン。 */
@Composable
private fun FoldButton(onFold: () -> Unit) {
    Box(
        modifier = Modifier
            .size(PagingPanelMetrics.foldButtonSize)
            .clip(CircleShape)
            .background(SampleTheme.background)
            .clickable(onClick = onFold)
            // 図案の文字ではなく、操作の名前を読み上げる。
            .clearAndSetSemantics {
                contentDescription = PagingDemoText.Fold
                role = Role.Button
                onClick { onFold(); true }
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "‹",
            style = MaterialTheme.typography.titleMedium,
            color = SampleTheme.accent,
        )
    }
}

/**
 * パネルの 1 行の切り替え。文言とスイッチをまとめて 1 つの切り替えとして扱う。
 *
 * @param text 文言
 * @param checked オンか
 * @param onCheckedChange 切り替えたときの処理
 */
@Composable
private fun PagingToggle(text: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .toggleable(value = checked, role = Role.Switch, onValueChange = onCheckedChange),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = SampleTheme.text,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            // 切り替えは行全体で受ける (文言を押しても切り替わる)。
            onCheckedChange = null,
            colors = SwitchDefaults.colors(
                checkedThumbColor = SampleTheme.onAccent,
                checkedTrackColor = SampleTheme.accent,
                checkedBorderColor = SampleTheme.accent,
            ),
        )
    }
}
