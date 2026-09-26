package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight

/**
 * ルートメニューの「外観」の 1 項目。選択中の項目にだけ印を付け、読み上げでは項目名に続けて
 * 「選択中」と読ませる。
 *
 * 選択の状態は Material の選択の意味づけ (selectable) では持たせない。持たせると選択中でない項目も
 * 「選択されていない」旨を読み上げ、iOS Sample の読み上げ (選択中の項目だけに「選択中」) とずれる。
 *
 * @param appearance この行が表す外観
 * @param isSelected 選択中かどうか
 * @param onClick 行が選ばれたときの処理
 */
@Composable
fun SampleAppearanceRow(appearance: SampleAppearance, isSelected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SampleTheme.cell)
            .clickable(onClick = onClick)
            .semantics {
                if (isSelected) stateDescription = SampleAppearance.SelectedStateDescription
            }
            .padding(
                horizontal = SampleTheme.horizontalPadding,
                vertical = SampleTheme.rowVerticalPadding,
            ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = appearance.title,
            style = MaterialTheme.typography.bodyLarge,
            color = SampleTheme.text,
        )
        Spacer(modifier = Modifier.weight(1f))
        if (isSelected) {
            // 印は見た目だけのもの。選択中であることは行の状態として読み上げる。
            Text(
                text = "✓",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                color = SampleTheme.accent,
                modifier = Modifier.clearAndSetSemantics { },
            )
        }
    }
    HorizontalDivider(color = SampleTheme.separator)
}
