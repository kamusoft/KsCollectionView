package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import jp.kamusoft.kscollectionview.KsCollectionView

/**
 * 「ルートヘッダー/フッター」画面。コンテンツ全体の先頭と末尾に固定の内容を置く。
 */
@Composable
fun HeaderFooterDemoScreen(modifier: Modifier = Modifier) {
    KsCollectionView(
        items = DemoData.fruits,
        key = { it.id },
        modifier = modifier,
        header = { EdgeLabel(text = "ルートヘッダー") },
        footer = { EdgeLabel(text = "ルートフッター") },
    ) {
        template { item -> DemoListRow(item) }
    }
}

/** ヘッダーとフッターの見出し。 */
@Composable
private fun EdgeLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyLarge,
        color = SampleTheme.secondaryText,
        modifier = modifier
            .fillMaxWidth()
            .background(SampleTheme.background)
            .padding(SampleTheme.horizontalPadding),
    )
}
