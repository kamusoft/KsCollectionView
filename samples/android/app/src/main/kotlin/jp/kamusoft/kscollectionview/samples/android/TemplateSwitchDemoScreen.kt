package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView

/**
 * 「テンプレート切り替え」画面。要素の種別ごとに別のテンプレートで描く。
 */
@Composable
fun TemplateSwitchDemoScreen(modifier: Modifier = Modifier) {
    KsCollectionView(
        items = DemoData.templateItems,
        key = { it.id },
        modifier = modifier,
        template = { it.kind },
    ) {
        template(TemplateDemoKind.Message) { item ->
            Text(
                text = item.title,
                style = MaterialTheme.typography.bodyLarge,
                color = SampleTheme.text,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SampleTheme.cell)
                    .padding(SampleTheme.horizontalPadding),
            )
        }
        template(TemplateDemoKind.Notice) { item ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SampleTheme.cell)
                    .padding(SampleTheme.horizontalPadding),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                NoticeBadge()
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = SampleTheme.accent,
                )
            }
        }
    }
}

/** 注意を表す丸い印。読み上げの対象からは外す。 */
@Composable
private fun NoticeBadge(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(20.dp)
            .clearAndSetSemantics { }
            .background(color = SampleTheme.accent, shape = CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "!",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SampleTheme.onAccent,
        )
    }
}
